Set-StrictMode -Version 2.0
function Invoke-NyxIsolatedCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CheckId,
        [Parameter(Mandatory=$true)][string]$Category,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][scriptblock]$Script,
        [string]$DataSource = ''
    )
    try {
        $value = & $Script
        if ($null -eq $value) {
            return New-NyxUnknownResult -CheckId $CheckId -Category $Category -Name $Name -Reason 'The check returned no result.' -DataSource $DataSource
        }
        return $value
    } catch {
        Write-NyxLog -Level 'WARN' -Message ("Check {0} failed: {1}" -f $CheckId,$_.Exception.Message)
        return New-NyxUnknownResult -CheckId $CheckId -Category $Category -Name $Name -Reason $_.Exception.Message -DataSource $DataSource
    }
}

function Get-NyxRequiredResultProperty {
    param([Parameter(Mandatory=$true)][object]$Result,[Parameter(Mandatory=$true)][string]$Name)
    $property=$Result.PSObject.Properties[$Name]
    if($null -eq $property){return $null}
    return $property.Value
}

function Convert-NyxScanResult {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Result,
        [string]$FallbackCheckId='',
        [string]$FallbackCategory='',
        [string]$FallbackName='',
        [string]$FallbackDataSource='',
        [switch]$NormalizeInvalid
    )
    $required=@('CheckId','Category','Name','Status','Severity','Finding','Reason','Recommendation','Complete')
    $valid=($null -ne $Result)
    if($valid){
        foreach($name in $required){if($null -eq $Result.PSObject.Properties[$name]){$valid=$false;break}}
    }
    if($valid){
        $checkId=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'CheckId')
        $category=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Category')
        $name=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Name')
        $status=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Status')
        $severity=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Severity')
        $completeValue=Get-NyxRequiredResultProperty -Result $Result -Name 'Complete'
        if([string]::IsNullOrWhiteSpace($checkId) -or [string]::IsNullOrWhiteSpace($category) -or [string]::IsNullOrWhiteSpace($name)){$valid=$false}
        if($status -notin @('Good','NeedsAttention','Optional','Unknown')){$valid=$false}
        if($severity -notin @('Info','Low','Medium','High')){$valid=$false}
        if($completeValue -isnot [bool]){$valid=$false}
    }
    if(-not $valid){
        if(-not $NormalizeInvalid){return $null}
        if([string]::IsNullOrWhiteSpace($FallbackCheckId)){$FallbackCheckId='scan.invalid-result'}
        if([string]::IsNullOrWhiteSpace($FallbackCategory)){$FallbackCategory='System'}
        if([string]::IsNullOrWhiteSpace($FallbackName)){$FallbackName='Incomplete check result'}
        return New-NyxUnknownResult -CheckId $FallbackCheckId -Category $FallbackCategory -Name $FallbackName `
            -Reason 'A check returned incomplete or unsupported data.' -DataSource $FallbackDataSource
    }
    $optional=@{}
    foreach($property in @('Evidence','ActionSafetyLevel','Timestamp','DataSource','RequiresElevation','ErrorReason','Details')){
        $member=$Result.PSObject.Properties[$property]
        $optional[$property]=if($null -eq $member){$null}else{$member.Value}
    }
    return [pscustomobject][ordered]@{
        CheckId=$checkId;Category=$category;Name=$name;Status=$status;Severity=$severity
        Finding=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Finding')
        Reason=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Reason')
        Evidence=$optional.Evidence
        Recommendation=[string](Get-NyxRequiredResultProperty -Result $Result -Name 'Recommendation')
        ActionSafetyLevel=if([string]::IsNullOrWhiteSpace([string]$optional.ActionSafetyLevel)){'None'}else{[string]$optional.ActionSafetyLevel}
        Timestamp=if([string]::IsNullOrWhiteSpace([string]$optional.Timestamp)){(Get-Date).ToUniversalTime().ToString('o')}else{[string]$optional.Timestamp}
        DataSource=[string]$optional.DataSource
        RequiresElevation=[bool]$optional.RequiresElevation
        Complete=[bool]$completeValue
        ErrorReason=[string]$optional.ErrorReason
        Details=$optional.Details
    }
}

function Convert-NyxPersistedScan {
    [CmdletBinding()]
    param([AllowNull()][object]$Scan,[switch]$AllowEmptyResults)
    if($null -eq $Scan){return $null}
    foreach($name in @('Schema','Mode','StartedUtc','CompletedUtc','Cancelled','ReadOnly','Results')){
        if($null -eq $Scan.PSObject.Properties[$name]){return $null}
    }
    if([string]$Scan.Schema -ne 'dietrich-ai-labs.nyx-pc-checkup.scan.v1'){return $null}
    if([string]$Scan.Mode -notin @('Quick','Full')){return $null}
    $startedUtc=[datetime]::MinValue
    $completedUtc=[datetime]::MinValue
    if(-not [datetime]::TryParse([string]$Scan.StartedUtc,[ref]$startedUtc)){return $null}
    if(-not [datetime]::TryParse([string]$Scan.CompletedUtc,[ref]$completedUtc)){return $null}
    if($Scan.Cancelled -isnot [bool]){return $null}
    if(($Scan.ReadOnly -isnot [bool]) -or (-not [bool]$Scan.ReadOnly)){return $null}
    if($null -eq $Scan.Results){return $null}
    $results=[System.Collections.Generic.List[object]]::new()
    foreach($candidate in @($Scan.Results)){
        $normalized=Convert-NyxScanResult -Result $candidate
        if($null -eq $normalized){return $null}
        [void]$results.Add($normalized)
    }
    if($results.Count -eq 0 -and -not $AllowEmptyResults){return $null}
    $summary=Get-NyxResultSummary -Results @($results.ToArray())
    return [pscustomobject][ordered]@{
        Schema='dietrich-ai-labs.nyx-pc-checkup.scan.v1'
        Mode=[string]$Scan.Mode
        StartedUtc=[string]$Scan.StartedUtc
        CompletedUtc=[string]$Scan.CompletedUtc
        Cancelled=[bool]$Scan.Cancelled
        ReadOnly=[bool]$Scan.ReadOnly
        Summary=$summary
        Results=@($results.ToArray())
    }
}

function Save-NyxScanResults {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Scan)
    $validated=Convert-NyxPersistedScan -Scan $Scan -AllowEmptyResults
    if($null -eq $validated){throw 'The scan result did not satisfy the persisted scan contract.'}
    $paths = Initialize-NyxDataDirectories
    $temp = "$($paths.LastScan).tmp"
    $validated | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $paths.LastScan -Force
}

function Get-NyxLastScan {
    $paths = Initialize-NyxDataDirectories
    if (-not (Test-Path -LiteralPath $paths.LastScan)) { return $null }
    try {
        $scan=Get-Content -LiteralPath $paths.LastScan -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $validated=Convert-NyxPersistedScan -Scan $scan
        if($null -eq $validated){Write-NyxLog -Level 'WARN' -Message 'Persisted scan state was rejected because it did not satisfy the current scan contract.'}
        return $validated
    } catch {
        Write-NyxLog -Level 'WARN' -Message 'Persisted scan state could not be read and was ignored.'
        return $null
    }
}

Export-ModuleMember -Function Invoke-NyxIsolatedCheck,Convert-NyxScanResult,Convert-NyxPersistedScan,Save-NyxScanResults,Get-NyxLastScan

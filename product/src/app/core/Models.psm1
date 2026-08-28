Set-StrictMode -Version 2.0

function New-NyxCheckResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CheckId,
        [Parameter(Mandatory=$true)][string]$Category,
        [Parameter(Mandatory=$true)][string]$Name,
        [ValidateSet('Good','NeedsAttention','Optional','Unknown')][string]$Status = 'Unknown',
        [ValidateSet('Info','Low','Medium','High')][string]$Severity = 'Info',
        [string]$Finding = '',
        [string]$Reason = '',
        [object]$Evidence = $null,
        [string]$Recommendation = '',
        [ValidateSet('None','SafeRedirect','ReversibleLocalChange','DestructiveAction')][string]$ActionSafetyLevel = 'None',
        [string]$DataSource = '',
        [bool]$RequiresElevation = $false,
        [bool]$Complete = $true,
        [string]$ErrorReason = '',
        [object]$Details = $null
    )

    return [pscustomobject][ordered]@{
        CheckId = $CheckId
        Category = $Category
        Name = $Name
        Status = $Status
        Severity = $Severity
        Finding = $Finding
        Reason = $Reason
        Evidence = $Evidence
        Recommendation = $Recommendation
        ActionSafetyLevel = $ActionSafetyLevel
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        DataSource = $DataSource
        RequiresElevation = $RequiresElevation
        Complete = $Complete
        ErrorReason = $ErrorReason
        Details = $Details
    }
}

function New-NyxUnknownResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CheckId,
        [Parameter(Mandatory=$true)][string]$Category,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Reason,
        [string]$DataSource = ''
    )
    return New-NyxCheckResult -CheckId $CheckId -Category $Category -Name $Name `
        -Status 'Unknown' -Severity 'Info' -Finding 'This check could not be completed.' `
        -Reason $Reason -Recommendation 'No automatic change was made. You can retry the check or review the technical details.' `
        -DataSource $DataSource -Complete $false -ErrorReason $Reason
}

function Get-NyxStatusLabel {
    param([string]$Status)
    switch ($Status) {
        'Good' { return 'Good' }
        'NeedsAttention' { return 'Needs Attention' }
        'Optional' { return 'Optional' }
        default { return 'Unknown / Could Not Check' }
    }
}

function Get-NyxStatusSymbol {
    param([string]$Status)
    switch ($Status) {
        'Good' { return [char]0x2713 }
        'NeedsAttention' { return '!' }
        'Optional' { return [char]0x25CB }
        default { return '?' }
    }
}

function Get-NyxResultSummary {
    [CmdletBinding()]
    param([object[]]$Results)

    $all = @($Results | Where-Object { $null -ne $_ })
    $needs = @($all | Where-Object { $_.Status -eq 'NeedsAttention' }).Count
    $optional = @($all | Where-Object { $_.Status -eq 'Optional' }).Count
    $unknown = @($all | Where-Object { $_.Status -eq 'Unknown' }).Count
    $good = @($all | Where-Object { $_.Status -eq 'Good' }).Count

    if ($needs -gt 0) {
        $overall = 'NeedsAttention'
        $headline = if ($needs -eq 1) { '1 thing needs attention.' } else { "$needs things need attention." }
    } elseif ($all.Count -eq 0 -or $unknown -eq $all.Count) {
        $overall = 'Unknown'
        $headline = 'The check could not determine enough information.'
    } else {
        $overall = 'Good'
        if ($optional -eq 0 -and $unknown -eq 0) {
            $headline = 'Your PC looks good. Nothing needs fixing.'
        } elseif ($optional -gt 0) {
            $headline = "Your PC looks good. $optional optional item$(if ($optional -eq 1) { '' } else { 's' }) available."
        } else {
            $headline = 'Your PC looks good. Some information could not be checked.'
        }
    }

    return [pscustomobject][ordered]@{
        OverallStatus = $overall
        Headline = $headline
        Good = $good
        NeedsAttention = $needs
        Optional = $optional
        Unknown = $unknown
        Total = $all.Count
    }
}

Export-ModuleMember -Function New-NyxCheckResult,New-NyxUnknownResult,Get-NyxStatusLabel,Get-NyxStatusSymbol,Get-NyxResultSummary

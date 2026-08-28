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

function Save-NyxScanResults {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Scan)
$paths = Initialize-NyxDataDirectories
    $temp = "$($paths.LastScan).tmp"
    $Scan | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $paths.LastScan -Force
}

function Get-NyxLastScan {
$paths = Initialize-NyxDataDirectories
    if (-not (Test-Path -LiteralPath $paths.LastScan)) { return $null }
    try { return (Get-Content -LiteralPath $paths.LastScan -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

Export-ModuleMember -Function Invoke-NyxIsolatedCheck,Save-NyxScanResults,Get-NyxLastScan

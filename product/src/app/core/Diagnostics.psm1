Set-StrictMode -Version 2.0
function Invoke-NyxLogRotation {
    $paths = Initialize-NyxDataDirectories
    $config = Get-NyxConfiguration
    $log = Join-Path $paths.Logs 'nyx-pc-checkup.log'
    if (Test-Path -LiteralPath $log) {
        $length = (Get-Item -LiteralPath $log).Length
        if ($length -ge [int64]$config.maxLogBytes) {
            for ($i = [int]$config.maxLogFiles - 1; $i -ge 1; $i--) {
                $source = "$log.$i"
                $dest = "$log.$($i + 1)"
                if (Test-Path -LiteralPath $source) { Move-Item -LiteralPath $source -Destination $dest -Force }
            }
            Move-Item -LiteralPath $log -Destination "$log.1" -Force
            $oldest = "$log.$([int]$config.maxLogFiles + 1)"
            if (Test-Path -LiteralPath $oldest) { Remove-Item -LiteralPath $oldest -Force -ErrorAction SilentlyContinue }
        }
    }
}

function Write-NyxLog {
    [CmdletBinding()]
    param(
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO',
        [Parameter(Mandatory=$true)][string]$Message
    )
    try {
        $config = Get-NyxConfiguration
        if ($Level -eq 'DEBUG' -and -not [bool]$config.developerLogging) { return }
        Invoke-NyxLogRotation
        $paths = Get-NyxPathMap
        $safe = Protect-NyxText -InputObject $Message
        $line = "{0} [{1}] {2}" -f (Get-Date).ToUniversalTime().ToString('o'),$Level,$safe
        Add-Content -LiteralPath (Join-Path $paths.Logs 'nyx-pc-checkup.log') -Value $line -Encoding UTF8
    } catch {
        # Logging failure must never crash the application.
    }
}

function Clear-NyxLogs {
    $paths = Initialize-NyxDataDirectories
    Get-ChildItem -LiteralPath $paths.Logs -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function Write-NyxLog,Clear-NyxLogs,Invoke-NyxLogRotation

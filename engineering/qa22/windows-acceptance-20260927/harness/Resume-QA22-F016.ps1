$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$evidence = Join-Path $env:LOCALAPPDATA ('NyxQA22Evidence\f016_' + (Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence | Out-Null
try {
    if ($env:USERNAME -ne 'Nyx') { throw 'Expected disposable Nyx profile' }
    if ($PSVersionTable.PSVersion.Major -ne 5) { throw 'Windows PowerShell 5.1 required' }
    $exe = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup\Nyx PC Checkup.exe'
    if (!(Test-Path -LiteralPath $exe)) { throw 'Installed app missing' }
    $observer = Start-Process -FilePath "$PSHOME\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Q22F019\Observe-QA22-Installed.ps1" -Evidence "' + $evidence + '"') -PassThru
    Start-Sleep -Seconds 3
    $statusPath = Join-Path $evidence 'OBSERVER_STATUS.json'
    if (!(Test-Path -LiteralPath $statusPath)) { throw 'Observer did not produce status' }
    $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    if ($status.Status -ne 'MONITORING') { throw 'Observer is not monitoring' }
    $app = Start-Process -FilePath $exe -PassThru
    @{Status='F016_READY';Build='2026.09.27-eng-qa22';ProductModified=$false;ObserverPid=$observer.Id;LauncherPid=$app.Id;PowerShell=$PSVersionTable.PSVersion.ToString();Evidence=$evidence} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'F016_RUN_STATUS.json') -Encoding UTF8
} catch {
    @{Status='EVIDENCE_HARNESS_BLOCKED';Error=$_.Exception.ToString();ProductModified=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'F016_RUN_STATUS.json') -Encoding UTF8
    throw
}

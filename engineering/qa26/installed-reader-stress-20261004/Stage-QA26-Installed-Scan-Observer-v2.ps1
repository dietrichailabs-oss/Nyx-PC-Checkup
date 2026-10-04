Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot ('scan_observer_stage_' + (Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $out | Out-Null
$vm = Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
if ($vm.Name -ne 'Nyx') { throw 'VM mismatch.' }
$drives = @(Get-VMHardDiskDrive -VM $vm)
if ($drives.Count -ne 1) { throw 'Expected one VM disk.' }
$diskPath = $drives[0].Path
$mounted = $false
$restart = $vm.State -eq 'Running'
try {
    if ($restart) {
        Stop-VM -VM $vm
        $deadline = (Get-Date).AddMinutes(3)
        while ((Get-VM -Id $vm.Id).State -ne 'Off') {
            if ((Get-Date) -gt $deadline) { throw 'Normal shutdown timed out.' }
            Start-Sleep -Seconds 2
        }
    }
    Mount-VHD -Path $diskPath -NoDriveLetter | Out-Null
    $mounted = $true
    $roots = @(Get-Disk | Where-Object Number -eq (Get-VHD -Path $diskPath).DiskNumber | Get-Partition | Get-Volume | ForEach-Object {
        if ($_.Path -and (Test-Path -LiteralPath (Join-Path $_.Path 'Q26F023')) -and (Test-Path -LiteralPath (Join-Path $_.Path 'Users\Nyx'))) { $_.Path }
    })
    if ($roots.Count -ne 1) { throw 'Ambiguous guest root.' }
    $root = $roots[0]
    $install = Join-Path $root 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
    if ((Get-FileHash -LiteralPath (Join-Path $install 'app\workers\ScanWorker.ps1')).Hash -ne '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79') { throw 'Worker mismatch.' }
    if ((Get-FileHash -LiteralPath (Join-Path $install 'app\NyxPCCheckup.ps1')).Hash -ne 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC') { throw 'Main mismatch.' }
    $data = Join-Path $root 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    Copy-Item -LiteralPath (Join-Path $data 'scans\last-scan.json') -Destination (Join-Path $out 'PRE_STAGE_LAST_SCAN_RAW.json')
    Copy-Item -LiteralPath (Join-Path $data 'logs') -Destination (Join-Path $out 'logs') -Recurse
    $source = Join-Path $PSScriptRoot 'QA26-Installed-Scan-Observer-v2.ps1'
    $target = Join-Path $root 'Q26EvidenceHarness\QA26-Installed-Scan-Observer-v2.ps1'
    if (Test-Path -LiteralPath $target) { throw 'Observer exists; refusing overwrite.' }
    Copy-Item -LiteralPath $source -Destination $target
    if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw 'Observer copy mismatch.' }
    $startup = Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\QA26-Installed-Scan-Observer.cmd'
    if (Test-Path -LiteralPath $startup) { throw 'Startup helper already exists.' }
    '@start "" /min "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\QA26-Installed-Scan-Observer-v2.ps1"' | Set-Content -LiteralPath $startup -Encoding ASCII
    [ordered]@{Status='STAGED';Utc=[DateTime]::UtcNow.ToString('o');ProductModified=$false;InstalledIdentityChecks=2;MonitorMinutes=30;ProgressReadShare='ReadWrite|Delete';StartupRemovalBeforeDownstreamRequired=$true;AuthoritativeHostValidationRequired=$true;ScanLoadFixtureCleanupPending=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    [ordered]@{Status='STAGING_ERROR';Error=$_.Exception.Message;ProductModified=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
    throw
} finally {
    if ($mounted) { Dismount-VHD -Path $diskPath }
    if ($restart -and (Get-VM -Id $vm.Id).State -eq 'Off') { Get-VM -Id $vm.Id | Start-VM }
}

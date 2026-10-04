Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot ('timing_collection_' + (Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $out | Out-Null
$vm = Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
if ($vm.Name -ne 'Nyx') { throw 'VM identity mismatch.' }
$drives = @(Get-VMHardDiskDrive -VM $vm)
if ($drives.Count -ne 1) { throw 'Expected one VM disk.' }
$diskPath = $drives[0].Path
$mounted = $false
$restart = $vm.State -eq 'Running'
function Find-GuestRoot {
    $roots = @(Get-Disk | Where-Object Number -eq (Get-VHD -Path $diskPath).DiskNumber | Get-Partition | Get-Volume | ForEach-Object {
        if ($_.Path -and (Test-Path -LiteralPath (Join-Path $_.Path 'Q26F023')) -and (Test-Path -LiteralPath (Join-Path $_.Path 'Users\Nyx'))) { $_.Path }
    })
    if ($roots.Count -ne 1) { throw 'Guest volume identity is ambiguous.' }
    return $roots[0]
}
try {
    if ($restart) {
        Stop-VM -VM $vm
        $deadline = (Get-Date).AddMinutes(3)
        while ((Get-VM -Id $vm.Id).State -ne 'Off') {
            if ((Get-Date) -gt $deadline) { throw 'Normal shutdown timed out.' }
            Start-Sleep -Seconds 2
        }
    }
    Mount-VHD -Path $diskPath -ReadOnly -NoDriveLetter | Out-Null
    $mounted = $true
    $root = Find-GuestRoot
    $timing = Join-Path $root 'Users\Nyx\AppData\Local\NyxQA26TimingBarrier'
    if (!(Test-Path -LiteralPath $timing)) { throw 'Timing evidence missing; cleanup refused.' }
    Copy-Item -LiteralPath $timing -Destination (Join-Path $out 'Timing') -Recurse
    $data = Join-Path $root 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    Copy-Item -LiteralPath (Join-Path $data 'scans\last-scan.json') -Destination (Join-Path $out 'LAST_SCAN_RAW.json')
    if (Test-Path -LiteralPath (Join-Path $data 'logs')) { Copy-Item -LiteralPath (Join-Path $data 'logs') -Destination (Join-Path $out 'logs') -Recurse }
    $install = Join-Path $root 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
    $checks = @(
        @{ Path='app\NyxPCCheckup.ps1'; Expected='BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC' },
        @{ Path='app\workers\ScanWorker.ps1'; Expected='6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79' }
    )
    foreach ($check in $checks) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $install $check.Path) -Algorithm SHA256).Hash
        if ($actual -ne $check.Expected) { throw ('Installed identity mismatch: ' + $check.Path) }
    }
    Dismount-VHD -Path $diskPath
    $mounted = $false
    Mount-VHD -Path $diskPath -NoDriveLetter | Out-Null
    $mounted = $true
    $root = Find-GuestRoot
    $startup = Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\QA26-Timing-Barrier.cmd'
    $expected = '@start "" /min "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\QA26-Timing-Barrier.ps1"'
    if (Test-Path -LiteralPath $startup) {
        if ([IO.File]::ReadAllText($startup).Trim() -ne $expected) { throw 'Timing startup content mismatch; removal refused.' }
        Remove-Item -LiteralPath $startup
    }
    [ordered]@{ Status='COLLECTED_READ_ONLY_AND_TIMING_AUTOSTART_REMOVED'; Utc=[DateTime]::UtcNow.ToString('o'); ProductModified=$false; InstalledIdentityChecks=2; LiveCleanupProofSource='Timing EVENTS.jsonl only, not shutdown inventory'; ScanLoadFixtureCleanupPending=$true } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    [ordered]@{ Status='COLLECTION_ERROR'; Error=$_.Exception.Message; ProductModified=$false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
    throw
} finally {
    if ($mounted) { Dismount-VHD -Path $diskPath }
    if ($restart -and (Get-VM -Id $vm.Id).State -eq 'Off') { Get-VM -Id $vm.Id | Start-VM }
}

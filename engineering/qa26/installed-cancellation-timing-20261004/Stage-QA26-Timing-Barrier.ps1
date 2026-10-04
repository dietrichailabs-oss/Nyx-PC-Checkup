Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$id = [guid]'275a191c-cf8a-4929-9849-b9a293e9149d'
$out = Join-Path $PSScriptRoot ('timing_barrier_stage_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $out | Out-Null
$mounted = $false
$restart = $false
$disk = $null
try {
    $vm = Get-VM -Id $id
    if ($vm.Name -ne 'Nyx') { throw 'Unexpected VM.' }
    $drives = @(Get-VMHardDiskDrive -VM $vm | Where-Object { $_.Path })
    if ($drives.Count -ne 1) { throw 'Expected a single Nyx VHD.' }
    $disk = $drives[0].Path
    if ($vm.State -ne 'Off') {
        Stop-VM -VM $vm
        $restart = $true
        $deadline = (Get-Date).AddMinutes(3)
        do { Start-Sleep -Seconds 2; $vm = Get-VM -Id $id } while ($vm.State -ne 'Off' -and (Get-Date) -lt $deadline)
        if ($vm.State -ne 'Off') { throw 'Normal shutdown did not complete.' }
    }
    Mount-VHD -Path $disk -NoDriveLetter | Out-Null
    $mounted = $true
    $roots = @()
    foreach ($partition in @(Get-Partition -DiskNumber (Get-VHD -Path $disk).DiskNumber)) {
        $volume = $partition | Get-Volume -ErrorAction SilentlyContinue
        if ($null -ne $volume -and $volume.Path -and (Test-Path -LiteralPath (Join-Path $volume.Path 'Q26F023')) -and (Test-Path -LiteralPath (Join-Path $volume.Path 'Users\Nyx'))) { $roots += $volume.Path }
    }
    if ($roots.Count -ne 1) { throw 'Unique frozen QA26 guest volume not found.' }
    $root = $roots[0]
    $installed = Join-Path $root 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
    if ((Get-FileHash -LiteralPath (Join-Path $installed 'app\workers\ScanWorker.ps1') -Algorithm SHA256).Hash -ne '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79') { throw 'Frozen worker mismatch.' }
    if ((Get-FileHash -LiteralPath (Join-Path $installed 'app\NyxPCCheckup.ps1') -Algorithm SHA256).Hash -ne 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC') { throw 'Frozen script mismatch.' }
    $helperRoot = Join-Path $root 'Q26EvidenceHarness'
    foreach ($name in 'QA26-Timing-Barrier.ps1', 'QA26-Timing-Watchdog.ps1') {
        $target = Join-Path $helperRoot $name
        if (Test-Path -LiteralPath $target) { throw ('Evidence helper already exists: ' + $name) }
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $target
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $name) -Algorithm SHA256).Hash) { throw 'Helper copy hash mismatch.' }
    }
    $startup = Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\QA26-Timing-Barrier.cmd'
    if (Test-Path -LiteralPath $startup) { throw 'Startup helper already exists; refusing to overwrite it.' }
    '@start "" /min "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\QA26-Timing-Barrier.ps1"' | Set-Content -LiteralPath $startup -Encoding ASCII
    [ordered]@{ Status = 'STAGED'; Utc = [DateTime]::UtcNow.ToString('o'); VM = $id.ToString(); ProductModified = $false; MaxWorkers = 2; HoldSeconds = 30; IndependentWatchdogSeconds = 45; StartupGuestPath = 'C:\Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\QA26-Timing-Barrier.cmd'; RemovalBeforeDownstreamSuites = $true } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    [ordered]@{ Status = 'STAGING_ERROR'; Utc = [DateTime]::UtcNow.ToString('o'); Error = $_.Exception.Message; ProductModified = $false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
    throw
} finally {
    if ($mounted) { Dismount-VHD -Path $disk }
    if ($restart) { Get-VM -Id $id | Start-VM | Out-Null }
}

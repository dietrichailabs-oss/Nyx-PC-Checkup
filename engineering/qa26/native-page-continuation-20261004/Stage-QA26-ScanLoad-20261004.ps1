Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$vmId = [guid]'275a191c-cf8a-4929-9849-b9a293e9149d'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$out = Join-Path $PSScriptRoot ('scan_load_stage_' + $stamp)
New-Item -ItemType Directory -Path $out | Out-Null
$disk = $null
$mounted = $false
$restart = $false
try {
    $vm = Get-VM -Id $vmId
    if ($vm.Name -ne 'Nyx') { throw 'Unexpected VM name.' }
    $drives = @(Get-VMHardDiskDrive -VM $vm | Where-Object { $_.Path })
    if ($drives.Count -ne 1) { throw 'Expected exactly one Nyx VHD.' }
    $disk = $drives[0].Path
    if ($vm.State -ne 'Off') {
        Stop-VM -VM $vm
        $restart = $true
        $deadline = (Get-Date).AddMinutes(3)
        do {
            Start-Sleep -Seconds 2
            $vm = Get-VM -Id $vmId
        } while ($vm.State -ne 'Off' -and (Get-Date) -lt $deadline)
        if ($vm.State -ne 'Off') { throw 'Guest did not shut down normally.' }
    }
    Mount-VHD -Path $disk -NoDriveLetter | Out-Null
    $mounted = $true
    $number = (Get-VHD -Path $disk).DiskNumber
    $roots = @()
    foreach ($partition in @(Get-Partition -DiskNumber $number)) {
        $volume = $partition | Get-Volume -ErrorAction SilentlyContinue
        if ($null -ne $volume -and $volume.Path) {
            $root = $volume.Path
            if ((Test-Path -LiteralPath (Join-Path $root 'Q26F023')) -and
                (Test-Path -LiteralPath (Join-Path $root 'Users\Nyx\Documents'))) {
                $roots += $root
            }
        }
    }
    if ($roots.Count -ne 1) { throw 'Cannot identify a unique QA26 guest volume.' }
    $root = $roots[0]
    $installed = Join-Path $root 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
    $required = @{
        'Nyx PC Checkup.exe' = '9B20E399C090EEAC78F6B257610EF915852A30BAA52BB31D7546C5783052CB75'
        'app\NyxPCCheckup.ps1' = 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC'
        'app\workers\ScanWorker.ps1' = '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79'
    }
    foreach ($entry in $required.GetEnumerator()) {
        if ((Get-FileHash -LiteralPath (Join-Path $installed $entry.Key) -Algorithm SHA256).Hash -ne $entry.Value) {
            throw ('Frozen installed identity mismatch: ' + $entry.Key)
        }
    }
    $data = Join-Path $root 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    Copy-Item -LiteralPath (Join-Path $data 'scans\last-scan.json') -Destination (Join-Path $out 'PRE_STAGE_LAST_SCAN.json')
    $logsOut = Join-Path $out 'logs'
    New-Item -ItemType Directory -Path $logsOut | Out-Null
    foreach ($log in @(Get-ChildItem -LiteralPath (Join-Path $data 'logs') -File)) {
        Copy-Item -LiteralPath $log.FullName -Destination $logsOut
    }
    $documents = [IO.Path]::GetFullPath((Join-Path $root 'Users\Nyx\Documents'))
    $fixture = [IO.Path]::GetFullPath((Join-Path $documents 'NyxQA26_ReadOnlyScanLoad_20261004'))
    if (-not $fixture.StartsWith($documents.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Fixture path escaped the disposable Documents directory.'
    }
    if (Test-Path -LiteralPath $fixture) { throw 'Fixture already exists; refusing to overwrite it.' }
    New-Item -ItemType Directory -Path $fixture | Out-Null
    $bytes = [Text.Encoding]::ASCII.GetBytes('QA26 disposable read-only scan workload. No personal data. Product files remain unchanged.' + "`r`n")
    $count = 25000
    for ($i = 0; $i -lt $count; $i++) {
        $name = 'fixture_{0:D5}.txt' -f $i
        [IO.File]::WriteAllBytes((Join-Path $fixture $name), $bytes)
    }
    [ordered]@{
        Status = 'STAGED'; Utc = [DateTime]::UtcNow.ToString('o'); VM = $vmId.ToString()
        FrozenSource = '0303a78a06f67252c86634cd73f1e4bda32dd3cc'; ProductModified = $false
        InstalledIdentityChecks = $required.Count; FixtureGuestPath = 'C:\Users\Nyx\Documents\NyxQA26_ReadOnlyScanLoad_20261004'
        Files = $count; BytesPerFile = $bytes.Length
        Purpose = 'Bounded disposable workload for actual installed Full Check cancellation/accessibility; not a modified worker or fabricated result.'
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    [ordered]@{ Status = 'STAGING_ERROR'; Error = $_.Exception.Message; Utc = [DateTime]::UtcNow.ToString('o'); ProductModified = $false } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
    throw
} finally {
    if ($mounted) { Dismount-VHD -Path $disk }
    if ($restart) { Get-VM -Id $vmId | Start-VM | Out-Null }
}

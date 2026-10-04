$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$out = Join-Path $PSScriptRoot ('unattended_collection_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $out | Out-Null
$vmId = [guid]'275a191c-cf8a-4929-9849-b9a293e9149d'
$mounted = $false
$vhdPath = $null
try {
    $vm = Get-VM -Id $vmId
    if ($vm.Name -ne 'Nyx') { throw 'Unexpected VM identity' }
    $drives = @(Get-VMHardDiskDrive -VM $vm)
    if ($drives.Count -ne 1) { throw 'Expected one guest disk' }
    $vhdPath = $drives[0].Path
    if ($vm.State -ne 'Off') {
        Stop-VM -VM $vm -Confirm:$false
        $deadline = [DateTime]::UtcNow.AddMinutes(3)
        while ((Get-VM -Id $vmId).State -ne 'Off') {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Normal shutdown timed out; no forced power-off' }
            Start-Sleep -Seconds 2
        }
    }
    $disk = Mount-VHD -Path $vhdPath -ReadOnly -NoDriveLetter -Passthru | Get-Disk
    $mounted = $true
    $roots = @()
    foreach ($partition in @(Get-Partition -DiskNumber $disk.Number)) {
        foreach ($volume in @($partition | Get-Volume -ErrorAction SilentlyContinue)) {
            if ($volume.Path -and (Test-Path -LiteralPath (Join-Path $volume.Path 'Q26F023')) -and (Test-Path -LiteralPath (Join-Path $volume.Path 'Users\Nyx'))) { $roots += $volume.Path }
        }
    }
    if ($roots.Count -ne 1) { throw 'Guest volume selection ambiguous' }
    $local = Join-Path $roots[0] 'Users\Nyx\AppData\Local'
    $install = Join-Path $local 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    Copy-Item -LiteralPath (Join-Path $install 'install-state.json') -Destination (Join-Path $out 'INSTALL_STATE_RAW.json')
    foreach ($name in @('NyxQA26Geometry','NyxQA26InstalledScanObserver','NyxQA26InstalledScanObserverV5')) {
        $path = Join-Path $local $name
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $out $name) -Recurse }
    }
    $data = Join-Path $local 'Dietrich AI Labs\Nyx PC Checkup'
    foreach ($name in @('scans','reports','logs')) {
        $path = Join-Path $data $name
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $out $name) -Recurse }
    }
    $hashes = @(Get-ChildItem -LiteralPath $install -File -Recurse | ForEach-Object {
        [pscustomobject]@{Path=$_.FullName.Substring($install.Length).TrimStart('\').Replace('\','/');Length=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    $hashes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'INSTALLED_HASHES.json') -Encoding UTF8
    [pscustomobject]@{Status='COLLECTED_READ_ONLY';Utc=[DateTime]::UtcNow.ToString('o');ProductModified=$false;InstalledFiles=$hashes.Count;LiveCleanupProof='Not established by offline collection; require pre-shutdown observer evidence';VhdMountedReadOnly=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $out 'COLLECTION_ERROR.txt') -Encoding UTF8
    throw
} finally {
    if ($mounted) { Dismount-VHD -Path $vhdPath }
    if ((Get-VM -Id $vmId).State -eq 'Off') { Get-VM -Id $vmId | Start-VM | Out-Null }
}

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$mounted = $false
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$collection = Join-Path (Split-Path $PSScriptRoot) ('qa22_native_evidence\F015_COLLECTION_' + $stamp)
New-Item -ItemType Directory -Path $collection | Out-Null
try {
    $vm = Get-VM -Name Nyx
    if ([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d') { throw 'VM identity mismatch' }
    if ($vm.State -eq 'Running') {
        $job = Stop-VM -VM $vm -AsJob
        if (!(Wait-Job $job -Timeout 90)) { throw 'Graceful shutdown timed out; no forced shutdown' }
        Receive-Job $job -ErrorAction Stop | Out-Null
    }
    if ((Get-VM -Name Nyx).State -ne 'Off') { throw 'VM must be off before mounting' }
    $vhd = Get-VMHardDiskDrive -VMName Nyx | Select-Object -First 1 -ExpandProperty Path
    $disk = Mount-VHD -Path $vhd -Passthru
    $mounted = $true
    $volumes = @($disk | Get-Disk | Get-Partition | Get-Volume | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019") })
    if ($volumes.Count -ne 1) { throw 'Ambiguous QA22 guest volume' }
    $drive = "$($volumes[0].DriveLetter):"
    Copy-Item -LiteralPath (Join-Path $drive 'Users\Nyx\AppData\Local\NyxQA22Evidence') -Destination (Join-Path $collection 'guest-evidence') -Recurse
    $data = Join-Path $drive 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    foreach ($name in @('logs','actions','scans')) {
        $path = Join-Path $data $name
        if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $collection $name) -Recurse }
    }
    $dest = Join-Path $drive 'Q22F019'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Run-QA22-F015-Fixture.ps1') -Destination $dest
    $link = Join-Path $drive 'ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\QA22 F019.lnk'
    $backup = Join-Path $dest ('PRESERVED_PRE_F015_' + $stamp + '.lnk')
    Copy-Item -LiteralPath $link -Destination $backup
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($link)
    $shortcut.Arguments = '-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q22F019\Run-QA22-F015-Fixture.ps1"'
    $shortcut.WindowStyle = 7
    $shortcut.Save()
    Dismount-VHD -Path $vhd
    $mounted = $false
    Start-VM -Name Nyx | Out-Null
    @{Status='STAGED_AND_STARTED';Collection=$collection;StartupBackup=$backup;ProductModified=$false;Utc=[DateTime]::UtcNow.ToString('o')} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'F015_STAGING_STATUS.json') -Encoding UTF8
} catch {
    @{Status='BLOCKED';Error=$_.Exception.ToString();Collection=$collection} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'F015_STAGING_STATUS.json') -Encoding UTF8
    throw
} finally { if ($mounted) { Dismount-VHD -Path $vhd } }

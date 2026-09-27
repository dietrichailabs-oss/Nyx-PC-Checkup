$ErrorActionPreference='Stop'
$mounted=$false
$status=Join-Path $PSScriptRoot 'F016_TIMING_HOST_STATUS.json'
try {
    $workspace=Split-Path $PSScriptRoot
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'Wrong VM'}
    if($vm.State -ne 'Off'){Stop-VM -VM $vm -Confirm:$false}
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'Guest did not stop gracefully'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx | Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -PassThru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019")})
    if($vol.Count -ne 1){throw 'Ambiguous guest disk'}
    $drive="$($vol[0].DriveLetter):"
    $dest="$drive\Q22F019"
    foreach($name in @('Run-QA22-F016-Timing.ps1','Complete-QA22-F016-Timing.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $dest}
    Copy-Item -LiteralPath (Join-Path $workspace 'qa22_clean_source_69fcb76bc1d2409b98c192680f99cf1f\dist\Nyx_PC_Checkup_1.0.0_Portable.zip') -Destination "$dest\QA22_FROZEN_PORTABLE.zip"
    $startup="$drive\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\QA22 F019.lnk"
    $backupName='PRESERVED_PRE_TIMING_'+(Get-Date -Format yyyyMMdd_HHmmss)+'.lnk'
    Copy-Item -LiteralPath $startup -Destination (Join-Path $dest $backupName)
    $shell=New-Object -ComObject WScript.Shell
    $shortcut=$shell.CreateShortcut($startup)
    $shortcut.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut.Arguments='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q22F019\Complete-QA22-F016-Timing.ps1"'
    $shortcut.WorkingDirectory='C:\Q22F019';$shortcut.WindowStyle=7;$shortcut.Save()
    Dismount-VHD -Path $vhd;$mounted=$false
    Start-VM -Name Nyx
    @{Status='TIMING_RUNNING';ProductModified=$false;StartupBackup=$backupName;Started=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status
    $deadline=(Get-Date).AddMinutes(6)
    while((Get-VM -Name Nyx).State -ne 'Off' -and (Get-Date) -lt $deadline){Start-Sleep -Seconds 3}
    if((Get-VM -Name Nyx).State -ne 'Off'){
        @{Status='GUEST_RETAINED_FOR_REVIEW';Reason='No verified-success shutdown within six minutes; no forced shutdown or product change';StartupBackup=$backupName} | ConvertTo-Json | Set-Content -LiteralPath $status
        return
    }
    $disk=Mount-VHD -Path $vhd -ReadOnly -PassThru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019")})
    if($vol.Count -ne 1){throw 'Ambiguous read-only guest disk'}
    $drive="$($vol[0].DriveLetter):"
    $guest=Join-Path "$drive\Users\Nyx\AppData\Local\NyxQA22Evidence" ((Get-ChildItem -LiteralPath "$drive\Users\Nyx\AppData\Local\NyxQA22Evidence" -Directory -Filter 'timing_*'|Sort-Object Name -Descending|Select-Object -First 1).Name)
    $out=Join-Path $workspace ('qa22_native_evidence\F016_TIMING_'+(Get-Date -Format yyyyMMdd_HHmmss))
    New-Item -ItemType Directory -Path $out | Out-Null
    Copy-Item -LiteralPath $guest -Destination "$out\guest" -Recurse
    $result=Get-Content -LiteralPath "$out\guest\RUN_STATUS.json" -Raw | ConvertFrom-Json
    Dismount-VHD -Path $vhd;$mounted=$false
    $disk=Mount-VHD -Path $vhd -PassThru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019")})
    if($vol.Count -ne 1){throw 'Ambiguous restore disk'}
    $drive="$($vol[0].DriveLetter):"
    Copy-Item -LiteralPath "$drive\Q22F019\$backupName" -Destination "$drive\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\QA22 F019.lnk" -Force
    Dismount-VHD -Path $vhd;$mounted=$false
    Start-VM -Name Nyx
    @{Status='TIMING_COLLECTED';GuestResult=$result.Status;Evidence=$out;ProductModified=$false;PreviousStartupRestored=$true} | ConvertTo-Json | Set-Content -LiteralPath $status
} catch {
    @{Status='HARNESS_BLOCKED';Error=$_.Exception.ToString();ProductModified=$false} | ConvertTo-Json | Set-Content -LiteralPath $status
} finally {if($mounted){Dismount-VHD -Path $vhd}}

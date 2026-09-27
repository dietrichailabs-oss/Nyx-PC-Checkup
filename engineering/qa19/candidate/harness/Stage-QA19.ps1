$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent $PSScriptRoot
$mounted=$false
try{
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch'}
    if($vm.State -ne 'Off'){throw 'Expected powered-off disposable VM; no changes made'}
    $recovery=Checkpoint-VM -VM $vm -SnapshotName ('QA18_FROZEN_BEFORE_QA19_'+(Get-Date -Format yyyyMMdd_HHmmss)) -Passthru
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -Passthru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Windows\System32")})
    if($vol.Count -ne 1){throw 'Guest volume ambiguous'}
    $drive="$($vol[0].DriveLetter):"
    $dest=Join-Path $drive 'Q19F016'
    if(Test-Path -LiteralPath $dest){throw 'QA19 staging exists; refusing overwrite'}
    New-Item -ItemType Directory -Path $dest|Out-Null
    foreach($name in @('Nyx_PC_Checkup_1.0.0_Setup.exe','Nyx_PC_Checkup_1.0.0_Portable.zip','Nyx_PC_Checkup_1.0.0_Source.zip')){Copy-Item -LiteralPath (Join-Path $workspace "qa19_f016_candidate_build\dist\$name") -Destination $dest}
    foreach($name in @('CANDIDATE_IDENTITY.json','Start-QA19-Guest.ps1','Test-QA19ProgressConcurrency.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $dest}
    $startup=Join-Path $drive 'ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp'
    $old=Join-Path $startup 'QA18 F015.lnk'
    if(Test-Path -LiteralPath $old){Move-Item -LiteralPath $old -Destination (Join-Path $dest 'PRESERVED_QA18_STARTUP.lnk')}
    $shell=New-Object -ComObject WScript.Shell
    $lnk=$shell.CreateShortcut((Join-Path $startup 'QA19 F016.lnk'))
    $lnk.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q19F016\Start-QA19-Guest.ps1"'
    $lnk.WorkingDirectory='C:\Q19F016';$lnk.Save()
    Dismount-VHD -Path $vhd;$mounted=$false
    Start-VM -Name Nyx
    [ordered]@{Status='STAGED_AND_STARTED';RecoveryCheckpoint=$recovery.Name;VHD=$vhd}|ConvertTo-Json|Set-Content "$PSScriptRoot\STAGING_STATUS.json"
}catch{[ordered]@{Status='BLOCKED';Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content "$PSScriptRoot\STAGING_STATUS.json"}finally{if($mounted){Dismount-VHD -Path $vhd}}

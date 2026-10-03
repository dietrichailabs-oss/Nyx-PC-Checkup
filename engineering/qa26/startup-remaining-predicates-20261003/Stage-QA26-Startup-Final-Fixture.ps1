$ErrorActionPreference='Stop'
$root='G:\Marks Apps 2\Nyx_PC_Checkup_1.0.0_Independent_QA5_HOLD_Master_Handoff(2)\qa26_vm_automation'
$mounted=$null
try{
 Import-Module Hyper-V
 $vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
 if($vm.Name -ne 'Nyx'){throw 'VM mismatch'}
 if($vm.State -ne 'Off'){Stop-VM -VM $vm -Confirm:$false;$limit=(Get-Date).AddMinutes(3);do{Start-Sleep 2;$vm=Get-VM -Id $vm.Id}until($vm.State -eq 'Off' -or (Get-Date) -gt $limit);if($vm.State -ne 'Off'){throw 'Shutdown timeout'}}
 $disks=@(Get-VMHardDiskDrive -VM $vm);if($disks.Count -ne 1){throw 'Disk not unique'}
 $mounted=Mount-VHD -Path $disks[0].Path -Passthru
 $roots=@($mounted|Get-Disk|Get-Partition|Get-Volume|Where-Object DriveLetter|ForEach-Object {"$($_.DriveLetter):\"}|Where-Object {(Test-Path -LiteralPath (Join-Path $_ 'Q26F023\QA26_CANDIDATE.json')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))})
 if($roots.Count -ne 1){throw 'Guest volume not unique'}
 $h=Join-Path $roots[0] 'Q26EvidenceHarness';New-Item -ItemType Directory -Path $h -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $root 'QA26-Startup-Final-Fixture.ps1') -Destination (Join-Path $h 'QA26-Startup-Final-Fixture.ps1')
 $startup=Join-Path $roots[0] 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\QA26_Startup_Final_Fixture.cmd'
 if(Test-Path -LiteralPath $startup){throw 'Startup helper exists; refusing overwrite'}
 '@start "" /min powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\QA26-Startup-Final-Fixture.ps1"'|Set-Content -LiteralPath $startup -Encoding ASCII
 @{Status='STAGED';ProductModified=$false;Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_FINAL_STAGING_STATUS.json')
}catch{@{Status='BLOCKED';Error=$_.ToString()}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_FINAL_STAGING_STATUS.json')}
finally{if($mounted){Dismount-VHD -Path $mounted.Path};if($vm -and (Get-VM -Id $vm.Id).State -eq 'Off'){Start-VM -VM $vm|Out-Null}}

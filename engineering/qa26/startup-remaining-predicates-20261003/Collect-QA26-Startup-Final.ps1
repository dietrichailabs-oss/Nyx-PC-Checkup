$ErrorActionPreference='Stop'
$root='G:\Marks Apps 2\Nyx_PC_Checkup_1.0.0_Independent_QA5_HOLD_Master_Handoff(2)\qa26_vm_automation'
$mounted=$null
try{
 Import-Module Hyper-V;$vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d';if($vm.Name -ne 'Nyx'){throw 'VM mismatch'}
 if($vm.State -ne 'Off'){Stop-VM -VM $vm -Confirm:$false;$limit=(Get-Date).AddMinutes(3);do{Start-Sleep 2;$vm=Get-VM -Id $vm.Id}until($vm.State -eq 'Off' -or (Get-Date) -gt $limit);if($vm.State -ne 'Off'){throw 'Shutdown timeout'}}
 $ds=@(Get-VMHardDiskDrive -VM $vm);if($ds.Count -ne 1){throw 'Disk not unique'}
 $mounted=Mount-VHD -Path $ds[0].Path -ReadOnly -Passthru
 $rs=@($mounted|Get-Disk|Get-Partition|Get-Volume|Where-Object DriveLetter|ForEach-Object {"$($_.DriveLetter):\"}|Where-Object {Test-Path -LiteralPath (Join-Path $_ 'Q26F023\QA26_CANDIDATE.json')});if($rs.Count -ne 1){throw 'Volume not unique'}
 $dest=Join-Path $root ('startup_final_collection_'+(Get-Date -Format yyyyMMdd_HHmmss));New-Item -ItemType Directory -Path $dest|Out-Null
 foreach($n in @('NyxQA26StartupFinal','Dietrich AI Labs\Nyx PC Checkup')){Copy-Item -LiteralPath (Join-Path $rs[0] ('Users\Nyx\AppData\Local\'+$n)) -Destination $dest -Recurse}
 @{Status='COLLECTED_READ_ONLY';Destination=$dest;Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_FINAL_COLLECTION_STATUS.json')
}catch{@{Status='BLOCKED';Error=$_.ToString()}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_FINAL_COLLECTION_STATUS.json')}
finally{if($mounted){Dismount-VHD -Path $mounted.Path};if($vm -and (Get-VM -Id $vm.Id).State -eq 'Off'){Start-VM -VM $vm|Out-Null}}

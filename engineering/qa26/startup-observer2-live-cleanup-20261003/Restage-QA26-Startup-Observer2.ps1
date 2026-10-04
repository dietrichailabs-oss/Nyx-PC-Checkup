$ErrorActionPreference='Stop'
$root='G:\Marks Apps 2\Nyx_PC_Checkup_1.0.0_Independent_QA5_HOLD_Master_Handoff(2)\qa26_vm_automation'
$mounted=$null
try{
 Import-Module Hyper-V;$vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d';if($vm.Name -ne 'Nyx'){throw 'VM mismatch'}
 if($vm.State -ne 'Off'){Stop-VM -VM $vm -Confirm:$false;$limit=(Get-Date).AddMinutes(3);do{Start-Sleep 2;$vm=Get-VM -Id $vm.Id}until($vm.State -eq 'Off' -or (Get-Date) -gt $limit);if($vm.State -ne 'Off'){throw 'Shutdown timeout'}}
 $ds=@(Get-VMHardDiskDrive -VM $vm);if($ds.Count -ne 1){throw 'Disk not unique'}
 $mounted=Mount-VHD -Path $ds[0].Path -Passthru
 $rs=@($mounted|Get-Disk|Get-Partition|Get-Volume|Where-Object DriveLetter|ForEach-Object {"$($_.DriveLetter):\"}|Where-Object {(Test-Path -LiteralPath (Join-Path $_ 'Q26F023\QA26_CANDIDATE.json')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))});if($rs.Count -ne 1){throw 'Volume not unique'}
 $source=Join-Path $root 'QA26-Startup-Final-Fixture.ps1';$target=Join-Path $rs[0] 'Q26EvidenceHarness\QA26-Startup-Final-Fixture.ps1'
 Copy-Item -LiteralPath $source -Destination $target
 $a=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash;$b=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash;if($a -ne $b){throw 'Observer copy hash mismatch'}
 @{Status='RESTAGED';Schema='QA26-STARTUP-LIVE-2';ProductModified=$false;ObserverSHA256=$a;Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_OBSERVER2_STAGING_STATUS.json')
}catch{@{Status='BLOCKED';Error=$_.ToString()}|ConvertTo-Json|Set-Content (Join-Path $root 'STARTUP_OBSERVER2_STAGING_STATUS.json')}
finally{if($mounted){Dismount-VHD -Path $mounted.Path};if($vm -and (Get-VM -Id $vm.Id).State -eq 'Off'){Start-VM -VM $vm|Out-Null}}

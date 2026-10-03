$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$workspace=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $workspace ('qa25_guest_evidence_'+(Get-Date -Format yyyyMMdd_HHmmss))
$status=Join-Path $PSScriptRoot 'COLLECTION_STATUS.json'
$mount=$null
function Write-Status([string]$State,[string]$Detail){
 @{State=$State;Detail=$Detail;Destination=$destination;Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath $status -Encoding UTF8
}
try{
 Write-Status 'Starting' 'Read-only collection after app closure; no product changes'
 Import-Module Hyper-V
 $vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
 if($vm.Name -ne 'Nyx'){throw 'Unexpected VM identity'}
 if($vm.State -eq 'Running'){
  Stop-VM -VM $vm -Confirm:$false
  $deadline=[DateTime]::UtcNow.AddMinutes(2)
  do{Start-Sleep -Seconds 2;$vm=Get-VM -Id $vm.Id}while($vm.State -ne 'Off' -and [DateTime]::UtcNow -lt $deadline)
 }
 if($vm.State -ne 'Off'){throw 'Graceful shutdown did not finish; no force attempted'}
 $drives=@(Get-VMHardDiskDrive -VM $vm)
 if($drives.Count -ne 1){throw 'Ambiguous VM disk configuration'}
 $mount=Mount-VHD -Path $drives[0].Path -ReadOnly -Passthru
 $disk=$mount|Get-Disk
 $roots=@(Get-Partition -DiskNumber $disk.Number|Where-Object DriveLetter|ForEach-Object {"$($_.DriveLetter):\"}|Where-Object {(Test-Path -LiteralPath (Join-Path $_ 'Windows\System32')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))})
 if($roots.Count -ne 1){throw 'Unique guest Windows volume not found; no repair or format attempted'}
 $guest=$roots[0]
 [void][IO.Directory]::CreateDirectory($destination)
 $evidence=Join-Path $guest 'Users\Nyx\AppData\Local\NyxQA25Evidence'
 if(-not (Test-Path -LiteralPath $evidence)){throw 'QA25 guest evidence directory missing'}
 Copy-Item -LiteralPath $evidence -Destination (Join-Path $destination 'guest-sessions') -Recurse
 $data=Join-Path $guest 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
 if(Test-Path -LiteralPath $data){Copy-Item -LiteralPath $data -Destination (Join-Path $destination 'app-data-at-collection') -Recurse}
 $installed=Join-Path $guest 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
 $records=@(foreach($file in Get-ChildItem -LiteralPath $installed -File -Recurse){[pscustomobject]@{Path=$file.FullName.Substring($installed.Length+1);Bytes=$file.Length;SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}})
 $records|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $destination 'INSTALLED_OFFLINE_HASHES.json') -Encoding UTF8
 @{VmId=[string]$vm.Id;VmName=$vm.Name;DiskMountedReadOnly=$true;Shutdown='Graceful';CollectedUtc=[DateTime]::UtcNow.ToString('o');Caveat='Offline inventory does not establish live pre-shutdown cleanup, DPI, or coordinate basis'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $destination 'COLLECTION.json') -Encoding UTF8
 Dismount-VHD -Path $drives[0].Path
 $mount=$null
 Write-Status 'Collected' 'Guest evidence collected; VM remains off to preserve session and avoid reinstall on login'
}catch{Write-Status 'Blocked' $_.Exception.ToString();throw}finally{if($null -ne $mount){Dismount-VHD -Path $mount.Path}}

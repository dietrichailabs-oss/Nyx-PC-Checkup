param([switch]$RestartAfterCollection)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $workspace ('qa24_guest_evidence_'+(Get-Date -Format yyyyMMdd_HHmmss))
$status=Join-Path $PSScriptRoot 'COLLECTION_STATUS.json'
$mount=$null
function Write-Status {param([string]$State,[string]$Detail) @{State=$State;Detail=$Detail;Destination=$destination;Utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8}
try{
    Write-Status 'Starting' 'Read-only guest evidence collection; application must already be closed'
    Import-Module Hyper-V
    $vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
    if($vm.Name -ne 'Nyx'){throw 'Unexpected VM identity'}
    if($vm.State -eq 'Running'){
        Stop-VM -VM $vm
        $deadline=(Get-Date).AddMinutes(2)
        do{Start-Sleep -Seconds 2;$vm=Get-VM -Id $vm.Id}while($vm.State -ne 'Off' -and (Get-Date) -lt $deadline)
    }
    if($vm.State -ne 'Off'){throw 'VM did not shut down normally; no forced shutdown attempted'}
    $drives=@(Get-VMHardDiskDrive -VM $vm)
    if($drives.Count -ne 1){throw 'Ambiguous VM disk configuration'}
    $mount=Mount-VHD -Path $drives[0].Path -ReadOnly -Passthru
    $disk=$mount | Get-Disk
    $roots=@(Get-Partition -DiskNumber $disk.Number | Where-Object DriveLetter | ForEach-Object {"$($_.DriveLetter):\"} | Where-Object {(Test-Path -LiteralPath (Join-Path $_ 'Windows\System32')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))})
    if($roots.Count -ne 1){throw 'Cannot identify mounted Windows volume; no formatting or repair attempted'}
    $guest=$roots[0]
    [void][IO.Directory]::CreateDirectory($destination)
    $evidence=Join-Path $guest 'Users\Nyx\AppData\Local\NyxQA24Evidence'
    if(-not (Test-Path -LiteralPath $evidence)){throw 'QA24 guest evidence directory is missing'}
    Copy-Item -LiteralPath $evidence -Destination (Join-Path $destination 'guest-sessions') -Recurse
    $data=Join-Path $guest 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    if(Test-Path -LiteralPath $data){Copy-Item -LiteralPath $data -Destination (Join-Path $destination 'app-data-at-collection') -Recurse}
    $installed=Join-Path $guest 'Users\Nyx\AppData\Local\Programs\Dietrich AI Labs\Nyx PC Checkup'
    $identities=foreach($file in Get-ChildItem -LiteralPath $installed -File -Recurse){
        [pscustomobject]@{Path=$file.FullName.Substring($installed.Length+1);Bytes=$file.Length;SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash}
    }
    $identities | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'INSTALLED_OFFLINE_HASHES.json') -Encoding UTF8
    @{VmId=[string]$vm.Id;VmName=$vm.Name;DiskMountedReadOnly=$true;Shutdown='Graceful';CollectedUtc=[DateTime]::UtcNow.ToString('o');Caveat='Offline inventory is not proof of live pre-shutdown cleanup. Use guest session records for live observations.'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'COLLECTION.json') -Encoding UTF8
    Dismount-VHD -Path $drives[0].Path
    $mount=$null
    $lines=Get-ChildItem -LiteralPath $destination -File -Recurse | Sort-Object FullName | ForEach-Object {('{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash,$_.FullName.Substring($destination.Length+1))}
    $lines | Set-Content -LiteralPath (Join-Path $destination 'SHA256SUMS.txt') -Encoding ASCII
    if($RestartAfterCollection){Start-VM -VM $vm}
    Write-Status 'Collected' 'Guest evidence copied from a read-only mount; product files not modified'
}catch{Write-Status 'Blocked' $_.Exception.ToString();throw}finally{if($null -ne $mount){Dismount-VHD -Path $mount.Path}}

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Import-Module Hyper-V
$vm=Get-VM -Name 'Nyx'
if($vm.Id.ToString() -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'Unexpected VM identity'}
if($vm.State -ne 'Off'){
    Stop-VM -VM $vm
    $limit=(Get-Date).AddMinutes(3)
    while((Get-VM -Id $vm.Id).State -ne 'Off'){
        if((Get-Date)-gt $limit){throw 'Normal shutdown timed out'}
        Start-Sleep -Seconds 2
    }
}
$drives=@(Get-VMHardDiskDrive -VM $vm)
if($drives.Count-ne 1){throw 'Expected exactly one VM disk'}
$diskPath=$drives[0].Path
$destination=Join-Path $PSScriptRoot ('geometry_collection_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
$mounted=$false
try{
    $vhd=Mount-VHD -Path $diskPath -ReadOnly -PassThru
    $mounted=$true
    $roots=@($vhd|Get-Disk|Get-Partition|Get-Volume|Where-Object DriveLetter|ForEach-Object{$_.DriveLetter.ToString()+':\'}|Where-Object{(Test-Path -LiteralPath (Join-Path $_ 'Windows'))-and(Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))})
    if($roots.Count-ne 1){throw 'Could not uniquely identify Nyx guest volume'}
    $local=Join-Path $roots[0] 'Users\Nyx\AppData\Local'
    New-Item -ItemType Directory -Path $destination|Out-Null
    foreach($name in @('NyxQA26Geometry','NyxQA26Evidence','Dietrich AI Labs\Nyx PC Checkup')){
        $source=Join-Path $local $name
        if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination $destination -Recurse}
    }
    [pscustomobject]@{Status='COLLECTED_READ_ONLY';Utc=[DateTime]::UtcNow.ToString('o');Destination=$destination;VM=$vm.Id.ToString()}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'GEOMETRY_COLLECTION_STATUS.json') -Encoding UTF8
}finally{
    if($mounted){Dismount-VHD -Path $diskPath}
    Start-VM -VM $vm|Out-Null
}

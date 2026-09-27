$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$workspace=Split-Path $PSScriptRoot
$output=Join-Path $workspace ('qa23_native_evidence\FAILURE_COLLECTION_'+(Get-Date -Format yyyyMMdd_HHmmss))
$statusPath=Join-Path $PSScriptRoot 'FAILURE_COLLECTION_STATUS.json'
$mounted=$false
New-Item -ItemType Directory -Path $output|Out-Null
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'Unexpected VM identity'}
    if($vm.State -eq 'Running'){
        $job=Stop-VM -VM $vm -AsJob
        if(!(Wait-Job $job -Timeout 90)){throw 'Graceful shutdown timed out; no forced shutdown attempted'}
        Receive-Job $job -ErrorAction Stop|Out-Null
    }
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'Guest must be off before read-only collection'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -ReadOnly -Passthru
    $mounted=$true
    $volumes=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q23F020")})
    if($volumes.Count -ne 1){throw 'Guest evidence volume is ambiguous'}
    $drive="$($volumes[0].DriveLetter):"
    $local=Join-Path $drive 'Users\Nyx\AppData\Local'
    $sessions=Join-Path $local 'NyxQA23Evidence'
    if(!(Test-Path -LiteralPath $sessions)){throw 'QA23 guest evidence missing'}
    Copy-Item -LiteralPath $sessions -Destination (Join-Path $output 'guest-sessions') -Recurse
    $data=Join-Path $local 'Dietrich AI Labs\Nyx PC Checkup'
    $state=Join-Path $output 'app-state'
    New-Item -ItemType Directory -Path $state|Out-Null
    foreach($name in @('config.json','logs','actions','scans\last-scan.json')){
        $path=Join-Path $data $name
        if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination $state -Recurse}
    }
    $install=Join-Path $local 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $hashes=@(Get-ChildItem -LiteralPath $install -File -Recurse|Sort-Object FullName|ForEach-Object {
        [pscustomobject]@{Path=$_.FullName.Substring($install.Length+1).Replace('\','/');Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    })
    $hashes|ConvertTo-Json -Depth 4|Set-Content -LiteralPath (Join-Path $output 'INSTALLED_AFTER_SHA256.json') -Encoding UTF8
    foreach($name in @('CANDIDATE_IDENTITY.json','Start-QA23-Guest.ps1','Observe-Installed.ps1')){
        Copy-Item -LiteralPath (Join-Path $drive ('Q23F020\'+$name)) -Destination $output
    }
    [ordered]@{Status='COLLECTED_READ_ONLY';VMId=[string]$vm.Id;GuestUser='Nyx';GuestLeftOff=$true;MountReadOnly=$true;CollectionUtc=[DateTime]::UtcNow.ToString('o');LiveCleanupClaimed=$false;Note='Post-shutdown collection is not substituted for live cleanup proof.'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $output 'COLLECTION.json') -Encoding UTF8
    Dismount-VHD -Path $vhd
    $mounted=$false
    @{Status='COLLECTED_VM_LEFT_OFF';Evidence=$output;ProductModified=$false}|ConvertTo-Json|Set-Content -LiteralPath $statusPath -Encoding UTF8
}catch{
    @{Status='BLOCKED';Evidence=$output;Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content -LiteralPath $statusPath -Encoding UTF8
    throw
}finally{if($mounted){Dismount-VHD -Path $vhd}}

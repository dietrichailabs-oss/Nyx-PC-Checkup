$ErrorActionPreference='Stop'
$mounted=$false
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch'}
    if($vm.State -eq 'Running'){
        $job=Stop-VM -VM $vm -AsJob -Confirm:$false
        if(-not (Wait-Job -Job $job -Timeout 90)){throw 'Graceful shutdown timed out; no disk mount attempted'}
        Receive-Job -Job $job -ErrorAction Stop|Out-Null
    }
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'VM must be off for read-only evidence collection'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -ReadOnly -Passthru;$mounted=$true
    $volumes=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q18F015")})
    if($volumes.Count -ne 1){throw 'Ambiguous guest staging location'}
    $drive="$($volumes[0].DriveLetter):"
    $root=Join-Path $drive 'Q18F015'
    $dest=Join-Path (Split-Path -Parent $PSScriptRoot) ('qa18_native_evidence\F015_'+(Get-Date -Format yyyyMMdd_HHmmss))
    New-Item -ItemType Directory -Path $dest|Out-Null
    Get-ChildItem -LiteralPath $root -Directory|Where-Object Name -like 'evidence*'|ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse}
    Copy-Item -LiteralPath (Join-Path $root 'CANDIDATE_IDENTITY.json') -Destination $dest
    $data=Join-Path $drive 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    New-Item -ItemType Directory -Path "$dest\application-data"|Out-Null
    foreach($name in @('logs','scans','temp')){if(Test-Path -LiteralPath (Join-Path $data $name)){Copy-Item -LiteralPath (Join-Path $data $name) -Destination "$dest\application-data" -Recurse}}
    Dismount-VHD -Path $vhd;$mounted=$false
    [ordered]@{Status='COLLECTED';Path=$dest;VMState='Off';ReadOnlyMount=$true}|ConvertTo-Json|Set-Content "$PSScriptRoot\COLLECTION_STATUS.json"
}catch{[ordered]@{Status='BLOCKED';Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content "$PSScriptRoot\COLLECTION_STATUS.json"}finally{if($mounted){Dismount-VHD -Path $vhd}}

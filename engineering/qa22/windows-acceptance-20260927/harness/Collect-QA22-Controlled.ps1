$ErrorActionPreference='Stop'
$mounted=$false
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'Wrong VM'}
    if($vm.State -ne 'Off'){Stop-VM -VM $vm -Confirm:$false}
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'Guest not safely off'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -ReadOnly -Passthru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019")})
    if($vol.Count -ne 1){throw 'Ambiguous guest volume'}
    $drive="$($vol[0].DriveLetter):"
    $out=Join-Path (Split-Path $PSScriptRoot) ('qa22_native_evidence\F019_COMPLETE_COLLECTION_'+(Get-Date -Format yyyyMMdd_HHmmss))
    New-Item -ItemType Directory -Path $out|Out-Null
    Copy-Item -LiteralPath "$drive\Users\Nyx\AppData\Local\NyxQA22Evidence" -Destination "$out\guest-evidence" -Recurse
    Copy-Item -LiteralPath "$drive\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup\logs" -Destination "$out\logs" -Recurse
    Copy-Item -LiteralPath "$drive\Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup\scans\last-scan.json" -Destination "$out\LAST_SCAN.json"
    Dismount-VHD -Path $vhd;$mounted=$false
    Start-VM -Name Nyx
    @{Status='COLLECTED_AND_RESTARTED';Evidence=$out;Method='Read-only offline copy after UI close and graceful shutdown';ProductModified=$false}|ConvertTo-Json|Set-Content "$PSScriptRoot\CONTROLLED_COLLECTION_STATUS.json"
}catch{@{Status='BLOCKED';Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content "$PSScriptRoot\CONTROLLED_COLLECTION_STATUS.json"}finally{if($mounted){Dismount-VHD -Path $vhd}}

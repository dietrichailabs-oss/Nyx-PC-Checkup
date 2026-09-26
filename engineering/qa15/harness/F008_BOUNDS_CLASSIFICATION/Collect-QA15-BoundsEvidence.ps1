$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $workspace ('qa15_native_evidence\F008_BOUNDS_CLASSIFICATION_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
$status=Join-Path $PSScriptRoot 'QA15_BOUNDS_COLLECTION.json'
$mounted=$false
try {
    New-Item -ItemType Directory -Path $destination | Out-Null
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id-ne'275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch.'}
    if($vm.State-ne'Off'){
        $job=Stop-VM -VM $vm -AsJob -Confirm:$false
        $completed=Wait-Job -Job $job -Timeout 45
        if(-not$completed){throw 'Guest shutdown did not complete within 45 seconds; disk was not mounted.'}
        Receive-Job -Job $job -ErrorAction Stop | Out-Null
    }
    if((Get-VM -Name Nyx).State-ne'Off'){throw 'Guest must be off for evidence collection.'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx | Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -ReadOnly -Passthru
    $mounted=$true
    $volumes=@($disk | Get-Disk | Get-Partition | Get-Volume | Where-Object {$_.DriveLetter-and(Test-Path "$($_.DriveLetter):\Q15Bounds\evidence")})
    if($volumes.Count-ne1){throw 'Exactly one guest evidence volume required.'}
    $source="$($volumes[0].DriveLetter):\Q15Bounds\evidence"
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
    [ordered]@{Status='COLLECTED';Destination=$destination;VHD=$vhd;ReadOnly=$true;RecordedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8
} catch {
    [ordered]@{Status='BLOCKED';Destination=$destination;Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8
} finally {if($mounted){Dismount-VHD -Path $vhd}}

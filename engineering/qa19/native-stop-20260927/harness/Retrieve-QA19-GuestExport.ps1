$ErrorActionPreference='Stop'
$mounted=$false
try{
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch'}
    if($vm.State -eq 'Running'){
        $job=Stop-VM -VM $vm -AsJob
        if(-not(Wait-Job -Job $job -Timeout 90)){throw 'Graceful shutdown timed out; no forced shutdown'}
        Receive-Job -Job $job -ErrorAction Stop|Out-Null
    }
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'VM is not off'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -ReadOnly -Passthru;$mounted=$true
    $vol=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q19F016")})
    if($vol.Count -ne 1){throw 'Ambiguous QA19 volume'}
    $source="$($vol[0].DriveLetter):\Users\Nyx\AppData\Local\NyxQA19Exports"
    $identityFile=Get-ChildItem -LiteralPath $source -File -Filter '*.zip.identity.json'|Sort-Object Name -Descending|Select-Object -First 1
    if(-not $identityFile){throw 'No completed guest export identity found; preserve guest export diagnostics'}
    $identity=Get-Content -LiteralPath $identityFile.FullName -Raw|ConvertFrom-Json
    $zip=Join-Path $source ([IO.Path]::GetFileName($identity.Path))
    if((Get-Item -LiteralPath $zip).Length -ne $identity.Bytes -or (Get-FileHash -LiteralPath $zip).Hash -ne $identity.SHA256){throw 'Guest archive identity mismatch'}
    $dest=Join-Path (Split-Path $PSScriptRoot) ('qa19_native_evidence\GUEST_EXPORT_'+(Get-Date -Format yyyyMMdd_HHmmss))
    New-Item -ItemType Directory -Path $dest|Out-Null
    Copy-Item -LiteralPath $zip,$identityFile.FullName -Destination $dest
    $local=Join-Path $dest ([IO.Path]::GetFileName($zip))
    if((Get-FileHash -LiteralPath $local).Hash -ne $identity.SHA256){throw 'Copied archive mismatch'}
    Dismount-VHD -Path $vhd;$mounted=$false
    @{Status='RETRIEVED';Path=$local;SHA256=$identity.SHA256;Bytes=$identity.Bytes;ProductModified=$false;VMState='Off';CleanupEvidence='Recorded by guest before shutdown, not inferred from offline disk'}|ConvertTo-Json|Set-Content "$PSScriptRoot\GUEST_EXPORT_RETRIEVAL_STATUS.json"
}catch{@{Status='BLOCKED';Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content "$PSScriptRoot\GUEST_EXPORT_RETRIEVAL_STATUS.json"}finally{if($mounted){Dismount-VHD -Path $vhd}}

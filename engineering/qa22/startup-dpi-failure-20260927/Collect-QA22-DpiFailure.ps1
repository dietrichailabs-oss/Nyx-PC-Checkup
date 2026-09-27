$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$mounted=$false
$output=Join-Path (Split-Path $PSScriptRoot) ('qa22_native_evidence\DPI_FAILURE_COLLECTION_'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $output|Out-Null
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch'}
    if($vm.State -eq 'Running'){
        $job=Stop-VM -VM $vm -AsJob
        if(!(Wait-Job $job -Timeout 90)){throw 'Graceful shutdown timeout; no forced shutdown'}
        Receive-Job $job -ErrorAction Stop|Out-Null
    }
    if((Get-VM -Name Nyx).State -ne 'Off'){throw 'VM not off'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx|Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -Passthru
    $mounted=$true
    $volumes=@($disk|Get-Disk|Get-Partition|Get-Volume|Where-Object {$_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019")})
    if($volumes.Count -ne 1){throw 'Ambiguous QA22 volume'}
    $drive="$($volumes[0].DriveLetter):"
    $guestRoot=Join-Path $drive 'Users\Nyx\AppData\Local\NyxQA22Evidence'
    $session=Get-ChildItem -LiteralPath $guestRoot -Directory -Filter 'f015_*'|Sort-Object Name|Select-Object -Last 1
    if(!$session){throw 'F015 evidence missing'}
    Copy-Item -LiteralPath $session.FullName -Destination (Join-Path $output 'guest-session') -Recurse
    $data=Join-Path $drive 'Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup'
    foreach($name in @('config','logs','actions')){
        $path=Join-Path $data $name
        if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination (Join-Path $output $name) -Recurse}
    }
    $backup=Join-Path $drive 'Q22F019\PRESERVED_PRE_F015_20260927_163351.lnk'
    $link=Join-Path $drive 'ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\QA22 F019.lnk'
    if(!(Test-Path -LiteralPath $backup)){throw 'Preserved startup shortcut missing'}
    Copy-Item -LiteralPath $backup -Destination $link -Force
    Dismount-VHD -Path $vhd
    $mounted=$false
    @{Status='COLLECTED_VM_LEFT_OFF';Evidence=$output;GuestSession=$session.Name;ProductModified=$false;StartupWrapperRestored=$true;Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'DPI_FAILURE_COLLECTION_STATUS.json') -Encoding UTF8
} catch {
    @{Status='BLOCKED';Evidence=$output;Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $PSScriptRoot 'DPI_FAILURE_COLLECTION_STATUS.json') -Encoding UTF8
    throw
} finally {if($mounted){Dismount-VHD -Path $vhd}}

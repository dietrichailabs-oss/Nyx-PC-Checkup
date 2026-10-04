$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$out=Join-Path $PSScriptRoot ('scan_observer_v3_stage_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $out | Out-Null
$vmId=[guid]'275a191c-cf8a-4929-9849-b9a293e9149d'
$mounted=$false
$vhdPath=$null
try {
    $vm=Get-VM -Id $vmId
    if($vm.Name-ne 'Nyx'){throw 'Unexpected VM'}
    $drives=@(Get-VMHardDiskDrive -VM $vm)
    if($drives.Count-ne 1){throw 'Expected one guest disk'}
    $vhdPath=$drives[0].Path
    if($vm.State-ne 'Off') {
        Stop-VM -VM $vm -Confirm:$false
        $deadline=[DateTime]::UtcNow.AddMinutes(3)
        while((Get-VM -Id $vmId).State-ne 'Off'){if([DateTime]::UtcNow-gt $deadline){throw 'Normal shutdown timed out'};Start-Sleep -Seconds 2}
    }
    $disk=Mount-VHD -Path $vhdPath -NoDriveLetter -Passthru | Get-Disk
    $mounted=$true
    $roots=@()
    foreach($partition in @(Get-Partition -DiskNumber $disk.Number)) {
        foreach($volume in @($partition|Get-Volume -ErrorAction SilentlyContinue)) {
            if($volume.Path-and(Test-Path -LiteralPath (Join-Path $volume.Path 'Q26F023'))-and(Test-Path -LiteralPath (Join-Path $volume.Path 'Users\Nyx'))){$roots+=$volume.Path}
        }
    }
    if($roots.Count-ne 1){throw 'Guest volume ambiguous'}
    $root=$roots[0]
    $local=Join-Path $root 'Users\Nyx\AppData\Local'
    $install=Join-Path $local 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $checks=@{'app\NyxPCCheckup.ps1'='BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC';'app\workers\ScanWorker.ps1'='6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79';'Nyx PC Checkup.exe'='9B20E399C090EEAC78F6B257610EF915852A30BAA52BB31D7546C5783052CB75'}
    foreach($check in $checks.GetEnumerator()){if((Get-FileHash -LiteralPath (Join-Path $install $check.Key) -Algorithm SHA256).Hash-ne $check.Value){throw 'Frozen installed identity mismatch'}}
    $guestHarness=Join-Path $root 'Q26EvidenceHarness'
    $source=Join-Path $PSScriptRoot 'QA26-Installed-Scan-Observer-v3.ps1'
    $target=Join-Path $guestHarness 'QA26-Installed-Scan-Observer-v3.ps1'
    if(Test-Path -LiteralPath $target){throw 'Existing v3 observer; refusing overwrite'}
    $startup=Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    $oldLine='@start "" /min "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\QA26-Installed-Scan-Observer-v2.ps1"'
    $removed=@()
    foreach($cmd in @(Get-ChildItem -LiteralPath $startup -File -Filter '*.cmd')) {
        $content=[IO.File]::ReadAllText($cmd.FullName)
        if($content.Contains('QA26-Installed-Scan-Observer-v2.ps1')) {
            if($content.Trim()-cne $oldLine){throw 'Unexpected v2 autostart content; refusing removal'}
            Copy-Item -LiteralPath $cmd.FullName -Destination (Join-Path $out $cmd.Name)
            Remove-Item -LiteralPath $cmd.FullName
            $removed+=$cmd.Name
        }
    }
    $cmdPath=Join-Path $startup 'NyxQA26InstalledScanObserverV3.cmd'
    if(Test-Path -LiteralPath $cmdPath){throw 'Existing v3 autostart; refusing overwrite'}
    Copy-Item -LiteralPath $source -Destination $target
    if((Get-FileHash -LiteralPath $source).Hash-ne(Get-FileHash -LiteralPath $target).Hash){throw 'Observer copy hash mismatch'}
    $newLine=$oldLine.Replace('QA26-Installed-Scan-Observer-v2.ps1','QA26-Installed-Scan-Observer-v3.ps1')
    [IO.File]::WriteAllText($cmdPath,$newLine+[Environment]::NewLine,[Text.Encoding]::ASCII)
    [pscustomobject]@{Status='STAGED';Utc=[DateTime]::UtcNow.ToString('o');ProductModified=$false;InstalledIdentityChecks=3;RemovedExactV2Autostarts=$removed;MonitorMinutes=30;NewObserver='QA26-Installed-Scan-Observer-v3.ps1';DownstreamAutostartRemovalRequired=$true} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'STATUS.json') -Encoding UTF8
} catch {
    $_|Out-String|Set-Content -LiteralPath (Join-Path $out 'STAGING_ERROR.txt') -Encoding UTF8
    throw
} finally {
    if($mounted){Dismount-VHD -Path $vhdPath}
    if((Get-VM -Id $vmId).State-eq 'Off'){Get-VM -Id $vmId|Start-VM|Out-Null}
}

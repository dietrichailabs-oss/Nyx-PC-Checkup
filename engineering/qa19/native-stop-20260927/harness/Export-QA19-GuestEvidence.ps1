Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$exportRoot=Join-Path $env:LOCALAPPDATA 'NyxQA19Exports'
$stamp=Get-Date -Format yyyyMMdd_HHmmss
$dest=Join-Path $exportRoot ('QA19_GUEST_EVIDENCE_'+$stamp)
New-Item -ItemType Directory -Path $dest -Force|Out-Null
try{
    $workers=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -match 'ScanWorker\.ps1'}|Select-Object ProcessId,ParentProcessId,CommandLine)
    if($workers.Count){$workers|ConvertTo-Json -Depth 4|Set-Content "$dest\ACTIVE_WORKERS.json";throw 'Scan worker still running; export stopped without stopping the worker.'}
    $observers=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.ProcessId -ne $PID -and $_.CommandLine -match '-File\s+"?C:\\Q19F016\\Observe-QA19-Installed\.ps1"?(?:\s|$)'})
    $observers|Select-Object ProcessId,CommandLine|ConvertTo-Json|Set-Content "$dest\OBSERVER_PROCESSES.json"
    foreach($observer in $observers){Stop-Process -Id $observer.ProcessId -ErrorAction Stop;Wait-Process -Id $observer.ProcessId -Timeout 10 -ErrorAction SilentlyContinue}
    $data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
    $temp=Join-Path $data 'temp'
    $remaining=@(if(Test-Path -LiteralPath $temp){Get-ChildItem -LiteralPath $temp -File -Filter 'scan-*'|Select-Object Name,Length,LastWriteTimeUtc})
    $workersAfter=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -match 'ScanWorker\.ps1'}|Select-Object ProcessId,CommandLine)
    [ordered]@{Time=(Get-Date).ToString('o');Computer=$env:COMPUTERNAME;User=$env:USERNAME;PowerShell=$PSVersionTable.PSVersion.ToString();GuestRunning=$true;CapturedBeforeShutdown=$true;WorkerCount=$workersAfter.Count;Workers=$workersAfter;ScanArtifacts=$remaining;ScanArtifactsAbsent=($remaining.Count -eq 0);ProductModified=$false;ObserverProcessesStopped=$observers.Count;HandleDeletionTest='Not independently exercised; absence records actual product cleanup, not a synthetic deletion test'}|ConvertTo-Json -Depth 6|Set-Content "$dest\PRE_SHUTDOWN_CLEANUP.json"
    if($workersAfter.Count){throw 'Worker appeared during export; stop and review'}
    $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $hashes=Get-Content 'C:\Q19F016\FROZEN_INSTALLED_HASHES.json' -Raw|ConvertFrom-Json
    $checks=@(foreach($entry in $hashes){$actual=(Get-FileHash -LiteralPath (Join-Path $install $entry.Path)).Hash;[pscustomobject]@{Path=$entry.Path;Expected=$entry.SHA256;Actual=$actual;Match=($actual -eq $entry.SHA256)}})
    $checks|ConvertTo-Json|Set-Content "$dest\INSTALLED_HASH_VERIFICATION.json"
    if(@($checks|Where-Object {-not $_.Match}).Count){throw 'Installed bytes differ; preserve evidence and stop'}
    $evidence=Join-Path $env:LOCALAPPDATA 'NyxQA19Evidence'
    if(Test-Path -LiteralPath $evidence){Copy-Item -LiteralPath $evidence -Destination $dest -Recurse}
    New-Item -ItemType Directory -Path "$dest\early-observers","$dest\application-data"|Out-Null
    foreach($folder in @(Get-ChildItem -LiteralPath 'C:\Q19F016' -Directory -Filter 'continuation_*')){Copy-Item -LiteralPath $folder.FullName -Destination "$dest\early-observers" -Recurse}
    foreach($name in @('logs','scans','temp')){if(Test-Path -LiteralPath (Join-Path $data $name)){Copy-Item -LiteralPath (Join-Path $data $name) -Destination "$dest\application-data" -Recurse}}
    @{Status='EXPORTED_FOR_REVIEW';Time=(Get-Date).ToString('o');Acceptance='NOT_CLAIMED';ProductModified=$false;Outstanding='Per-run validation and full acceptance review still required'}|ConvertTo-Json|Set-Content "$dest\EXPORT_STATUS.json"
    $manifest=@(Get-ChildItem -LiteralPath $dest -Recurse -File|ForEach-Object {[pscustomobject]@{Path=$_.FullName.Substring($dest.Length+1);Size=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
    $manifest|ConvertTo-Json -Depth 4|Set-Content "$dest\SHA256SUMS.json"
    Compress-Archive -Path "$dest\*" -DestinationPath "$dest.zip" -CompressionLevel Optimal
    [ordered]@{Path="$dest.zip";Bytes=(Get-Item -LiteralPath "$dest.zip").Length;SHA256=(Get-FileHash -LiteralPath "$dest.zip").Hash}|ConvertTo-Json|Tee-Object -FilePath "$dest.zip.identity.json"
    Write-Host 'Export completed. Leave the VM running; do not start another scan.'
}catch{
    @{Status='BLOCKED';Error=$_.Exception.ToString();Time=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content "$dest\EXPORT_STATUS.json"
    throw
}

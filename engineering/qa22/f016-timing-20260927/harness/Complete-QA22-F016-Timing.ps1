$ErrorActionPreference='Stop'
$started=Get-Date
& 'C:\Q22F019\Run-QA22-F016-Timing.ps1'
$root=Join-Path $env:LOCALAPPDATA 'NyxQA22Evidence'
$folder=Get-ChildItem -LiteralPath $root -Directory -Filter 'timing_*' | Where-Object {$_.CreationTime -ge $started.AddSeconds(-2)} | Sort-Object Name -Descending | Select-Object -First 1
if(!$folder){throw 'No timing evidence folder'}
$status=Get-Content -LiteralPath (Join-Path $folder.FullName 'RUN_STATUS.json') -Raw | ConvertFrom-Json
if($status.Status -ne 'F016_THREE_CASES_PASS'){return}
Start-Sleep -Seconds 2
$workers=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.CommandLine -match 'ScanWorker\.ps1'})
$temp=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup\temp'
$artifacts=@(Get-ChildItem -LiteralPath $temp -File -Filter 'scan-*')
@{Time=[DateTime]::UtcNow.ToString('o');GuestRunning=$true;WorkerCount=$workers.Count;ArtifactCount=$artifacts.Count;SafeToShutdown=($workers.Count -eq 0 -and $artifacts.Count -eq 0)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder.FullName 'PRE_SHUTDOWN_FINAL.json')
if($workers.Count -or $artifacts.Count){throw 'Live cleanup failed; guest retained for review'}
& "$env:SystemRoot\System32\shutdown.exe" /s /t 0

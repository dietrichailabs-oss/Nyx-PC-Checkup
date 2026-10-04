$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$dir=Join-Path $env:LOCALAPPDATA ('NyxQA26StartupFinal\'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $dir -Force|Out-Null
$scanTemp=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup\temp'
$scanResult=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup\scans\last-scan.json'
$snapshotDir=Join-Path $dir 'scan-snapshots'
New-Item -ItemType Directory -Path $snapshotDir|Out-Null
$lastResultHash=''
$commonStartup=[Environment]::GetFolderPath('CommonStartup')
if([string]::IsNullOrWhiteSpace($commonStartup)){throw 'CommonStartup path unavailable'}
function Get-StartupFileInventory {
 @((Get-ChildItem -LiteralPath $commonStartup -File -Force|Sort-Object Name)|ForEach-Object {
  [pscustomobject]@{Name=$_.Name;Length=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
 })
}
$startupBefore=@(Get-StartupFileInventory)
$startupBefore|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'ALL_USERS_STARTUP_BEFORE.json') -Encoding UTF8
$run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$name='NyxQA26_MissingTarget_Fixture'
$missing='C:\Q26EvidenceHarness\QA26_INTENTIONALLY_MISSING.exe'
if(Test-Path -LiteralPath $missing){throw 'Missing-target precondition violated'}
if((Get-Item -LiteralPath $run).GetValueNames() -contains $name){throw 'Fixture already exists; refusing overwrite'}
$before=@(Get-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'|Select-Object -Property * -ExcludeProperty PS*)
$before|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'ALL_USERS_RUN_BEFORE.json') -Encoding UTF8
New-ItemProperty -LiteralPath $run -Name $name -Value ('"'+$missing+'"') -PropertyType String|Out-Null
@{Name=$name;Target=$missing;Exists=$false;Utc=[datetime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $dir 'FIXTURE.json') -Encoding UTF8
$seen=$false;$empty=0;$deadline=(Get-Date).AddHours(6)
try {
 while((Get-Date) -lt $deadline){
  $processes=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -in @('powershell.exe','Nyx PC Checkup.exe') -and $_.ProcessId -ne $PID}|Select-Object ProcessId,ParentProcessId,Name,CommandLine)
  $apps=@($processes|Where-Object {$_.CommandLine -match 'NyxPCCheckup\.ps1|Nyx PC Checkup\.exe'})
  if($apps.Count){$seen=$true;$empty=0}else{if($seen){$empty++}}
  $workers=@($processes|Where-Object {$_.CommandLine -match 'ScanWorker\.ps1'})
  $files=@(if(Test-Path -LiteralPath $scanTemp){Get-ChildItem -LiteralPath $scanTemp -File -Force -ErrorAction Stop})
  $probes=@(if($workers.Count -eq 0){foreach($file in $files){
   $handle=$null
   try {$handle=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None);[pscustomobject]@{Path=$file.FullName;ExclusiveRead=$true;Error=$null}}
   catch [IO.IOException] {[pscustomobject]@{Path=$file.FullName;ExclusiveRead=$false;Error=$_.Exception.Message}}
   catch [UnauthorizedAccessException] {[pscustomobject]@{Path=$file.FullName;ExclusiveRead=$false;Error=$_.Exception.Message}}
   finally {if($handle){$handle.Dispose()}}
  }})
  if(Test-Path -LiteralPath $scanResult){
   try {
    $hash=(Get-FileHash -LiteralPath $scanResult -Algorithm SHA256).Hash
    if($hash -ne $lastResultHash){
     $target=Join-Path $snapshotDir ($hash+'.json')
     Copy-Item -LiteralPath $scanResult -Destination $target
     $copiedHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
     if($copiedHash -eq $hash){$lastResultHash=$hash}
     @{Utc=[datetime]::UtcNow.ToString('o');SourceSHA256=$hash;CopiedSHA256=$copiedHash;Path=$target;Stable=($copiedHash -eq $hash)}|ConvertTo-Json -Compress|Add-Content (Join-Path $dir 'SCAN_SNAPSHOT_INDEX.jsonl') -Encoding UTF8
    }
   }catch [IO.IOException] {
    @{Utc=[datetime]::UtcNow.ToString('o');Error=$_.Exception.Message;Scope='Observer snapshot read; retry next poll'}|ConvertTo-Json -Compress|Add-Content (Join-Path $dir 'SNAPSHOT_READ_ERRORS.jsonl') -Encoding UTF8
   }
  }
  @{Schema='QA26-STARTUP-LIVE-2';Utc=[datetime]::UtcNow.ToString('o');Processes=$processes;WorkerCount=$workers.Count;ScanTempPath=$scanTemp;ScanTempExists=(Test-Path -LiteralPath $scanTemp);TempFiles=@($files|Select-Object Name,FullName,Length,LastWriteTimeUtc);IdleHandleProbes=$probes}|ConvertTo-Json -Depth 8 -Compress|Add-Content (Join-Path $dir 'LIVE_PROCESS_TEMP.jsonl') -Encoding UTF8
  if($seen -and $empty -ge 3){break};Start-Sleep -Seconds 2
 }
}finally{
 Remove-ItemProperty -LiteralPath $run -Name $name -Force
 $after=@(Get-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'|Select-Object -Property * -ExcludeProperty PS*)
 $after|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'ALL_USERS_RUN_AFTER.json') -Encoding UTF8
 $startupAfter=@(Get-StartupFileInventory)
 $startupAfter|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'ALL_USERS_STARTUP_AFTER.json') -Encoding UTF8
 @{Schema='QA26-STARTUP-LIVE-2';Utc=[datetime]::UtcNow.ToString('o');FixtureRemoved=$true;AppSeen=$seen;EmptyPolls=$empty;AllUsersRunUnchanged=(($before|ConvertTo-Json -Depth 6 -Compress) -ceq ($after|ConvertTo-Json -Depth 6 -Compress));AllUsersStartupUnchanged=(($startupBefore|ConvertTo-Json -Depth 6 -Compress) -ceq ($startupAfter|ConvertTo-Json -Depth 6 -Compress));ScanTempPath=$scanTemp;Scope='Actual Nyx temp inventory and idle read-only handle probes; records require acceptance interpretation'}|ConvertTo-Json|Set-Content (Join-Path $dir 'END.json') -Encoding UTF8
}

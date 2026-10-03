$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$dir=Join-Path $env:LOCALAPPDATA ('NyxQA26StartupFinal\'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $dir -Force|Out-Null
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
  @{Utc=[datetime]::UtcNow.ToString('o');Processes=$processes;TempFiles=@(Get-ChildItem -LiteralPath $env:TEMP -File -ErrorAction Stop|Select-Object Name,Length,LastWriteTimeUtc)}|ConvertTo-Json -Depth 8 -Compress|Add-Content (Join-Path $dir 'LIVE_PROCESS_TEMP.jsonl') -Encoding UTF8
  if($seen -and $empty -ge 3){break};Start-Sleep -Seconds 2
 }
}finally{
 Remove-ItemProperty -LiteralPath $run -Name $name -Force
 $after=@(Get-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'|Select-Object -Property * -ExcludeProperty PS*)
 $after|ConvertTo-Json -Depth 6|Set-Content (Join-Path $dir 'ALL_USERS_RUN_AFTER.json') -Encoding UTF8
 @{Utc=[datetime]::UtcNow.ToString('o');FixtureRemoved=$true;AppSeen=$seen;EmptyPolls=$empty;AllUsersRunUnchanged=(($before|ConvertTo-Json -Depth 6 -Compress) -ceq ($after|ConvertTo-Json -Depth 6 -Compress));Scope='HKLM Run comparison only; temp records require interpretation, not automatic cleanup PASS'}|ConvertTo-Json|Set-Content (Join-Path $dir 'END.json') -Encoding UTF8
}

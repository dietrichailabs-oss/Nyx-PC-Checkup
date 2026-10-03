$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$root='C:\Q25F022'
$session=Join-Path $env:LOCALAPPDATA ('NyxQA25Evidence\native_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $session -Force|Out-Null
Start-Transcript -Path (Join-Path $session 'TRANSCRIPT.txt')
try{
 if($env:USERNAME -ne 'Nyx'){throw 'QA25 requires the disposable Nyx user'}
 if($PSVersionTable.PSVersion.Major -ne 5 -or -not [Environment]::Is64BitProcess){throw 'Native x64 PowerShell5.1 required'}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 $principal=New-Object Security.Principal.WindowsPrincipal($identity)
 if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Focused installed gate must run non-elevated'}
 $expected=@{
 'Nyx_PC_Checkup_1.0.0_Setup.exe'='5F5C1C294F23487DE1B4325173DC72C89950A2AAA96EBB1AC3F80B6CDE788112'
 'Nyx_PC_Checkup_1.0.0_Portable.zip'='B38A40D40CFFE86E30F1EA8E88D21295D14B1DD792D60A27962A22783E63D19C'
 'Nyx_PC_Checkup_1.0.0_Source.zip'='A4ED460A880BA04A289F504312BF7A1B8D0F3C1A5956DE46E19AFC837CF7049C'
 }
 $hashes=@(foreach($name in $expected.Keys){$file=Join-Path $root $name;$hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash;if($hash -ne $expected[$name]){throw "Candidate hash mismatch: $name"};[pscustomobject]@{Name=$name;SHA256=$hash}})
 $hashes|ConvertTo-Json|Set-Content (Join-Path $session 'ARTIFACT_HASHES.json') -Encoding UTF8
 @{Build='2026.09.28-eng-qa25';Harness='QA25-F022-PS51-25';User=$identity.Name;PowerShell=$PSVersionTable.PSVersion.ToString();OS=[Environment]::OSVersion.VersionString;Utc=[DateTime]::UtcNow.ToString('o');DpiAcceptance='Record actual Windows Settings; no DPI-unaware size accepted as proof'}|ConvertTo-Json|Set-Content (Join-Path $session 'ENVIRONMENT.json') -Encoding UTF8
 $setup=Start-Process -FilePath (Join-Path $root 'Nyx_PC_Checkup_1.0.0_Setup.exe') -ArgumentList '/quiet /nolaunch /desktop' -PassThru -Wait
 @{ExitCode=$setup.ExitCode;Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $session 'SETUP_RESULT.json') -Encoding UTF8
 if($setup.ExitCode -ne 0){throw "Setup failed: $($setup.ExitCode)"}
 $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
 $payload=Get-Content -LiteralPath (Join-Path $root 'EXPECTED_PAYLOAD.json') -Raw|ConvertFrom-Json
 $actual=@(foreach($item in $payload){$file=Join-Path $install $item.Path;$hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash;if($hash -ne $item.SHA256){throw "Installed payload mismatch: $($item.Path)"};[pscustomobject]@{Path=$item.Path;SHA256=$hash}})
 $actual|ConvertTo-Json|Set-Content (Join-Path $session 'INSTALLED_PAYLOAD_HASHES.json') -Encoding UTF8
 $shortcut=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
 $shell=New-Object -ComObject WScript.Shell
 $link=$shell.CreateShortcut($shortcut)
 @{TargetPath=$link.TargetPath;Arguments=$link.Arguments;WorkingDirectory=$link.WorkingDirectory;IconLocation=$link.IconLocation}|ConvertTo-Json|Set-Content (Join-Path $session 'SHORTCUT.json') -Encoding UTF8
 Start-Process -FilePath $shortcut
 $end=[DateTime]::UtcNow.AddHours(12)
 $seen=$false;$empty=0
 while([DateTime]::UtcNow -lt $end){
  $children=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -like "*$install\app\NyxPCCheckup.ps1*"}|Select-Object ProcessId,ParentProcessId,CommandLine,CreationDate)
  @{Utc=[DateTime]::UtcNow.ToString('o');Processes=$children}|ConvertTo-Json -Depth 5 -Compress|Add-Content (Join-Path $session 'PROCESS_OBSERVATIONS.jsonl') -Encoding UTF8
  if($children.Count){$seen=$true;$empty=0}else{$empty++}
  if($seen -and $empty -ge 3){break}
  if(-not $seen -and $empty -ge 15){throw 'Installed app did not become observable'}
  Start-Sleep -Seconds 4
 }
 $data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
 if(Test-Path -LiteralPath $data){Copy-Item -LiteralPath $data -Destination (Join-Path $session 'app-data-at-end') -Recurse}
 @{Utc=[DateTime]::UtcNow.ToString('o');AppSeen=$seen;ConsecutiveEmptySamples=$empty;Acceptance='NOT_AUTOMATICALLY_DECIDED'}|ConvertTo-Json|Set-Content (Join-Path $session 'END.json') -Encoding UTF8
}catch{
 $_|Out-String|Set-Content (Join-Path $session 'BLOCKER.txt') -Encoding UTF8
 throw
}finally{Stop-Transcript}

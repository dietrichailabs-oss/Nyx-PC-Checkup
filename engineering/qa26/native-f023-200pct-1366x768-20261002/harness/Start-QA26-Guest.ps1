$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$root='C:\Q26F023'
$session=Join-Path $env:LOCALAPPDATA ('NyxQA26Evidence\native_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
[void][IO.Directory]::CreateDirectory($session)
Start-Transcript -Path (Join-Path $session 'TRANSCRIPT.txt')
try{
 if($env:USERNAME -ne 'Nyx' -or $PSVersionTable.PSVersion.Major -ne 5 -or -not [Environment]::Is64BitProcess){throw 'Disposable Nyx user and native x64 PS5.1 required'}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 if((New-Object Security.Principal.WindowsPrincipal($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Focused gate must run non-elevated'}
 $expected=Get-Content -LiteralPath (Join-Path $root 'QA26_CANDIDATE.json') -Raw|ConvertFrom-Json
 foreach($kind in @('setup','portable','source')){
  $item=$expected.$kind;$file=Join-Path $root $item.name
  if((Get-Item -LiteralPath $file).Length -ne $item.bytes -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $item.sha256){throw "Frozen artifact mismatch: $kind"}
 }
 $expected|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $session 'CANDIDATE.json') -Encoding UTF8
 $setup=Start-Process -FilePath (Join-Path $root $expected.setup.name) -ArgumentList '/quiet /nolaunch /desktop' -PassThru -Wait
 @{ExitCode=$setup.ExitCode;Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $session 'SETUP_RESULT.json') -Encoding UTF8
 if($setup.ExitCode -ne 0){throw 'QA26 Setup failed'}
 $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
 $payload=@((Get-Content -LiteralPath (Join-Path $root 'EXPECTED_PAYLOAD.json') -Raw|ConvertFrom-Json))
 $actual=@(foreach($item in $payload){
  $file=Join-Path $install $item.Path;$info=Get-Item -LiteralPath $file;$hash=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
  if($info.Length -ne $item.Bytes -or $hash -ne $item.SHA256){throw "Installed payload mismatch: $($item.Path)"}
  [pscustomobject]@{Path=$item.Path;Bytes=$info.Length;SHA256=$hash}
 })
 $all=@(Get-ChildItem -LiteralPath $install -File -Recurse)
 if($all.Count -ne $payload.Count+1 -or -not (Test-Path -LiteralPath (Join-Path $install 'install-state.json'))){throw 'Unexpected installed file set'}
 $actual|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $session 'INSTALLED_PAYLOAD_HASHES.json') -Encoding UTF8
 Copy-Item -LiteralPath (Join-Path $install 'install-state.json') -Destination (Join-Path $session 'INSTALL_STATE.json')
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class QA26WindowEvidence {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
 [DllImport("user32.dll")] public static extern uint GetDpiForSystem();
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr w);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr w,out Rect r);
}
'@
 $setAware=[QA26WindowEvidence]::SetProcessDpiAwarenessContext([IntPtr](-4))
 Add-Type -AssemblyName System.Windows.Forms,System.Drawing
 $screen=[Windows.Forms.Screen]::PrimaryScreen
 $aware=[QA26WindowEvidence]::AreDpiAwarenessContextsEqual([QA26WindowEvidence]::GetThreadDpiAwarenessContext(),[IntPtr](-4))
 @{Build=$expected.build;Harness=$expected.harness;User=$identity.Name;PowerShell=$PSVersionTable.PSVersion.ToString();OS=[Environment]::OSVersion.VersionString;Utc=[DateTime]::UtcNow.ToString('o');ObserverPerMonitorV2=$aware;SetAwarenessSucceeded=$setAware;SystemDpi=[QA26WindowEvidence]::GetDpiForSystem();PrimaryBounds=$screen.Bounds.ToString();WorkingArea=$screen.WorkingArea.ToString();CoordinateCaveat='Accept physical bounds only if observer awareness is confirmed; individual cell geometry remains a separate gate'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $session 'ENVIRONMENT.json') -Encoding UTF8
 $shortcut=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
 $shell=New-Object -ComObject WScript.Shell;$link=$shell.CreateShortcut($shortcut)
 @{TargetPath=$link.TargetPath;Arguments=$link.Arguments;WorkingDirectory=$link.WorkingDirectory;IconLocation=$link.IconLocation}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $session 'SHORTCUT.json') -Encoding UTF8
 Start-Process -FilePath $shortcut
 $deadline=[DateTime]::UtcNow.AddHours(12);$seen=$false;$empty=0
 while([DateTime]::UtcNow -lt $deadline){
  $children=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -like "*$install\app\NyxPCCheckup.ps1*"}|Select-Object ProcessId,ParentProcessId,CommandLine,CreationDate)
  @{Utc=[DateTime]::UtcNow.ToString('o');Processes=$children}|ConvertTo-Json -Depth 5 -Compress|Add-Content -LiteralPath (Join-Path $session 'PROCESS_OBSERVATIONS.jsonl') -Encoding UTF8
  foreach($child in $children){
   $process=Get-Process -Id $child.ProcessId -ErrorAction Stop
   if($process.MainWindowHandle -ne [IntPtr]::Zero){
    $rect=New-Object QA26WindowEvidence+Rect
    $ok=[QA26WindowEvidence]::GetWindowRect($process.MainWindowHandle,[ref]$rect)
    @{Utc=[DateTime]::UtcNow.ToString('o');PID=$child.ProcessId;WindowTitle=$process.MainWindowTitle;Dpi=[QA26WindowEvidence]::GetDpiForWindow($process.MainWindowHandle);RectAvailable=$ok;Rect=$rect;ObserverPerMonitorV2=$aware}|ConvertTo-Json -Depth 5 -Compress|Add-Content -LiteralPath (Join-Path $session 'WINDOW_OBSERVATIONS.jsonl') -Encoding UTF8
   }
  }
  if($children.Count){$seen=$true;$empty=0}else{$empty++}
  if($seen -and $empty -ge 3){break}
  if(-not $seen -and $empty -ge 15){throw 'Installed QA26 was not observable'}
  Start-Sleep -Seconds 4
 }
 $data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
 if(Test-Path -LiteralPath $data){Copy-Item -LiteralPath $data -Destination (Join-Path $session 'app-data-at-end') -Recurse}
 @{Utc=[DateTime]::UtcNow.ToString('o');AppSeen=$seen;ConsecutiveEmptySamples=$empty;Acceptance='NOT_AUTOMATICALLY_DECIDED'}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $session 'END.json') -Encoding UTF8
}catch{$_|Out-String|Set-Content -LiteralPath (Join-Path $session 'BLOCKER.txt') -Encoding UTF8;throw}finally{Stop-Transcript}

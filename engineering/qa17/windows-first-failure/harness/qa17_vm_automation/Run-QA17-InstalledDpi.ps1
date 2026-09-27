$ErrorActionPreference='Stop'
$root='C:\Q17F014'
$evidence=Join-Path $root ('evidence_dpi_physical_'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence -Force|Out-Null
try {
    $identity=Get-Content -LiteralPath "$root\CANDIDATE_IDENTITY.json" -Raw|ConvertFrom-Json
    foreach($kind in @('setup','portable','source')){
        $entry=$identity.$kind
        $file=Join-Path $root ([IO.Path]::GetFileName($entry.path))
        if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256){throw "Candidate mismatch: $kind"}
    }
    $install="$env:LOCALAPPDATA\Programs\Dietrich AI Labs\Nyx PC Checkup"
    $manifest=Get-Content -LiteralPath (Join-Path $install 'PAYLOAD_MANIFEST.json') -Raw|ConvertFrom-Json
    if(-not (Test-Path -LiteralPath (Join-Path $install 'Nyx PC Checkup.exe'))){throw 'Frozen installed candidate missing'}
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    Add-Type -ReferencedAssemblies System.Drawing @'
using System;using System.Runtime.InteropServices;
public static class Q17Native {
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO {public int cbSize;public RECT Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h,uint flags);
 [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h,ref MONITORINFO m);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
 [DllImport("user32.dll")] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
 [DllImport("user32.dll")] static extern int GetSystemMetrics(int index);
 public class Snapshot {
   public RECT Window; public MONITORINFO Monitor; public uint Dpi;
   public int DesktopX,DesktopY,DesktopWidth,DesktopHeight;
   public bool ObserverPerMonitorV2;
 }
 public static Snapshot Capture(IntPtr window,string screenshot) {
   IntPtr previous=SetThreadDpiAwarenessContext(new IntPtr(-4));
   if(previous==IntPtr.Zero) throw new InvalidOperationException("Cannot set observer DPI context");
   try {
     Snapshot s=new Snapshot();
     s.ObserverPerMonitorV2=AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),new IntPtr(-4));
     if(!s.ObserverPerMonitorV2) throw new InvalidOperationException("Observer is not PerMonitorV2");
     s.Monitor.cbSize=Marshal.SizeOf(typeof(MONITORINFO));
     if(!GetWindowRect(window,out s.Window) || !GetMonitorInfo(MonitorFromWindow(window,2),ref s.Monitor))
       throw new InvalidOperationException("Native physical bounds capture failed");
     s.Dpi=GetDpiForWindow(window);
     s.DesktopX=GetSystemMetrics(76);s.DesktopY=GetSystemMetrics(77);
     s.DesktopWidth=GetSystemMetrics(78);s.DesktopHeight=GetSystemMetrics(79);
     if(s.DesktopWidth<=0 || s.DesktopHeight<=0) throw new InvalidOperationException("Invalid physical desktop size");
     using(var bitmap=new System.Drawing.Bitmap(s.DesktopWidth,s.DesktopHeight))
     using(var graphics=System.Drawing.Graphics.FromImage(bitmap)) {
       graphics.CopyFromScreen(s.DesktopX,s.DesktopY,0,0,bitmap.Size);
       bitmap.Save(screenshot,System.Drawing.Imaging.ImageFormat.Png);
     }
     return s;
   } finally {SetThreadDpiAwarenessContext(previous);}
 }
}
'@
    $launch=Start-Process -FilePath "$install\Nyx PC Checkup.exe" -PassThru
    $deadline=[DateTime]::UtcNow.AddSeconds(40)
    $app=$null
    do {
        Start-Sleep -Milliseconds 500
        $apps=@(Get-Process powershell -ErrorAction SilentlyContinue|Where-Object {$_.MainWindowTitle -eq 'Nyx PC Checkup'})
        if($apps.Count -eq 1){$app=$apps[0]}
    }while($null -eq $app -and [DateTime]::UtcNow -lt $deadline)
    if($null -eq $app){throw 'Real installed EXE produced no visible main window within 40 seconds'}
    Start-Sleep -Seconds 5
    $process=Get-CimInstance Win32_Process -Filter "ProcessId=$($app.Id)"
    if($process.ParentProcessId -ne $launch.Id -or $process.CommandLine.IndexOf($install,[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'Visible window does not belong to this installed native launch'}
    # One synchronous native call covers measurement AND screenshot. Change
    # only this observer thread, never the application process or its window.
    $capture=[Q17Native]::Capture($app.MainWindowHandle,"$evidence\NATIVE_EXE_DESKTOP.png")
    $rect=$capture.Window
    $monitor=$capture.Monitor
    $inside=$rect.Left -ge $monitor.Work.Left -and $rect.Top -ge $monitor.Work.Top -and $rect.Right -le $monitor.Work.Right -and $rect.Bottom -le $monitor.Work.Bottom
    [ordered]@{HarnessCorrectionRevision='QA17-F014-OBSERVER-PHYSICAL-1';Status=$(if($inside){'BOUNDS_PASS_PENDING_DPI_AND_IN_PROCESS_REVIEW'}else{'FAIL'});LauncherPID=$launch.Id;ApplicationPID=$app.Id;Window=$rect;WorkingArea=$monitor.Work;DPI=$capture.Dpi;PhysicalCapture=$capture;User=$env:USERNAME;PowerShell=$PSVersionTable.PSVersion.ToString();Process=($process|Select-Object ProcessId,ParentProcessId,CommandLine);CoordinateSpace='Physical pixels: GetWindowRect, GetMonitorInfo, desktop metrics and screenshot on the same verified PerMonitorV2 observer thread; application awareness unchanged';CandidateModified=$false}|ConvertTo-Json -Depth 8|Set-Content "$evidence\NATIVE_EXE_RESULT.json" -Encoding UTF8
    if(-not $inside){throw 'F-013 native EXE bounds failed; stop'}
    [void][Q17Native]::PostMessage($app.MainWindowHandle,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
    if(-not $app.WaitForExit(15000)){throw 'Native app did not close cleanly'}
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $info.Arguments='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q17F014\Invoke-QA17-CurrentDpiBounds.ps1" -InstalledRoot "'+$install+'" -EvidenceDirectory "'+$evidence+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $observer=[Diagnostics.Process]::Start($info)
    [ordered]@{Status='IN_PROCESS_OBSERVER_STARTED';PID=$observer.Id;CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json" -Encoding UTF8
}catch{[ordered]@{Status='STOPPED';Error=$_.Exception.ToString();CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json" -Encoding UTF8}

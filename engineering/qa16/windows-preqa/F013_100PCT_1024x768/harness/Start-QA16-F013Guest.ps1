$ErrorActionPreference='Stop'
$root='C:\Q16F013'
$evidence=Join-Path $root 'evidence'
New-Item -ItemType Directory -Path $evidence -Force|Out-Null
try {
    $identity=Get-Content -LiteralPath "$root\CANDIDATE_IDENTITY.json" -Raw|ConvertFrom-Json
    foreach($kind in @('setup','portable','source')){
        $entry=$identity.$kind
        $file=Join-Path $root ([IO.Path]::GetFileName($entry.path))
        if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256){throw "Candidate mismatch: $kind"}
    }
    if(Test-Path -LiteralPath "$env:LOCALAPPDATA\Dietrich AI Labs\Nyx PC Checkup"){throw 'Clean profile prerequisite failed'}
    $setup=Start-Process -FilePath "$root\Nyx_PC_Checkup_1.0.0_Setup.exe" -ArgumentList '/quiet /nolaunch /desktop' -Wait -PassThru
    if($setup.ExitCode -ne 0){throw "Setup failed: $($setup.ExitCode)"}
    $install="$env:LOCALAPPDATA\Programs\Dietrich AI Labs\Nyx PC Checkup"
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    Add-Type @'
using System;using System.Runtime.InteropServices;
public static class Q16Native {
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO {public int cbSize;public RECT Monitor,Work;public uint Flags;}
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h,uint flags);
 [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h,ref MONITORINFO m);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint msg,IntPtr w,IntPtr l);
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
    $rect=New-Object Q16Native+RECT
    $monitor=New-Object Q16Native+MONITORINFO
    $monitor.cbSize=[Runtime.InteropServices.Marshal]::SizeOf($monitor)
    if(-not [Q16Native]::GetWindowRect($app.MainWindowHandle,[ref]$rect)){throw 'GetWindowRect failed'}
    if(-not [Q16Native]::GetMonitorInfo([Q16Native]::MonitorFromWindow($app.MainWindowHandle,2),[ref]$monitor)){throw 'Monitor query failed'}
    $inside=$rect.Left -ge $monitor.Work.Left -and $rect.Top -ge $monitor.Work.Top -and $rect.Right -le $monitor.Work.Right -and $rect.Bottom -le $monitor.Work.Bottom
    $desktop=[Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap=New-Object Drawing.Bitmap($desktop.Width,$desktop.Height)
    $g=[Drawing.Graphics]::FromImage($bitmap)
    try{$g.CopyFromScreen($desktop.Location,[Drawing.Point]::Empty,$desktop.Size);$bitmap.Save("$evidence\NATIVE_EXE_DESKTOP.png")}finally{$g.Dispose();$bitmap.Dispose()}
    [ordered]@{Status=$(if($inside){'BOUNDS_PASS_PENDING_DPI_AND_IN_PROCESS_REVIEW'}else{'FAIL'});LauncherPID=$launch.Id;ApplicationPID=$app.Id;Window=$rect;WorkingArea=$monitor.Work;DPI=[Q16Native]::GetDpiForWindow($app.MainWindowHandle);Display=$desktop.ToString();User=$env:USERNAME;PowerShell=$PSVersionTable.PSVersion.ToString();Process=(Get-CimInstance Win32_Process -Filter "ProcessId=$($app.Id)"|Select-Object ProcessId,ParentProcessId,CommandLine);CoordinateSpace='External observer context; paired in-process capture required';CandidateModified=$false}|ConvertTo-Json -Depth 8|Set-Content "$evidence\NATIVE_EXE_RESULT.json" -Encoding UTF8
    if(-not $inside){throw 'F-013 native EXE bounds failed; stop'}
    [void][Q16Native]::PostMessage($app.MainWindowHandle,0x10,[IntPtr]::Zero,[IntPtr]::Zero)
    if(-not $app.WaitForExit(15000)){throw 'Native app did not close cleanly'}
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $info.Arguments='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q16F013\Invoke-QA16-FirstCellBounds.ps1" -InstalledRoot "'+$install+'" -EvidenceDirectory "'+$evidence+'"'
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $observer=[Diagnostics.Process]::Start($info)
    [ordered]@{Status='IN_PROCESS_OBSERVER_STARTED';PID=$observer.Id;CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json" -Encoding UTF8
}catch{[ordered]@{Status='STOPPED';Error=$_.Exception.ToString();CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json" -Encoding UTF8}

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstalledRoot,
    [Parameter(Mandatory=$true)][string]$EvidenceDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
Start-Transcript -LiteralPath (Join-Path $EvidenceDirectory 'OBSERVER_TRANSCRIPT.txt') -Force | Out-Null
$global:Q16BoundsOutput = [IO.Path]::GetFullPath($EvidenceDirectory)
$global:Q16BoundsInstall = [IO.Path]::GetFullPath($InstalledRoot)
$entry = Join-Path $InstalledRoot 'app\NyxPCCheckup.ps1'
$module = Join-Path $InstalledRoot 'app\ui\MainWindow.psm1'
if (-not (Test-Path -LiteralPath $entry)) { throw 'Installed application entry point is missing.' }
if ($PSVersionTable.PSVersion.Major -ne 5 -or -not [Environment]::Is64BitProcess) { throw 'Native Windows PowerShell 5.1 x64 is required.' }

Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Q16BoundsNative {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT Monitor,Work; public uint Flags; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DEVMODE {
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string DeviceName;
        public ushort SpecVersion,DriverVersion,Size,DriverExtra; public uint Fields;
        public int PositionX,PositionY; public uint DisplayOrientation,DisplayFixedOutput;
        public short Color,Duplex,YResolution,TTOption,Collate;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string FormName;
        public ushort LogPixels; public uint BitsPerPel,PelsWidth,PelsHeight,DisplayFlags,DisplayFrequency,ICMMethod,ICMIntent,MediaType,DitherType,Reserved1,Reserved2,PanningWidth,PanningHeight;
    }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h,uint flags);
    [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr h,ref MONITORINFO m);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern bool EnumDisplaySettings(string name,int mode,ref DEVMODE d);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")] public static extern IntPtr GetWindowDpiAwarenessContext(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetAwarenessFromDpiAwarenessContext(IntPtr c);
    [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a,IntPtr b);
    [DllImport("shcore.dll")] public static extern int GetProcessDpiAwareness(IntPtr p,out int value);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
}
'@
function global:Save-Q16Json($Value, $Name) {
    $Value | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath (Join-Path $global:Q16BoundsOutput $Name) -Encoding UTF8
}
function global:Convert-Q16Rectangle($R) {
    [ordered]@{X=$R.X;Y=$R.Y;Width=$R.Width;Height=$R.Height;Left=$R.Left;Top=$R.Top;Right=$R.Right;Bottom=$R.Bottom}
}
function global:Convert-Q17NativeRectangle($R) {
    [ordered]@{Left=$R.Left;Top=$R.Top;Right=$R.Right;Bottom=$R.Bottom;Width=($R.Right-$R.Left);Height=($R.Bottom-$R.Top)}
}
function global:Get-Q16Awareness([IntPtr]$Context) {
    $equal=[ordered]@{}
    foreach($pair in @(@('Unaware',-1),@('SystemAware',-2),@('PerMonitor',-3),@('PerMonitorV2',-4),@('UnawareGdiScaled',-5))) {
        $equal[$pair[0]]=[Q16BoundsNative]::AreDpiAwarenessContextsEqual($Context,[IntPtr]$pair[1])
    }
    [ordered]@{Context=$Context.ToInt64();Awareness=[Q16BoundsNative]::GetAwarenessFromDpiAwarenessContext($Context);ContextsEqual=$equal}
}
function global:Write-Q16FirstCell {
    param([Windows.Forms.Form]$Form)
    $handle=$Form.Handle
    $primary=[Windows.Forms.Screen]::PrimaryScreen
    $actual=[Windows.Forms.Screen]::FromHandle($handle)
    $rect=New-Object Q16BoundsNative+RECT
    if(-not [Q16BoundsNative]::GetWindowRect($handle,[ref]$rect)){throw 'GetWindowRect failed.'}
    $monitor=New-Object Q16BoundsNative+MONITORINFO
    $monitor.cbSize=[Runtime.InteropServices.Marshal]::SizeOf($monitor)
    if(-not [Q16BoundsNative]::GetMonitorInfo([Q16BoundsNative]::MonitorFromWindow($handle,2),[ref]$monitor)){throw 'GetMonitorInfo failed.'}
    $mode=New-Object Q16BoundsNative+DEVMODE
    $mode.Size=[Runtime.InteropServices.Marshal]::SizeOf($mode)
    if(-not [Q16BoundsNative]::EnumDisplaySettings($actual.DeviceName,-1,[ref]$mode)){throw 'Active display mode unavailable.'}
    $graphics=$Form.CreateGraphics()
    try {$graphicsDpi=[ordered]@{X=$graphics.DpiX;Y=$graphics.DpiY}} finally {$graphics.Dispose()}
    $processDpi=0
    $hr=[Q16BoundsNative]::GetProcessDpiAwareness([IntPtr]::Zero,[ref]$processDpi)
    $awareness=[ordered]@{
        ProcessId=$PID;ThreadId=[Q16BoundsNative]::GetCurrentThreadId();ProcessAwareness=$processDpi;ProcessAwarenessHResult=$hr
        Thread=(Get-Q16Awareness ([Q16BoundsNative]::GetThreadDpiAwarenessContext()))
        Window=(Get-Q16Awareness ([Q16BoundsNative]::GetWindowDpiAwarenessContext($handle)))
        Instrumentation='Read-only capture on the application UI thread via an external PowerShell debugger breakpoint and timer.'
        LaunchMode='Installed script under native-launcher-equivalent PowerShell flags, with an external observation wrapper.'
        NativeLauncherAwareness='Not observed in this instrumented script process; no equivalence claim made.'
    }
    $comparisons=@(
        [ordered]@{Expression='Window.Left < WorkArea.Left';Window=$rect.Left;WorkArea=$monitor.Work.Left;Result=($rect.Left-lt$monitor.Work.Left)},
        [ordered]@{Expression='Window.Top < WorkArea.Top';Window=$rect.Top;WorkArea=$monitor.Work.Top;Result=($rect.Top-lt$monitor.Work.Top)},
        [ordered]@{Expression='Window.Right > WorkArea.Right';Window=$rect.Right;WorkArea=$monitor.Work.Right;Result=($rect.Right-gt$monitor.Work.Right)},
        [ordered]@{Expression='Window.Bottom > WorkArea.Bottom';Window=$rect.Bottom;WorkArea=$monitor.Work.Bottom;Result=($rect.Bottom-gt$monitor.Work.Bottom)}
    )
    $comparison=[ordered]@{CoordinateSpace='Native GetWindowRect and GetMonitorInfo called synchronously on the same UI thread without changing awareness context.';Window=(Convert-Q17NativeRectangle $rect);WorkArea=(Convert-Q17NativeRectangle $monitor.Work);Comparisons=$comparisons;WindowBeyondScreen=(@($comparisons|Where-Object{$_.Result}).Count-gt0)}
    $deviceDpi=$null
    if($Form.PSObject.Properties['DeviceDpi']){$deviceDpi=$Form.DeviceDpi}
    $screenshotPath=Join-Path $global:Q16BoundsOutput 'FULL_DESKTOP_SCREENSHOT.png'
    $desktop=[Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap=New-Object Drawing.Bitmap($desktop.Width,$desktop.Height)
    $g=[Drawing.Graphics]::FromImage($bitmap)
    try {$g.CopyFromScreen($desktop.Location,[Drawing.Point]::Empty,$desktop.Size);$bitmap.Save($screenshotPath,[Drawing.Imaging.ImageFormat]::Png)} finally {$g.Dispose();$bitmap.Dispose()}
    $environment=[ordered]@{ComputerName=$env:COMPUTERNAME;User=$env:USERNAME;OS=[Environment]::OSVersion.VersionString;PowerShell=$PSVersionTable.PSVersion.ToString();Is64BitProcess=[Environment]::Is64BitProcess;SessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId;SessionName=$env:SESSIONNAME;Interactive=[Environment]::UserInteractive;DisplayMode=[ordered]@{Width=$mode.PelsWidth;Height=$mode.PelsHeight;Frequency=$mode.DisplayFrequency;Device=$actual.DeviceName};Screenshot=[ordered]@{Path='FULL_DESKTOP_SCREENSHOT.png';Width=$desktop.Width;Height=$desktop.Height;CaptureRectangle=(Convert-Q16Rectangle $desktop);Cropped=$false}}
    $record=[ordered]@{
        Schema='qa16.f013.bounds.v1';CapturedUtc=[DateTime]::UtcNow.ToString('o');CandidateModified=$false;Theme='FollowWindows';Page='Home';RequestedScaling='CURRENT_DESKTOP_OBSERVATION'
        Handle=$handle.ToInt64();NativeVisible=[Q16BoundsNative]::IsWindowVisible($handle);NativeMinimized=[Q16BoundsNative]::IsIconic($handle);CaptureTrigger='At least three stable native-visible UI timer observations';PrimaryScreen=[ordered]@{Bounds=(Convert-Q16Rectangle $primary.Bounds);WorkingArea=(Convert-Q16Rectangle $primary.WorkingArea)}
        ScreenFromHandle=[ordered]@{Bounds=(Convert-Q16Rectangle $actual.Bounds);WorkingArea=(Convert-Q16Rectangle $actual.WorkingArea)}
        Form=[ordered]@{Bounds=(Convert-Q16Rectangle $Form.Bounds);RestoreBounds=(Convert-Q16Rectangle $Form.RestoreBounds);ClientRectangle=(Convert-Q16Rectangle $Form.ClientRectangle);Size=[ordered]@{Width=$Form.Size.Width;Height=$Form.Size.Height};ClientSize=[ordered]@{Width=$Form.ClientSize.Width;Height=$Form.ClientSize.Height};MinimumSize=[ordered]@{Width=$Form.MinimumSize.Width;Height=$Form.MinimumSize.Height};WindowState=[string]$Form.WindowState;Location=[ordered]@{X=$Form.Location.X;Y=$Form.Location.Y};Visible=$Form.Visible}
        GetWindowRect=(Convert-Q17NativeRectangle $rect);SystemMetrics=[ordered]@{SM_CXSCREEN=[Q16BoundsNative]::GetSystemMetrics(0);SM_CYSCREEN=[Q16BoundsNative]::GetSystemMetrics(1)}
        Dpi=[ordered]@{FormDeviceDpi=$deviceDpi;Graphics=$graphicsDpi;NativeWindow=[Q16BoundsNative]::GetDpiForWindow($handle)}
        Awareness=$awareness;Environment=$environment;BoundsDecision=$comparison
        Verdict='CAPTURED_PENDING_IDENTITY_ENVIRONMENT_AND_NATIVE_LAUNCH_REVIEW'
    }
    Save-Q16Json $awareness 'DPI_AWARENESS.json'
    Save-Q16Json $environment 'VM_ENVIRONMENT.json'
    Save-Q16Json $comparison 'BOUNDS_COMPARISON.json'
    Save-Q16Json $record 'F008_FIRST_CELL_BOUNDS.json'
}

# A line breakpoint attaches the observer after product initialization, without
# editing the installed script or changing its DPI, dimensions, position, or state.
$lines=[IO.File]::ReadAllLines($module)
$matches=@(for($i=0;$i-lt$lines.Length;$i++){if($lines[$i]-match '\[Windows\.Forms\.Application\]::Run\(\$form\)'){$i+1}})
if($matches.Count-ne1){throw 'Expected one exact application message-loop entry point.'}
$global:Q16BoundsTimer=$null
$global:Q16BoundsStable=0
$global:Q16BoundsLast=''
$global:Q16BoundsTicks=0
$breakpoint=Set-PSBreakpoint -Script $module -Line $matches[0] -Action {
    $global:Q16BoundsTimer=New-Object Windows.Forms.Timer
    $global:Q16BoundsTimer.Interval=1000
    $global:Q16BoundsTimer.Add_Tick({
        try {
            $global:Q16BoundsTicks++
            if($global:Q16BoundsTicks-gt30){throw 'No stable native-visible main window was captured within 30 UI timer ticks.'}
            $forms=@([Windows.Forms.Application]::OpenForms | Where-Object {$_.Text-eq'Nyx PC Checkup'-and$_.Visible})
            if($forms.Count-ne1){return}
            $shown=$forms[0]
            if(-not[Q16BoundsNative]::IsWindowVisible($shown.Handle)-or[Q16BoundsNative]::IsIconic($shown.Handle)){return}
            $geometry=$shown.Bounds.ToString()
            if($geometry-eq$global:Q16BoundsLast){$global:Q16BoundsStable++}else{$global:Q16BoundsLast=$geometry;$global:Q16BoundsStable=0}
            if($global:Q16BoundsStable-lt3){return}
            $global:Q16BoundsTimer.Stop()
            Write-Q16FirstCell $forms[0]
        } catch {$global:Q16BoundsTimer.Stop();Save-Q16Json ([ordered]@{Status='HARNESS_CAPTURE_BLOCKED';Error=$_.Exception.ToString();CandidateModified=$false}) 'CAPTURE_ERROR.json'}
    })
    $global:Q16BoundsTimer.Start()
}
try { & $entry } catch {Save-Q16Json ([ordered]@{Status='HARNESS_EXECUTION_BLOCKED';Error=$_.Exception.ToString()}) 'CAPTURE_ERROR.json';throw} finally {Remove-PSBreakpoint -Breakpoint $breakpoint -ErrorAction SilentlyContinue;Stop-Transcript -ErrorAction SilentlyContinue | Out-Null}

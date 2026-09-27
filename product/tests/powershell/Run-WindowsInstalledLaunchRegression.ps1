[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SetupPath,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [switch]$DestructiveCleanVmAcknowledged
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0

$script:ExpectedBuild='2026.09.27-eng-qa21'
$script:ExpectedHarnessRevision='QA21-F018-PS51-21'
$script:Results=[System.Collections.Generic.List[object]]::new()
$script:Failures=0
$script:ControlRecords=[System.Collections.Generic.List[object]]::new()
$script:Screenshots=[System.Collections.Generic.List[string]]::new()

function Test-Step {
    param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Passed,[string]$Details='')
    $script:Results.Add([pscustomobject][ordered]@{Name=$Name;Passed=$Passed;Details=$Details})
    if(-not $Passed){$script:Failures++}
}

function Wait-NyxValue {
    param([Parameter(Mandatory=$true)][scriptblock]$Probe,[int]$Seconds=30,[int]$Milliseconds=200)
    $attempts=[math]::Max(1,[int](($Seconds*1000)/$Milliseconds))
    for($i=0;$i -lt $attempts;$i++){
        $value=& $Probe
        if($null -ne $value){return $value}
        Start-Sleep -Milliseconds $Milliseconds
    }
    return $null
}

if($env:OS -ne 'Windows_NT'){throw 'The F-011 installed-launch regression requires native Windows.'}
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Run the F-011 regression with inbox Windows PowerShell 5.1 Desktop edition.'}
if(-not $DestructiveCleanVmAcknowledged){throw 'This regression installs and uninstalls Nyx PC Checkup. Use only a clean disposable VM and pass -DestructiveCleanVmAcknowledged.'}
if(-not [Environment]::UserInteractive){throw 'The F-011 visible-window regression requires an interactive Windows desktop session.'}
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if($isAdmin){throw 'The F-011 installed-launch regression must run from a normal non-elevated desktop session.'}

$SetupPath=(Resolve-Path -LiteralPath $SetupPath).Path
$outputFull=[IO.Path]::GetFullPath($OutputPath)
$outputDirectory=[IO.Path]::GetDirectoryName($outputFull)
if(-not(Test-Path -LiteralPath $outputDirectory -PathType Container)){New-Item -ItemType Directory -Path $outputDirectory -Force|Out-Null}
$evidenceDirectory=Join-Path $outputDirectory 'F011_INSTALLED_LAUNCH_EVIDENCE'
New-Item -ItemType Directory -Path $evidenceDirectory -Force|Out-Null
$diagnosticWriteDirectory=Join-Path ([IO.Path]::GetTempPath()) ('NQ15F011_'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $diagnosticWriteDirectory -Force|Out-Null

. (Join-Path $PSScriptRoot 'InstallerDiagnosticsHelpers.ps1')
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$nativeSource=@'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public sealed class NyxTopLevelWindowRecord {
    public long Handle;
    public uint ProcessId;
    public string Title;
    public bool Visible;
    public long Owner;
    public int ExtendedStyle;
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

public static class NyxTopLevelWindows {
    private delegate bool EnumWindowsDelegate(IntPtr hWnd, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)]
    private struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsDelegate callback, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowTextW(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] private static extern int GetWindowTextLengthW(IntPtr hWnd);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] private static extern IntPtr GetWindow(IntPtr hWnd, uint command);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW")] private static extern int GetWindowLong(IntPtr hWnd, int index);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hWnd, out RECT rectangle);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern bool PostMessageW(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam);

    public static NyxTopLevelWindowRecord[] Snapshot() {
        List<NyxTopLevelWindowRecord> records=new List<NyxTopLevelWindowRecord>();
        EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
            uint processId;
            GetWindowThreadProcessId(hWnd,out processId);
            int length=GetWindowTextLengthW(hWnd);
            StringBuilder title=new StringBuilder(Math.Max(length+1,2));
            GetWindowTextW(hWnd,title,title.Capacity);
            RECT rect;
            GetWindowRect(hWnd,out rect);
            records.Add(new NyxTopLevelWindowRecord {
                Handle=hWnd.ToInt64(), ProcessId=processId, Title=title.ToString(), Visible=IsWindowVisible(hWnd),
                Owner=GetWindow(hWnd,4).ToInt64(), ExtendedStyle=GetWindowLong(hWnd,-20),
                Left=rect.Left, Top=rect.Top, Right=rect.Right, Bottom=rect.Bottom
            });
            return true;
        },IntPtr.Zero);
        return records.ToArray();
    }

    public static bool Close(long handle) { return PostMessageW(new IntPtr(handle),0x0010,IntPtr.Zero,IntPtr.Zero); }
}
'@
Add-Type -TypeDefinition $nativeSource -Language CSharp -ErrorAction Stop

$installRoot=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$dataRoot=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$launcherPath=Join-Path $installRoot 'Nyx PC Checkup.exe'
$appScriptPath=Join-Path $installRoot 'app\NyxPCCheckup.ps1'
$desktopShortcut=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
$startShortcut=Join-Path ([Environment]::GetFolderPath('Programs')) 'Dietrich AI Labs\Nyx PC Checkup.lnk'
$uninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup'
$startedUtc=(Get-Date).ToUniversalTime()
$setupRuns=[System.Collections.Generic.List[object]]::new()

function Get-NyxExactProcesses {
    $records=[System.Collections.Generic.List[object]]::new()
    foreach($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)){
        $exe=[string]$process.ExecutablePath
        $command=[string]$process.CommandLine
        $isLauncher=(-not [string]::IsNullOrWhiteSpace($exe) -and [string]::Equals([IO.Path]::GetFullPath($exe),[IO.Path]::GetFullPath($launcherPath),[StringComparison]::OrdinalIgnoreCase))
        $isAppPowerShell=([string]$process.Name -ieq 'powershell.exe' -and -not [string]::IsNullOrWhiteSpace($command) -and $command.IndexOf($appScriptPath,[StringComparison]::OrdinalIgnoreCase) -ge 0)
        $isNyxWorker=([string]$process.Name -ieq 'powershell.exe' -and -not [string]::IsNullOrWhiteSpace($command) -and $command.IndexOf($installRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $command.IndexOf('workers\',[StringComparison]::OrdinalIgnoreCase) -ge 0)
        if($isLauncher -or $isAppPowerShell -or $isNyxWorker){
            $records.Add([pscustomobject][ordered]@{ProcessId=[int]$process.ProcessId;ParentProcessId=[int]$process.ParentProcessId;Name=[string]$process.Name;ExecutablePath=$exe;CommandLine=$command;Kind=$(if($isLauncher){'Launcher'}elseif($isAppPowerShell){'Application'}else{'Worker'})})
        }
    }
    return @($records.ToArray())
}

function Get-NyxVisibleWindow {
    param([Parameter(Mandatory=$true)][int]$ProcessId,[string]$Title='Nyx PC Checkup')
    return @([NyxTopLevelWindows]::Snapshot()|Where-Object{[int]$_.ProcessId -eq $ProcessId -and [bool]$_.Visible -and [string]$_.Title -eq $Title}|Select-Object -First 1)
}

function Wait-NyxProcessExit {
    param([Parameter(Mandatory=$true)][int]$ProcessId,[int]$Seconds=15)
    $result=Wait-NyxValue -Seconds $Seconds -Probe {if($null -eq (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)){return $true};return $null}
    return ($null -ne $result)
}

function Wait-NyxClean {
    param([int]$Seconds=15)
    $result=Wait-NyxValue -Seconds $Seconds -Probe {if(@(Get-NyxExactProcesses).Count -eq 0){return $true};return $null}
    return ($null -ne $result)
}

function Clear-NyxExactProcesses {
    foreach($window in @([NyxTopLevelWindows]::Snapshot()|Where-Object{[string]$_.Title -eq 'Nyx PC Checkup' -and [bool]$_.Visible})){
        $owned=@(Get-NyxExactProcesses|Where-Object{[int]$_.ProcessId -eq [int]$window.ProcessId})
        if($owned.Count -gt 0){[void][NyxTopLevelWindows]::Close([int64]$window.Handle)}
    }
    [void](Wait-NyxClean -Seconds 5)
    foreach($process in @(Get-NyxExactProcesses|Sort-Object Kind -Descending)){
        Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue
    }
    [void](Wait-NyxClean -Seconds 10)
}

function Get-NewLauncher {
    param([int[]]$PriorProcessIds,[int]$Seconds=15)
    return Wait-NyxValue -Seconds $Seconds -Probe {
        $candidate=@(Get-NyxExactProcesses|Where-Object{$_.Kind -eq 'Launcher' -and $PriorProcessIds -notcontains [int]$_.ProcessId}|Select-Object -First 1)
        if($candidate.Count -eq 1){return $candidate[0]}
        return $null
    }
}

function Get-ApplicationChild {
    param([Parameter(Mandatory=$true)][int]$LauncherProcessId,[int]$Seconds=15)
    return Wait-NyxValue -Seconds $Seconds -Probe {
        $candidate=@(Get-NyxExactProcesses|Where-Object{$_.Kind -eq 'Application' -and [int]$_.ParentProcessId -eq $LauncherProcessId}|Select-Object -First 1)
        if($candidate.Count -eq 1){return $candidate[0]}
        return $null
    }
}

function Wait-NyxMainWindow {
    param([Parameter(Mandatory=$true)][int]$ApplicationProcessId,[int]$Seconds=30)
    return Wait-NyxValue -Seconds $Seconds -Probe {
        $candidate=@(Get-NyxVisibleWindow -ProcessId $ApplicationProcessId)
        if($candidate.Count -eq 1){return $candidate[0]}
        return $null
    }
}

function Save-NyxWindowScreenshot {
    param([Parameter(Mandatory=$true)][object]$Window,[Parameter(Mandatory=$true)][string]$Name)
    $width=[int]$Window.Right-[int]$Window.Left
    $height=[int]$Window.Bottom-[int]$Window.Top
    if($width -lt 100 -or $height -lt 100){return ''}
    $path=Join-Path $evidenceDirectory ($Name+'.png')
    $bitmap=New-Object Drawing.Bitmap($width,$height)
    try{
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try{$graphics.CopyFromScreen([int]$Window.Left,[int]$Window.Top,0,0,$bitmap.Size,[Drawing.CopyPixelOperation]::SourceCopy)}finally{$graphics.Dispose()}
        $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
    }finally{$bitmap.Dispose()}
    if(Test-Path -LiteralPath $path -PathType Leaf){$script:Screenshots.Add($path);return $path}
    return ''
}

function Close-NyxVisibleInstance {
    param([Parameter(Mandatory=$true)][object]$Window,[Parameter(Mandatory=$true)][int]$ApplicationProcessId,[int]$LauncherProcessId=0)
    [void][NyxTopLevelWindows]::Close([int64]$Window.Handle)
    $appExited=Wait-NyxProcessExit -ProcessId $ApplicationProcessId -Seconds 20
    $launcherExited=$true
    if($LauncherProcessId -gt 0){$launcherExited=Wait-NyxProcessExit -ProcessId $LauncherProcessId -Seconds 10}
    return [pscustomobject][ordered]@{ApplicationExited=$appExited;LauncherExited=$launcherExited;AllNyxProcessesExited=(Wait-NyxClean -Seconds 10)}
}

function Start-NyxInstalledControl {
    param([Parameter(Mandatory=$true)][ValidateSet('Shortcut','NativeExe','ScriptNoSta','ScriptSta')][string]$Control)
    Clear-NyxExactProcesses
    $cleanBefore=Wait-NyxClean -Seconds 10
    $prior=@(Get-NyxExactProcesses|ForEach-Object{[int]$_.ProcessId})
    $started=(Get-Date).ToUniversalTime()
    $directProcess=$null
    if($Control -eq 'Shortcut'){
        Start-Process -FilePath $desktopShortcut|Out-Null
        $launcher=Get-NewLauncher -PriorProcessIds $prior
        if($null -eq $launcher){throw 'The desktop shortcut did not start the exact installed native launcher.'}
        $application=Get-ApplicationChild -LauncherProcessId ([int]$launcher.ProcessId)
    }elseif($Control -eq 'NativeExe'){
        $directProcess=Start-Process -FilePath $launcherPath -WorkingDirectory $installRoot -PassThru
        $launcher=Get-NewLauncher -PriorProcessIds $prior
        if($null -eq $launcher -and $null -ne $directProcess){$launcher=[pscustomobject][ordered]@{ProcessId=[int]$directProcess.Id;ParentProcessId=0;Name='Nyx PC Checkup.exe';ExecutablePath=$launcherPath;CommandLine='';Kind='Launcher'}}
        if($null -eq $launcher){throw 'Direct EXE launch did not create the exact native launcher process.'}
        $application=Get-ApplicationChild -LauncherProcessId ([int]$launcher.ProcessId)
    }else{
        $arguments=[System.Collections.Generic.List[string]]::new()
        $arguments.Add('-NoLogo');$arguments.Add('-NoProfile');$arguments.Add('-NonInteractive')
        if($Control -eq 'ScriptSta'){$arguments.Add('-STA')}
        $arguments.Add('-ExecutionPolicy');$arguments.Add('Bypass');$arguments.Add('-File');$arguments.Add(('"{0}"' -f $appScriptPath))
        $directProcess=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList ($arguments -join ' ') -WorkingDirectory $installRoot -PassThru
        $launcher=$null
        $application=[pscustomobject][ordered]@{ProcessId=[int]$directProcess.Id;ParentProcessId=0;Name='powershell.exe';ExecutablePath="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe";CommandLine=($arguments -join ' ');Kind='Application'}
    }
    if($null -eq $application){throw ("{0} did not create the expected application PowerShell child." -f $Control)}
    $window=Wait-NyxMainWindow -ApplicationProcessId ([int]$application.ProcessId)
    $record=[pscustomobject][ordered]@{
        Control=$Control
        CleanBefore=$cleanBefore
        StartedUtc=$started.ToString('o')
        Launcher=$launcher
        Application=$application
        Window=$window
        Visible=($null -ne $window)
        TaskbarEligible=($null -ne $window -and [int64]$window.Owner -eq 0 -and (([int]$window.ExtendedStyle -band 0x80) -eq 0))
    }
    $script:ControlRecords.Add($record)
    return $record
}

try{
    Test-Step 'Setup candidate exists' (Test-Path -LiteralPath $SetupPath -PathType Leaf) $SetupPath
    Clear-NyxExactProcesses
    if(Test-Path -LiteralPath $installRoot -PathType Container){
        $oldUninstaller=Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe'
        if(Test-Path -LiteralPath $oldUninstaller -PathType Leaf){$old=Start-Process -FilePath $oldUninstaller -ArgumentList '/quiet /purgedata' -Wait -PassThru;Test-Step 'Prior exact installation uninstall exits 0' ([int]$old.ExitCode -eq 0) ([string]$old.ExitCode)}
    }
    if(Test-Path -LiteralPath $installRoot){throw 'A prior Nyx PC Checkup installation remains. Revert the disposable VM snapshot.'}
    Remove-Item -LiteralPath $dataRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $desktopShortcut,$startShortcut -Force -ErrorAction SilentlyContinue

    $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $SetupPath -BaseArguments '/quiet /nolaunch /desktop' -EvidenceDirectory $diagnosticWriteDirectory -Label 'F011FreshInstall'
    if(([string]$setupRun.DiagnosticPath).Length -ge 220){throw ('F-011 diagnostics write path is not safely below MAX_PATH: '+$setupRun.DiagnosticPath)}
    $archivedDiagnosticPath=''
    if([bool]$setupRun.DiagnosticExists){
        $archivedDiagnosticPath=Join-Path $evidenceDirectory 'F011FreshInstall_setup_diagnostics.json'
        Copy-Item -LiteralPath $setupRun.DiagnosticPath -Destination $archivedDiagnosticPath -Force
    }
    $setupRun|Add-Member -NotePropertyName DiagnosticWritePathLength -NotePropertyValue ([string]$setupRun.DiagnosticPath).Length
    $setupRun|Add-Member -NotePropertyName ArchivedDiagnosticPath -NotePropertyValue $archivedDiagnosticPath
    $setupRuns.Add($setupRun)
    Test-Step 'F-011 fresh install exits 0' ([int]$setupRun.ExitCode -eq 0) (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'F-011 fresh install reports SUCCESS branch' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'SUCCESS') (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Installed launcher exists' (Test-Path -LiteralPath $launcherPath -PathType Leaf) $launcherPath
    Test-Step 'Installed application script exists' (Test-Path -LiteralPath $appScriptPath -PathType Leaf) $appScriptPath
    Test-Step 'Installed desktop shortcut exists' (Test-Path -LiteralPath $desktopShortcut -PathType Leaf) $desktopShortcut

    $payload=Get-Content -LiteralPath (Join-Path $installRoot 'PAYLOAD_MANIFEST.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $launcherEntry=@($payload.files|Where-Object{[string]$_.path -eq 'Nyx PC Checkup.exe'}|Select-Object -First 1)
    $scriptEntry=@($payload.files|Where-Object{[string]$_.path -eq 'app/NyxPCCheckup.ps1'}|Select-Object -First 1)
    Test-Step 'Payload manifest has one launcher identity' ($launcherEntry.Count -eq 1) ($launcherEntry|ConvertTo-Json -Compress)
    Test-Step 'Installed launcher matches payload manifest' ($launcherEntry.Count -eq 1 -and (Get-FileHash -LiteralPath $launcherPath -Algorithm SHA256).Hash -eq [string]$launcherEntry[0].sha256) ((Get-FileHash -LiteralPath $launcherPath -Algorithm SHA256).Hash)
    Test-Step 'Installed script matches payload manifest' ($scriptEntry.Count -eq 1 -and (Get-FileHash -LiteralPath $appScriptPath -Algorithm SHA256).Hash -eq [string]$scriptEntry[0].sha256) ((Get-FileHash -LiteralPath $appScriptPath -Algorithm SHA256).Hash)

    $shortcut=(New-Object -ComObject WScript.Shell).CreateShortcut($desktopShortcut)
    Test-Step 'Desktop shortcut target is exact installed launcher' ([string]::Equals([IO.Path]::GetFullPath([string]$shortcut.TargetPath),[IO.Path]::GetFullPath($launcherPath),[StringComparison]::OrdinalIgnoreCase)) ([string]$shortcut.TargetPath)
    Test-Step 'Desktop shortcut working directory is exact install root' ([string]::Equals([IO.Path]::GetFullPath([string]$shortcut.WorkingDirectory),[IO.Path]::GetFullPath($installRoot),[StringComparison]::OrdinalIgnoreCase)) ([string]$shortcut.WorkingDirectory)

    $shortcutControl=Start-NyxInstalledControl -Control Shortcut
    Test-Step 'Shortcut control starts from clean process state' ([bool]$shortcutControl.CleanBefore) (($shortcutControl|ConvertTo-Json -Depth 5 -Compress))
    Test-Step 'Desktop shortcut starts exactly one application child' ($null -ne $shortcutControl.Launcher -and $null -ne $shortcutControl.Application) (($shortcutControl|ConvertTo-Json -Depth 5 -Compress))
    Test-Step 'Desktop shortcut produces a visible Nyx main window' ([bool]$shortcutControl.Visible) (($shortcutControl|ConvertTo-Json -Depth 5 -Compress))
    Test-Step 'Desktop shortcut main window is taskbar-eligible' ([bool]$shortcutControl.TaskbarEligible) (($shortcutControl|ConvertTo-Json -Depth 5 -Compress))
    if($null -eq $shortcutControl.Window){throw 'The actual desktop shortcut did not produce a visible Nyx main window.'}
    $shot=Save-NyxWindowScreenshot -Window $shortcutControl.Window -Name 'F011_desktop_shortcut_visible_main_window'
    Test-Step 'Desktop shortcut visible main-window screenshot captured' (-not [string]::IsNullOrWhiteSpace($shot)) $shot

    $firstLauncherId=[int]$shortcutControl.Launcher.ProcessId
    $firstApplicationId=[int]$shortcutControl.Application.ProcessId
    $beforeSecond=@(Get-NyxExactProcesses|ForEach-Object{[int]$_.ProcessId})
    $secondStart=Start-Process -FilePath $launcherPath -WorkingDirectory $installRoot -PassThru
    $secondLauncher=Get-NewLauncher -PriorProcessIds $beforeSecond
    if($null -eq $secondLauncher){$secondLauncher=[pscustomobject][ordered]@{ProcessId=[int]$secondStart.Id}}
    $secondApplication=Get-ApplicationChild -LauncherProcessId ([int]$secondLauncher.ProcessId)
    $secondWindow=$null
    if($null -ne $secondApplication){$secondWindow=Wait-NyxMainWindow -ApplicationProcessId ([int]$secondApplication.ProcessId) -Seconds 15}
    Test-Step 'Second installed launch starts a distinct application child' ($null -ne $secondApplication -and [int]$secondApplication.ProcessId -ne $firstApplicationId) $(if($null -ne $secondApplication){$secondApplication|ConvertTo-Json -Compress}else{'missing'})
    Test-Step 'Second installed launch displays visible singleton warning' ($null -ne $secondWindow) $(if($null -ne $secondWindow){$secondWindow|ConvertTo-Json -Compress}else{'missing'})
    Test-Step 'First visible instance remains alive during singleton warning' ($null -ne (Get-Process -Id $firstApplicationId -ErrorAction SilentlyContinue)) ([string]$firstApplicationId)
    if($null -ne $secondWindow){[void][NyxTopLevelWindows]::Close([int64]$secondWindow.Handle)}
    if($null -ne $secondApplication){Test-Step 'Second application exits after singleton warning closes' (Wait-NyxProcessExit -ProcessId ([int]$secondApplication.ProcessId) -Seconds 15) ([string]$secondApplication.ProcessId)}
    Test-Step 'Second native launcher exits after singleton warning closes' (Wait-NyxProcessExit -ProcessId ([int]$secondLauncher.ProcessId) -Seconds 10) ([string]$secondLauncher.ProcessId)

    $closeFirst=Close-NyxVisibleInstance -Window $shortcutControl.Window -ApplicationProcessId $firstApplicationId -LauncherProcessId $firstLauncherId
    Test-Step 'Closing shortcut main window exits application child' ([bool]$closeFirst.ApplicationExited) ($closeFirst|ConvertTo-Json -Compress)
    Test-Step 'Closing shortcut main window exits native launcher' ([bool]$closeFirst.LauncherExited) ($closeFirst|ConvertTo-Json -Compress)
    Test-Step 'Closing shortcut main window leaves no exact Nyx process' ([bool]$closeFirst.AllNyxProcessesExited) ($closeFirst|ConvertTo-Json -Compress)

    $nativeControl=Start-NyxInstalledControl -Control NativeExe
    Test-Step 'Direct installed EXE starts from clean process state' ([bool]$nativeControl.CleanBefore) ($nativeControl|ConvertTo-Json -Depth 5 -Compress)
    Test-Step 'Direct installed EXE produces a visible Nyx main window' ([bool]$nativeControl.Visible) ($nativeControl|ConvertTo-Json -Depth 5 -Compress)
    Test-Step 'Direct installed EXE main window is taskbar-eligible' ([bool]$nativeControl.TaskbarEligible) ($nativeControl|ConvertTo-Json -Depth 5 -Compress)
    if($null -eq $nativeControl.Window){throw 'Direct installed EXE did not produce a visible Nyx main window.'}
    $closeNative=Close-NyxVisibleInstance -Window $nativeControl.Window -ApplicationProcessId ([int]$nativeControl.Application.ProcessId) -LauncherProcessId ([int]$nativeControl.Launcher.ProcessId)
    Test-Step 'Direct installed EXE closes cleanly' ([bool]$closeNative.ApplicationExited -and [bool]$closeNative.LauncherExited -and [bool]$closeNative.AllNyxProcessesExited) ($closeNative|ConvertTo-Json -Compress)

    $scriptNoSta=Start-NyxInstalledControl -Control ScriptNoSta
    Test-Step 'Clean direct-script control without explicit STA is classified' ([bool]$scriptNoSta.CleanBefore -and $null -ne $scriptNoSta.Application) ($scriptNoSta|ConvertTo-Json -Depth 5 -Compress)
    Test-Step 'Clean direct-script control without explicit STA produces visible main window' ([bool]$scriptNoSta.Visible) ($scriptNoSta|ConvertTo-Json -Depth 5 -Compress)
    if($null -ne $scriptNoSta.Window){$closeNoSta=Close-NyxVisibleInstance -Window $scriptNoSta.Window -ApplicationProcessId ([int]$scriptNoSta.Application.ProcessId);Test-Step 'Direct-script no-STA control closes cleanly' ([bool]$closeNoSta.AllNyxProcessesExited) ($closeNoSta|ConvertTo-Json -Compress)}else{Clear-NyxExactProcesses}

    $scriptSta=Start-NyxInstalledControl -Control ScriptSta
    Test-Step 'Clean direct-script control with explicit STA is classified' ([bool]$scriptSta.CleanBefore -and $null -ne $scriptSta.Application) ($scriptSta|ConvertTo-Json -Depth 5 -Compress)
    Test-Step 'Clean direct-script control with explicit STA produces visible main window' ([bool]$scriptSta.Visible) ($scriptSta|ConvertTo-Json -Depth 5 -Compress)
    if($null -ne $scriptSta.Window){$closeSta=Close-NyxVisibleInstance -Window $scriptSta.Window -ApplicationProcessId ([int]$scriptSta.Application.ProcessId);Test-Step 'Direct-script STA control closes cleanly' ([bool]$closeSta.AllNyxProcessesExited) ($closeSta|ConvertTo-Json -Compress)}else{Clear-NyxExactProcesses}

    $relaunch=Start-NyxInstalledControl -Control NativeExe
    Test-Step 'Immediate fresh relaunch opens visibly again' ([bool]$relaunch.CleanBefore -and [bool]$relaunch.Visible -and [bool]$relaunch.TaskbarEligible) ($relaunch|ConvertTo-Json -Depth 5 -Compress)
    if($null -ne $relaunch.Window){$closeRelaunch=Close-NyxVisibleInstance -Window $relaunch.Window -ApplicationProcessId ([int]$relaunch.Application.ProcessId) -LauncherProcessId ([int]$relaunch.Launcher.ProcessId);Test-Step 'Immediate fresh relaunch closes without residue' ([bool]$closeRelaunch.AllNyxProcessesExited) ($closeRelaunch|ConvertTo-Json -Compress)}else{Clear-NyxExactProcesses}
}catch{
    Test-Step 'F-011 installed-launch harness completed without unhandled error' $false $_.Exception.ToString()
}finally{
    Clear-NyxExactProcesses
    Remove-Item -LiteralPath $diagnosticWriteDirectory -Recurse -Force -ErrorAction SilentlyContinue
    if(Test-Path -LiteralPath $installRoot -PathType Container){
        $uninstaller=Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe'
        if(Test-Path -LiteralPath $uninstaller -PathType Leaf){
            try{
                $uninstall=Start-Process -FilePath $uninstaller -ArgumentList '/quiet /purgedata' -Wait -PassThru
                Test-Step 'F-011 cleanup uninstaller exits 0' ([int]$uninstall.ExitCode -eq 0) ([string]$uninstall.ExitCode)
            }catch{Test-Step 'F-011 cleanup uninstaller runs without exception' $false $_.Exception.ToString()}
        }
    }
    $installGone=$null -ne (Wait-NyxValue -Seconds 25 -Probe {if(-not(Test-Path -LiteralPath $installRoot)){return $true};return $null})
    Test-Step 'F-011 cleanup removes install root' $installGone $installRoot
    Test-Step 'F-011 cleanup leaves no exact Nyx process' (Wait-NyxClean -Seconds 10) ((Get-NyxExactProcesses|ConvertTo-Json -Depth 5 -Compress))
}

$completedUtc=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.qa14-f011-installed-launch-regression.v1'
    Build=$script:ExpectedBuild
    HarnessRevision=$script:ExpectedHarnessRevision
    HarnessCorrectionRevision='QA15-F011-PATH-1'
    StartedUtc=$startedUtc.ToString('o')
    CompletedUtc=$completedUtc.ToString('o')
    ElapsedSeconds=[math]::Round(($completedUtc-$startedUtc).TotalSeconds,3)
    ComputerName=$env:COMPUTERNAME
    UserIdentity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    PSEdition=$PSVersionTable.PSEdition
    IsAdministrator=$isAdmin
    SetupPath=$SetupPath
    SetupSha256=(Get-FileHash -LiteralPath $SetupPath -Algorithm SHA256).Hash
    InstallRoot=$installRoot
    Passed=($script:Failures -eq 0)
    Total=$script:Results.Count
    Failed=$script:Failures
    Results=@($script:Results.ToArray())
    Controls=@($script:ControlRecords.ToArray())
    SetupRuns=@($setupRuns.ToArray())
    Screenshots=@($script:Screenshots.ToArray())
}
[IO.File]::WriteAllText($outputFull,($report|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
Write-Host ("F-011 installed-launch regression: {0}/{1} PASS" -f ($report.Total-$report.Failed),$report.Total)
Write-Host ("Report: {0}" -f $outputFull)
if(-not $report.Passed){exit 1}
exit 0

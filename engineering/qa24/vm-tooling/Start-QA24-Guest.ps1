Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\Q24F021'
$session=Join-Path $env:LOCALAPPDATA ('NyxQA24Evidence\f021_'+(Get-Date -Format yyyyMMdd_HHmmss))
[void][IO.Directory]::CreateDirectory($session)
Start-Transcript -LiteralPath (Join-Path $session 'TRANSCRIPT.txt') -Force | Out-Null
function Write-Record {param([string]$Name,$Value) $Value | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $session $Name) -Encoding UTF8}
try{
    if($PSVersionTable.PSVersion.Major -ne 5 -or -not [Environment]::Is64BitProcess){throw 'Native x64 Windows PowerShell 5.1 required'}
    if($env:USERNAME -ne 'Nyx'){throw 'Use the disposable Nyx user'}
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Focused interactive gate must be non-elevated'}
    $expected=@{
        'Nyx_PC_Checkup_1.0.0_Setup.exe'='52834E3703A42265679727EDB54387E5B84D1BBCEA564B831D6F1B98F04EC73F'
        'Nyx_PC_Checkup_1.0.0_Portable.zip'='E52AF958BD18EC9C5FC298B0CCFE04C0D4816AE709BEEFA98BF745E45EA45095'
        'Nyx_PC_Checkup_1.0.0_Source.zip'='1745C60064D2BBE42B15E20A5089A7CDBDC81FC08177806DA75C1F868BE012B1'
    }
    $artifactRecords=foreach($name in $expected.Keys){
        $path=Join-Path $root $name
        $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if($hash -ne $expected[$name]){throw "Frozen artifact mismatch: $name"}
        [pscustomobject]@{Name=$name;SHA256=$hash;Bytes=(Get-Item -LiteralPath $path).Length}
    }
    Write-Record 'ARTIFACTS.json' @($artifactRecords)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $graphics=[Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    try{$dpi=$graphics.DpiX}finally{$graphics.Dispose()}
    Write-Record 'ENVIRONMENT.json' ([pscustomobject]@{
        Build='2026.09.27-eng-qa24';Harness='QA24-F021-PS51-24'
        SourceCommit='31ff35dead242485bad2ab74c4838e8a5d41cb7f';User=$identity.Name
        OS=[Environment]::OSVersion.VersionString;PowerShell=$PSVersionTable.PSVersion.ToString()
        Dpi=$dpi;Screen=[Windows.Forms.Screen]::PrimaryScreen.Bounds.ToString()
        WorkingArea=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea.ToString();Utc=[DateTime]::UtcNow.ToString('o')
        Kind='installed interactive observation session; not an automatic acceptance verdict'
    })
    $installRoot=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $setup=Start-Process -FilePath (Join-Path $root 'Nyx_PC_Checkup_1.0.0_Setup.exe') -ArgumentList ('/quiet /nolaunch /desktop /diagnostics:"'+(Join-Path $session 'SETUP_DIAGNOSTICS.json')+'"') -PassThru -Wait
    Write-Record 'SETUP_RESULT.json' @{ExitCode=$setup.ExitCode;Utc=[DateTime]::UtcNow.ToString('o');InstallRoot=$installRoot}
    if($setup.ExitCode -ne 0){throw "Setup failed with exit $($setup.ExitCode)"}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $root 'Nyx_PC_Checkup_1.0.0_Portable.zip'))
    $payload=New-Object 'Collections.Generic.List[object]'
    try{
        foreach($entry in $archive.Entries){
            if($entry.FullName.EndsWith('/')){continue}
            $relative=$entry.FullName.Substring($entry.FullName.IndexOf('/')+1)
            if($relative -notlike 'app/*' -and $relative -ne 'Nyx PC Checkup.exe'){continue}
            $installed=Join-Path $installRoot $relative
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try{$expectedHash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
            $actualHash=(Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash
            $payload.Add([pscustomobject]@{Path=$relative;Expected=$expectedHash;Actual=$actualHash;Match=($actualHash -eq $expectedHash)})
            if($actualHash -ne $expectedHash){throw "Installed payload mismatch: $relative"}
        }
    }finally{$archive.Dispose();Write-Record 'INSTALLED_PAYLOAD_HASHES.json' $payload.ToArray()}
    if($payload.Count -lt 40){throw 'Insufficient installed payload identity coverage'}
    $shell=New-Object -ComObject WScript.Shell
    $shortcutPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
    $shortcut=$shell.CreateShortcut($shortcutPath)
    Write-Record 'SHORTCUT.json' @{Path=$shortcutPath;TargetPath=$shortcut.TargetPath;Arguments=$shortcut.Arguments;WorkingDirectory=$shortcut.WorkingDirectory;IconLocation=$shortcut.IconLocation}
    if($shortcut.TargetPath -ne (Join-Path $installRoot 'Nyx PC Checkup.exe')){throw 'Installed desktop shortcut target mismatch'}
    $started=[DateTime]::UtcNow
    $launcher=Start-Process -FilePath $shortcutPath -PassThru
    Write-Record 'LAUNCH.json' @{LauncherPID=$launcher.Id;Utc=$started.ToString('o');Method='installed desktop shortcut'}
    $seen=$false;$absent=0
    while($true){
        $processes=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.CommandLine -like ('*'+$installRoot+'\app\NyxPCCheckup.ps1*')})
        $records=@(foreach($process in $processes){
            $live=Get-Process -Id $process.ProcessId -ErrorAction SilentlyContinue
            [pscustomobject]@{PID=$process.ProcessId;ParentPID=$process.ParentProcessId;CommandLine=$process.CommandLine;MainWindowTitle=$(if($live){$live.MainWindowTitle}else{''});MainWindowHandle=$(if($live){$live.MainWindowHandle.ToInt64()}else{0})}
        })
        $observation=[pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Processes=$records}
        $observation | ConvertTo-Json -Depth 5 -Compress | Add-Content -LiteralPath (Join-Path $session 'PROCESS_OBSERVATIONS.jsonl') -Encoding UTF8
        if($processes.Count){$seen=$true;$absent=0}else{$absent++}
        if(-not $seen -and ([DateTime]::UtcNow-$started).TotalSeconds -gt 45){throw 'No installed application PowerShell child observed within 45 seconds'}
        if($seen -and $absent -ge 3){break}
        Start-Sleep -Seconds 2
    }
    $dataRoot=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
    if(Test-Path -LiteralPath $dataRoot){Copy-Item -LiteralPath $dataRoot -Destination (Join-Path $session 'app-data-after-close') -Recurse}
    Write-Record 'CLOSED.json' @{Utc=[DateTime]::UtcNow.ToString('o');InstalledChildNoLongerPresent=$true;Acceptance='Pending review of interactive evidence'}
}catch{
    Write-Record 'SESSION_BLOCKED.json' @{Utc=[DateTime]::UtcNow.ToString('o');Error=$_.Exception.ToString();Stack=$_.ScriptStackTrace;Acceptance='Not established'}
}finally{Stop-Transcript | Out-Null}

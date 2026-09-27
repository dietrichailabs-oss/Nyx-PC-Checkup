Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$root='C:\Q23F020'
$evidence=Join-Path $env:LOCALAPPDATA ('NyxQA23Evidence\f020_'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence|Out-Null
$fixture='NyxQA23_MissingTarget_F020'
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$created=$false
try{
    if($env:USERNAME -ne 'Nyx'){throw 'Expected disposable Nyx user'}
    if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Inbox PS5.1 required'}
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if($admin){throw 'Focused installed gate must be non-elevated'}
    $identity=Get-Content -LiteralPath "$root\CANDIDATE_IDENTITY.json" -Raw|ConvertFrom-Json
    foreach($kind in @('Setup','Portable','Source')){
        if((Get-FileHash -LiteralPath (Join-Path $root $identity.$kind.File)).Hash -ne $identity.$kind.SHA256){throw "Frozen identity mismatch: $kind"}
    }
    $data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
    foreach($name in @('config.json','scans\last-scan.json')){
        $path=Join-Path $data $name
        if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination (Join-Path $evidence ('PREINSTALL_'+[IO.Path]::GetFileName($path)))}
    }
    $setup=Start-Process -FilePath "$root\Nyx_PC_Checkup_1.0.0_Setup.exe" -ArgumentList '/quiet /nolaunch /desktop' -PassThru -Wait
    @{ExitCode=$setup.ExitCode;PowerShell=$PSVersionTable.PSVersion.ToString();Elevated=$admin;Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath "$evidence\INSTALL_RESULT.json" -Encoding UTF8
    if($setup.ExitCode -ne 0){throw 'QA23 Setup failed; stop'}
    $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    if((Get-Content -LiteralPath "$install\VERSION.json" -Raw|ConvertFrom-Json).build -ne $identity.Build){throw 'Installed build mismatch'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $root $identity.Portable.File))
    $comparisons=New-Object 'Collections.Generic.List[object]'
    try{
        foreach($entry in $archive.Entries){
            if(!$entry.Name){continue}
            $relative=$entry.FullName.Substring($entry.FullName.IndexOf('/')+1).Replace('/', '\')
            if(!$relative -or $relative.Contains('..')){throw 'Invalid portable relative path'}
            $path=Join-Path $install $relative
            $stream=$entry.Open();$hasher=[Security.Cryptography.SHA256]::Create()
            try{$expected=([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','')}finally{$stream.Dispose();$hasher.Dispose()}
            $actual=if(Test-Path -LiteralPath $path){(Get-FileHash -LiteralPath $path).Hash}else{'MISSING'}
            $comparisons.Add([pscustomobject]@{Path=$relative;Expected=$expected;Actual=$actual;Match=($expected -eq $actual)})
        }
    }finally{$archive.Dispose()}
    $comparisons.ToArray()|ConvertTo-Json -Depth 4|Set-Content -LiteralPath "$evidence\INSTALLED_PORTABLE_COMPARISON.json" -Encoding UTF8
    if(@($comparisons|Where-Object {-not $_.Match}).Count){throw 'Installed payload does not match frozen portable'}
    $startup=Get-ItemProperty -LiteralPath $key
    if($startup.PSObject.Properties.Name -contains $fixture){throw 'Fixture exists; refusing overwrite'}
    $startup|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$evidence\STARTUP_BEFORE.json" -Encoding UTF8
    New-ItemProperty -LiteralPath $key -Name $fixture -Value '"C:\NyxQA23Nonexistent_F020\missing.exe"' -PropertyType String|Out-Null
    $created=$true
    $observer=Start-Process -FilePath "$PSHOME\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Q23F020\Observe-Installed.ps1" -Evidence "'+$evidence+'"') -PassThru
    Start-Sleep -Seconds 3
    if((Get-Content -LiteralPath "$evidence\OBSERVER_STATUS.json" -Raw|ConvertFrom-Json).Status -ne 'MONITORING'){throw 'Observer not ready'}
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $probe=New-Object Windows.Forms.Form
    $graphics=$probe.CreateGraphics()
    try{$dpi=$graphics.DpiX}finally{$graphics.Dispose();$probe.Dispose()}
    @{Dpi=$dpi;Scale=($dpi/96);Screen=[Windows.Forms.Screen]::PrimaryScreen.Bounds.ToString();WorkingArea=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea.ToString();User=$env:USERNAME;PowerShell=$PSVersionTable.PSVersion.ToString();Elevated=$admin}|ConvertTo-Json|Set-Content -LiteralPath "$evidence\ENVIRONMENT.json" -Encoding UTF8
    $launcher=Start-Process -FilePath "$install\Nyx PC Checkup.exe" -PassThru
    @{Status='F020_INSTALLED_READY';Build=$identity.Build;LauncherPID=$launcher.Id;ObserverPID=$observer.Id;Acceptance='NOT_CLAIMED'}|ConvertTo-Json|Set-Content -LiteralPath "$evidence\RUN_STATUS.json" -Encoding UTF8
    $seen=$false;$deadline=(Get-Date).AddSeconds(60)
    do{
        Start-Sleep -Seconds 2
        $ui=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -and $_.CommandLine.Contains($install) -and $_.CommandLine -match 'NyxPCCheckup\.ps1'})
        if($ui.Count){$seen=$true}
        if(!$seen -and (Get-Date) -gt $deadline){throw 'Installed UI process not observed'}
    }while(!$seen -or $ui.Count)
    Remove-ItemProperty -LiteralPath $key -Name $fixture
    $created=$false
    Get-ItemProperty -LiteralPath $key|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$evidence\STARTUP_RESTORED.json" -Encoding UTF8
    @{Status='UI_CLOSED_FIXTURE_REMOVED';Build=$identity.Build;Acceptance='REQUIRES_UI_EVIDENCE';Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath "$evidence\RUN_STATUS.json" -Encoding UTF8
}catch{
    @{Status='STOPPED';Error=$_.Exception.ToString();Utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath "$evidence\RUN_STATUS.json" -Encoding UTF8
    throw
}finally{if($created){Remove-ItemProperty -LiteralPath $key -Name $fixture -ErrorAction Stop}}

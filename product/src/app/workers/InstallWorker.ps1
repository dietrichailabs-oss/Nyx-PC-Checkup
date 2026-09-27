[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallRoot,[int]$CreateDesktop=0,[int]$Quiet=0)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

function Get-NyxFileSnapshot {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not(Test-Path -LiteralPath $Path)){return [pscustomobject]@{Path=$Path;Exists=$false;Bytes=''}}
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or $item.Length -gt 1048576){throw "An existing installer integration file is unsafe or unexpectedly large: $Path"}
    return [pscustomobject]@{Path=$Path;Exists=$true;Bytes=[Convert]::ToBase64String([IO.File]::ReadAllBytes($item.FullName))}
}

function Restore-NyxFileSnapshot {
    param([Parameter(Mandatory=$true)][object]$Snapshot)
    if([bool]$Snapshot.Exists){
        $parent=Split-Path -Parent ([string]$Snapshot.Path)
        if(-not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
        [IO.File]::WriteAllBytes([string]$Snapshot.Path,[Convert]::FromBase64String([string]$Snapshot.Bytes))
    }else{
        Remove-Item -LiteralPath ([string]$Snapshot.Path) -Force -ErrorAction SilentlyContinue
    }
}

function Get-NyxRegistrySnapshot {
    param([Parameter(Mandatory=$true)][string]$Path)
    if(-not(Test-Path -LiteralPath $Path)){return [pscustomobject]@{Path=$Path;Exists=$false;Values=@()}}
    $key=Get-Item -LiteralPath $Path -ErrorAction Stop
    $values=[System.Collections.Generic.List[object]]::new()
    foreach($name in @($key.GetValueNames())){
        $kind=[string]$key.GetValueKind($name)
        $value=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if($kind -eq 'Binary'){$value=[Convert]::ToBase64String([byte[]]$value)}
        $values.Add([pscustomobject]@{Name=[string]$name;Kind=$kind;Value=$value})
    }
    return [pscustomobject]@{Path=$Path;Exists=$true;Values=@($values.ToArray())}
}

function Restore-NyxRegistrySnapshot {
    param([Parameter(Mandatory=$true)][object]$Snapshot)
    Remove-Item -LiteralPath ([string]$Snapshot.Path) -Recurse -Force -ErrorAction SilentlyContinue
    if(-not [bool]$Snapshot.Exists){return}
    New-Item -Path ([string]$Snapshot.Path) -Force|Out-Null
    $key=Get-Item -LiteralPath ([string]$Snapshot.Path) -ErrorAction Stop
    foreach($entry in @($Snapshot.Values)){
        $kind=[Microsoft.Win32.RegistryValueKind]([Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$entry.Kind,$true))
        $value=$entry.Value
        if([string]$entry.Kind -eq 'Binary'){$value=[Convert]::FromBase64String([string]$value)}
        elseif([string]$entry.Kind -eq 'DWord'){$value=[int]$value}
        elseif([string]$entry.Kind -eq 'QWord'){$value=[int64]$value}
        elseif([string]$entry.Kind -eq 'MultiString'){$value=[string[]]@($value)}
        $key.SetValue([string]$entry.Name,$value,$kind)
    }
}

$snapshotsCaptured=$false
$startSnapshot=$null
$desktopSnapshot=$null
$uninstallSnapshot=$null
$startFolder=''
$startFolderExisted=$true
$shell=$null
try{
    $expected=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $actualFull=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
    $expectedFull=[IO.Path]::GetFullPath($expected).TrimEnd('\')
    if(-not [string]::Equals($actualFull,$expectedFull,[StringComparison]::OrdinalIgnoreCase)){throw 'The installation location failed its safety boundary check.'}
    $InstallRoot=$actualFull
    $manifestPath=Join-Path $InstallRoot 'PAYLOAD_MANIFEST.json'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'The clean-payload manifest is missing.'}
    $manifestItem=Get-Item -LiteralPath $manifestPath -Force -ErrorAction Stop
    if(($manifestItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $manifestItem.Length -gt 4194304){throw 'The clean-payload manifest is unsafe or too large.'}
    $manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
    if([string]$manifest.schema -ne 'dietrich-ai-labs.nyx-pc-checkup.payload.v1' -or [string]$manifest.version -ne '1.0.0'){throw 'The clean-payload manifest identity is invalid.'}
    $expectedFiles=@{}
    foreach($entry in @($manifest.files)){
        $rel=[string]$entry.path
        if([string]::IsNullOrWhiteSpace($rel) -or $rel.StartsWith('/') -or $rel.StartsWith('\') -or $rel -match '(^|[\\/])\.\.([\\/]|$)' -or $expectedFiles.ContainsKey($rel)){throw 'The clean-payload manifest contains an invalid or duplicate path.'}
        $expectedFiles[$rel]=$entry
        $full=Join-Path $InstallRoot ($rel.Replace('/','\'))
        $item=Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw "The payload item is not an ordinary file: $rel"}
        if([int64]$item.Length -ne [int64]$entry.size){throw "The payload size does not match: $rel"}
        $hash=(Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash
        if($hash -ne [string]$entry.sha256){throw "The payload hash does not match: $rel"}
    }
    $actualFiles=@(Get-ChildItem -LiteralPath $InstallRoot -Recurse -File -Force -ErrorAction Stop|Where-Object{$_.FullName -ne $manifestPath})
    foreach($item in $actualFiles){
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'The installed payload contains a reparse point.'}
        $rel=$item.FullName.Substring($InstallRoot.Length).TrimStart('\').Replace('\','/')
        if(-not $expectedFiles.ContainsKey($rel)){throw "An unexpected file appeared in the clean payload: $rel"}
    }
    if($actualFiles.Count -ne $expectedFiles.Count){throw 'The payload file count does not match the clean-payload manifest.'}

    $target=Join-Path $InstallRoot 'Nyx PC Checkup.exe'
    $icon=Join-Path $InstallRoot 'app\assets\nyx_pc_checkup.ico'
    if(-not(Test-Path -LiteralPath $target)){throw 'The application launcher is missing from the installed payload.'}
    $startFolder=Join-Path ([Environment]::GetFolderPath('Programs')) 'Dietrich AI Labs'
    $startFolderExisted=Test-Path -LiteralPath $startFolder -PathType Container
    $startLink=Join-Path $startFolder 'Nyx PC Checkup.lnk'
    $desktopLink=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
    $uninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup'
    $startSnapshot=Get-NyxFileSnapshot -Path $startLink
    $desktopSnapshot=Get-NyxFileSnapshot -Path $desktopLink
    $uninstallSnapshot=Get-NyxRegistrySnapshot -Path $uninstallKey
    $snapshotsCaptured=$true

    # Internal install-state is written before external integration changes.
    [pscustomobject]@{Product='Nyx PC Checkup';Version='1.0.0';Build='2026.09.26-eng-qa19';InstalledUtc=(Get-Date).ToUniversalTime().ToString('o');InstallRoot=$InstallRoot;PayloadManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $InstallRoot 'install-state.json') -Encoding UTF8

    $shell=New-Object -ComObject WScript.Shell
    New-Item -ItemType Directory -Path $startFolder -Force|Out-Null
    $shortcut=$shell.CreateShortcut($startLink);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$InstallRoot;$shortcut.Description='Clear, local-first Windows PC health checkup';$shortcut.IconLocation="$icon,0";$shortcut.Save()
    if($CreateDesktop -eq 1){
        $shortcut=$shell.CreateShortcut($desktopLink);$shortcut.TargetPath=$target;$shortcut.WorkingDirectory=$InstallRoot;$shortcut.Description='Nyx PC Checkup';$shortcut.IconLocation="$icon,0";$shortcut.Save()
    }
    New-Item -Path $uninstallKey -Force|Out-Null
    $values=@{
        DisplayName='Nyx PC Checkup';DisplayVersion='1.0.0';Publisher='Dietrich AI Labs';InstallLocation=$InstallRoot;
        DisplayIcon="$icon,0";UninstallString=('"'+(Join-Path $InstallRoot 'Uninstall Nyx PC Checkup.exe')+'"');
        QuietUninstallString=('"'+(Join-Path $InstallRoot 'Uninstall Nyx PC Checkup.exe')+'" /quiet');
        Comments='Local-first Windows PC health and maintenance checkup';InstallDate=(Get-Date).ToString('yyyyMMdd')
    }
    foreach($name in $values.Keys){New-ItemProperty -LiteralPath $uninstallKey -Name $name -Value $values[$name] -PropertyType String -Force|Out-Null}
    New-ItemProperty -LiteralPath $uninstallKey -Name NoModify -Value 1 -PropertyType DWord -Force|Out-Null
    New-ItemProperty -LiteralPath $uninstallKey -Name NoRepair -Value 1 -PropertyType DWord -Force|Out-Null
    exit 0
}catch{
    if($snapshotsCaptured){
        try{Restore-NyxFileSnapshot -Snapshot $startSnapshot}catch{}
        try{Restore-NyxFileSnapshot -Snapshot $desktopSnapshot}catch{}
        try{Restore-NyxRegistrySnapshot -Snapshot $uninstallSnapshot}catch{}
        try{if(-not $startFolderExisted -and (Test-Path -LiteralPath $startFolder -PathType Container) -and @(Get-ChildItem -LiteralPath $startFolder -Force -ErrorAction Stop).Count -eq 0){Remove-Item -LiteralPath $startFolder -Force -ErrorAction Stop}}catch{}
    }
    if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show("Installation finalization failed:`r`n$($_.Exception.Message)",'Nyx PC Checkup Installer','OK','Error')|Out-Null}
    exit 1
}finally{
    if($null -ne $shell){try{[Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)|Out-Null}catch{}}
}

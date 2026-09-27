[CmdletBinding()]
param(
    [switch]$AcceptanceProbe,
    [switch]$AcceptanceUiCloseProbe,
    [string]$AcceptanceOutputPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$AppRoot=$PSScriptRoot
$mutex=$null
$created=$false

function Write-NyxAcceptanceProbeFile {
    param([Parameter(Mandatory=$true)][object]$Value)
    if([string]::IsNullOrWhiteSpace($AcceptanceOutputPath)){throw 'AcceptanceOutputPath is required for the acceptance probe.'}
    $full=[IO.Path]::GetFullPath($AcceptanceOutputPath)
    if([IO.Path]::GetFileName($full) -notmatch '^Nyx_PC_Checkup_App_Probe_[1-4]\.json$'){throw 'The acceptance probe output filename is invalid.'}
    $parent=[IO.Path]::GetDirectoryName($full)
    $parentItem=Get-Item -LiteralPath $parent -Force -ErrorAction Stop
    if(-not $parentItem.PSIsContainer -or (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The acceptance probe output directory is unsafe.'}
    [IO.File]::WriteAllText($full,($Value|ConvertTo-Json -Depth 15),[Text.UTF8Encoding]::new($false))
}

function Invoke-NyxApplicationAcceptanceProbe {
    param([Parameter(Mandatory=$true)][object]$Composition)
    if($env:NYX_PC_CHECKUP_ACCEPTANCE -ne '1'){throw 'The application acceptance probe is available only to the explicit QA harness.'}
    $paths=Initialize-NyxDataDirectories
    $id=[guid]::NewGuid().ToString('N')
    $out=Join-Path $paths.Temp ("scan-$id.json")
    $progress=Join-Path $paths.Temp ("scan-$id-progress.jsonl")
    $cancel=Join-Path $paths.Temp ("scan-$id.cancel")
    try{
        $worker=Join-Path $AppRoot 'workers\ScanWorker.ps1'
        $ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" -Mode Quick -OutputPath `"$out`" -ProgressPath `"$progress`" -CancelPath `"$cancel`""
        $process=Start-Process -FilePath $ps -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        if($process.ExitCode -ne 0){throw ("The real Quick Check worker exited {0}." -f $process.ExitCode)}
        if(-not(Test-Path -LiteralPath $out -PathType Leaf)){throw 'The real Quick Check did not produce a result file.'}
        $scan=Get-Content -LiteralPath $out -Raw -Encoding UTF8|ConvertFrom-Json
        if($null -ne $scan.PSObject.Properties['WorkerError']){throw ("The real Quick Check reported a worker error: {0}" -f $scan.WorkerError)}
        if(-not [bool]$scan.ReadOnly){throw 'The real Quick Check result was not marked read-only.'}
        if(@($scan.Results).Count -lt 8){throw ("The real Quick Check returned too few results: {0}" -f @($scan.Results).Count)}
        return [pscustomobject][ordered]@{
            Schema='dietrich-ai-labs.nyx-pc-checkup.application-acceptance-probe.v1'
            Build='2026.09.27-eng-qa24'
            Passed=$true
            Composition=$Composition
            QuickCheck=[pscustomobject][ordered]@{ExitCode=$process.ExitCode;ReadOnly=[bool]$scan.ReadOnly;ResultCount=@($scan.Results).Count;Summary=$scan.Summary}
            CompletedUtc=(Get-Date).ToUniversalTime().ToString('o')
        }
    }finally{
        [void](Remove-NyxTemporaryArtifacts -Path @($out,$progress,$cancel))
    }
}

try{
    $dpiSource=@'
using System;
using System.Runtime.InteropServices;
public static class NyxDpiAwareness {
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
}
'@
    Add-Type -TypeDefinition $dpiSource -ErrorAction SilentlyContinue
    try{[NyxDpiAwareness]::SetProcessDpiAwarenessContext([IntPtr](-4))|Out-Null}catch{}
    Add-Type -AssemblyName System.Windows.Forms
    $mutex=[Threading.Mutex]::new($true,'Local\DietrichAI.NyxPCCheckup.v1',[ref]$created)
    if(-not $created){
        if($AcceptanceProbe){throw 'Nyx PC Checkup is already open for this Windows user.'}
        [Windows.Forms.MessageBox]::Show('Nyx PC Checkup is already open for this Windows user.','Nyx PC Checkup','OK','Information')|Out-Null
        exit 0
    }
    Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
    $composition=Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile UI
    Write-NyxLog -Level 'INFO' -Message 'Nyx PC Checkup started.'
    if($AcceptanceProbe){
        if($AcceptanceUiCloseProbe){
            Show-NyxMainWindow -AcceptanceCloseProbe
            $probe=[pscustomobject][ordered]@{
                Schema='dietrich-ai-labs.nyx-pc-checkup.application-acceptance-probe.v1'
                Build='2026.09.27-eng-qa24'
                Passed=$true
                ProbeKind='UiClose'
                Composition=$composition
                CompletedUtc=(Get-Date).ToUniversalTime().ToString('o')
            }
        }else{
            $probe=Invoke-NyxApplicationAcceptanceProbe -Composition $composition
        }
        Write-NyxAcceptanceProbeFile -Value $probe
        Write-NyxLog -Level 'INFO' -Message 'Nyx PC Checkup acceptance probe completed.'
        $mutex.ReleaseMutex();$mutex.Dispose();$mutex=$null
        exit 0
    }
    Show-NyxMainWindow
    Write-NyxLog -Level 'INFO' -Message 'Nyx PC Checkup closed.'
    $mutex.ReleaseMutex();$mutex.Dispose();$mutex=$null
}catch{
    if($AcceptanceProbe){
        try{Write-NyxAcceptanceProbeFile -Value ([pscustomobject][ordered]@{Schema='dietrich-ai-labs.nyx-pc-checkup.application-acceptance-probe.v1';Build='2026.09.27-eng-qa24';Passed=$false;Error=$_.Exception.ToString();CompletedUtc=(Get-Date).ToUniversalTime().ToString('o')})}catch{}
    }
    try{
        if($null -eq (Get-Command Write-NyxLog -CommandType Function -ErrorAction SilentlyContinue)){
            Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
            [void](Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Diagnostics)
        }
        Write-NyxLog -Level 'ERROR' -Message ("Unhandled application error: {0}" -f $_.Exception.ToString())
    }catch{}
    if(-not $AcceptanceProbe){try{Add-Type -AssemblyName System.Windows.Forms;[Windows.Forms.MessageBox]::Show("Nyx PC Checkup could not continue.`r`n`r`n$($_.Exception.Message)`r`n`r`nNo changes were made to this computer.",'Nyx PC Checkup','OK','Error')|Out-Null}catch{}}
    if($null -ne $mutex){try{if($created){$mutex.ReleaseMutex()}}catch{};try{$mutex.Dispose()}catch{}}
    exit 1
}

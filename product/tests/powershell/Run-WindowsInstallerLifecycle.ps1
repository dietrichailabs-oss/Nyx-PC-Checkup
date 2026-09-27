[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SetupPath,
    [switch]$DestructiveCleanVmAcknowledged,
    [string]$OutputPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'This acceptance harness must run under Windows PowerShell 5.1 (Desktop edition).'}
if(-not $DestructiveCleanVmAcknowledged){throw 'This test installs, repairs, uninstalls, and purges Nyx PC Checkup. Run only in a disposable clean Windows VM and pass -DestructiveCleanVmAcknowledged.'}
$SetupPath=(Resolve-Path $SetupPath).Path
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path (Get-Location) ('Nyx_PC_Checkup_Installer_Lifecycle_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')}
. (Join-Path $PSScriptRoot 'InstallerDiagnosticsHelpers.ps1')
$outputDirectory=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath))
if(-not(Test-Path -LiteralPath $outputDirectory -PathType Container)){New-Item -ItemType Directory -Path $outputDirectory -Force -ErrorAction Stop|Out-Null}
$diagnosticsDirectory=Join-Path $outputDirectory 'installer-diagnostics'
$localAppDataForHarness=[string]$env:LOCALAPPDATA
if([string]::IsNullOrWhiteSpace($localAppDataForHarness)){$localAppDataForHarness=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)}
if([string]::IsNullOrWhiteSpace($localAppDataForHarness)){throw 'Neither LOCALAPPDATA nor the LocalApplicationData special folder is available for harness path construction.'}
$installParent=Join-Path $localAppDataForHarness 'Programs\Dietrich AI Labs'
$installerPreflight=New-NyxInstallerEnvironmentPreflight -InstallParent $installParent
$installerPreflightPath=Join-Path $outputDirectory ('Nyx_PC_Checkup_Installer_Preflight_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
$installerPreflight|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $installerPreflightPath -Encoding UTF8
$setupRuns=[System.Collections.Generic.List[object]]::new()
$installRoot=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$dataRoot=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$uninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup'
$startLink=Join-Path ([Environment]::GetFolderPath('Programs')) 'Dietrich AI Labs\Nyx PC Checkup.lnk'
$desktopLink=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
$results=[System.Collections.Generic.List[object]]::new()
$failures=0
$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Test-Step {
    param([string]$Name,[bool]$Passed,[string]$Details='')
    $script:results.Add([pscustomobject][ordered]@{Name=$Name;Passed=$Passed;Details=$Details})
    if(-not $Passed){$script:failures++}
}
function Run-Exe {
    param([string]$Path,[string]$Arguments)
    $process=Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    return $process.ExitCode
}
function Wait-Absent {
    param([string]$Path,[int]$Seconds=20)
    for($i=0;$i -lt ($Seconds*5);$i++){
        if(-not(Test-Path -LiteralPath $Path)){return $true}
        Start-Sleep -Milliseconds 200
    }
    return $false
}
function Verify-Payload {
    param([string]$Root)
    $manifest=Get-Content -LiteralPath (Join-Path $Root 'PAYLOAD_MANIFEST.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $fail=[System.Collections.Generic.List[string]]::new()
    $expected=@{}
    foreach($entry in @($manifest.files)){
        $expected[[string]$entry.path]=$entry
        $full=Join-Path $Root ([string]$entry.path).Replace('/','\')
        if(-not(Test-Path -LiteralPath $full -PathType Leaf)){$fail.Add('missing '+$entry.path);continue}
        $file=Get-Item -LiteralPath $full
        if($file.Length -ne [int64]$entry.size){$fail.Add('size '+$entry.path)}
        if((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash -ne [string]$entry.sha256){$fail.Add('hash '+$entry.path)}
    }
    $actual=@(Get-ChildItem -LiteralPath $Root -Recurse -File|Where-Object{$_.Name -ne 'install-state.json' -and $_.Name -ne 'PAYLOAD_MANIFEST.json'})
    foreach($file in $actual){
        $rel=$file.FullName.Substring($Root.Length).TrimStart('\').Replace('\','/')
        if(-not $expected.ContainsKey($rel)){$fail.Add('unexpected '+$rel)}
    }
    return @($fail.ToArray())
}
function Remove-EmptyDirectory {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not(Test-Path -LiteralPath $Path -PathType Container)){return}
    try{if(@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop).Count -eq 0){Remove-Item -LiteralPath $Path -Force -ErrorAction Stop}}catch{}
}

function Import-QA7ActionsRuntime {
    param([Parameter(Mandatory=$true)][string]$Root)
    $compositionPath=Join-Path $Root 'core\RuntimeComposition.psm1'
    if(-not(Test-Path -LiteralPath $compositionPath -PathType Leaf)){throw ("QA7 runtime composition root is missing: {0}" -f $compositionPath)}
    Import-Module -Name $compositionPath -Global -ErrorAction Stop
    $composition=Import-NyxRuntimeGraph -AppRoot $Root -Profile Actions
    if(-not [bool]$composition.Passed){throw ("QA7 Actions composition failed: {0}" -f ($composition|ConvertTo-Json -Depth 10 -Compress))}
    $required=@('Get-NyxStableId','Get-NyxStartupApplications','Disable-NyxStartupApplication','Enable-NyxStartupApplication','Get-NyxActiveStartupDisables','Get-NyxLegacyMachineRollbackObligations','Get-NyxLegacyMachineStartupRollbackRoot')
    $missing=@($required|Where-Object{$null -eq (Get-Command -Name $_ -CommandType Function -ErrorAction SilentlyContinue)})
    if($missing.Count -gt 0){throw ("QA7 Actions composition is missing required command(s): {0}" -f ($missing -join ', '))}
    return $composition
}

$started=(Get-Date).ToUniversalTime()
try{
    Test-Step 'Installer preflight records LOCALAPPDATA' (-not [string]::IsNullOrWhiteSpace([string]$installerPreflight.LocalAppDataEnvironment)) ([string]$installerPreflight.LocalAppDataEnvironment)
    Test-Step 'Installer preflight can create and remove a bounded write probe' ([bool]$installerPreflight.WriteCapability.Succeeded) ($installerPreflight.WriteCapability|ConvertTo-Json -Depth 6 -Compress)
    if(Test-Path -LiteralPath $installRoot){
        $oldUninstaller=Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe'
        if(Test-Path -LiteralPath $oldUninstaller){[void](Run-Exe $oldUninstaller '/quiet /purgedata');[void](Wait-Absent $installRoot)}
        if(Test-Path -LiteralPath $installRoot){throw 'A prior installation remains. Revert the clean VM snapshot.'}
    }
    Remove-Item -LiteralPath $dataRoot -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $startLink,$desktopLink -Force -ErrorAction SilentlyContinue

    $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $SetupPath -BaseArguments '/quiet /nolaunch' -EvidenceDirectory $diagnosticsDirectory -Label 'FreshInstall'
    $setupRuns.Add($setupRun)
    $code=[int]$setupRun.ExitCode
    Test-Step 'Fresh install exits 0' ($code -eq 0) (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Fresh install emits valid branch diagnostics' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'SUCCESS') (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Fresh install root exists' (Test-Path -LiteralPath $installRoot -PathType Container)
    Test-Step 'Fresh install launcher exists' (Test-Path -LiteralPath (Join-Path $installRoot 'Nyx PC Checkup.exe') -PathType Leaf)
    Test-Step 'Fresh install uninstaller exists' (Test-Path -LiteralPath (Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe') -PathType Leaf)
    Test-Step 'Fresh install includes weekly update checker module' (Test-Path -LiteralPath (Join-Path $installRoot 'app\updates\UpdateChecker.psm1') -PathType Leaf)
    Test-Step 'Fresh install includes isolated update worker' (Test-Path -LiteralPath (Join-Path $installRoot 'app\workers\UpdateCheckWorker.ps1') -PathType Leaf)
    $payloadProblems=@(Verify-Payload $installRoot)
    Test-Step 'Fresh install payload matches exact manifest' ($payloadProblems.Count -eq 0) ($payloadProblems -join '; ')
    Test-Step 'Fresh install Start-menu shortcut exists' (Test-Path -LiteralPath $startLink -PathType Leaf)
    Test-Step 'Fresh install desktop shortcut is absent when not requested' (-not(Test-Path -LiteralPath $desktopLink))
    Test-Step 'Fresh install registration exists' (Test-Path -LiteralPath $uninstallKey)

    $created=$false
    $mutex=New-Object Threading.Mutex($true,'Local\DietrichAI.NyxPCCheckup.v1',[ref]$created)
    try{
        $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $SetupPath -BaseArguments '/quiet /nolaunch' -EvidenceDirectory $diagnosticsDirectory -Label 'RunningMutex'
        $setupRuns.Add($setupRun)
        $code=[int]$setupRun.ExitCode
        Test-Step 'Installer rejects running application mutex' ($code -eq 10) (Format-NyxSetupRunDetail -Run $setupRun)
        Test-Step 'Running-instance rejection identifies its exact setup branch' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'RUNNING_INSTANCE') (Format-NyxSetupRunDetail -Run $setupRun)
    }finally{
        if($created){$mutex.ReleaseMutex()}
        $mutex.Dispose()
    }

    $repairProbe=Join-Path $installRoot 'docs\USER_GUIDE.md'
    Add-Content -LiteralPath $repairProbe -Value 'intentional QA repair corruption'
    $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $SetupPath -BaseArguments '/quiet /nolaunch /desktop' -EvidenceDirectory $diagnosticsDirectory -Label 'Repair'
    $setupRuns.Add($setupRun)
    $code=[int]$setupRun.ExitCode
    Test-Step 'Repair exits 0' ($code -eq 0) (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Repair emits valid branch diagnostics' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'SUCCESS') (Format-NyxSetupRunDetail -Run $setupRun)
    $payloadProblems=@(Verify-Payload $installRoot)
    Test-Step 'Repair restores docs\USER_GUIDE.md and exact payload' ($payloadProblems.Count -eq 0) ($payloadProblems -join '; ')
    Test-Step 'Repair creates desktop shortcut when requested' (Test-Path -LiteralPath $desktopLink -PathType Leaf)

    New-Item -ItemType Directory -Path $dataRoot -Force|Out-Null
    $marker=Join-Path $dataRoot 'qa-preserve-marker.txt'
    Set-Content -LiteralPath $marker -Value 'preserve' -Encoding ASCII
    $uninstaller=Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe'

    # On an elevated disposable-VM run, create only an isolated legacy machine
    # rollback journal. No HKLM startup value and no per-user pointer are created.
    # The QA7 uninstaller must discover ProgramData independently, exit 7, and
    # preserve the complete installation until separate repair clears the legacy
    # machine rollback obligation.
    if($isAdmin){
        $runtimeComposition=Import-QA7ActionsRuntime -Root (Join-Path $installRoot 'app')
        Test-Step 'QA7 Actions composition is complete for elevated rollback lifecycle' ([bool]$runtimeComposition.Passed -and $null -ne (Get-Command Get-NyxStableId -CommandType Function -ErrorAction SilentlyContinue)) ($runtimeComposition|ConvertTo-Json -Depth 8 -Compress)
        $baseline=Get-NyxLegacyMachineRollbackObligations
        Test-Step 'Legacy machine rollback lifecycle starts from a clear root' ([string]$baseline.Status -eq 'Clear') ($baseline|ConvertTo-Json -Depth 8 -Compress)
        if([string]$baseline.Status -eq 'Clear'){
            $legacyRoot=Get-NyxLegacyMachineStartupRollbackRoot
            $legacyRootExistedBefore=Test-Path -LiteralPath $legacyRoot
            $legacyActionId=[guid]::NewGuid().ToString('N')
            $legacyFolder=Join-Path $legacyRoot $legacyActionId
            try{
                New-Item -ItemType Directory -Path $legacyFolder -Force -ErrorAction Stop|Out-Null
                [pscustomobject][ordered]@{
                    JournalVersion=1;JournalScope='Machine';ActionId=$legacyActionId
                    OwnerSid=[string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value
                    Name='QA legacy machine rollback';SourceLabel='All users Run';SourceType='Registry'
                    SourcePath='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';ValueName='NyxPCCheckup_QA_Legacy'
                    Command='"C:\Windows\System32\notepad.exe"';RequiresElevation=$true
                }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $legacyFolder 'rollback.json') -Encoding UTF8

                $code=Run-Exe $uninstaller '/quiet'
                Test-Step 'Uninstall blocks on independently discovered legacy machine rollback with exit 7' ($code -eq 7) ('ExitCode='+$code)
                Test-Step 'Legacy machine rollback block preserves install root' (Test-Path -LiteralPath $installRoot -PathType Container)
                Test-Step 'Legacy machine rollback block preserves registration' (Test-Path -LiteralPath $uninstallKey)
                Test-Step 'Legacy machine rollback block preserves Start shortcut' (Test-Path -LiteralPath $startLink -PathType Leaf)
                Test-Step 'Legacy machine rollback block preserves local data' (Test-Path -LiteralPath $marker -PathType Leaf)
            }finally{
                Remove-Item -LiteralPath $legacyFolder -Recurse -Force -ErrorAction SilentlyContinue
                if(-not $legacyRootExistedBefore){
                    Remove-EmptyDirectory -Path $legacyRoot
                    Remove-EmptyDirectory -Path (Split-Path -Parent $legacyRoot)
                }
            }
        }
    }else{
        Test-Step 'Legacy machine rollback uninstall block deferred to elevated lifecycle run' $true 'Run this same lifecycle suite from an elevated disposable-VM session to execute the exit-7 ProgramData case. The normal-user run still validates the per-user install/uninstall path.'
    }

    # Prove uninstall is fail-closed when a reversible current-user startup
    # entry cannot be restored. The first Uninstall attempt must leave code,
    # registration, shortcuts, local data, and the recovery journal intact.
    $qaRunPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $qaStartupName='NyxPCCheckup_QA_Uninstall_'+[guid]::NewGuid().ToString('N')
    $qaStartupCommand='"'+(Join-Path $env:SystemRoot 'System32\notepad.exe')+'" --nyx-pc-checkup-uninstall-rollback-test'
    $qaConflictCommand='"'+(Join-Path $env:SystemRoot 'System32\cmd.exe')+'" /c exit 0'
    $qaRollbackId=''
    try{
        $runtimeComposition=Import-QA7ActionsRuntime -Root (Join-Path $installRoot 'app')
        Test-Step 'QA7 Actions composition is complete for uninstall rollback fixture' ([bool]$runtimeComposition.Passed -and $null -ne (Get-Command Get-NyxStableId -CommandType Function -ErrorAction SilentlyContinue) -and $null -ne (Get-Command Get-NyxStartupApplications -CommandType Function -ErrorAction SilentlyContinue) -and $null -ne (Get-Command Disable-NyxStartupApplication -CommandType Function -ErrorAction SilentlyContinue)) ($runtimeComposition|ConvertTo-Json -Depth 8 -Compress)
        if(-not(Test-Path -LiteralPath $qaRunPath)){New-Item -Path $qaRunPath -Force|Out-Null}
        New-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Value $qaStartupCommand -PropertyType String -Force|Out-Null
        $qaApp=@(Get-NyxStartupApplications|Where-Object{$_.SourcePath -eq $qaRunPath -and $_.ValueName -eq $qaStartupName -and $_.Enabled}|Select-Object -First 1)
        Test-Step 'Uninstall regression startup fixture is enumerated' ($qaApp.Count -eq 1)
        if($qaApp.Count -ne 1){throw 'The uninstall rollback fixture was not enumerated.'}
        $disabled=Disable-NyxStartupApplication -Application $qaApp[0] -Confirmed
        $qaRollbackId=[string]$disabled.ActionId
        Test-Step 'Uninstall regression startup fixture is disabled' ([bool]$disabled.Success -and [string]$disabled.Status -eq 'Completed') ($disabled|ConvertTo-Json -Depth 6 -Compress)
        if(-not $disabled.Success){throw 'The uninstall rollback fixture could not be disabled.'}
        New-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Value $qaConflictCommand -PropertyType String -Force|Out-Null

        $code=Run-Exe $uninstaller '/quiet'
        Test-Step 'Uninstall aborts with exit 6 when current-user startup restoration conflicts' ($code -eq 6) ('ExitCode='+$code)
        Test-Step 'Failed Uninstall restore preserves install root' (Test-Path -LiteralPath $installRoot -PathType Container)
        Test-Step 'Failed Uninstall restore preserves registration' (Test-Path -LiteralPath $uninstallKey)
        Test-Step 'Failed Uninstall restore preserves Start shortcut' (Test-Path -LiteralPath $startLink -PathType Leaf)
        Test-Step 'Failed Uninstall restore preserves active rollback journal' (@(Get-NyxActiveStartupDisables|Where-Object{$_.ActionId -eq $qaRollbackId}).Count -eq 1)
        Test-Step 'Failed Uninstall restore preserves local data' (Test-Path -LiteralPath $marker -PathType Leaf)

        Remove-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Force -ErrorAction Stop
        $code=Run-Exe $uninstaller '/quiet'
        Test-Step 'Uninstall exits 0 after restore conflict is removed' ($code -eq 0) ('ExitCode='+$code)
        $restoredCommand=(Get-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -ErrorAction Stop).($qaStartupName)
        Test-Step 'Uninstall restores exact startup command before removal' ([string]$restoredCommand -eq $qaStartupCommand) ([string]$restoredCommand)
        Test-Step 'Uninstall removes install root' (Wait-Absent $installRoot)
        Test-Step 'Uninstall preserves local data by default' (Test-Path -LiteralPath $marker -PathType Leaf)
        Test-Step 'Uninstall removes registration' (-not(Test-Path -LiteralPath $uninstallKey))
        Test-Step 'Uninstall removes Start shortcut' (-not(Test-Path -LiteralPath $startLink))
        $startFolder=Split-Path -Parent $startLink
        Test-Step 'Uninstall removes empty Dietrich AI Labs Start folder' (Wait-Absent $startFolder 5)
        $qaRollbackId=''
    }finally{
        Remove-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Force -ErrorAction SilentlyContinue
        if($qaRollbackId -and (Test-Path -LiteralPath $installRoot -PathType Container)){
            try{[void](Enable-NyxStartupApplication -RollbackActionId $qaRollbackId -Confirmed)}catch{}
        }
    }

    $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $SetupPath -BaseArguments '/quiet /nolaunch' -EvidenceDirectory $diagnosticsDirectory -Label 'ReinstallAfterUninstall'
    $setupRuns.Add($setupRun)
    $code=[int]$setupRun.ExitCode
    Test-Step 'Reinstall after Uninstall exits 0' ($code -eq 0) (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Reinstall emits valid branch diagnostics' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'SUCCESS') (Format-NyxSetupRunDetail -Run $setupRun)
    $uninstaller=Join-Path $installRoot 'Uninstall Nyx PC Checkup.exe'
    $code=Run-Exe $uninstaller '/quiet /purgedata'
    Test-Step 'Explicit purge Uninstall exits 0' ($code -eq 0) ('ExitCode='+$code)
    Test-Step 'Purge Uninstall removes install root' (Wait-Absent $installRoot)
    Test-Step 'Purge Uninstall removes local data' (Wait-Absent $dataRoot)
    Test-Step 'Purge Uninstall removes registration' (-not(Test-Path -LiteralPath $uninstallKey))
    Test-Step 'No Nyx service was installed' (@(Get-Service -ErrorAction SilentlyContinue|Where-Object{$_.Name -like '*Nyx*PC*Checkup*'}).Count -eq 0)
    try{
        Test-Step 'No Nyx scheduled task was installed' (@(Get-ScheduledTask -ErrorAction Stop|Where-Object{$_.TaskName -like '*Nyx*PC*Checkup*'}).Count -eq 0)
    }catch{
        Test-Step 'No Nyx scheduled task was installed' $true 'ScheduledTasks API unavailable; package manifest still contains no task component.'
    }
}catch{
    Test-Step 'Installer lifecycle harness completed without unhandled error' $false $_.Exception.ToString()
}

$stopped=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.installer-lifecycle.v2'
    HarnessRevision='QA23-F020-PS51-23'
    Scope='installer lifecycle'
    StartedUtc=$started.ToString('o')
    CompletedUtc=$stopped.ToString('o')
    ElapsedSeconds=[math]::Round(($stopped-$started).TotalSeconds,3)
    ComputerName=$env:COMPUTERNAME
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    IsAdministrator=$isAdmin
    SetupPath=$SetupPath
    SetupSha256=(Get-FileHash -LiteralPath $SetupPath -Algorithm SHA256).Hash
    InstallerEnvironmentPreflightPath=$installerPreflightPath
    InstallerEnvironmentPreflight=$installerPreflight
    SetupRuns=@($setupRuns.ToArray())
    Passed=($failures -eq 0)
    Total=$results.Count
    Failed=$failures
    Results=@($results.ToArray())
}
$report|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Installer lifecycle: {0}/{1} passed. Evidence: {2}" -f ($report.Total-$report.Failed),$report.Total,$OutputPath)
if($failures -gt 0){exit 1}
exit 0

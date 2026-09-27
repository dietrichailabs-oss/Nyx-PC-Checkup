[CmdletBinding()]
param(
    [string]$QA2SetupPath = '',
    [string]$CorrectedSetupPath = '',
    [string]$OutputPath = '',
    [switch]$DestructiveCleanVmAcknowledged
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'This acceptance harness must run under Windows PowerShell 5.1 (Desktop edition).'}

# This suite intentionally installs/uninstalls the exact prior QA2 build and the
# corrected candidate. Run it only in a disposable Windows 10/11 x64 snapshot.
if(-not $DestructiveCleanVmAcknowledged){
    throw 'Run only on a disposable Windows VM and pass -DestructiveCleanVmAcknowledged.'
}
if($env:OS -ne 'Windows_NT'){throw 'This regression suite requires Windows.'}

$script:Results=[System.Collections.Generic.List[object]]::new()
$script:Failures=0
$script:QA2SetupSha256='FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5'
$script:QA2ActionHistorySha256='965143541BFBBE80C2A508F67A496ED3C6E574B241BFD48B667C637168D5751A'
$script:QA2PathsSha256='851323C19AD563291E1B54A25C28A588B7ED151E048E672DCC65761134D8386B'
$script:QA2ModuleScopeObservation=$null
$script:QA2HarnessPathMap=$null
$script:QA2LegacyFields=@(
    'JournalScope','ActionId','OwnerSid','Id','Name','Publisher','SourceType','SourcePath','SourceLabel',
    'ValueName','ValueKind','Command','ExecutablePath','RequiresElevation','BackupPath','SourceLength','SourceHash'
)
$script:InstallRoot=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$script:AppRoot=Join-Path $script:InstallRoot 'app'
$script:DataRoot=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$script:RollbackRoot=Join-Path $script:DataRoot 'actions\disabled-startup'
$script:RunPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:RunOncePath='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$script:UninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup'
$script:FixturePrefix='NyxPCCheckup_QA2_Migration_'
$script:ResetRuns=[System.Collections.Generic.List[object]]::new()
$script:ResetCounter=0

if([string]::IsNullOrWhiteSpace($QA2SetupPath)){
    $QA2SetupPath=Join-Path $PSScriptRoot '..\fixtures\qa2\Nyx_PC_Checkup_1.0.0_QA2_Setup.exe'
}
if([string]::IsNullOrWhiteSpace($CorrectedSetupPath)){
    $CorrectedSetupPath=Join-Path $PSScriptRoot '..\..\candidate\Nyx_PC_Checkup_1.0.0_Setup.exe'
}
$QA2SetupPath=(Resolve-Path $QA2SetupPath).Path
$CorrectedSetupPath=(Resolve-Path $CorrectedSetupPath).Path
if([string]::IsNullOrWhiteSpace($OutputPath)){
    $OutputPath=Join-Path (Get-Location) ('Nyx_PC_Checkup_QA2_Migration_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
}
. (Join-Path $PSScriptRoot 'InstallerDiagnosticsHelpers.ps1')
$outputDirectory=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath))
if(-not(Test-Path -LiteralPath $outputDirectory -PathType Container)){New-Item -ItemType Directory -Path $outputDirectory -Force -ErrorAction Stop|Out-Null}
$diagnosticsDirectory=Join-Path $outputDirectory 'installer-diagnostics'
$localAppDataForHarness=[string]$env:LOCALAPPDATA
if([string]::IsNullOrWhiteSpace($localAppDataForHarness)){$localAppDataForHarness=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)}
if([string]::IsNullOrWhiteSpace($localAppDataForHarness)){throw 'Neither LOCALAPPDATA nor the LocalApplicationData special folder is available for harness path construction.'}
$installParent=Join-Path $localAppDataForHarness 'Programs\Dietrich AI Labs'
$script:InstallParent=$installParent
$script:InstallerPreflight=New-NyxInstallerEnvironmentPreflight -InstallParent $installParent
$script:InstallerPreflightPath=Join-Path $outputDirectory ('Nyx_PC_Checkup_QA2_Migration_Preflight_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
$script:InstallerPreflight|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $script:InstallerPreflightPath -Encoding UTF8
$script:CorrectedSetupRuns=[System.Collections.Generic.List[object]]::new()
$startupFolder=[Environment]::GetFolderPath('Startup')
$commonStartupFolder=[Environment]::GetFolderPath('CommonStartup')
$programsFolder=[Environment]::GetFolderPath('Programs')
$desktopFolder=[Environment]::GetFolderPath('Desktop')
$script:StartupFolder=$startupFolder
$script:CommonStartupFolder=$commonStartupFolder
$script:ProgramsFolder=$programsFolder
$script:DesktopFolder=$desktopFolder
$startupExists=(-not [string]::IsNullOrWhiteSpace($startupFolder) -and (Test-Path -LiteralPath $startupFolder -PathType Container))
$commonStartupExists=(-not [string]::IsNullOrWhiteSpace($commonStartupFolder) -and (Test-Path -LiteralPath $commonStartupFolder -PathType Container))
$startupReadable=$false
$commonStartupReadable=$false
$startupWritable=$false
if($startupExists){
    try{[void]@(Get-ChildItem -LiteralPath $startupFolder -Force -ErrorAction Stop);$startupReadable=$true}catch{}
    $probe=Join-Path $startupFolder ('.nyx_qa2_precondition_'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{[IO.File]::WriteAllText($probe,'qa',[Text.Encoding]::ASCII);$startupWritable=$true}finally{if(Test-Path -LiteralPath $probe -PathType Leaf){Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue}}
}
if($commonStartupExists){try{[void]@(Get-ChildItem -LiteralPath $commonStartupFolder -Force -ErrorAction Stop);$commonStartupReadable=$true}catch{}}
$script:QA2ShellFolderPreflight=[pscustomobject][ordered]@{
    StartupPath=$startupFolder;StartupBlank=[string]::IsNullOrWhiteSpace($startupFolder);StartupExists=$startupExists;StartupReadable=$startupReadable;StartupWritable=$startupWritable
    CommonStartupPath=$commonStartupFolder;CommonStartupBlank=[string]::IsNullOrWhiteSpace($commonStartupFolder);CommonStartupExists=$commonStartupExists;CommonStartupReadable=$commonStartupReadable
}
$script:PreconditionBlocked=([string]::IsNullOrWhiteSpace($startupFolder) -or -not $startupExists -or -not $startupWritable -or [string]::IsNullOrWhiteSpace($commonStartupFolder))

$script:QA2SetupRuns=[System.Collections.Generic.List[object]]::new()
$script:SetupRunCounter=0

function Add-TestResult {
    param([string]$Name,[bool]$Passed,[string]$Details='')
    $script:Results.Add([pscustomobject][ordered]@{Name=$Name;Passed=$Passed;Details=$Details})
    if(-not $Passed){$script:Failures++}
}
function Test-Step {
    param([string]$Name,[bool]$Condition,[string]$Details='')
    Add-TestResult -Name $Name -Passed $Condition -Details $Details
    if(-not $Condition){throw "Required test step failed: $Name - $Details"}
}
function Run-Exe {
    param([Parameter(Mandatory=$true)][string]$Path,[string]$Arguments='')
    $process=Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    return [int]$process.ExitCode
}
function Wait-Absent {
    param([Parameter(Mandatory=$true)][string]$Path,[int]$Seconds=12)
    $deadline=(Get-Date).AddSeconds($Seconds)
    while((Get-Date) -lt $deadline){if(-not(Test-Path -LiteralPath $Path)){return $true};Start-Sleep -Milliseconds 250}
    return (-not(Test-Path -LiteralPath $Path))
}
function Remove-NyxLoadedModules {
    foreach($module in @(Get-Module|Where-Object{$_.Path -and $_.Path.StartsWith($script:InstallRoot,[StringComparison]::OrdinalIgnoreCase)})){
        Remove-Module -ModuleInfo $module -Force -ErrorAction SilentlyContinue
    }
}
function Import-NyxRuntime {
    Remove-NyxLoadedModules
    $compositionPath=Join-Path $script:AppRoot 'core\RuntimeComposition.psm1'
    if(Test-Path -LiteralPath $compositionPath -PathType Leaf){
        Import-Module -Name $compositionPath -ErrorAction Stop
        [void](Import-NyxRuntimeGraph -AppRoot $script:AppRoot -Profile Actions)
    }else{
        Import-Module (Join-Path $script:AppRoot 'core\Paths.psm1') -Force
        Import-Module (Join-Path $script:AppRoot 'core\ActionHistory.psm1') -Force
        Import-Module (Join-Path $script:AppRoot 'checks\StartupApps.psm1') -Force
        Import-Module (Join-Path $script:AppRoot 'actions\StartupActions.psm1') -Force
    }
}
function Assert-OrdinaryFile {
    param([string]$Path)
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw "Expected an ordinary file: $Path"}
    return $item
}
function Get-QAFixtureRegistryValues {
    $records=[System.Collections.Generic.List[string]]::new()
    foreach($path in @($script:RunPath,$script:RunOncePath)){
        if(Test-Path -LiteralPath $path){
            $item=Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
            if($null -ne $item){
                foreach($property in @($item.PSObject.Properties|Where-Object{$_.Name -like ($script:FixturePrefix+'*')})){
                    $records.Add(($path+'::'+$property.Name))
                }
            }
        }
    }
    return @($records.ToArray())
}
function Get-QAFixtureStartupFiles {
    $records=[System.Collections.Generic.List[string]]::new()
    foreach($folder in @($script:StartupFolder,$script:CommonStartupFolder)){
        if(-not [string]::IsNullOrWhiteSpace([string]$folder) -and (Test-Path -LiteralPath $folder -PathType Container)){
            foreach($file in @(Get-ChildItem -LiteralPath $folder -File -Filter ($script:FixturePrefix+'*') -ErrorAction SilentlyContinue)){
                $records.Add([string]$file.FullName)
            }
        }
    }
    return @($records.ToArray())
}
function Remove-QAFixtures {
    foreach($path in @($script:RunPath,$script:RunOncePath)){
        if(Test-Path -LiteralPath $path){
            $item=Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
            if($null -ne $item){
                foreach($property in @($item.PSObject.Properties|Where-Object{$_.Name -like ($script:FixturePrefix+'*')})){
                    Remove-ItemProperty -LiteralPath $path -Name $property.Name -Force -ErrorAction Stop
                }
            }
        }
    }
    foreach($file in @(Get-QAFixtureStartupFiles)){
        $item=Get-Item -LiteralPath $file -Force -ErrorAction Stop
        if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
            throw ("HARNESS_RESET_BLOCKED: fixture Startup path is not an ordinary file: {0}" -f $file)
        }
        Remove-Item -LiteralPath $file -Force -ErrorAction Stop
    }
}
function Get-ExactNyxHarnessIntegrationPaths {
    $local=[string]$env:LOCALAPPDATA
    if([string]::IsNullOrWhiteSpace($local)){$local=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)}
    if([string]::IsNullOrWhiteSpace($local)){throw 'HARNESS_RESET_BLOCKED: LocalApplicationData is unavailable.'}
    $programs=[Environment]::GetFolderPath('Programs')
    $desktop=[Environment]::GetFolderPath('Desktop')
    if([string]::IsNullOrWhiteSpace($programs)){throw 'HARNESS_RESET_BLOCKED: current-user Programs special folder is unavailable.'}
    if([string]::IsNullOrWhiteSpace($desktop)){throw 'HARNESS_RESET_BLOCKED: current-user Desktop special folder is unavailable.'}
    return [pscustomobject][ordered]@{
        InstallParent=Join-Path $local 'Programs\Dietrich AI Labs'
        InstallRoot=Join-Path $local 'Programs\Dietrich AI Labs\Nyx PC Checkup'
        DataRoot=Join-Path $local 'Dietrich AI Labs\Nyx PC Checkup'
        UninstallKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup'
        StartLink=Join-Path $programs 'Dietrich AI Labs\Nyx PC Checkup.lnk'
        DesktopLink=Join-Path $desktop 'Nyx PC Checkup.lnk'
    }
}
function Assert-ExactHarnessBoundary {
    param([Parameter(Mandatory=$true)][string]$Actual,[Parameter(Mandatory=$true)][string]$Expected,[Parameter(Mandatory=$true)][string]$Label)
    $actualFull=[IO.Path]::GetFullPath($Actual).TrimEnd('\')
    $expectedFull=[IO.Path]::GetFullPath($Expected).TrimEnd('\')
    if(-not [string]::Equals($actualFull,$expectedFull,[StringComparison]::OrdinalIgnoreCase)){
        throw ("HARNESS_RESET_BLOCKED: {0} escaped its exact boundary. Actual={1}; Expected={2}" -f $Label,$actualFull,$expectedFull)
    }
}
function Remove-ExactHarnessDirectory {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Expected,[Parameter(Mandatory=$true)][string]$Label)
    Assert-ExactHarnessBoundary -Actual $Path -Expected $Expected -Label $Label
    if(-not(Test-Path -LiteralPath $Path)){return}
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if(-not $item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
        throw ("HARNESS_RESET_BLOCKED: {0} is not an ordinary directory: {1}" -f $Label,$Path)
    }
    $reparseChildren=@(Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction Stop|Where-Object{($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0})
    if($reparseChildren.Count -gt 0){
        throw ("HARNESS_RESET_BLOCKED: {0} contains reparse-backed child state and will not be recursively removed: {1}" -f $Label,(($reparseChildren|ForEach-Object{$_.FullName}) -join '; '))
    }
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
}
function Remove-ExactHarnessShortcut {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Expected,[Parameter(Mandatory=$true)][string]$Label)
    Assert-ExactHarnessBoundary -Actual $Path -Expected $Expected -Label $Label
    if(-not(Test-Path -LiteralPath $Path)){return}
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
        throw ("HARNESS_RESET_BLOCKED: {0} is not an ordinary shortcut file: {1}" -f $Label,$Path)
    }
    Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
}
function Remove-ExactNyxIntegrationState {
    param([Parameter(Mandatory=$true)][object]$Paths)
    Remove-ExactHarnessDirectory -Path $script:InstallRoot -Expected ([string]$Paths.InstallRoot) -Label 'InstallRoot'
    Remove-ExactHarnessDirectory -Path $script:DataRoot -Expected ([string]$Paths.DataRoot) -Label 'DataRoot'
    if(-not [string]::Equals([string]$script:UninstallKey,[string]$Paths.UninstallKey,[StringComparison]::Ordinal)){
        throw 'HARNESS_RESET_BLOCKED: uninstall registration path no longer matches the exact Nyx key.'
    }
    if(Test-Path -LiteralPath $script:UninstallKey){
        Remove-Item -LiteralPath $script:UninstallKey -Recurse -Force -ErrorAction Stop
    }
    Remove-ExactHarnessShortcut -Path ([string]$Paths.StartLink) -Expected ([string]$Paths.StartLink) -Label 'StartLink'
    Remove-ExactHarnessShortcut -Path ([string]$Paths.DesktopLink) -Expected ([string]$Paths.DesktopLink) -Label 'DesktopLink'
}
function Get-ResetPostconditions {
    param([Parameter(Mandatory=$true)][object]$Paths)
    Assert-ExactHarnessBoundary -Actual $script:InstallRoot -Expected ([string]$Paths.InstallRoot) -Label 'InstallRoot'
    Assert-ExactHarnessBoundary -Actual $script:DataRoot -Expected ([string]$Paths.DataRoot) -Label 'DataRoot'
    Assert-ExactHarnessBoundary -Actual $script:InstallParent -Expected ([string]$Paths.InstallParent) -Label 'InstallParent'
    $preCreateComponents=@(Get-NyxPathComponentEvidence -Path $script:InstallParent)
    $preCreateReparse=@($preCreateComponents|Where-Object{$_.Exists -and $_.IsReparsePoint})
    if($preCreateReparse.Count -gt 0){
        throw ("HARNESS_RESET_BLOCKED: installation-parent path contains an existing reparse component: {0}" -f (($preCreateReparse|ForEach-Object{$_.Path}) -join '; '))
    }
    if(-not(Test-Path -LiteralPath $script:InstallParent -PathType Container)){
        New-Item -ItemType Directory -Path $script:InstallParent -Force -ErrorAction Stop|Out-Null
    }
    $parentItem=Get-Item -LiteralPath $script:InstallParent -Force -ErrorAction Stop
    $parentOrdinary=($parentItem.PSIsContainer -and (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0))
    $components=@(Get-NyxPathComponentEvidence -Path $script:InstallParent)
    $reparseComponents=@($components|Where-Object{$_.Exists -and $_.IsReparsePoint})
    $writeProbe=Test-NyxInstallerParentWriteCapability -IntendedParent $script:InstallParent
    $fixtureRegistry=@(Get-QAFixtureRegistryValues)
    $fixtureFiles=@(Get-QAFixtureStartupFiles)
    return [pscustomobject][ordered]@{
        InstallRootAbsent=(-not(Test-Path -LiteralPath $script:InstallRoot))
        DataRootAbsent=(-not(Test-Path -LiteralPath $script:DataRoot))
        UninstallRegistrationAbsent=(-not(Test-Path -LiteralPath $script:UninstallKey))
        StartLinkAbsent=(-not(Test-Path -LiteralPath ([string]$Paths.StartLink)))
        DesktopLinkAbsent=(-not(Test-Path -LiteralPath ([string]$Paths.DesktopLink)))
        FixtureRegistryValues=$fixtureRegistry
        FixtureStartupFiles=$fixtureFiles
        InstallParent=[string]$script:InstallParent
        InstallParentOrdinary=[bool]$parentOrdinary
        InstallParentReparseComponents=@($reparseComponents)
        InstallParentWriteCapability=$writeProbe
    }
}
function Assert-ResetPostconditions {
    param([Parameter(Mandatory=$true)][object]$State,[Parameter(Mandatory=$true)][string]$Label)
    Test-Step ($Label+': InstallRoot absent') ([bool]$State.InstallRootAbsent)
    Test-Step ($Label+': DataRoot absent') ([bool]$State.DataRootAbsent)
    Test-Step ($Label+': Nyx uninstall registration absent') ([bool]$State.UninstallRegistrationAbsent)
    Test-Step ($Label+': Nyx Start-menu shortcut absent') ([bool]$State.StartLinkAbsent)
    Test-Step ($Label+': Nyx desktop shortcut absent') ([bool]$State.DesktopLinkAbsent)
    Test-Step ($Label+': no harness fixture Run or RunOnce value remains') (@($State.FixtureRegistryValues).Count -eq 0) ((@($State.FixtureRegistryValues)) -join '; ')
    Test-Step ($Label+': no harness fixture Startup file remains') (@($State.FixtureStartupFiles).Count -eq 0) ((@($State.FixtureStartupFiles)) -join '; ')
    Test-Step ($Label+': installation parent is an ordinary directory') ([bool]$State.InstallParentOrdinary -and @($State.InstallParentReparseComponents).Count -eq 0) ($State|ConvertTo-Json -Depth 8 -Compress)
    Test-Step ($Label+': installation parent is writable') ([bool]$State.InstallParentWriteCapability.Succeeded) ($State.InstallParentWriteCapability|ConvertTo-Json -Depth 6 -Compress)
}
function Reset-DisposableState {
    param([Parameter(Mandatory=$true)][string]$Label)
    $script:ResetCounter++
    $paths=Get-ExactNyxHarnessIntegrationPaths
    $trace=[ordered]@{
        ResetNumber=$script:ResetCounter
        Label=$Label
        StartedUtc=(Get-Date).ToUniversalTime().ToString('o')
        UninstallerAttempted=$false
        UninstallerPath=''
        UninstallerExitCode=$null
        ForcedExactCleanup=$false
        ForcedCleanupReason=''
        Postconditions=$null
        Passed=$false
        Error=''
    }
    try{
        Remove-NyxLoadedModules
        if(Test-Path -LiteralPath $script:InstallRoot){
            $installItem=Get-Item -LiteralPath $script:InstallRoot -Force -ErrorAction Stop
            if(-not $installItem.PSIsContainer -or (($installItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){
                throw ("HARNESS_RESET_BLOCKED: InstallRoot is not an ordinary directory: {0}" -f $script:InstallRoot)
            }
            $uninstaller=Join-Path $script:InstallRoot 'Uninstall Nyx PC Checkup.exe'
            if(-not(Test-Path -LiteralPath $uninstaller -PathType Leaf)){
                throw ("HARNESS_RESET_BLOCKED: installed product has no exact uninstaller: {0}" -f $uninstaller)
            }
            [void](Assert-OrdinaryFile $uninstaller)
            $trace.UninstallerAttempted=$true
            $trace.UninstallerPath=$uninstaller
            $exit=Run-Exe $uninstaller '/quiet /purgedata'
            $trace.UninstallerExitCode=[int]$exit
            if($exit -eq 0){
                if(-not(Wait-Absent $script:InstallRoot 15)){
                    throw 'HARNESS_RESET_BLOCKED: product uninstaller returned 0 but InstallRoot did not disappear.'
                }
                if(-not(Wait-Absent $script:DataRoot 15)){
                    throw 'HARNESS_RESET_BLOCKED: purge uninstall returned 0 but DataRoot did not disappear.'
                }
            }elseif($exit -eq 6){
                if(-not $DestructiveCleanVmAcknowledged){
                    throw 'HARNESS_RESET_BLOCKED: exit-6 fail-closed state requires the disposable-VM destructive acknowledgment.'
                }
                $trace.ForcedExactCleanup=$true
                $trace.ForcedCleanupReason='QA9 exit 6: intentionally invalid/incomplete current-user rollback state from migration scenario.'
            }else{
                throw ("HARNESS_RESET_BLOCKED: product uninstaller returned unexpected exit code {0}; exact state was preserved." -f $exit)
            }
        }else{
            $staleKnownState=(Test-Path -LiteralPath $script:DataRoot) -or (Test-Path -LiteralPath $script:UninstallKey) -or (Test-Path -LiteralPath ([string]$paths.StartLink)) -or (Test-Path -LiteralPath ([string]$paths.DesktopLink))
            if($staleKnownState){
                if(-not $DestructiveCleanVmAcknowledged){throw 'HARNESS_RESET_BLOCKED: stale exact Nyx integration requires disposable-VM acknowledgment.'}
                $trace.ForcedExactCleanup=$true
                $trace.ForcedCleanupReason='No InstallRoot was present, but exact known Nyx integration state remained from an interrupted disposable harness run.'
            }
        }
        Remove-QAFixtures
        if([bool]$trace.ForcedExactCleanup){
            Remove-ExactNyxIntegrationState -Paths $paths
            Remove-QAFixtures
        }
        $state=Get-ResetPostconditions -Paths $paths
        $trace.Postconditions=$state
        Assert-ResetPostconditions -State $state -Label $Label
        $trace.Passed=$true
    }catch{
        $trace.Error=$_.Exception.ToString()
        throw
    }finally{
        $trace.CompletedUtc=(Get-Date).ToUniversalTime().ToString('o')
        $script:ResetRuns.Add([pscustomobject]$trace)
    }
}
function Get-QA2HarnessStableId {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $bytes=[Text.Encoding]::UTF8.GetBytes($Text)
        $hash=$sha.ComputeHash($bytes)
        return ((($hash|ForEach-Object{$_.ToString('x2')}) -join '').Substring(0,24))
    }finally{$sha.Dispose()}
}
function Get-QA2HarnessPublisher {
    param([string]$Path)
    try{
        if(Test-Path -LiteralPath $Path -PathType Leaf){
            $version=[Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            if($version.CompanyName){return [string]$version.CompanyName}
        }
    }catch{}
    return ''
}
function Get-QA2HarnessPathMap {
    $base=[string]$env:LOCALAPPDATA
    if([string]::IsNullOrWhiteSpace($base)){
        $base=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    }
    if([string]::IsNullOrWhiteSpace($base)){throw 'Windows did not provide the QA2 local application-data folder required by the migration fixture.'}
    $rootPath=Join-Path $base 'Dietrich AI Labs\Nyx PC Checkup'
    return [pscustomobject][ordered]@{
        Root=$rootPath
        Config=Join-Path $rootPath 'config.json'
        Logs=Join-Path $rootPath 'logs'
        Scans=Join-Path $rootPath 'scans'
        Actions=Join-Path $rootPath 'actions'
        ActionHistory=Join-Path $rootPath 'actions\history.jsonl'
        DisabledStartup=Join-Path $rootPath 'actions\disabled-startup'
        Reports=Join-Path $rootPath 'reports'
        Temp=Join-Path $rootPath 'temp'
        LastScan=Join-Path $rootPath 'scans\last-scan.json'
    }
}
function Assert-QA2HarnessOrdinaryDirectory {
    param([Parameter(Mandatory=$true)][string]$Path)
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if(-not $item.PSIsContainer){throw ("QA2 fixture path is not a directory: {0}" -f $Path)}
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw ("QA2 fixture directory cannot be a junction or symbolic link: {0}" -f $Path)}
    return $item
}
function Initialize-QA2HarnessDataDirectories {
    $paths=Get-QA2HarnessPathMap
    $expectedRoot=[IO.Path]::GetFullPath($script:DataRoot).TrimEnd('\')
    $actualRoot=[IO.Path]::GetFullPath([string]$paths.Root).TrimEnd('\')
    if(-not [string]::Equals($actualRoot,$expectedRoot,[StringComparison]::OrdinalIgnoreCase)){
        throw ("Harness-derived QA2 data root does not match immutable QA2 Paths contract. Expected={0};Actual={1}" -f $expectedRoot,$actualRoot)
    }
    $expectedRollback=[IO.Path]::GetFullPath($script:RollbackRoot).TrimEnd('\')
    $actualRollback=[IO.Path]::GetFullPath([string]$paths.DisabledStartup).TrimEnd('\')
    if(-not [string]::Equals($actualRollback,$expectedRollback,[StringComparison]::OrdinalIgnoreCase)){
        throw ("Harness-derived QA2 rollback root does not match immutable QA2 Paths contract. Expected={0};Actual={1}" -f $expectedRollback,$actualRollback)
    }
    foreach($directory in @($paths.Root,$paths.Logs,$paths.Scans,$paths.Actions,$paths.DisabledStartup,$paths.Reports,$paths.Temp)){
        if(-not(Test-Path -LiteralPath $directory)){
            New-Item -ItemType Directory -Path $directory -Force -ErrorAction Stop|Out-Null
        }
        [void](Assert-QA2HarnessOrdinaryDirectory -Path $directory)
    }
    return $paths
}
function Import-QA2FixtureSupport {
    Remove-NyxLoadedModules
    $pathsModule=Join-Path $script:AppRoot 'core\Paths.psm1'
    $actionHistory=Join-Path $script:AppRoot 'core\ActionHistory.psm1'
    [void](Assert-OrdinaryFile $pathsModule)
    [void](Assert-OrdinaryFile $actionHistory)
    $actualPathsHash=(Get-FileHash -LiteralPath $pathsModule -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
    $actualActionHistoryHash=(Get-FileHash -LiteralPath $actionHistory -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
    Test-Step 'Installed immutable QA2 Paths hash matches fixture contract' ($actualPathsHash -eq $script:QA2PathsSha256) $actualPathsHash
    Test-Step 'Installed immutable QA2 ActionHistory hash matches fixture contract' ($actualActionHistoryHash -eq $script:QA2ActionHistorySha256) $actualActionHistoryHash

    Import-Module -Name $pathsModule -Force -ErrorAction Stop
    $initializerBefore=Get-Command Initialize-NyxDataDirectories -CommandType Function -ErrorAction SilentlyContinue
    $initializerBeforePath=if($null -ne $initializerBefore){[string]$initializerBefore.Module.Path}else{''}
    Test-Step 'QA2 Paths initializer is visible immediately after direct Paths import' ($null -ne $initializerBefore) $initializerBeforePath

    Import-Module -Name $actionHistory -Force -ErrorAction Stop
    $initializerAfter=Get-Command Initialize-NyxDataDirectories -CommandType Function -ErrorAction SilentlyContinue
    $script:QA2ModuleScopeObservation=[pscustomobject][ordered]@{
        PathsModule=$pathsModule
        PathsSha256=$actualPathsHash
        InitializerVisibleAfterDirectPathsImport=($null -ne $initializerBefore)
        InitializerVisibleAfterActionHistoryImport=($null -ne $initializerAfter)
        PostActionHistoryInitializerModule=if($null -ne $initializerAfter){[string]$initializerAfter.Module.Path}else{''}
        CallerVisibilityRequiredForFixtureCreation=$false
    }
    Add-TestResult -Name 'QA2 post-ActionHistory caller-scope visibility is observed but not required' -Passed $true -Details ($script:QA2ModuleScopeObservation|ConvertTo-Json -Depth 6 -Compress)

    $protect=Get-Command Protect-NyxState -CommandType Function -ErrorAction Stop
    $unprotect=Get-Command Unprotect-NyxState -CommandType Function -ErrorAction Stop
    Test-Step 'QA2 DPAPI protect helper is loaded from immutable QA2 ActionHistory' ([string]::Equals([string]$protect.Module.Path,$actionHistory,[StringComparison]::OrdinalIgnoreCase)) ([string]$protect.Module.Path)
    Test-Step 'QA2 DPAPI unprotect helper is loaded from immutable QA2 ActionHistory' ([string]::Equals([string]$unprotect.Module.Path,$actionHistory,[StringComparison]::OrdinalIgnoreCase)) ([string]$unprotect.Module.Path)

    $script:QA2HarnessPathMap=Initialize-QA2HarnessDataDirectories
    Test-Step 'Harness-derived QA2 data root exactly matches immutable Paths contract' ([string]::Equals([IO.Path]::GetFullPath([string]$script:QA2HarnessPathMap.Root).TrimEnd('\'),[IO.Path]::GetFullPath($script:DataRoot).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)) ([string]$script:QA2HarnessPathMap.Root)
    Test-Step 'Harness-derived QA2 rollback root exactly matches immutable Paths contract' ([string]::Equals([IO.Path]::GetFullPath([string]$script:QA2HarnessPathMap.DisabledStartup).TrimEnd('\'),[IO.Path]::GetFullPath($script:RollbackRoot).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)) ([string]$script:QA2HarnessPathMap.DisabledStartup)
}
function Assert-QA2LegacyFixtureState {
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$ActionId,
        [Parameter(Mandatory=$true)][ValidateSet('Registry','StartupFile')][string]$SourceType
    )
    $actual=@($State.PSObject.Properties|ForEach-Object{[string]$_.Name}|Sort-Object)
    $expected=@($script:QA2LegacyFields|Sort-Object)
    $difference=@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual)
    Test-Step 'Harness-created QA2 state has the exact legacy property set' ($difference.Count -eq 0) ($difference|ConvertTo-Json -Compress)
    Test-Step 'Harness-created QA2 state has no JournalVersion' ($null -eq $State.PSObject.Properties['JournalVersion'])
    Test-Step 'Harness-created QA2 state uses User scope' ([string]$State.JournalScope -eq 'User') ([string]$State.JournalScope)
    Test-Step 'Harness-created QA2 state keeps the legacy empty OwnerSid' ([string]$State.OwnerSid -eq '') ([string]$State.OwnerSid)
    $requires=$State.PSObject.Properties['RequiresElevation']
    Test-Step 'Harness-created QA2 state uses a Boolean false elevation boundary' ($null -ne $requires -and $requires.Value -is [bool] -and -not [bool]$requires.Value) (($requires.Value|Out-String).Trim())
    Test-Step 'Harness-created QA2 state has exact lowercase action identity' ($ActionId -match '^[a-f0-9]{32}$' -and [string]$State.ActionId -ceq $ActionId) ([string]$State.ActionId)
    Test-Step 'Harness-created QA2 state has the intended source type' ([string]$State.SourceType -eq $SourceType) ([string]$State.SourceType)
    if($SourceType -eq 'Registry'){
        Test-Step 'Harness-created QA2 registry state uses an exact current-user Run source' (
            [string]::Equals([string]$State.SourcePath,$script:RunPath,[StringComparison]::OrdinalIgnoreCase) -and
            -not [string]::IsNullOrWhiteSpace([string]$State.ValueName) -and
            [string]$State.ValueKind -in @('String','ExpandString') -and
            [string]$State.BackupPath -eq '' -and
            $null -eq $State.SourceLength -and
            [string]$State.SourceHash -eq ''
        ) ($State|ConvertTo-Json -Depth 6 -Compress)
    }else{
        $startup=[Environment]::GetFolderPath('Startup')
        $source=[IO.Path]::GetFullPath([string]$State.SourcePath)
        $sourceParent=[IO.Path]::GetDirectoryName($source).TrimEnd('\')
        $allowed=[IO.Path]::GetFullPath($startup).TrimEnd('\')
        Test-Step 'Harness-created QA2 Startup-file state stays in current-user Startup' (
            [string]::Equals($sourceParent,$allowed,[StringComparison]::OrdinalIgnoreCase) -and
            [string]$State.ValueName -eq '' -and
            [string]$State.ValueKind -eq '' -and
            [string]$State.SourceHash -match '^[A-Fa-f0-9]{64}$' -and
            $null -ne $State.SourceLength -and
            [int64]$State.SourceLength -ge 0
        ) ($State|ConvertTo-Json -Depth 6 -Compress)
    }
}
function New-QA2HarnessJournal {
    param(
        [Parameter(Mandatory=$true)][string]$ActionId,
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][ValidateSet('Registry','StartupFile')][string]$SourceType
    )
    Assert-QA2LegacyFixtureState -State $State -ActionId $ActionId -SourceType $SourceType
    $paths=Initialize-QA2HarnessDataDirectories
    $root=Get-Item -LiteralPath $paths.DisabledStartup -Force -ErrorAction Stop
    if(-not $root.PSIsContainer -or (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'QA2 rollback root is not an ordinary directory.'}
    $folder=Join-Path $root.FullName $ActionId
    if(Test-Path -LiteralPath $folder){throw 'A QA2 rollback fixture already exists for this action.'}
    New-Item -ItemType Directory -Path $folder -ErrorAction Stop|Out-Null
    $folderItem=Get-Item -LiteralPath $folder -Force -ErrorAction Stop
    if(-not $folderItem.PSIsContainer -or (($folderItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'QA2 rollback fixture folder is unsafe.'}
    $journal=Join-Path $folder 'rollback.dpapi'
    $protected=Protect-NyxState -State $State
    Test-Step 'Harness-created QA2 journal uses the exact DPAPI1 protected-state format' ([string]$protected -like 'DPAPI1:*') ([string]$protected.Substring(0,[Math]::Min(7,$protected.Length)))
    [IO.File]::WriteAllText($journal,$protected,[Text.Encoding]::UTF8)
    $journalItem=Assert-OrdinaryFile $journal
    Test-Step 'Harness-created QA2 journal is bounded' ([int64]$journalItem.Length -gt 0 -and [int64]$journalItem.Length -le 1048576) ([string]$journalItem.Length)
    $stored=(Get-Content -LiteralPath $journal -Raw -Encoding UTF8 -ErrorAction Stop).Trim()
    $decrypted=Unprotect-NyxState -ProtectedText $stored
    Test-Step 'Harness-created QA2 journal decrypts with immutable QA2 CurrentUser DPAPI helper' ($null -ne $decrypted)
    Assert-QA2LegacyFixtureState -State $decrypted -ActionId $ActionId -SourceType $SourceType
    return [pscustomobject][ordered]@{Folder=$folder;Journal=$journal;Protected=$stored;State=$decrypted}
}
function Install-QA2 {
    if($script:ResetRuns.Count -eq 0){throw 'HARNESS_RESET_BLOCKED: immutable QA2 install was requested before any disposable-state reset.'}
    $lastReset=$script:ResetRuns[$script:ResetRuns.Count-1]
    Test-Step 'Immutable QA2 install is preceded by a successful disposable-state reset' ([bool]$lastReset.Passed) ($lastReset|ConvertTo-Json -Depth 10 -Compress)
    $script:SetupRunCounter++
    $code=Run-Exe $QA2SetupPath '/quiet /nolaunch'
    $inference=New-NyxQA2ExitInference -ExitCode $code -Preflight $script:InstallerPreflight -Label ('QA2Install_'+$script:SetupRunCounter)
    $script:QA2SetupRuns.Add($inference)
    Test-Step 'Exact QA2 setup installs successfully' ($code -eq 0) (('ExitCode={0}; Inference={1}' -f $code,($inference|ConvertTo-Json -Depth 8 -Compress)))
    Test-Step 'QA2 application root exists' (Test-Path -LiteralPath $script:AppRoot -PathType Container)
    Import-QA2FixtureSupport
}
function Upgrade-Corrected {
    Remove-NyxLoadedModules
    $script:SetupRunCounter++
    $setupRun=Invoke-NyxSetupWithDiagnostics -SetupPath $CorrectedSetupPath -BaseArguments '/quiet /nolaunch' -EvidenceDirectory $diagnosticsDirectory -Label ('QA2Upgrade_'+$script:SetupRunCounter)
    $script:CorrectedSetupRuns.Add($setupRun)
    $code=[int]$setupRun.ExitCode
    Test-Step 'Corrected setup upgrades QA2 successfully' ($code -eq 0) (Format-NyxSetupRunDetail -Run $setupRun)
    Test-Step 'Corrected setup emits valid branch diagnostics' ([bool]$setupRun.DiagnosticValid -and [string]$setupRun.Diagnostic.branchId -eq 'SUCCESS') (Format-NyxSetupRunDetail -Run $setupRun)
    Import-NyxRuntime
    $version=Get-Content -LiteralPath (Join-Path $script:InstallRoot 'VERSION.json') -Raw -Encoding UTF8|ConvertFrom-Json
    Test-Step 'Corrected build identity is active after upgrade' ([string]$version.build -eq '2026.09.27-eng-qa21') ([string]$version.build)
}
function Get-RollbackJournal {
    param([Parameter(Mandatory=$true)][string]$ActionId)
    $folder=Join-Path $script:RollbackRoot $ActionId
    $journal=Join-Path $folder 'rollback.dpapi'
    [void](Assert-OrdinaryFile $journal)
    $protected=(Get-Content -LiteralPath $journal -Raw -Encoding UTF8).Trim()
    $state=Unprotect-NyxState -ProtectedText $protected
    return [pscustomobject][ordered]@{Folder=$folder;Journal=$journal;Protected=$protected;State=$state}
}
function New-QA2RegistryDisable {
    param([string]$Name)
    if(-not(Test-Path -LiteralPath $script:RunPath)){New-Item -Path $script:RunPath -Force|Out-Null}
    $exe=Join-Path $env:SystemRoot 'System32\notepad.exe'
    $command='"'+$exe+'" --nyx-qa2-migration-'+$Name
    New-ItemProperty -LiteralPath $script:RunPath -Name $Name -Value $command -PropertyType String -Force -ErrorAction Stop|Out-Null
    $key=Get-Item -LiteralPath $script:RunPath -ErrorAction Stop
    $kind=[string]$key.GetValueKind($Name)
    $current=(Get-ItemProperty -LiteralPath $script:RunPath -Name $Name -ErrorAction Stop).($Name)
    Test-Step 'QA2 harness registry source exists before journal creation' ([string]$current -eq $command) ([string]$current)
    $actionId=[guid]::NewGuid().ToString('N')
    $state=[pscustomobject][ordered]@{
        JournalScope='User';ActionId=$actionId;OwnerSid=''
        Id=(Get-QA2HarnessStableId -Text ("registry|{0}|{1}" -f $script:RunPath,$Name));Name=$Name;Publisher=(Get-QA2HarnessPublisher -Path $exe)
        SourceType='Registry';SourcePath=$script:RunPath;SourceLabel='Current user Run';ValueName=$Name;ValueKind=$kind
        Command=$command;ExecutablePath=$exe;RequiresElevation=$false;BackupPath='';SourceLength=$null;SourceHash=''
    }
    $journal=New-QA2HarnessJournal -ActionId $actionId -State $state -SourceType Registry
    Remove-ItemProperty -LiteralPath $script:RunPath -Name $Name -ErrorAction Stop
    Test-Step 'Harness-owned QA2 registry fixture matches completed disable state' ($null -eq (Get-ItemProperty -LiteralPath $script:RunPath -Name $Name -ErrorAction SilentlyContinue)) ($journal|ConvertTo-Json -Depth 6 -Compress)
    return [pscustomobject][ordered]@{Name=$Name;Command=$command;ActionId=$actionId}
}
function New-QA2StartupFileDisable {
    param([string]$Name)
    $startup=[Environment]::GetFolderPath('Startup')
    if([string]::IsNullOrWhiteSpace($startup)){throw 'Current-user Startup folder is unavailable.'}
    $startupItem=Get-Item -LiteralPath $startup -Force -ErrorAction Stop
    if(-not $startupItem.PSIsContainer -or (($startupItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'Current-user Startup folder is unsafe for the migration fixture.'}
    $path=Join-Path $startup ($Name+'.cmd')
    $bytes=[Text.UTF8Encoding]::new($false).GetBytes("@echo off`r`nrem Nyx QA2 migration $Name`r`n")
    [IO.File]::WriteAllBytes($path,$bytes)
    $source=Assert-OrdinaryFile $path
    $expectedHash=(Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash
    $actionId=[guid]::NewGuid().ToString('N')
    $folder=Join-Path $script:RollbackRoot $actionId
    $backupPath=Join-Path $folder ('payload\'+[IO.Path]::GetFileName($path))
    $state=[pscustomobject][ordered]@{
        JournalScope='User';ActionId=$actionId;OwnerSid=''
        Id=(Get-QA2HarnessStableId -Text ("file|{0}" -f $path));Name=[IO.Path]::GetFileNameWithoutExtension($path);Publisher=''
        SourceType='StartupFile';SourcePath=$path;SourceLabel='Current user Startup folder';ValueName='';ValueKind=''
        Command=$path;ExecutablePath=$path;RequiresElevation=$false;BackupPath=$backupPath;SourceLength=[int64]$source.Length;SourceHash=$expectedHash
    }
    $journal=New-QA2HarnessJournal -ActionId $actionId -State $state -SourceType StartupFile
    $payloadParent=Split-Path -Parent $backupPath
    New-Item -ItemType Directory -Path $payloadParent -Force -ErrorAction Stop|Out-Null
    $payloadParentItem=Get-Item -LiteralPath $payloadParent -Force -ErrorAction Stop
    if(-not $payloadParentItem.PSIsContainer -or (($payloadParentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'QA2 rollback payload directory is unsafe.'}
    Move-Item -LiteralPath $path -Destination $backupPath -ErrorAction Stop
    $backup=Assert-OrdinaryFile $backupPath
    $backupHash=(Get-FileHash -LiteralPath $backup.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
    Test-Step 'Harness-owned QA2 Startup-file fixture source is absent after disable' (-not(Test-Path -LiteralPath $path)) $path
    Test-Step 'Harness-owned QA2 Startup-file fixture backup matches exact length and hash' ([int64]$backup.Length -eq [int64]$source.Length -and [string]::Equals($backupHash,$expectedHash,[StringComparison]::OrdinalIgnoreCase)) (('Length={0};Hash={1}' -f $backup.Length,$backupHash))
    $roundTrip=Get-RollbackJournal -ActionId $actionId
    Assert-QA2LegacyFixtureState -State $roundTrip.State -ActionId $actionId -SourceType StartupFile
    Test-Step 'Harness-owned QA2 Startup-file fixture backup path is exact' ([string]::Equals([IO.Path]::GetFullPath([string]$roundTrip.State.BackupPath),[IO.Path]::GetFullPath($backupPath),[StringComparison]::OrdinalIgnoreCase)) ([string]$roundTrip.State.BackupPath)
    return [pscustomobject][ordered]@{Path=$path;Bytes=$bytes;Hash=$expectedHash;ActionId=$actionId}
}

$started=(Get-Date).ToUniversalTime()
$unhandled=''
try{
    Test-Step 'Installer preflight records LOCALAPPDATA' (-not [string]::IsNullOrWhiteSpace([string]$script:InstallerPreflight.LocalAppDataEnvironment)) ([string]$script:InstallerPreflight.LocalAppDataEnvironment)
    Test-Step 'Installer preflight can create and remove a bounded write probe' ([bool]$script:InstallerPreflight.WriteCapability.Succeeded) ($script:InstallerPreflight.WriteCapability|ConvertTo-Json -Depth 6 -Compress)
    Test-Step 'Exact QA2 setup fixture hash matches' ((Get-FileHash -LiteralPath $QA2SetupPath -Algorithm SHA256).Hash -eq $script:QA2SetupSha256) ((Get-FileHash -LiteralPath $QA2SetupPath -Algorithm SHA256).Hash)
    Test-Step 'Corrected setup is an ordinary file' ($null -ne (Assert-OrdinaryFile $CorrectedSetupPath))

    Test-Step 'QA2 legacy shell-folder preconditions are explicitly captured' $true ($script:QA2ShellFolderPreflight|ConvertTo-Json -Depth 6 -Compress)
    if($script:PreconditionBlocked){
        Test-Step 'QA2 migration environment precondition is satisfied' $false ('PRECONDITION_BLOCKED: '+($script:QA2ShellFolderPreflight|ConvertTo-Json -Depth 6 -Compress))
    }else{
        Test-Step 'QA2 migration environment precondition is satisfied' $true ($script:QA2ShellFolderPreflight|ConvertTo-Json -Depth 6 -Compress)

    # Scenario 1: exact QA2 HKCU rollback survives upgrade and is restored.
    Reset-DisposableState -Label 'BeforeScenario1'
    Install-QA2
    $reg=New-QA2RegistryDisable -Name ($script:FixturePrefix+'Registry')
    $legacy=Get-RollbackJournal -ActionId $reg.ActionId
    Test-Step 'QA2 registry journal has no JournalVersion' ($null -eq $legacy.State.PSObject.Properties['JournalVersion'])
    Test-Step 'QA2 registry journal has empty OwnerSid' ([string]$legacy.State.OwnerSid -eq '') ([string]$legacy.State.OwnerSid)
    Test-Step 'QA2 registry journal is current-user and non-elevated' ([string]$legacy.State.JournalScope -eq 'User' -and -not [bool]$legacy.State.RequiresElevation)
    Upgrade-Corrected
    $inventory=Get-NyxStartupRollbackInventory
    $entry=@($inventory.Entries|Where-Object{$_.ActionId -eq $reg.ActionId}|Select-Object -First 1)
    Test-Step 'Corrected rollback inventory remains complete for exact QA2 registry state' ([bool]$inventory.Complete) ($inventory|ConvertTo-Json -Depth 10 -Compress)
    Test-Step 'Corrected build identifies QA2 user schema' ($entry.Count -eq 1 -and [string]$entry[0].JournalSchema -eq 'QA2-User' -and [bool]$entry[0].NormalizedInMemory) ($entry|ConvertTo-Json -Depth 8 -Compress)
    $restored=Enable-NyxStartupApplication -RollbackActionId $reg.ActionId -Confirmed
    Test-Step 'Corrected build restores QA2 registry rollback' ([bool]$restored.Success -and [string]$restored.Status -eq 'Completed') ($restored|ConvertTo-Json -Depth 8 -Compress)
    $actual=(Get-ItemProperty -LiteralPath $script:RunPath -Name $reg.Name -ErrorAction Stop).($reg.Name)
    Test-Step 'QA2 registry command restores exactly' ([string]$actual -eq $reg.Command) ([string]$actual)

    # Scenario 2: exact QA2 current Startup-folder rollback restores exact bytes.
    Reset-DisposableState -Label 'BeforeScenario2'
    Install-QA2
    $file=New-QA2StartupFileDisable -Name ($script:FixturePrefix+'StartupFile')
    $legacy=Get-RollbackJournal -ActionId $file.ActionId
    Test-Step 'QA2 Startup-folder journal has no JournalVersion' ($null -eq $legacy.State.PSObject.Properties['JournalVersion'])
    Test-Step 'QA2 Startup-folder journal records exact hash and length' ([string]$legacy.State.SourceHash -eq $file.Hash -and [int64]$legacy.State.SourceLength -eq $file.Bytes.Length) ($legacy.State|ConvertTo-Json -Depth 8 -Compress)
    Upgrade-Corrected
    $inventory=Get-NyxStartupRollbackInventory
    Test-Step 'Corrected rollback inventory remains complete for exact QA2 Startup-folder state' ([bool]$inventory.Complete) ($inventory|ConvertTo-Json -Depth 10 -Compress)
    $restored=Enable-NyxStartupApplication -RollbackActionId $file.ActionId -Confirmed
    Test-Step 'Corrected build restores QA2 Startup-folder rollback' ([bool]$restored.Success -and [string]$restored.Status -eq 'Completed') ($restored|ConvertTo-Json -Depth 8 -Compress)
    $actualBytes=[IO.File]::ReadAllBytes($file.Path)
    Test-Step 'QA2 Startup-folder payload restores exact bytes' ([Convert]::ToBase64String($actualBytes) -eq [Convert]::ToBase64String($file.Bytes)) ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash)

    # Scenario 3: a successfully decrypted but malformed/tampered legacy record
    # remains preserved and cannot mutate the startup source.
    Reset-DisposableState -Label 'BeforeScenario3'
    Install-QA2
    $bad=New-QA2RegistryDisable -Name ($script:FixturePrefix+'Tampered')
    $journal=Get-RollbackJournal -ActionId $bad.ActionId
    $journal.State|Add-Member -NotePropertyName UnexpectedLegacyField -NotePropertyValue 'tampered' -Force
    $tamperedProtected=Protect-NyxState -State $journal.State
    [IO.File]::WriteAllText($journal.Journal,$tamperedProtected,[Text.UTF8Encoding]::new($false))
    Upgrade-Corrected
    $inventory=Get-NyxStartupRollbackInventory
    Test-Step 'Tampered QA2 journal fails closed' (-not [bool]$inventory.Complete -and @($inventory.Errors).Count -gt 0) ($inventory|ConvertTo-Json -Depth 10 -Compress)
    $attempt=Enable-NyxStartupApplication -RollbackActionId $bad.ActionId -Confirmed
    Test-Step 'Tampered QA2 journal cannot trigger restore mutation' (-not [bool]$attempt.Success -and $null -eq (Get-ItemProperty -LiteralPath $script:RunPath -Name $bad.Name -ErrorAction SilentlyContinue)) ($attempt|ConvertTo-Json -Depth 8 -Compress)
    Test-Step 'Tampered QA2 journal bytes are preserved' (Test-Path -LiteralPath $journal.Journal -PathType Leaf)

    # Scenario 4: a DPAPI-readable QA2 Machine pointer placed in the user root
    # is never normalized into a writable current-user rollback.
    Reset-DisposableState -Label 'BeforeScenario4'
    Install-QA2
    $machineId=[guid]::NewGuid().ToString('N')
    $machineFolder=Join-Path $script:RollbackRoot $machineId
    New-Item -ItemType Directory -Path $machineFolder -Force|Out-Null
    $machineState=[pscustomobject][ordered]@{
        JournalScope='Machine';ActionId=$machineId;OwnerSid=[string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        Id='qa2-machine-pointer';Name='QA2 machine pointer';Publisher='QA';SourceType='Registry'
        SourcePath='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';SourceLabel='All users Run';ValueName='NyxPCCheckup_QA2_Machine'
        ValueKind='String';Command='"C:\Windows\System32\notepad.exe"';ExecutablePath='C:\Windows\System32\notepad.exe'
        RequiresElevation=$true;BackupPath='';SourceLength=$null;SourceHash=''
    }
    [IO.File]::WriteAllText((Join-Path $machineFolder 'rollback.dpapi'),(Protect-NyxState -State $machineState),[Text.UTF8Encoding]::new($false))
    Upgrade-Corrected
    $inventory=Get-NyxStartupRollbackInventory
    Test-Step 'QA2 machine pointer is rejected' (-not [bool]$inventory.Complete -and @($inventory.Entries|Where-Object{$_.ActionId -eq $machineId}).Count -eq 0) ($inventory|ConvertTo-Json -Depth 10 -Compress)
    Test-Step 'QA2 machine pointer rejection creates no HKLM startup value' ($null -eq (Get-ItemProperty -LiteralPath 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'NyxPCCheckup_QA2_Machine' -ErrorAction SilentlyContinue))

    # Scenario 5: corrected uninstaller consumes the migrated QA2 user rollback
    # before deleting code, registration, and optionally local data.
    Reset-DisposableState -Label 'BeforeScenario5'
    Install-QA2
    $uninstallCase=New-QA2RegistryDisable -Name ($script:FixturePrefix+'Uninstall')
    Upgrade-Corrected
    $uninstaller=Join-Path $script:InstallRoot 'Uninstall Nyx PC Checkup.exe'
    Remove-NyxLoadedModules
    $exit=Run-Exe $uninstaller '/quiet /purgedata'
    Test-Step 'Corrected uninstall exits 0 with QA2 current-user rollback present' ($exit -eq 0) ('ExitCode='+$exit)
    $restoredCommand=(Get-ItemProperty -LiteralPath $script:RunPath -Name $uninstallCase.Name -ErrorAction Stop).($uninstallCase.Name)
    Test-Step 'Uninstall restores QA2 current-user rollback before removal' ([string]$restoredCommand -eq $uninstallCase.Command) ([string]$restoredCommand)
    Test-Step 'Corrected uninstall removes install root after QA2 restoration' (Wait-Absent $script:InstallRoot 15)
    Test-Step 'Corrected purge uninstall removes local rollback data' (Wait-Absent $script:DataRoot 15)
    }
}catch{
    $unhandled=$_.Exception.ToString()
    Add-TestResult -Name 'QA2 migration harness completed without unhandled error' -Passed $false -Details $unhandled
}finally{
    try{Reset-DisposableState -Label 'FinalCleanup'}catch{Add-TestResult -Name 'Disposable-VM cleanup completed' -Passed $false -Details $_.Exception.ToString()}
}

$stopped=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.qa2-migration-regression.v1'
    HarnessRevision='QA21-F018-PS51-21'
    HarnessCorrectionRevision='QA9-WH006-1'
    Product='Nyx PC Checkup'
    CorrectedBuild='2026.09.27-eng-qa21'
    Scope='Exact QA2 current-user rollback migration and corrected uninstall regression'
    QA2FixtureMethod='Harness-owned exact QA2 legacy rollback journal using immutable QA2 CurrentUser DPAPI helpers and exact pinned QA2 Paths layout; scenario reset records uninstaller exit and cleans only exact known Nyx roots after intentional exit-6 fail-closed state'
    StartedUtc=$started.ToString('o')
    CompletedUtc=$stopped.ToString('o')
    ElapsedSeconds=[math]::Round(($stopped-$started).TotalSeconds,3)
    ComputerName=$env:COMPUTERNAME
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    QA2SetupPath=$QA2SetupPath
    QA2SetupSha256=(Get-FileHash -LiteralPath $QA2SetupPath -Algorithm SHA256).Hash
    CorrectedSetupPath=$CorrectedSetupPath
    CorrectedSetupSha256=(Get-FileHash -LiteralPath $CorrectedSetupPath -Algorithm SHA256).Hash
    InstallerEnvironmentPreflightPath=$script:InstallerPreflightPath
    InstallerEnvironmentPreflight=$script:InstallerPreflight
    QA2ShellFolderPreflight=$script:QA2ShellFolderPreflight
    QA2ModuleScopeObservation=$script:QA2ModuleScopeObservation
    QA2HarnessPathMap=$script:QA2HarnessPathMap
    HarnessCorrectionHistory=@('QA9-WH004-1','QA9-WH005-1','QA9-WH006-1')
    PreconditionBlocked=[bool]$script:PreconditionBlocked
    QA2SetupInferences=@($script:QA2SetupRuns.ToArray())
    CorrectedSetupRuns=@($script:CorrectedSetupRuns.ToArray())
    ResetRuns=@($script:ResetRuns.ToArray())
    DestructiveCleanVmAcknowledged=[bool]$DestructiveCleanVmAcknowledged
    Passed=($script:Failures -eq 0)
    Total=$script:Results.Count
    Failed=$script:Failures
    Results=@($script:Results.ToArray())
    UnhandledError=$unhandled
}
$report|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("QA2 migration regression: {0}/{1} passed. Evidence: {2}" -f ($report.Total-$report.Failed),$report.Total,$OutputPath)
if($script:Failures -gt 0){exit 1}
exit 0

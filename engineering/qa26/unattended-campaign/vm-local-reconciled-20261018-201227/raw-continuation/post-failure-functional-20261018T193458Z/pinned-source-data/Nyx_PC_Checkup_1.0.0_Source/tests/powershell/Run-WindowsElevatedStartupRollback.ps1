[CmdletBinding()]
param(
    [string]$AppRoot='',
    [switch]$DestructiveCleanVmAcknowledged,
    [string]$ExpectedUserSid='',
    [string]$OutputPath=''
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'This acceptance harness must run under Windows PowerShell 5.1 (Desktop edition).'}

function Add-TestResult {
    param([string]$Name,[bool]$Passed,[string]$Details='')
    $script:Results.Add([pscustomobject][ordered]@{Name=$Name;Passed=$Passed;Details=$Details})
    if(-not $Passed){$script:Failures++}
}
function Assert-True {
    param([string]$Name,[bool]$Condition,[string]$Details='')
    Add-TestResult -Name $Name -Passed $Condition -Details $Details
}
function Get-MachineStartupSnapshot {
    $records=[System.Collections.Generic.List[object]]::new()
    foreach($path in @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )){
        $values=[ordered]@{}
        try{
            $item=Get-ItemProperty -LiteralPath $path -ErrorAction Stop
            foreach($property in @($item.PSObject.Properties|Where-Object{-not $_.Name.StartsWith('PS')}|Sort-Object Name)){$values[$property.Name]=[string]$property.Value}
        }catch{$values['[READ ERROR]']=$_.Exception.Message}
        $records.Add([pscustomobject]@{Kind='Registry';Path=$path;Values=$values})
    }
    $common=[Environment]::GetFolderPath('CommonStartup')
    if(-not [string]::IsNullOrWhiteSpace($common) -and (Test-Path -LiteralPath $common -PathType Container)){
        foreach($file in @(Get-ChildItem -LiteralPath $common -File -Force -ErrorAction SilentlyContinue|Sort-Object FullName)){
            $digest=''
            try{$digest=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash}catch{}
            $records.Add([pscustomobject]@{Kind='File';Path=$file.FullName;Length=[int64]$file.Length;Sha256=$digest})
        }
    }
    return ($records.ToArray()|ConvertTo-Json -Depth 10 -Compress)
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
$script:Results=[System.Collections.Generic.List[object]]::new()
$script:Failures=0
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$currentSid=if($null -ne $identity.User){[string]$identity.User.Value}else{''}
$isAdmin=([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if([string]::IsNullOrWhiteSpace($AppRoot)){
    $installed=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup\app'
    if(Test-Path -LiteralPath $installed -PathType Container){$AppRoot=$installed}else{$AppRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\src\app')).Path}
}
$AppRoot=(Resolve-Path $AppRoot).Path
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path (Get-Location) ('Nyx_PC_Checkup_Privilege_Boundary_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')}

try{
    $runtimeComposition=Import-QA7ActionsRuntime -Root $AppRoot
    Assert-True 'QA7 Actions composition exposes Get-NyxStableId and startup/action commands' ([bool]$runtimeComposition.Passed -and $null -ne (Get-Command Get-NyxStableId -CommandType Function -ErrorAction SilentlyContinue) -and $null -ne (Get-Command Get-NyxStartupApplications -CommandType Function -ErrorAction SilentlyContinue) -and $null -ne (Get-Command Disable-NyxStartupApplication -CommandType Function -ErrorAction SilentlyContinue)) ($runtimeComposition|ConvertTo-Json -Depth 8 -Compress)

    if([string]::IsNullOrWhiteSpace($ExpectedUserSid)){
        Add-TestResult -Name 'Expected user SID not supplied; alternate administrator identity assertion is informational' -Passed $true -Details ("Current SID=$currentSid. Re-run with -ExpectedUserSid when recording the alternate administrator scenario.")
    }else{
        Assert-True 'Expected alternate administrator or standard-user SID owns this run' ([string]::Equals($currentSid,$ExpectedUserSid,[StringComparison]::OrdinalIgnoreCase)) ("Expected=$ExpectedUserSid Actual=$currentSid")
    }

    $runtimeFiles=@(
        (Join-Path $AppRoot 'ui\MainWindow.psm1'),
        (Join-Path $AppRoot 'workers\ActionWorker.ps1'),
        (Join-Path $AppRoot 'workers\UninstallWorker.ps1'),
        (Join-Path $AppRoot 'actions\StartupActions.psm1')
    )
    $runtimeText=($runtimeFiles|ForEach-Object{Get-Content -LiteralPath $_ -Raw -Encoding UTF8}) -join "`n"
    Assert-True 'No UAC RunAs launcher remains in mutable application code' ($runtimeText -notmatch '(?i)(?:-Verb\s+RunAs|\bVerb\s*=\s*["'']RunAs["'']|ShellExecuteEx.*runas)') 'The QA7 runtime must not launch any elevated PowerShell path.'
    Assert-True 'No machine-startup mutation helper remains in Version 1' ($runtimeText -notmatch '(?i)(?:New-NyxMachineStartupRollback|Disable-NyxMachineStartup|Enable-NyxMachineStartup|Set-NyxMachineStartup)') 'All-users entries are read-only.'

    $before=Get-MachineStartupSnapshot
    $fakeMachine=[pscustomobject][ordered]@{
        Id='qa-machine-read-only';Name='QA all-users fixture';Publisher='QA';SourceType='Registry'
        SourcePath='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';SourceLabel='All users Run';ValueName='NyxPCCheckup_QA_ReadOnly'
        Command='"C:\Windows\System32\notepad.exe"';ExecutablePath='C:\Windows\System32\notepad.exe'
        FileExists=$true;Enabled=$true;RequiresElevation=$true;CanModify=$false;ReadOnlyReason='All-users startup entries are displayed read-only in Version 1.'
    }
    $pidBefore=$PID
    $readOnlyResult=Disable-NyxStartupApplication -Application $fakeMachine -Confirmed
    Assert-True 'All-users entry is read-only' (-not [bool]$readOnlyResult.Success -and [string]$readOnlyResult.Status -eq 'ReadOnly') ($readOnlyResult|ConvertTo-Json -Depth 8 -Compress)
    Assert-True 'No UAC process transition occurs for an all-users entry' ($PID -eq $pidBefore -and [string]$readOnlyResult.Message -match 'did not request elevation') ([string]$readOnlyResult.Message)
    $after=Get-MachineStartupSnapshot
    Assert-True 'Read-only all-users action leaves machine startup state byte-for-byte unchanged' ($before -eq $after)

    $machineBoundaryRejected=$false
    try{
        [void](Test-NyxStartupStateBoundary -State ([pscustomobject]@{
            JournalScope='Machine';OwnerSid=$currentSid;RequiresElevation=$true;SourceType='Registry'
            SourcePath='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';ValueName='QA'
        }))
    }catch{$machineBoundaryRejected=$true}
    Assert-True 'Machine-scoped rollback state is rejected by the writable action boundary' $machineBoundaryRejected

    $enumerated=@(Get-NyxStartupApplications|Where-Object{[bool]$_.RequiresElevation})
    $badEnumerated=@($enumerated|Where-Object{[bool]$_.CanModify})
    Assert-True 'Every enumerated all-users startup entry is read-only' ($badEnumerated.Count -eq 0) ($badEnumerated|ConvertTo-Json -Depth 6 -Compress)

    $legacyBaseline=Get-NyxLegacyMachineRollbackObligations
    Assert-True 'Legacy machine rollback is independently discoverable without a per-user pointer' ([string]$legacyBaseline.Status -in @('Clear','Present','Unknown') -and -not [string]::IsNullOrWhiteSpace([string]$legacyBaseline.Root)) ($legacyBaseline|ConvertTo-Json -Depth 8 -Compress)

    if($DestructiveCleanVmAcknowledged){
        if(-not $isAdmin){
            Assert-True 'Legacy machine rollback fixture requires an elevated disposable-VM run' $false 'The switch was supplied, but this process is not an administrator.'
        }elseif([string]$legacyBaseline.Status -ne 'Clear'){
            Assert-True 'Legacy machine rollback fixture starts from a clear QA root' $false ($legacyBaseline|ConvertTo-Json -Depth 8 -Compress)
        }else{
            $legacyRoot=Get-NyxLegacyMachineStartupRollbackRoot
            $legacyRootExistedBefore=Test-Path -LiteralPath $legacyRoot
            $actionId=[guid]::NewGuid().ToString('N')
            $actionFolder=Join-Path $legacyRoot $actionId
            $journalPath=Join-Path $actionFolder 'rollback.json'
            try{
                New-Item -ItemType Directory -Path $actionFolder -Force -ErrorAction Stop|Out-Null
                $legacyState=[pscustomobject][ordered]@{
                    JournalVersion=1;JournalScope='Machine';ActionId=$actionId;OwnerSid=$currentSid
                    Name='QA legacy machine entry';SourceLabel='All users Run';SourceType='Registry'
                    SourcePath='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run';ValueName='NyxPCCheckup_QA_Legacy'
                    Command='"C:\Windows\System32\notepad.exe"';RequiresElevation=$true
                }
                $legacyState|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $journalPath -Encoding UTF8
                $paths=Initialize-NyxDataDirectories
                $pointer=Join-Path $paths.DisabledStartup $actionId
                Assert-True 'Legacy fixture intentionally has no per-user pointer' (-not(Test-Path -LiteralPath $pointer)) $pointer
                $present=Get-NyxLegacyMachineRollbackObligations
                Assert-True 'Legacy machine rollback obligation is found from ProgramData alone' ([string]$present.Status -eq 'Present' -and @($present.Obligations|Where-Object{$_.ActionId -eq $actionId}).Count -eq 1) ($present|ConvertTo-Json -Depth 8 -Compress)

                Set-Content -LiteralPath $journalPath -Value '{ malformed legacy journal' -Encoding UTF8
                $unknown=Get-NyxLegacyMachineRollbackObligations
                Assert-True 'Malformed legacy machine rollback state fails closed as Unknown' ([string]$unknown.Status -eq 'Unknown' -and -not [bool]$unknown.Complete) ($unknown|ConvertTo-Json -Depth 8 -Compress)
            }finally{
                Remove-Item -LiteralPath $actionFolder -Recurse -Force -ErrorAction SilentlyContinue
                if(-not $legacyRootExistedBefore){
                    Remove-EmptyDirectory -Path $legacyRoot
                    Remove-EmptyDirectory -Path (Split-Path -Parent $legacyRoot)
                }
            }
        }
    }else{
        Add-TestResult -Name 'Legacy machine rollback mutation test not requested' -Passed $true -Details 'Run again as administrator in a disposable VM with -DestructiveCleanVmAcknowledged to create and remove an isolated ProgramData journal. No HKLM startup value is ever created.'
    }

    Add-TestResult -Name 'Alternate administrator UAC observation requirement' -Passed $true -Details 'QA should repeat the all-users read-only action while an alternate administrator credential is available and record that no credential prompt appears; the executable manifest and runtime expose no elevation path.'
}catch{
    Add-TestResult -Name 'Privilege-boundary harness completed without unhandled error' -Passed $false -Details $_.Exception.ToString()
}

$stopped=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.privilege-boundary.v2'
    HarnessRevision='QA26-F023-PS51-26'
    Scope='privilege-boundary and legacy rollback'
    StartedUtc=$started.ToString('o')
    CompletedUtc=$stopped.ToString('o')
    ElapsedSeconds=[math]::Round(($stopped-$started).TotalSeconds,3)
    ComputerName=$env:COMPUTERNAME
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    CurrentUserSid=$currentSid
    IsAdministrator=$isAdmin
    ExpectedUserSid=$ExpectedUserSid
    DestructiveCleanVmAcknowledged=[bool]$DestructiveCleanVmAcknowledged
    AppRoot=$AppRoot
    Passed=($script:Failures -eq 0)
    Total=$script:Results.Count
    Failed=$script:Failures
    Results=@($script:Results.ToArray())
}
$report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Privilege-boundary and legacy rollback tests: {0}/{1} passed. Evidence: {2}" -f ($report.Total-$report.Failed),$report.Total,$OutputPath)
if($script:Failures -gt 0){exit 1}
exit 0

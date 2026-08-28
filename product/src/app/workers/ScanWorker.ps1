[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('Quick','Full')][string]$Mode,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][string]$ProgressPath,
    [Parameter(Mandatory=$true)][string]$CancelPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$AppRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
[void](Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Scan)

function Assert-NyxScanWorkerPaths {
    $paths=Initialize-NyxDataDirectories
    $tempItem=Get-Item -LiteralPath $paths.Temp -Force -ErrorAction Stop
    if(($tempItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'The Nyx scan workspace cannot be a reparse point.'}
    $tempFull=[IO.Path]::GetFullPath($paths.Temp).TrimEnd('\')
    $values=@($OutputPath,$ProgressPath,$CancelPath)
    foreach($value in $values){
        $full=[IO.Path]::GetFullPath($value)
        if(-not [string]::Equals([IO.Path]::GetDirectoryName($full).TrimEnd('\'),$tempFull,[StringComparison]::OrdinalIgnoreCase)){throw 'Scan files must remain inside the Nyx scan workspace.'}
        if(Test-Path -LiteralPath $full){$item=Get-Item -LiteralPath $full -Force -ErrorAction Stop;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'A scan file cannot be a reparse point.'}}
    }
    $outMatch=[regex]::Match([IO.Path]::GetFileName($OutputPath),'^scan-([a-f0-9]{32})\.json$','IgnoreCase')
    $progressMatch=[regex]::Match([IO.Path]::GetFileName($ProgressPath),'^scan-([a-f0-9]{32})-progress\.jsonl$','IgnoreCase')
    $cancelMatch=[regex]::Match([IO.Path]::GetFileName($CancelPath),'^scan-([a-f0-9]{32})\.cancel$','IgnoreCase')
    if(-not $outMatch.Success -or -not $progressMatch.Success -or -not $cancelMatch.Success){throw 'The scan file names are invalid.'}
    if($outMatch.Groups[1].Value -ne $progressMatch.Groups[1].Value -or $outMatch.Groups[1].Value -ne $cancelMatch.Groups[1].Value){throw 'The scan file identities do not match.'}
}
Assert-NyxScanWorkerPaths

function Write-NyxProgressEvent {
    param([string]$Type,[int]$Percent,[string]$Message,[object]$Payload=$null)
    $event=[pscustomobject][ordered]@{ Type=$Type; Percent=$Percent; Message=$Message; Timestamp=(Get-Date).ToUniversalTime().ToString('o'); Payload=$Payload }
    Add-Content -LiteralPath $ProgressPath -Value ($event|ConvertTo-Json -Compress -Depth 15) -Encoding UTF8
}

$started=(Get-Date).ToUniversalTime()
$results=[System.Collections.Generic.List[object]]::new()
$cancelled=$false
$tasks=[System.Collections.Generic.List[object]]::new()
function Add-Task([string]$Id,[string]$Category,[string]$Name,[scriptblock]$Run,[string]$Source){
    $tasks.Add([pscustomobject]@{ Id=$Id; Category=$Category; Name=$Name; Run=$Run; Source=$Source })
}
Add-Task 'system.overview' 'System' 'System overview' { Get-NyxSystemInfoCheck } 'Windows CIM'
Add-Task 'storage.system-drive' 'Storage' 'System-drive free space' { Get-NyxStorageHealthCheck } '.NET DriveInfo'
Add-Task 'updates.group' 'Updates' 'Windows updates' { Get-NyxWindowsUpdateChecks } 'Windows Update / registry'
Add-Task 'security.group' 'Security' 'Windows security' { Get-NyxSecurityStatusChecks } 'Windows Security APIs'
Add-Task 'startup.entries' 'Startup' 'Startup applications' { Get-NyxStartupAppsCheck } 'Registry / Startup folders'
Add-Task 'backup.status' 'Backup' 'Backup checkup' { Get-NyxBackupStatusCheck } 'Windows backup indicators'
Add-Task 'system.uptime' 'System' 'PC uptime' { Get-NyxUptimeCheck } 'Windows CIM'
Add-Task 'network.basics' 'Network' 'Network basics' { Get-NyxNetworkBasicsCheck } 'Windows networking APIs'
if($Mode -eq 'Full'){
    Add-Task 'storage.user-folders' 'Storage' 'User folders and largest files' { Get-NyxStorageScanCheck -CancelFile $CancelPath } 'File-system enumeration'
    Add-Task 'downloads.analysis' 'Downloads' 'Downloads checkup' { Get-NyxDownloadsAnalysisCheck -CancelFile $CancelPath } 'Downloads metadata / bounded hashes'
    Add-Task 'cleanup.preview' 'Cleanup' 'Safe cleanup preview' { Get-NyxCleanupPreviewCheck -CancelFile $CancelPath } 'Approved local cleanup roots'
    $hasBattery=@(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0
    if($hasBattery){Add-Task 'battery.health' 'Battery' 'Battery health' { Get-NyxBatteryHealthCheck } 'Windows battery APIs'}
    Add-Task 'drive.health' 'Drive Health' 'Physical drive health' { Get-NyxDriveHealthCheck } 'Windows Storage module'
    Add-Task 'performance.snapshot' 'Performance' 'Performance snapshot' { Get-NyxPerformanceSnapshotCheck } 'Windows CIM / counters'
    Add-Task 'apps.inventory' 'Applications' 'Installed applications' { Get-NyxInstalledAppsCheck } 'Uninstall registry'
}

try{
    if(Test-Path -LiteralPath $ProgressPath){Remove-Item -LiteralPath $ProgressPath -Force}
    Write-NyxProgressEvent -Type 'Started' -Percent 0 -Message "$Mode check started. Scanning is read-only."
    for($i=0;$i -lt $tasks.Count;$i++){
        if(Test-Path -LiteralPath $CancelPath){$cancelled=$true;break}
        $task=$tasks[$i]
        $before=[int][math]::Floor(($i/[double]$tasks.Count)*100)
        Write-NyxProgressEvent -Type 'CheckStarted' -Percent $before -Message ("Checking {0}..." -f $task.Name) -Payload ([pscustomobject]@{ CheckId=$task.Id; Category=$task.Category })
        $values=@(Invoke-NyxIsolatedCheck -CheckId $task.Id -Category $task.Category -Name $task.Name -Script $task.Run -DataSource $task.Source)
        foreach($value in $values){
            if($null -eq $value){continue}
            $results.Add($value)
            Write-NyxProgressEvent -Type 'Result' -Percent ([int][math]::Floor((($i+1)/[double]$tasks.Count)*100)) -Message ([string]$value.Finding) -Payload $value
        }
    }
    $summary=Get-NyxResultSummary -Results @($results.ToArray())
    $scan=[pscustomobject][ordered]@{
        Schema='dietrich-ai-labs.nyx-pc-checkup.scan.v1'; Mode=$Mode; StartedUtc=$started.ToString('o');
        CompletedUtc=(Get-Date).ToUniversalTime().ToString('o'); Cancelled=$cancelled; ReadOnly=$true;
        Summary=$summary; Results=@($results.ToArray())
    }
    $scan|ConvertTo-Json -Depth 18|Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Save-NyxScanResults -Scan $scan
    Write-NyxProgressEvent -Type $(if($cancelled){'Cancelled'}else{'Completed'}) -Percent 100 -Message $(if($cancelled){'Check cancelled. Partial results were preserved.'}else{$summary.Headline}) -Payload $summary
    exit 0
}catch{
    Write-NyxLog -Level 'ERROR' -Message ("Scan worker failed: {0}" -f $_.Exception.Message)
    $failure=[pscustomobject]@{ Schema='dietrich-ai-labs.nyx-pc-checkup.scan.v1'; Mode=$Mode; StartedUtc=$started.ToString('o'); CompletedUtc=(Get-Date).ToUniversalTime().ToString('o'); Cancelled=$false; ReadOnly=$true; Summary=(Get-NyxResultSummary -Results @()); Results=@(); WorkerError=$_.Exception.Message }
    $failure|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-NyxProgressEvent -Type 'Failed' -Percent 100 -Message 'The scan worker stopped unexpectedly. No changes were made.' -Payload ([pscustomobject]@{ Error=$_.Exception.Message })
    exit 1
}

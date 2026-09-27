Set-StrictMode -Version 2.0

# RuntimeComposition is the only owner of application-module loading. Runtime
# modules do not import or force-reload one another. This prevents a nested
# Import-Module -Force operation from removing commands that were already
# exported to the caller under Windows PowerShell 5.1.
$script:NyxRuntimeModules = @(
    [pscustomobject][ordered]@{Name='Paths';RelativePath='core\Paths.psm1';Exports=@('Get-NyxDataRoot','Get-NyxPathMap','Assert-NyxOrdinaryDataDirectory','Initialize-NyxDataDirectories','Remove-NyxTemporaryArtifacts','Get-NyxInstallRoot')},
    [pscustomobject][ordered]@{Name='Privacy';RelativePath='core\Privacy.psm1';Exports=@('Test-NyxSensitivePropertyName','Remove-NyxIpAddresses','Protect-NyxText','Protect-NyxObject','Get-NyxPrivacyStatement')},
    [pscustomobject][ordered]@{Name='Configuration';RelativePath='core\Configuration.psm1';Exports=@('Get-NyxDefaultConfiguration','ConvertTo-NyxUtcTimestampText','Repair-NyxConfiguration','Get-NyxConfiguration','Save-NyxConfiguration')},
    [pscustomobject][ordered]@{Name='Diagnostics';RelativePath='core\Diagnostics.psm1';Exports=@('Write-NyxLog','Clear-NyxLogs','Invoke-NyxLogRotation')},
    [pscustomobject][ordered]@{Name='Models';RelativePath='core\Models.psm1';Exports=@('New-NyxCheckResult','New-NyxUnknownResult','Get-NyxStatusLabel','Get-NyxStatusSymbol','Get-NyxResultSummary')},
    [pscustomobject][ordered]@{Name='HealthRules';RelativePath='health_rules\HealthRules.psm1';Exports=@('Get-NyxRules','Get-NyxStorageRuleResult','Get-NyxUptimeRuleResult','Get-NyxBatteryRuleResult','Get-NyxPerformanceRuleResult')},
    [pscustomobject][ordered]@{Name='WindowsHelpers';RelativePath='platform\windows\WindowsHelpers.psm1';Exports=@('Test-NyxWindowsPlatform','ConvertTo-NyxBytesText','Get-NyxStableId','Get-NyxDownloadsPath','Test-NyxReparsePoint','Get-NyxSystemDriveInfo','Get-NyxRestartPending','Get-NyxFolderSize','Get-NyxWindowsEdition')},
    [pscustomobject][ordered]@{Name='ActionHistory';RelativePath='core\ActionHistory.psm1';Exports=@('Protect-NyxState','Unprotect-NyxState','Get-NyxActionHistory','Add-NyxActionHistory','Test-NyxCurrentUserRollbackState','ConvertFrom-NyxQA2CurrentUserRollbackState','Resolve-NyxCurrentUserRollbackState','Get-NyxStartupRollbackInventory','Get-NyxActiveStartupDisables')},
    [pscustomobject][ordered]@{Name='CheckupEngine';RelativePath='core\CheckupEngine.psm1';Exports=@('Invoke-NyxIsolatedCheck','Convert-NyxScanResult','Convert-NyxPersistedScan','Save-NyxScanResults','Get-NyxLastScan')},
    [pscustomobject][ordered]@{Name='Versioning';RelativePath='updates\Versioning.psm1';Exports=@('ConvertTo-NyxSemanticVersion','Compare-NyxSemanticVersion')},
    [pscustomobject][ordered]@{Name='Manifest';RelativePath='updates\Manifest.psm1';Exports=@('Get-NyxUpdateProductConfiguration','Test-NyxUpdateDestinationUri','Test-NyxManifestDisplayText','ConvertTo-NyxValidatedUpdateManifest')},
    [pscustomobject][ordered]@{Name='Preferences';RelativePath='updates\Preferences.psm1';Exports=@('Test-NyxAutomaticUpdateCheckDue','Set-NyxUpdateCheckAttemptUtc')},
    [pscustomobject][ordered]@{Name='UpdateChecker';RelativePath='updates\UpdateChecker.psm1';Exports=@('New-NyxUpdateCheckResult','Get-NyxUpdateManifestText','Invoke-NyxUpdateCheck')},
    [pscustomobject][ordered]@{Name='PdfWriter';RelativePath='reports\PdfWriter.psm1';Exports=@('Write-NyxSimplePdf','Split-NyxReportLines')},
    [pscustomobject][ordered]@{Name='ReportExport';RelativePath='reports\ReportExport.psm1';Exports=@('Get-NyxVersionMetadata','Get-NyxReportEvidence','New-NyxSafeReport','ConvertTo-NyxReportText','Export-NyxReport')},
    [pscustomobject][ordered]@{Name='SystemInfo';RelativePath='checks\SystemInfo.psm1';Exports=@('Get-NyxSystemInfoCheck')},
    [pscustomobject][ordered]@{Name='StorageHealth';RelativePath='checks\StorageHealth.psm1';Exports=@('Get-NyxStorageHealthCheck')},
    [pscustomobject][ordered]@{Name='StorageScan';RelativePath='checks\StorageScan.psm1';Exports=@('Get-NyxTopFiles','Get-NyxStorageScanCheck')},
    [pscustomobject][ordered]@{Name='DownloadsAnalysis';RelativePath='checks\DownloadsAnalysis.psm1';Exports=@('Get-NyxDownloadCategory','Get-NyxDuplicateCandidates','Get-NyxDownloadsAnalysisCheck')},
    [pscustomobject][ordered]@{Name='StartupApps';RelativePath='checks\StartupApps.psm1';Exports=@('Get-NyxExecutableFromCommand','Get-NyxStartupApplications','Get-NyxStartupAppsCheck')},
    [pscustomobject][ordered]@{Name='WindowsUpdates';RelativePath='checks\WindowsUpdates.psm1';Exports=@('Get-NyxPendingUpdateSnapshot','Get-NyxWindowsUpdateChecks')},
    [pscustomobject][ordered]@{Name='SecurityStatus';RelativePath='checks\SecurityStatus.psm1';Exports=@('Get-NyxSecurityStatusChecks')},
    [pscustomobject][ordered]@{Name='BackupStatus';RelativePath='checks\BackupStatus.psm1';Exports=@('Get-NyxBackupStatusCheck')},
    [pscustomobject][ordered]@{Name='BatteryHealth';RelativePath='checks\BatteryHealth.psm1';Exports=@('Get-NyxBatteryChargingState','Get-NyxBatteryHealthCheck')},
    [pscustomobject][ordered]@{Name='PerformanceSnapshot';RelativePath='checks\PerformanceSnapshot.psm1';Exports=@('Get-NyxPerformanceSnapshotCheck')},
    [pscustomobject][ordered]@{Name='DriveHealth';RelativePath='checks\DriveHealth.psm1';Exports=@('Get-NyxDriveHealthCheck')},
    [pscustomobject][ordered]@{Name='InstalledApps';RelativePath='checks\InstalledApps.psm1';Exports=@('Get-NyxInstalledApplications','Get-NyxInstalledAppsCheck')},
    [pscustomobject][ordered]@{Name='Uptime';RelativePath='checks\Uptime.psm1';Exports=@('Get-NyxUptimeCheck')},
    [pscustomobject][ordered]@{Name='NetworkBasics';RelativePath='checks\NetworkBasics.psm1';Exports=@('Get-NyxNetworkBasicsCheck')},
    [pscustomobject][ordered]@{Name='CleanupScan';RelativePath='checks\CleanupScan.psm1';Exports=@('New-NyxCleanupCandidate','Get-NyxRecycleBinSummary','Get-NyxCleanupCandidates','Get-NyxCleanupPreviewCheck')},
    [pscustomobject][ordered]@{Name='StartupActions';RelativePath='actions\StartupActions.psm1';Exports=@('Get-NyxCurrentUserSid','Get-NyxStartupBoundary','Test-NyxStartupStateBoundary','Get-NyxLegacyMachineStartupRollbackRoot','Get-NyxLegacyMachineRollbackObligations','Disable-NyxStartupApplication','Enable-NyxStartupApplication','Restore-AllNyxStartupApplications')},
    [pscustomobject][ordered]@{Name='CleanupActions';RelativePath='actions\CleanupActions.psm1';Exports=@('Invoke-NyxCleanup')},
    [pscustomobject][ordered]@{Name='Theme';RelativePath='ui\Theme.psm1';Exports=@('Get-NyxEffectiveTheme','Get-NyxPalette','Get-NyxStatusColor','Set-NyxGridTheme')},
    [pscustomobject][ordered]@{Name='Controls';RelativePath='ui\Controls.psm1';Exports=@('New-NyxLabel','New-NyxButton','New-NyxNavButton','New-NyxCard','New-NyxGrid','New-NyxStatusPill','Get-NyxControlDpiScale','Register-NyxScrollFocus','Set-NyxDeviceGeometry','Set-NyxScrollExtentFromChildren','Initialize-NyxScrollableDialog')},
    [pscustomobject][ordered]@{Name='Dialogs';RelativePath='ui\Dialogs.psm1';Exports=@('Show-NyxResultDetailDialog','Show-NyxReportPreviewDialog','Show-NyxUpdateAvailableDialog')},
    [pscustomobject][ordered]@{Name='MainWindow';RelativePath='ui\MainWindow.psm1';Exports=@('Show-NyxMainWindow')}
)

$script:NyxRuntimeProfiles = [ordered]@{
    Diagnostics = @('Paths','Privacy','Configuration','Diagnostics')
    Core = @('Paths','Privacy','Configuration','Diagnostics','Models','HealthRules','WindowsHelpers')
    Update = @('Paths','Privacy','Configuration','Diagnostics','Versioning','Manifest','Preferences','UpdateChecker')
    Uninstall = @('Paths','Privacy','Configuration','Diagnostics','ActionHistory','StartupActions')
    Actions = @('Paths','Privacy','Configuration','Diagnostics','Models','HealthRules','WindowsHelpers','ActionHistory','DownloadsAnalysis','CleanupScan','StartupApps','StartupActions','CleanupActions')
    Scan = @('Paths','Privacy','Configuration','Diagnostics','Models','HealthRules','WindowsHelpers','ActionHistory','CheckupEngine','SystemInfo','StorageHealth','StorageScan','DownloadsAnalysis','StartupApps','WindowsUpdates','SecurityStatus','BackupStatus','BatteryHealth','PerformanceSnapshot','DriveHealth','InstalledApps','Uptime','NetworkBasics','CleanupScan')
    Full = @('Paths','Privacy','Configuration','Diagnostics','Models','HealthRules','WindowsHelpers','ActionHistory','CheckupEngine','Versioning','Manifest','Preferences','UpdateChecker','PdfWriter','ReportExport','SystemInfo','StorageHealth','StorageScan','DownloadsAnalysis','StartupApps','WindowsUpdates','SecurityStatus','BackupStatus','BatteryHealth','PerformanceSnapshot','DriveHealth','InstalledApps','Uptime','NetworkBasics','CleanupScan','StartupActions','CleanupActions','Theme','Controls','Dialogs','MainWindow')
    UI = @('Paths','Privacy','Configuration','Diagnostics','Models','HealthRules','WindowsHelpers','ActionHistory','CheckupEngine','Versioning','Manifest','Preferences','UpdateChecker','PdfWriter','ReportExport','SystemInfo','StorageHealth','StorageScan','DownloadsAnalysis','StartupApps','WindowsUpdates','SecurityStatus','BackupStatus','BatteryHealth','PerformanceSnapshot','DriveHealth','InstalledApps','Uptime','NetworkBasics','CleanupScan','StartupActions','CleanupActions','Theme','Controls','Dialogs','MainWindow')
}

function Get-NyxRuntimeModulePlan {
    [CmdletBinding()]
    param([ValidateSet('Diagnostics','Core','Update','Uninstall','Actions','Scan','Full','UI')][string]$Profile='Full')
    $names=@($script:NyxRuntimeProfiles[$Profile])
    $result=[System.Collections.Generic.List[object]]::new()
    foreach($name in $names){
        $entry=@($script:NyxRuntimeModules|Where-Object{[string]$_.Name -eq [string]$name}|Select-Object -First 1)
        if($entry.Count -ne 1){throw ("Runtime module profile {0} references an unknown or duplicate module: {1}" -f $Profile,$name)}
        $result.Add($entry[0])
    }
    return @($result.ToArray())
}

function Test-NyxRuntimeCommandSurface {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$AppRoot,
        [Parameter(Mandatory=$true)][object[]]$Plan,
        [int]$ThroughIndex=-1
    )
    $root=[IO.Path]::GetFullPath($AppRoot).TrimEnd('\')
    if($ThroughIndex -lt 0 -or $ThroughIndex -ge $Plan.Count){$ThroughIndex=$Plan.Count-1}
    $missing=[System.Collections.Generic.List[object]]::new()
    for($i=0;$i -le $ThroughIndex;$i++){
        $module=$Plan[$i]
        $expectedPath=[IO.Path]::GetFullPath((Join-Path $root ([string]$module.RelativePath)))
        foreach($name in @($module.Exports)){
            $commands=@(Get-Command -Name ([string]$name) -CommandType Function -All -ErrorAction SilentlyContinue)
            $match=@($commands|Where-Object{$null -ne $_.Module -and -not [string]::IsNullOrWhiteSpace([string]$_.Module.Path) -and [string]::Equals([IO.Path]::GetFullPath([string]$_.Module.Path),$expectedPath,[StringComparison]::OrdinalIgnoreCase)})
            if($match.Count -lt 1){
                $missing.Add([pscustomobject][ordered]@{Command=[string]$name;ExpectedModule=[string]$module.Name;ExpectedPath=$expectedPath;ObservedSources=@($commands|ForEach-Object{[string]$_.Source})})
            }
        }
    }
    return [pscustomobject][ordered]@{Passed=($missing.Count -eq 0);CheckedThroughIndex=$ThroughIndex;Missing=@($missing.ToArray())}
}

function Import-NyxRuntimeGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$AppRoot,
        [ValidateSet('Diagnostics','Core','Update','Uninstall','Actions','Scan','Full','UI')][string]$Profile='Full'
    )
    $root=(Resolve-Path -LiteralPath $AppRoot -ErrorAction Stop).Path
    $rootItem=Get-Item -LiteralPath $root -Force -ErrorAction Stop
    if(-not $rootItem.PSIsContainer -or (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The application module root must be an ordinary directory.'}
    $rootFull=[IO.Path]::GetFullPath($root).TrimEnd('\')
    $plan=@(Get-NyxRuntimeModulePlan -Profile $Profile)
    $layers=[System.Collections.Generic.List[object]]::new()

    for($i=0;$i -lt $plan.Count;$i++){
        $entry=$plan[$i]
        $full=[IO.Path]::GetFullPath((Join-Path $rootFull ([string]$entry.RelativePath)))
        $prefix=$rootFull+'\'
        if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw ("Runtime module escaped the application root: {0}" -f $entry.RelativePath)}
        $item=Get-Item -LiteralPath $full -Force -ErrorAction Stop
        if($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw ("Runtime module is not an ordinary file: {0}" -f $entry.RelativePath)}

        $sameName=@(Get-Module -All -Name ([string]$entry.Name))
        foreach($loaded in $sameName){
            if([string]::IsNullOrWhiteSpace([string]$loaded.Path)){continue}
            $loadedFull=[IO.Path]::GetFullPath([string]$loaded.Path)
            if(-not [string]::Equals($loadedFull,$full,[StringComparison]::OrdinalIgnoreCase)){
                throw ("A conflicting module named {0} is already loaded from {1}" -f $entry.Name,$loaded.Path)
            }
        }

        $exact=@(Get-Module -All|Where-Object{-not [string]::IsNullOrWhiteSpace([string]$_.Path) -and [string]::Equals([IO.Path]::GetFullPath([string]$_.Path),$full,[StringComparison]::OrdinalIgnoreCase)})
        $imported=$false
        if($exact.Count -eq 0){
            Import-Module -Name $full -Global -ErrorAction Stop
            $imported=$true
        }else{
            $singlePlan=@($entry)
            $singleSurface=Test-NyxRuntimeCommandSurface -AppRoot $rootFull -Plan $singlePlan -ThroughIndex 0
            if(-not [bool]$singleSurface.Passed){
                throw ("Runtime module {0} is already loaded from the exact application path but its expected command surface is unavailable; refusing an implicit reload." -f $entry.Name)
            }
        }

        $surface=Test-NyxRuntimeCommandSurface -AppRoot $rootFull -Plan $plan -ThroughIndex $i
        if(-not [bool]$surface.Passed){throw ("Runtime command surface failed after loading {0}: {1}" -f $entry.Name,($surface.Missing|ConvertTo-Json -Depth 8 -Compress))}
        $layers.Add([pscustomobject][ordered]@{Index=$i;Module=[string]$entry.Name;RelativePath=[string]$entry.RelativePath;ImportedToGlobalScope=$imported;CumulativeCommandSurfacePassed=$true})
    }

    $final=Test-NyxRuntimeCommandSurface -AppRoot $rootFull -Plan $plan
    return [pscustomobject][ordered]@{
        Schema='dietrich-ai-labs.nyx-pc-checkup.runtime-composition.v1'
        Profile=$Profile
        AppRoot=$rootFull
        Passed=[bool]$final.Passed
        ModuleCount=$plan.Count
        Layers=@($layers.ToArray())
        Missing=@($final.Missing)
    }
}

Export-ModuleMember -Function Get-NyxRuntimeModulePlan,Test-NyxRuntimeCommandSurface,Import-NyxRuntimeGraph

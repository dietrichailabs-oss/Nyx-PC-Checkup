[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Results=[System.Collections.Generic.List[object]]::new()
$script:Failures=0
$started=(Get-Date).ToUniversalTime()

function Add-F012Result {
    param([string]$Name,[bool]$Passed,[string]$Details='')
    $script:Results.Add([pscustomobject][ordered]@{Name=$Name;Passed=$Passed;Details=$Details})
    if(-not $Passed){$script:Failures++}
}

function Assert-F012 {
    param([string]$Name,[bool]$Condition,[string]$Details='')
    Add-F012Result -Name $Name -Passed $Condition -Details $Details
}

$originalLocalAppData=$env:LOCALAPPDATA
$probeRoot=Join-Path $env:TEMP ('Nyx_F012_Settings_'+[guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $probeRoot -Force|Out-Null
    $env:LOCALAPPDATA=$probeRoot
    Add-Type -AssemblyName System.Windows.Forms
    Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -Force -ErrorAction Stop
    $composition=Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Full
    Assert-F012 'F-012 full runtime composition succeeds' ([bool]$composition.Passed) ($composition|ConvertTo-Json -Depth 8 -Compress)

    $mainPath=Join-Path $AppRoot 'ui\MainWindow.psm1'
    $mainSource=Get-Content -LiteralPath $mainPath -Raw -Encoding UTF8
    Assert-F012 'F-012 Save button owns explicit Settings state' ($mainSource.Contains('$save.Tag=$settingsState'))
    Assert-F012 'F-012 deferred handler resolves state from sender' ($mainSource.Contains('$state=$sender.Tag'))
    Assert-F012 'F-012 handler no longer reads deferred local theme control' (-not $mainSource.Contains('$config.theme=[string]$theme.SelectedItem'))
    Assert-F012 'F-012 validates the complete supported theme set' ($mainSource.Contains("`$selectedTheme -notin @('FollowWindows','Dark','Light')"))

    $transitions=@('FollowWindows','Dark','Light','FollowWindows')
    $configuration=Get-NyxConfiguration
    foreach($theme in $transitions){
        $configuration.theme=$theme
        Save-NyxConfiguration -Configuration $configuration
        $configuration=Get-NyxConfiguration
        Assert-F012 ("F-012 theme persists after save and reload: {0}" -f $theme) ([string]$configuration.theme -eq $theme) ([string]$configuration.theme)
    }

    foreach($repeat in 1..3){
        Save-NyxConfiguration -Configuration $configuration
        $reloaded=Get-NyxConfiguration
        Assert-F012 ("F-012 repeated unchanged Save remains stable: {0}" -f $repeat) ([string]$reloaded.theme -eq 'FollowWindows' -and -not [bool]$reloaded.notificationsEnabled -and [bool]$reloaded.updates.enabled) ($reloaded|ConvertTo-Json -Depth 6 -Compress)
        $configuration=$reloaded
    }

    $configuration.theme='Dark';$configuration.notificationsEnabled=$true
    Save-NyxConfiguration -Configuration $configuration
    $configuration=Get-NyxConfiguration
    Assert-F012 'F-012 theme and notifications persist together' ([string]$configuration.theme -eq 'Dark' -and [bool]$configuration.notificationsEnabled) ($configuration|ConvertTo-Json -Depth 6 -Compress)

    $configuration.theme='Light';$configuration.updates.enabled=$false
    Save-NyxConfiguration -Configuration $configuration
    $configuration=Get-NyxConfiguration
    Assert-F012 'F-012 theme and automatic updates persist together' ([string]$configuration.theme -eq 'Light' -and -not [bool]$configuration.updates.enabled) ($configuration|ConvertTo-Json -Depth 6 -Compress)

    $configuration.theme='FollowWindows';$configuration.notificationsEnabled=$false;$configuration.updates.enabled=$true;$configuration.updates.lastCheckUtc='2026-09-01T00:00:00.0000000Z'
    Save-NyxConfiguration -Configuration $configuration
    $configuration=Get-NyxConfiguration
    Assert-F012 'F-012 all three Settings values persist together' ([string]$configuration.theme -eq 'FollowWindows' -and -not [bool]$configuration.notificationsEnabled -and [bool]$configuration.updates.enabled) ($configuration|ConvertTo-Json -Depth 6 -Compress)
    $expectedTimestampText='2026-09-01T00:00:00.0000000Z'
    $observedTimestampText=[string]$configuration.updates.lastCheckUtc
    $expectedTimestamp=[datetimeoffset]::MinValue
    $observedTimestamp=[datetimeoffset]::MinValue
    $timestampStyle=[Globalization.DateTimeStyles]::RoundtripKind
    $expectedTimestampParsed=[datetimeoffset]::TryParse($expectedTimestampText,[Globalization.CultureInfo]::InvariantCulture,$timestampStyle,[ref]$expectedTimestamp)
    $observedTimestampParsed=[datetimeoffset]::TryParse($observedTimestampText,[Globalization.CultureInfo]::InvariantCulture,$timestampStyle,[ref]$observedTimestamp)
    $expectedTimestampUtc=$expectedTimestamp.ToUniversalTime()
    $observedTimestampUtc=$observedTimestamp.ToUniversalTime()
    $timestampsRepresentSameInstant=($expectedTimestampParsed -and $observedTimestampParsed -and $expectedTimestampUtc.Offset -eq [timespan]::Zero -and $observedTimestampUtc.Offset -eq [timespan]::Zero -and $expectedTimestampUtc.UtcDateTime.Ticks -eq $observedTimestampUtc.UtcDateTime.Ticks)
    $timestampEvidence=[pscustomobject][ordered]@{
        ExpectedText=$expectedTimestampText
        ObservedText=$observedTimestampText
        ExpectedParsed=$expectedTimestampParsed
        ObservedParsed=$observedTimestampParsed
        ExpectedUtc=if($expectedTimestampParsed){$expectedTimestampUtc.ToString('o')}else{$null}
        ObservedUtc=if($observedTimestampParsed){$observedTimestampUtc.ToString('o')}else{$null}
        SameUtcInstant=$timestampsRepresentSameInstant
    }
    Assert-F012 'F-012 saving Settings preserves unrelated update timestamp' $timestampsRepresentSameInstant ($timestampEvidence|ConvertTo-Json -Compress)

    $configuration.theme='UnsupportedTheme'
    Save-NyxConfiguration -Configuration $configuration
    $configuration=Get-NyxConfiguration
    Assert-F012 'F-012 unsupported persisted theme repairs safely' ([string]$configuration.theme -eq 'FollowWindows') ([string]$configuration.theme)
} catch {
    Add-F012Result -Name 'F-012 native Settings regression completes without unhandled error' -Passed $false -Details $_.Exception.ToString()
} finally {
    $env:LOCALAPPDATA=$originalLocalAppData
    Remove-Item -LiteralPath $probeRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$completed=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.qa15-f012-settings-theme.v1'
    Build='2026.09.26-eng-qa19'
    HarnessRevision='QA19-F016-PS51-19'
    HarnessCorrectionRevision='QA15-F012-TIMESTAMP-1'
    StartedUtc=$started.ToString('o')
    CompletedUtc=$completed.ToString('o')
    Passed=($script:Failures -eq 0)
    Total=$script:Results.Count
    Failed=$script:Failures
    Results=@($script:Results.ToArray())
}
$report|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("F-012 Settings/theme regression: {0}/{1} passed. Evidence: {2}" -f ($report.Total-$report.Failed),$report.Total,$OutputPath)
if($script:Failures -gt 0){exit 1}
exit 0

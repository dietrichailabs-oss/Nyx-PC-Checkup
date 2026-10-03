[CmdletBinding()]
param(
    [string]$AppRoot = '',
    [string]$OutputPath = ''
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
function Get-RunKeySnapshot {
    $paths=@(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )
    $result=[System.Collections.Generic.List[object]]::new()
    foreach($path in $paths){
        $values=[ordered]@{}
        try{
            $item=Get-ItemProperty -LiteralPath $path -ErrorAction Stop
            foreach($p in @($item.PSObject.Properties|Where-Object{-not $_.Name.StartsWith('PS')}|Sort-Object Name)){$values[$p.Name]=[string]$p.Value}
        }catch{}
        $result.Add([pscustomobject]@{Path=$path;Values=$values})
    }
    return ($result.ToArray()|ConvertTo-Json -Depth 8 -Compress)
}

$started=(Get-Date).ToUniversalTime()
$script:Results=[System.Collections.Generic.List[object]]::new()
$script:Failures=0
if([string]::IsNullOrWhiteSpace($AppRoot)){
    $installed=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup\app'
    if(Test-Path -LiteralPath $installed -PathType Container){$AppRoot=$installed}else{$AppRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..\src\app')).Path}
}
$AppRoot=(Resolve-Path $AppRoot).Path
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path (Get-Location) ('Nyx_PC_Checkup_Windows_Smoke_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')}

try{
    $parseErrors=[System.Collections.Generic.List[object]]::new()
    Get-ChildItem -LiteralPath $AppRoot -Recurse -File|Where-Object{$_.Extension -in @('.ps1','.psm1')}|ForEach-Object{
        $scriptFile=$_.FullName
        $parserTokens=$null;$parserErrors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile,[ref]$parserTokens,[ref]$parserErrors)
        foreach($parseError in @($parserErrors)){$parseErrors.Add([pscustomobject]@{File=$scriptFile;Message=$parseError.Message;Extent=$parseError.Extent.Text})}
    }
    Assert-True 'PowerShell 5 parser accepts every runtime script' ($parseErrors.Count -eq 0) ($parseErrors.ToArray()|ConvertTo-Json -Depth 5 -Compress)

    Add-Type -AssemblyName System.Windows.Forms
    Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
    $composition=Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Full
    Assert-True 'Full runtime module composition succeeds' ([bool]$composition.Passed) ($composition|ConvertTo-Json -Depth 10 -Compress)
    Assert-True 'Runtime composition validates every cumulative dependency layer' (@($composition.Layers|Where-Object{-not [bool]$_.CumulativeCommandSurfacePassed}).Count -eq 0 -and @($composition.Layers).Count -eq [int]$composition.ModuleCount) ($composition|ConvertTo-Json -Depth 10 -Compress)
    foreach($requiredCommand in @('New-NyxCheckResult','New-NyxUnknownResult','Get-NyxStatusLabel','Get-NyxStatusSymbol','Get-NyxResultSummary')){
        Assert-True ("Shared model command remains available after full graph: {0}" -f $requiredCommand) ($null -ne (Get-Command -Name $requiredCommand -CommandType Function -ErrorAction SilentlyContinue))
    }
    $repeatComposition=Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Full
    Assert-True 'Repeated composition is idempotent and preserves command availability' ([bool]$repeatComposition.Passed -and $null -ne (Get-Command New-NyxCheckResult -CommandType Function -ErrorAction SilentlyContinue)) ($repeatComposition|ConvertTo-Json -Depth 10 -Compress)

    $healthy=Get-NyxResultSummary -Results @(
        (New-NyxCheckResult -CheckId 't1' -Category 'Test' -Name 'One' -Status Good),
        (New-NyxCheckResult -CheckId 't2' -Category 'Test' -Name 'Two' -Status Good)
    )
    Assert-True 'Healthy acceptance sentence is exact' ($healthy.Headline -eq 'Your PC looks good. Nothing needs fixing.') ([string]$healthy.Headline)
    Assert-True 'Needs Attention outranks other states' ((Get-NyxResultSummary -Results @((New-NyxCheckResult -CheckId a -Category t -Name a -Status Good),(New-NyxCheckResult -CheckId b -Category t -Name b -Status NeedsAttention))).OverallStatus -eq 'NeedsAttention')
    Assert-True 'All Unknown aggregates to Unknown' ((Get-NyxResultSummary -Results @((New-NyxCheckResult -CheckId a -Category t -Name a -Status Unknown))).OverallStatus -eq 'Unknown')

    $gb=[int64]1073741824
    Assert-True 'Thirty GB free is not automatically critical' ((Get-NyxStorageRuleResult -FreeBytes (30*$gb) -TotalBytes (500*$gb)).Status -eq 'Good')
    Assert-True 'Four GB free needs attention' ((Get-NyxStorageRuleResult -FreeBytes (4*$gb) -TotalBytes (500*$gb)).Status -eq 'NeedsAttention')
    Assert-True 'Zero-capacity storage becomes Unknown' ((Get-NyxStorageRuleResult -FreeBytes 0 -TotalBytes 0).Status -eq 'Unknown')
    Assert-True 'Fourteen-day uptime is Optional without pending restart' ((Get-NyxUptimeRuleResult -Days 14 -RestartPending $false).Status -eq 'Optional')
    Assert-True 'Pending restart plus long uptime needs attention' ((Get-NyxUptimeRuleResult -Days 8 -RestartPending $true).Status -eq 'NeedsAttention')
    Assert-True 'Ordinary battery aging remains Optional' ((Get-NyxBatteryRuleResult -HealthPercent 70).Status -eq 'Optional')
    Assert-True 'Severe battery wear needs attention' ((Get-NyxBatteryRuleResult -HealthPercent 40).Status -eq 'NeedsAttention')

    $oldUser=$env:USERNAME
    $secret="user=$oldUser ip=192.168.1.9 loop=::1 compressed=2001:db8::1 mapped=::ffff:192.0.2.128 token=abc123 password='my secret phrase' email=a@example.com authorization=Bearer xyz"
    $safe=Protect-NyxText -InputObject $secret
    Assert-True 'Privacy redaction removes username' (-not $safe.Contains($oldUser)) $safe
    Assert-True 'Privacy redaction removes IPv4 and compressed IPv6' (-not($safe.Contains('192.168.1.9') -or $safe.Contains('::1') -or $safe.Contains('2001:db8::1') -or $safe.Contains('::ffff:192.0.2.128'))) $safe
    Assert-True 'Privacy redaction removes token/password/authorization values' (-not($safe.Contains('abc123') -or $safe.Contains('my secret phrase') -or $safe.Contains('xyz'))) $safe
    Assert-True 'Privacy redaction removes email address' (-not $safe.Contains('a@example.com')) $safe

    $structuredSecret=[pscustomobject][ordered]@{
        Safe='visible'
        Password='multi word password'
        Nested=[pscustomobject][ordered]@{
            token='nested-token-value'
            Authorization='Bearer nested.authorization.value'
            connection_string='server=example;password=inside'
            Address='2001:db8::1'
        }
    }
    $privateObject=Protect-NyxObject -InputObject $structuredSecret
    $privateJson=$privateObject|ConvertTo-Json -Depth 12 -Compress
    Assert-True 'Structured privacy minimization redacts secret-bearing property roles before serialization' (-not($privateJson.Contains('multi word password') -or $privateJson.Contains('nested-token-value') -or $privateJson.Contains('nested.authorization.value') -or $privateJson.Contains('server=example') -or $privateJson.Contains('2001:db8::1'))) $privateJson
    Assert-True 'Structured privacy minimization preserves safe fields' ($privateJson.Contains('visible')) $privateJson

    $startupNoConfirm=Disable-NyxStartupApplication -Application ([pscustomobject]@{Enabled=$true})
    Assert-True 'Startup change without confirmation is rejected' ($startupNoConfirm.Status -eq 'ConfirmationRequired') ([string]$startupNoConfirm.Status)
    $cleanupNoConfirm=Invoke-NyxCleanup -CandidateIds @('not-a-candidate')
    Assert-True 'Cleanup without confirmation is rejected' ($cleanupNoConfirm.Status -eq 'ConfirmationRequired') ([string]$cleanupNoConfirm.Status)
    $boundaryRejected=$false
    try{[void](Test-NyxStartupStateBoundary -State ([pscustomobject]@{SourceType='Registry';SourcePath='HKCU:\Software\Bad';ValueName='x';RequiresElevation=$false;JournalScope='User';OwnerSid=[string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value}))}catch{$boundaryRejected=$true}
    Assert-True 'Startup registry path outside allowlist is rejected' $boundaryRejected

    $repaired=Repair-NyxConfiguration -Configuration ([pscustomobject]@{
        theme='UnsafeTheme';notificationsEnabled='not-a-boolean';developerLogging=$false;maxLogBytes=-50;maxLogFiles=999;
        actionHistoryLimit=0;reportIncludeUserName=$false;reportIncludeIpAddresses=$false;
        scan=[pscustomobject]@{maxFiles=999999999;maxSeconds=999999;duplicateHashMaxBytes=-1;duplicateHashMaxFiles=999999}
    })
    Assert-True 'Corrupt theme is repaired to FollowWindows' ([string]$repaired.theme -eq 'FollowWindows') ([string]$repaired.theme)
    Assert-True 'Invalid notification boolean is repaired to disabled' (-not [bool]$repaired.notificationsEnabled) ([string]$repaired.notificationsEnabled)
    Assert-True 'Configuration numeric bounds are enforced' ([int64]$repaired.maxLogBytes -eq 65536 -and [int64]$repaired.maxLogFiles -eq 10 -and [int64]$repaired.scan.maxFiles -eq 2000000 -and [int64]$repaired.scan.maxSeconds -eq 900) ($repaired|ConvertTo-Json -Depth 5 -Compress)
    Assert-True 'Update configuration defaults to weekly enabled' ([bool]$repaired.updates.enabled -and [string]::IsNullOrWhiteSpace([string]$repaired.updates.lastCheckUtc)) ($repaired.updates|ConvertTo-Json -Compress)

    $now=[DateTimeOffset]::Parse('2026-08-23T20:00:00Z')
    $schedule=[pscustomobject]@{updates=[pscustomobject]@{enabled=$true;lastCheckUtc=''}}
    Assert-True 'First automatic update check is due' (Test-NyxAutomaticUpdateCheckDue -Configuration $schedule -NowUtc $now)
    $schedule.updates.lastCheckUtc=$now.AddDays(-6).ToString('o')
    Assert-True 'Second automatic update check within seven days is suppressed' (-not(Test-NyxAutomaticUpdateCheckDue -Configuration $schedule -NowUtc $now))
    $schedule.updates.lastCheckUtc=$now.AddDays(-7).ToString('o')
    Assert-True 'Automatic update check at seven days is due' (Test-NyxAutomaticUpdateCheckDue -Configuration $schedule -NowUtc $now)
    $schedule.updates.enabled=$false
    Assert-True 'Disabled automatic update checks are respected' (-not(Test-NyxAutomaticUpdateCheckDue -Configuration $schedule -NowUtc $now))

    Assert-True 'Semantic version handles multi-digit components' ((Compare-NyxSemanticVersion -Left '1.10.0' -Right '1.9.0') -gt 0)
    Assert-True 'Semantic version orders release candidates correctly' ((Compare-NyxSemanticVersion -Left '1.0.0-rc.8' -Right '1.0.0-rc.9') -lt 0)
    Assert-True 'Stable version outranks prerelease' ((Compare-NyxSemanticVersion -Left '1.8.0' -Right '1.8.0-beta.2') -gt 0)
    $badVersionRejected=$false
    try{[void](ConvertTo-NyxSemanticVersion -Version '1.0.0-beta.01')}catch{$badVersionRejected=$true}
    Assert-True 'Malformed semantic version is rejected safely' $badVersionRejected

    $manifest=[pscustomobject][ordered]@{
        schema_version=1
        product='nyx-pc-checkup'
        latest_version='1.0.1'
        release_name='Nyx PC Checkup 1.0.1'
        release_channel='stable'
        published_at='2026-08-23T00:00:00Z'
        release_url='https://www.dietrichailabs.com/apps/nyx-pc-checkup/'
        download_url='https://www.dietrichailabs.com/downloads/'
        sha256=('A'*64)
        message='A new version of Nyx PC Checkup is available.'
        future_field='ignored'
    }
    $validatedManifest=ConvertTo-NyxValidatedUpdateManifest -Manifest $manifest
    Assert-True 'Valid official update manifest is accepted' ([string]$validatedManifest.Product -eq 'nyx-pc-checkup' -and [string]$validatedManifest.LatestVersion -eq '1.0.1') ($validatedManifest|ConvertTo-Json -Depth 6 -Compress)
    $wrongProductRejected=$false
    $wrongProduct=$manifest|Select-Object *;$wrongProduct.product='rangescout'
    try{[void](ConvertTo-NyxValidatedUpdateManifest -Manifest $wrongProduct)}catch{$wrongProductRejected=$true}
    Assert-True 'Wrong-product update manifest is rejected' $wrongProductRejected
    $booleanSchemaRejected=$false
    $booleanSchema=$manifest|Select-Object *;$booleanSchema.schema_version=$true
    try{[void](ConvertTo-NyxValidatedUpdateManifest -Manifest $booleanSchema)}catch{$booleanSchemaRejected=$true}
    Assert-True 'Boolean schema version is rejected as invalid metadata' $booleanSchemaRejected
    $badUrlRejected=$false
    $badUrl=$manifest|Select-Object *;$badUrl.release_url='https://evil.example/apps/nyx-pc-checkup/'
    try{[void](ConvertTo-NyxValidatedUpdateManifest -Manifest $badUrl)}catch{$badUrlRejected=$true}
    Assert-True 'Unapproved update destination is rejected' $badUrlRejected

    # Deterministic injected transport failures exercise the shipped catch and
    # validation paths without changing the compiled production endpoint.
    foreach($networkCase in @(
        [pscustomobject]@{Name='timeout';Status=[Net.WebExceptionStatus]::Timeout},
        [pscustomobject]@{Name='DNS failure';Status=[Net.WebExceptionStatus]::NameResolutionFailure},
        [pscustomobject]@{Name='TLS failure';Status=[Net.WebExceptionStatus]::TrustFailure},
        [pscustomobject]@{Name='HTTP 404';Status=[Net.WebExceptionStatus]::ProtocolError},
        [pscustomobject]@{Name='HTTP 500';Status=[Net.WebExceptionStatus]::ProtocolError}
    )){
        $simulatedException=New-Object Net.WebException -ArgumentList ("QA simulated $($networkCase.Name)"),$networkCase.Status
        $provider={throw $simulatedException}.GetNewClosure()
        $failureResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider $provider
        Assert-True ("Update checker safely contains $($networkCase.Name)") ([string]$failureResult.State -eq 'CHECK_FAILED' -and [string]$failureResult.ErrorCode -eq 'NETWORK_OR_TLS_FAILURE') ($failureResult|ConvertTo-Json -Depth 6 -Compress)
    }
    $invalidJsonResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider {return '{not json'}
    Assert-True 'Update checker safely rejects invalid JSON' ([string]$invalidJsonResult.State -eq 'CHECK_FAILED' -and [string]$invalidJsonResult.ErrorCode -eq 'INVALID_RESPONSE_OR_METADATA') ($invalidJsonResult|ConvertTo-Json -Depth 6 -Compress)
    $oversizeResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider {return 'x'.PadRight(65537,'x')}
    Assert-True 'Update checker safely rejects oversized response' ([string]$oversizeResult.State -eq 'CHECK_FAILED') ($oversizeResult|ConvertTo-Json -Depth 6 -Compress)
    $wrongProductJson=$wrongProduct|ConvertTo-Json -Depth 8 -Compress
    $wrongProductProvider={$wrongProductJson}.GetNewClosure()
    $wrongProductResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider $wrongProductProvider
    Assert-True 'Update checker safely rejects wrong-product JSON' ([string]$wrongProductResult.State -eq 'CHECK_FAILED') ($wrongProductResult|ConvertTo-Json -Depth 6 -Compress)
    $availableJson=$manifest|ConvertTo-Json -Depth 8 -Compress
    $availableProvider={$availableJson}.GetNewClosure()
    $availableResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider $availableProvider
    Assert-True 'Update checker reports a genuinely newer version' ([string]$availableResult.State -eq 'UPDATE_AVAILABLE') ($availableResult|ConvertTo-Json -Depth 8 -Compress)
    $sameManifest=$manifest|Select-Object *;$sameManifest.latest_version='1.0.0';$sameManifest.release_name='Nyx PC Checkup 1.0.0'
    $sameJson=$sameManifest|ConvertTo-Json -Depth 8 -Compress
    $sameProvider={$sameJson}.GetNewClosure()
    $sameResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider $sameProvider
    Assert-True 'Update checker reports installed version as up to date' ([string]$sameResult.State -eq 'UP_TO_DATE') ($sameResult|ConvertTo-Json -Depth 8 -Compress)
    $olderManifest=$manifest|Select-Object *;$olderManifest.latest_version='0.9.9';$olderManifest.release_name='Nyx PC Checkup 0.9.9'
    $olderJson=$olderManifest|ConvertTo-Json -Depth 8 -Compress
    $olderProvider={$olderJson}.GetNewClosure()
    $olderResult=Invoke-NyxUpdateCheck -Manual -TestManifestTextProvider $olderProvider
    Assert-True 'Update checker never offers a downgrade' ([string]$olderResult.State -eq 'UP_TO_DATE') ($olderResult|ConvertTo-Json -Depth 8 -Compress)

    # Manual update check: disable automatic checks and set a fresh timestamp,
    # then invoke the real isolated worker with -Manual 1. Any bounded result is
    # acceptable because the official manifest may intentionally be unpublished
    # before release approval; DISABLED and SKIPPED are not acceptable.
    $originalConfig=Get-NyxConfiguration
    $paths=Initialize-NyxDataDirectories
    $manualOutput=Join-Path $paths.Temp ('update-'+[guid]::NewGuid().ToString('N')+'-result.json')
    try{
        $manualConfig=Get-NyxConfiguration
        $manualConfig.updates.enabled=$false
        $manualConfig.updates.lastCheckUtc=(Get-Date).ToUniversalTime().ToString('o')
        Save-NyxConfiguration -Configuration $manualConfig
        $updateWorker=Join-Path $AppRoot 'workers\UpdateCheckWorker.ps1'
        $updateArgs="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$updateWorker`" -OutputPath `"$manualOutput`" -Manual 1"
        $updateProcess=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $updateArgs -WindowStyle Hidden -Wait -PassThru
        Assert-True 'Manual update worker exits cleanly' ($updateProcess.ExitCode -eq 0) ('ExitCode='+$updateProcess.ExitCode)
        Assert-True 'Manual update worker writes a bounded result' (Test-Path -LiteralPath $manualOutput -PathType Leaf)
        if(Test-Path -LiteralPath $manualOutput -PathType Leaf){
            $manualResult=Get-Content -LiteralPath $manualOutput -Raw -Encoding UTF8|ConvertFrom-Json
            Assert-True 'Manual update check bypasses disabled weekly schedule' ([bool]$manualResult.Manual -and [string]$manualResult.State -in @('UP_TO_DATE','UPDATE_AVAILABLE','CHECK_FAILED')) ($manualResult|ConvertTo-Json -Depth 8 -Compress)
            Assert-True 'Manual update result uses only official manifest endpoint' ([string]$manualResult.ManifestUrl -eq 'https://www.dietrichailabs.com/updates/nyx-pc-checkup.json') ([string]$manualResult.ManifestUrl)
        }
    }finally{
        Save-NyxConfiguration -Configuration $originalConfig
        Remove-Item -LiteralPath $manualOutput -Force -ErrorAction SilentlyContinue
    }

    # QA8-F-007 regression: force a legitimate zero-candidate cleanup result
    # by bounding traversal after one fresh temporary file. This exercises the
    # shipped Get-NyxCleanupCandidates result path under Windows PowerShell 5.1.
    $originalTemp=$env:TEMP
    $originalLocalAppData=$env:LOCALAPPDATA
    $zeroRoot=Join-Path $paths.Temp ('qa9-f007-zero-cleanup-'+[guid]::NewGuid().ToString('N'))
    $zeroTemp=Join-Path $zeroRoot 'Temp'
    try{
        New-Item -ItemType Directory -Path $zeroTemp -Force|Out-Null
        [IO.File]::WriteAllText((Join-Path $zeroTemp 'fresh.tmp'),'fresh',[Text.Encoding]::ASCII)
        $env:TEMP=$zeroTemp
        $env:LOCALAPPDATA=$zeroRoot
        $zeroCleanup=Get-NyxCleanupCandidates -Limit 10 -MaxVisitedFiles 1 -MaxSeconds 5
        Assert-True 'F-007 zero cleanup candidate set returns a valid result' ($null -ne $zeroCleanup -and @($zeroCleanup.Candidates).Count -eq 0) ($zeroCleanup|ConvertTo-Json -Depth 6 -Compress)
        Assert-True 'F-007 zero cleanup candidate set reports TotalBytes zero' ([int64]$zeroCleanup.TotalBytes -eq 0) ([string]$zeroCleanup.TotalBytes)
        Assert-True 'F-007 bounded zero cleanup stops without PropertyNotFoundException' ([string]$zeroCleanup.LimitReason -eq 'VisitedFileLimit') ([string]$zeroCleanup.LimitReason)
    }finally{
        $env:TEMP=$originalTemp
        $env:LOCALAPPDATA=$originalLocalAppData
        Remove-Item -LiteralPath $zeroRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Exercise the Downloads result-construction path with exact empty and
    # non-candidate collections inside the loaded shipped module. The helper is
    # private to the module; production callers still use Get-NyxDownloadsAnalysisCheck.
    $downloadsModule=@(Get-Module -Name DownloadsAnalysis -All|Select-Object -First 1)
    Assert-True 'F-007 DownloadsAnalysis module is loaded for private empty-state regression' ($downloadsModule.Count -eq 1)
    if($downloadsModule.Count -eq 1){
        $emptyDownloads=& $downloadsModule[0] {
            $empty=[System.Collections.Generic.List[object]]::new()
            New-NyxDownloadsAnalysisResult -Downloads 'C:\QA\EmptyDownloads' -Items $empty -Denied 0 -Cancelled $false
        }
        Assert-True 'F-007 empty Downloads returns a valid Good result' ([string]$emptyDownloads.Status -eq 'Good' -and [bool]$emptyDownloads.Complete) ($emptyDownloads|ConvertTo-Json -Depth 8 -Compress)
        Assert-True 'F-007 empty Downloads reports TotalBytes zero' ([int64]$emptyDownloads.Evidence.TotalBytes -eq 0) ([string]$emptyDownloads.Evidence.TotalBytes)
        $nonCandidateDownloads=& $downloadsModule[0] {
            $items=[System.Collections.Generic.List[object]]::new()
            $items.Add([pscustomobject]@{Path='C:\QA\EmptyDownloads\note.txt';Name='note.txt';Category='Document';SizeBytes=[int64]12;AgeDays=0;OlderThan30Days=$false;OlderThan90Days=$false;OlderThanOneYear=$false;LargerThan100MB=$false;LargerThan1GB=$false;CleanupCandidate=$false})
            New-NyxDownloadsAnalysisResult -Downloads 'C:\QA\EmptyDownloads' -Items $items -Denied 0 -Cancelled $false
        }
        Assert-True 'F-007 non-candidate-only Downloads remains Good' ([string]$nonCandidateDownloads.Status -eq 'Good') ($nonCandidateDownloads|ConvertTo-Json -Depth 8 -Compress)
        Assert-True 'F-007 non-candidate-only Downloads totals bytes without Measure-Object Sum' ([int64]$nonCandidateDownloads.Evidence.TotalBytes -eq 12) ([string]$nonCandidateDownloads.Evidence.TotalBytes)
    }

    $f007Revalidation=Invoke-NyxCleanup -CandidateIds @('qa9-f007-nonexistent-candidate') -Confirmed
    Assert-True 'F-007 cleanup action safety revalidation remains fail-closed' (-not [bool]$f007Revalidation.Success -and [string]$f007Revalidation.Status -eq 'Failed' -and @($f007Revalidation.Items|Where-Object{[bool]$_.Success}).Count -eq 0) ($f007Revalidation|ConvertTo-Json -Depth 8 -Compress)

    $boundedCleanup=Get-NyxCleanupCandidates -Limit 1 -MaxVisitedFiles 1 -MaxSeconds 1
    Assert-True 'Cleanup preview honors traversal bound' ([int]$boundedCleanup.VisitedFiles -le 1) ('VisitedFiles='+$boundedCleanup.VisitedFiles)
    Assert-True 'Cleanup preview candidates remain unselected by default' (@($boundedCleanup.Candidates|Where-Object{[bool]$_.SelectedByDefault}).Count -eq 0)
    Assert-True 'Cleanup preview exposes completeness and stop reason' ($null -ne $boundedCleanup.PSObject.Properties['Complete'] -and $null -ne $boundedCleanup.PSObject.Properties['LimitReason']) ($boundedCleanup|ConvertTo-Json -Depth 5 -Compress)

    $qaRunPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $qaStartupName='NyxPCCheckup_QA_'+[guid]::NewGuid().ToString('N')
    $qaStartupCommand='"'+(Join-Path $env:SystemRoot 'System32\notepad.exe')+'" --nyx-pc-checkup-rollback-test'
    $qaRollbackId=''
    try{
        if(-not(Test-Path -LiteralPath $qaRunPath)){New-Item -Path $qaRunPath -Force|Out-Null}
        New-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Value $qaStartupCommand -PropertyType String -Force|Out-Null
        $qaApp=@(Get-NyxStartupApplications|Where-Object{$_.SourcePath -eq $qaRunPath -and $_.ValueName -eq $qaStartupName -and $_.Enabled}|Select-Object -First 1)
        Assert-True 'Current-user QA startup entry is enumerated' ($qaApp.Count -eq 1)
        if($qaApp.Count -eq 1){
            $disabled=Disable-NyxStartupApplication -Application $qaApp[0] -Confirmed
            $qaRollbackId=[string]$disabled.ActionId
            Assert-True 'Current-user startup disable completes' ([bool]$disabled.Success -and [string]$disabled.Status -eq 'Completed') ($disabled|ConvertTo-Json -Depth 6 -Compress)
            $stillPresent=$true
            try{[void](Get-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -ErrorAction Stop)}catch{$stillPresent=$false}
            Assert-True 'Startup disable removes only the selected value' (-not $stillPresent)
            Assert-True 'Current-user rollback journal is active' (@(Get-NyxActiveStartupDisables|Where-Object{$_.ActionId -eq $qaRollbackId}).Count -eq 1)
            $restored=Enable-NyxStartupApplication -RollbackActionId $qaRollbackId -Confirmed
            Assert-True 'Current-user startup restore completes' ([bool]$restored.Success -and [string]$restored.Status -eq 'Completed') ($restored|ConvertTo-Json -Depth 6 -Compress)
            $actualCommand=(Get-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -ErrorAction Stop).($qaStartupName)
            Assert-True 'Startup restore preserves the exact command' ([string]$actualCommand -eq $qaStartupCommand) ([string]$actualCommand)
            Assert-True 'Successful restore closes active journal' (@(Get-NyxActiveStartupDisables|Where-Object{$_.ActionId -eq $qaRollbackId}).Count -eq 0)
            $qaRollbackId=''
        }
    }catch{
        Add-TestResult -Name 'Current-user startup rollback round trip completed without error' -Passed $false -Details $_.Exception.ToString()
    }finally{
        if($qaRollbackId){
            Remove-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Force -ErrorAction SilentlyContinue
            try{[void](Enable-NyxStartupApplication -RollbackActionId $qaRollbackId -Confirmed)}catch{}
        }
        Remove-ItemProperty -LiteralPath $qaRunPath -Name $qaStartupName -Force -ErrorAction SilentlyContinue
    }

    $paths=Initialize-NyxDataDirectories

    # QA11-F-010: persisted scan state is accepted only through one strict contract.
    $originalLastScan=$null
    if(Test-Path -LiteralPath $paths.LastScan -PathType Leaf){$originalLastScan=[IO.File]::ReadAllBytes($paths.LastScan)}
    try{
        [IO.File]::WriteAllText($paths.LastScan,'{invalid json',[Text.UTF8Encoding]::new($false))
        Assert-True 'F-010 invalid persisted JSON is ignored safely' ($null -eq (Get-NyxLastScan)) ''
        $validResult=New-NyxCheckResult -CheckId 'qa.f010' -Category 'System' -Name 'F-010 valid result' -Status 'Unknown' -Severity 'Info' -Finding 'No conclusion was fabricated.' -Reason 'Synthetic regression.' -Recommendation 'Run a new check.' -Complete $false
        $baseScan=[pscustomobject][ordered]@{Schema='dietrich-ai-labs.nyx-pc-checkup.scan.v1';Mode='Full';StartedUtc=(Get-Date).ToUniversalTime().ToString('o');CompletedUtc=(Get-Date).ToUniversalTime().ToString('o');Cancelled=$true;ReadOnly=$true;Summary=$null;Results=@($validResult)}
        $cases=@(
            [pscustomobject]@{Name='unsupported schema';Value=([pscustomobject]@{Schema='unsupported';Mode='Full';StartedUtc='x';CompletedUtc='x';Cancelled=$true;ReadOnly=$true;Results=@($validResult)})},
            [pscustomobject]@{Name='missing Results';Value=([pscustomobject]@{Schema=$baseScan.Schema;Mode='Full';StartedUtc='x';CompletedUtc='x';Cancelled=$true;ReadOnly=$true})},
            [pscustomobject]@{Name='null Results';Value=([pscustomobject]@{Schema=$baseScan.Schema;Mode='Full';StartedUtc='x';CompletedUtc='x';Cancelled=$true;ReadOnly=$true;Results=$null})},
            [pscustomobject]@{Name='empty Results';Value=([pscustomobject]@{Schema=$baseScan.Schema;Mode='Full';StartedUtc='x';CompletedUtc='x';Cancelled=$true;ReadOnly=$true;Results=@()})}
        )
        foreach($case in $cases){$case.Value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $paths.LastScan -Encoding UTF8;Assert-True ("F-010 {0} is ignored safely" -f $case.Name) ($null -eq (Get-NyxLastScan)) ''}
        foreach($missing in @('Status','Category','CheckId','Finding','Reason','Recommendation','Complete')){
            $bad=[ordered]@{};foreach($property in $validResult.PSObject.Properties){if($property.Name -ne $missing){$bad[$property.Name]=$property.Value}}
            $scan=$baseScan.PSObject.Copy();$scan.Results=@([pscustomobject]$bad);$scan|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $paths.LastScan -Encoding UTF8
            Assert-True ("F-010 result missing {0} is ignored safely" -f $missing) ($null -eq (Get-NyxLastScan)) ''
        }
        $badStatus=$validResult.PSObject.Copy();$badStatus.Status='Healthy';$scan=$baseScan.PSObject.Copy();$scan.Results=@($badStatus);$scan|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $paths.LastScan -Encoding UTF8
        Assert-True 'F-010 unsupported result Status is ignored safely' ($null -eq (Get-NyxLastScan)) ''
        $baseScan|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $paths.LastScan -Encoding UTF8;$loaded=Get-NyxLastScan
        Assert-True 'F-010 valid partial cancelled scan loads safely' ($null -ne $loaded -and $loaded -isnot [array] -and [string]$loaded.Results[0].Status -eq 'Unknown' -and -not [bool]$loaded.Results[0].Complete) ($loaded|ConvertTo-Json -Depth 8 -Compress)
        $producerFallback=Convert-NyxScanResult -Result ([pscustomobject]@{Finding='incomplete'}) -FallbackCheckId 'qa.f010.producer' -FallbackCategory 'System' -FallbackName 'Producer fallback' -NormalizeInvalid
        Assert-True 'F-010 malformed producer output normalizes to honest Unknown' ([string]$producerFallback.Status -eq 'Unknown' -and -not [bool]$producerFallback.Complete) ($producerFallback|ConvertTo-Json -Compress)
    }finally{
        if($null -eq $originalLastScan){Remove-Item -LiteralPath $paths.LastScan -Force -ErrorAction SilentlyContinue}else{[IO.File]::WriteAllBytes($paths.LastScan,$originalLastScan)}
    }

    # QA10-F-009 regression: optional cleanup must tolerate empty paths and
    # must never delete a lookalike path outside the exact Nyx temp root.
    $f009Id=[guid]::NewGuid().ToString('N')
    $f009Inside=Join-Path $paths.Temp ("update-$f009Id-result.json")
    $f009Outside=Join-Path $paths.Root ("update-$f009Id-result.json")
    [IO.File]::WriteAllText($f009Inside,'inside',[Text.Encoding]::ASCII)
    [IO.File]::WriteAllText($f009Outside,'outside',[Text.Encoding]::ASCII)
    $f009Cleanup=Remove-NyxTemporaryArtifacts -Path @('', $null, '   ', $f009Inside, $f009Outside)
    Assert-True 'F-009 optional temp cleanup accepts empty path fields without throwing' ([int]$f009Cleanup.EmptySkipped -eq 3) ($f009Cleanup|ConvertTo-Json -Compress)
    Assert-True 'F-009 optional temp cleanup deletes an allowed Nyx temp file' (-not(Test-Path -LiteralPath $f009Inside -PathType Leaf)) ($f009Cleanup|ConvertTo-Json -Compress)
    Assert-True 'F-009 optional temp cleanup rejects a lookalike path outside Nyx temp' (Test-Path -LiteralPath $f009Outside -PathType Leaf) ($f009Cleanup|ConvertTo-Json -Compress)
    Assert-True 'F-009 optional temp cleanup records the rejected outside path' ([int]$f009Cleanup.UnsafeRejected -ge 1) ($f009Cleanup|ConvertTo-Json -Compress)
    Remove-Item -LiteralPath $f009Outside -Force -ErrorAction SilentlyContinue

    $pdf=Join-Path $paths.Temp ('smoke-'+[guid]::NewGuid().ToString('N')+'.pdf')
    Write-NyxSimplePdf -Path $pdf -Lines @('Nyx PC Checkup',('Unicode is safely normalized: caf'+[char]0x00E9))
    $bytes=[IO.File]::ReadAllBytes($pdf)
    $header=[Text.Encoding]::ASCII.GetString($bytes,0,[Math]::Min(5,$bytes.Length))
    Assert-True 'PDF writer creates a PDF header' ($header -eq '%PDF-') $header
    Remove-Item -LiteralPath $pdf -Force -ErrorAction SilentlyContinue

    $fake=[pscustomobject]@{
        Mode='Quick';StartedUtc=(Get-Date).ToUniversalTime().ToString('o');CompletedUtc=(Get-Date).ToUniversalTime().ToString('o');Summary=$healthy
        Password='report password value'
        Results=@((New-NyxCheckResult -CheckId 'network.basics' -Category Network -Name Network -Status Good -Evidence ([pscustomobject]@{Adapters=@();Profiles=@();DnsResolutionSucceeded=$true;token='report-token';Authorization='Bearer report.auth'}) -Finding $secret -Reason $secret -Recommendation $secret))
    }
    $reportJson=(New-NyxSafeReport -Scan $fake|ConvertTo-Json -Depth 15)
    Assert-True 'Export report redacts injected structured secrets and address forms' (-not($reportJson.Contains('192.168.1.9') -or $reportJson.Contains('2001:db8::1') -or $reportJson.Contains('abc123') -or $reportJson.Contains('my secret phrase') -or $reportJson.Contains('report password value') -or $reportJson.Contains('report-token') -or $reportJson.Contains('report.auth') -or $reportJson.Contains('a@example.com'))) $reportJson

    $previousAcceptance=$env:NYX_PC_CHECKUP_ACCEPTANCE
    try{
        $env:NYX_PC_CHECKUP_ACCEPTANCE='1'
        foreach($probeNumber in @(1,2)){
            $probePath=Join-Path (Split-Path -Parent $OutputPath) ("Nyx_PC_Checkup_App_Probe_{0}.json" -f $probeNumber)
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
            $appScript=Join-Path $AppRoot 'NyxPCCheckup.ps1'
            $probeArgs="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$appScript`" -AcceptanceProbe -AcceptanceOutputPath `"$probePath`""
            $probeProcess=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $probeArgs -WindowStyle Hidden -Wait -PassThru
            Assert-True ("Real application acceptance launch {0} exits successfully" -f $probeNumber) ($probeProcess.ExitCode -eq 0) ('ExitCode='+$probeProcess.ExitCode)
            Assert-True ("Real application acceptance launch {0} writes evidence" -f $probeNumber) (Test-Path -LiteralPath $probePath -PathType Leaf)
            if(Test-Path -LiteralPath $probePath -PathType Leaf){
                $probeReport=Get-Content -LiteralPath $probePath -Raw -Encoding UTF8|ConvertFrom-Json
                Assert-True ("Real application acceptance launch {0} loads the full module graph" -f $probeNumber) ([bool]$probeReport.Passed -and [bool]$probeReport.Composition.Passed) ($probeReport|ConvertTo-Json -Depth 12 -Compress)
                Assert-True ("Real application acceptance launch {0} completes a real Quick Check" -f $probeNumber) ([int]$probeReport.QuickCheck.ResultCount -ge 8 -and [bool]$probeReport.QuickCheck.ReadOnly) ($probeReport|ConvertTo-Json -Depth 12 -Compress)
            }
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        }

        # Exercise the actual WinForms Shown -> FormClosing path twice. The
        # first run has automatic updates disabled; the second enables/due-checks
        # updates so close occurs while optional update output may still be empty.
        $originalConfiguration=Get-NyxConfiguration
        $originalConfigurationJson=$originalConfiguration|ConvertTo-Json -Depth 12 -Compress
        foreach($closeProbe in @(
            [pscustomobject]@{Number=3;UpdatesEnabled=$false;Label='updates disabled'},
            [pscustomobject]@{Number=4;UpdatesEnabled=$true;Label='updates enabled before output exists'}
        )){
            $probeConfiguration=$originalConfigurationJson|ConvertFrom-Json
            $probeConfiguration.updates.enabled=[bool]$closeProbe.UpdatesEnabled
            if([bool]$closeProbe.UpdatesEnabled){$probeConfiguration.updates.lastCheckUtc=$null}
            Save-NyxConfiguration -Configuration $probeConfiguration
            $probePath=Join-Path (Split-Path -Parent $OutputPath) ("Nyx_PC_Checkup_App_Probe_{0}.json" -f $closeProbe.Number)
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
            $appScript=Join-Path $AppRoot 'NyxPCCheckup.ps1'
            $probeArgs="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$appScript`" -AcceptanceProbe -AcceptanceUiCloseProbe -AcceptanceOutputPath `"$probePath`""
            $probeProcess=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $probeArgs -WindowStyle Hidden -Wait -PassThru
            Assert-True ("F-009 real UI close probe ({0}) exits cleanly" -f $closeProbe.Label) ($probeProcess.ExitCode -eq 0) ('ExitCode='+$probeProcess.ExitCode)
            Assert-True ("F-009 real UI close probe ({0}) writes terminal evidence" -f $closeProbe.Label) (Test-Path -LiteralPath $probePath -PathType Leaf)
            if(Test-Path -LiteralPath $probePath -PathType Leaf){
                $probeReport=Get-Content -LiteralPath $probePath -Raw -Encoding UTF8|ConvertFrom-Json
                Assert-True ("F-009 real UI close probe ({0}) reports UiClose PASS" -f $closeProbe.Label) ([bool]$probeReport.Passed -and [string]$probeReport.ProbeKind -eq 'UiClose') ($probeReport|ConvertTo-Json -Depth 12 -Compress)
            }
            Remove-Item -LiteralPath $probePath -Force -ErrorAction SilentlyContinue
        }
        Save-NyxConfiguration -Configuration ($originalConfigurationJson|ConvertFrom-Json)
    }finally{
        if($null -eq $previousAcceptance){Remove-Item Env:\NYX_PC_CHECKUP_ACCEPTANCE -ErrorAction SilentlyContinue}else{$env:NYX_PC_CHECKUP_ACCEPTANCE=$previousAcceptance}
    }

    $before=Get-RunKeySnapshot
    $sentinel=Join-Path $paths.Temp ('scan-sentinel-'+[guid]::NewGuid().ToString('N')+'.txt')
    [IO.File]::WriteAllText($sentinel,'Nyx scan must not modify this file',[Text.Encoding]::UTF8)
    $sentinelHash=(Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash
    $id=[guid]::NewGuid().ToString('N')
    $out=Join-Path $paths.Temp ("scan-$id.json")
    $progress=Join-Path $paths.Temp ("scan-$id-progress.jsonl")
    $cancel=Join-Path $paths.Temp ("scan-$id.cancel")
    $worker=Join-Path $AppRoot 'workers\ScanWorker.ps1'
    $args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" -Mode Quick -OutputPath `"$out`" -ProgressPath `"$progress`" -CancelPath `"$cancel`""
    $proc=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WindowStyle Hidden -Wait -PassThru
    Assert-True 'Quick scan worker exits successfully' ($proc.ExitCode -eq 0) ('ExitCode='+$proc.ExitCode)
    Assert-True 'Quick scan produced a result file' (Test-Path -LiteralPath $out -PathType Leaf)
    if(Test-Path -LiteralPath $out -PathType Leaf){
        $scan=Get-Content -LiteralPath $out -Raw -Encoding UTF8|ConvertFrom-Json
        Assert-True 'Scan envelope is explicitly read-only' ([bool]$scan.ReadOnly)
        Assert-True 'Quick scan returned results' (@($scan.Results).Count -ge 8) ('Count='+@($scan.Results).Count)
        Assert-True 'Quick scan status values are valid' (@($scan.Results|Where-Object{$_.Status -notin @('Good','NeedsAttention','Optional','Unknown')}).Count -eq 0)
        Assert-True 'Every result has explanation fields' (@($scan.Results|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.CheckId) -or [string]::IsNullOrWhiteSpace([string]$_.Finding) -or [string]::IsNullOrWhiteSpace([string]$_.Reason) -or [string]::IsNullOrWhiteSpace([string]$_.Recommendation)}).Count -eq 0)
        Assert-True 'Quick scan had no worker-level fatal error' ($null -eq $scan.PSObject.Properties['WorkerError'])
    }
    $after=Get-RunKeySnapshot
    Assert-True 'Quick scan did not modify supported startup registry keys' ($before -eq $after)
    Assert-True 'Quick scan did not modify sentinel file' ((Get-FileHash -LiteralPath $sentinel -Algorithm SHA256).Hash -eq $sentinelHash)
    Remove-Item -LiteralPath $out,$progress,$cancel,$sentinel -Force -ErrorAction SilentlyContinue
}catch{
    Add-TestResult -Name 'Smoke test harness completed without unhandled error' -Passed $false -Details $_.Exception.ToString()
}

$stopped=(Get-Date).ToUniversalTime()
$report=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.windows-smoke.v2'
    HarnessRevision='QA26-F023-PS51-26'
    Scope='normal-user smoke and privacy/update'
    StartedUtc=$started.ToString('o')
    CompletedUtc=$stopped.ToString('o')
    ElapsedSeconds=[math]::Round(($stopped-$started).TotalSeconds,3)
    ComputerName=$env:COMPUTERNAME
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    IsAdministrator=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    AppRoot=$AppRoot
    Passed=($script:Failures -eq 0)
    Total=$script:Results.Count
    Failed=$script:Failures
    Results=@($script:Results.ToArray())
}
$report|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Windows smoke/privacy/update tests: {0}/{1} passed. Evidence: {2}" -f ($report.Total-$report.Failed),$report.Total,$OutputPath)
if($script:Failures -gt 0){exit 1}
exit 0

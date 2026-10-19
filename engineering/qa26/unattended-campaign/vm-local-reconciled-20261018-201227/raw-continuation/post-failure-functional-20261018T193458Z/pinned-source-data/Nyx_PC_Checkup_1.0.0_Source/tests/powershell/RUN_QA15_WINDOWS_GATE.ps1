[CmdletBinding()]
param(
    [ValidateSet('Smoke','Standard','Elevated')]
    [string]$Phase = 'Smoke',
    [switch]$DestructiveCleanVmAcknowledged,
    [string]$HandoffRoot = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if($env:OS -ne 'Windows_NT'){throw 'This QA13 gate runner requires native Windows.'}
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Run this orchestrator with inbox Windows PowerShell 5.1 Desktop edition.'}

$script:ExpectedBuild='2026.10.02-eng-qa26'
$script:ExpectedHarnessRevision='QA26-F023-PS51-26'
$script:RunResults=[System.Collections.Generic.List[object]]::new()
$script:RunnerFailures=[System.Collections.Generic.List[string]]::new()

function Get-ManifestEntry {
    param([Parameter(Mandatory=$true)][object]$Manifest,[Parameter(Mandatory=$true)][string]$RelativePath)
    $entry=@($Manifest.files|Where-Object{[string]$_.path -eq $RelativePath}|Select-Object -First 1)
    if($entry.Count -ne 1){throw ("Manifest entry is missing or ambiguous: {0}" -f $RelativePath)}
    return $entry[0]
}

function Assert-ManifestFile {
    param([Parameter(Mandatory=$true)][object]$Manifest,[Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$RelativePath)
    $entry=Get-ManifestEntry -Manifest $Manifest -RelativePath $RelativePath
    $path=Join-Path $Root ($RelativePath -replace '/','\')
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ("Required handoff file is missing: {0}" -f $RelativePath)}
    $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if([int64]$item.Length -ne [int64]$entry.size){throw ("Size mismatch for {0}" -f $RelativePath)}
    $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
    if($actual -ne [string]$entry.sha256){throw ("SHA-256 mismatch for {0}" -f $RelativePath)}
    return $path
}

if([string]::IsNullOrWhiteSpace($HandoffRoot)){
    if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'MASTER_MANIFEST.json') -PathType Leaf){
        $HandoffRoot=$PSScriptRoot
    }else{
        $HandoffRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    }
}
$HandoffRoot=(Resolve-Path -LiteralPath $HandoffRoot).Path
$manifestPath=Join-Path $HandoffRoot 'MASTER_MANIFEST.json'
if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'MASTER_MANIFEST.json is missing. Run this script from the extracted QA15 Engineering master handoff.'}
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
if([string]$manifest.build -ne $script:ExpectedBuild){throw ("Unexpected handoff build: {0}" -f [string]$manifest.build)}

$setup=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'candidate/Nyx_PC_Checkup_1.0.0_Setup.exe'
$portable=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'candidate/Nyx_PC_Checkup_1.0.0_Portable.zip'
$sourceZip=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'source/Nyx_PC_Checkup_1.0.0_Source.zip'
$qa2Setup=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'tests/fixtures/qa2/Nyx_PC_Checkup_1.0.0_QA2_Setup.exe'
$qa2Source=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'tests/fixtures/qa2/Nyx_PC_Checkup_1.0.0_QA2_Source.zip'
$harnessNames=@(
    'Run-WindowsSmokeTests.ps1',
    'Run-WindowsElevatedStartupRollback.ps1',
    'Run-WindowsQA2MigrationRegression.ps1',
    'Run-WindowsInstallerLifecycle.ps1',
    'Run-WindowsInstalledLaunchRegression.ps1'
)
$harnessPaths=@{}
foreach($name in $harnessNames){
    $relative='tests/powershell/'+$name
    $harnessPaths[$name]=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath $relative
}
$nestedRunner=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'tests/powershell/RUN_QA15_WINDOWS_GATE.ps1'
$installerDiagnosticsHelper=Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'tests/powershell/InstallerDiagnosticsHelpers.ps1'
if(Test-Path -LiteralPath (Join-Path $HandoffRoot 'RUN_QA15_WINDOWS_GATE.ps1') -PathType Leaf){
    [void](Assert-ManifestFile -Manifest $manifest -Root $HandoffRoot -RelativePath 'RUN_QA15_WINDOWS_GATE.ps1')
}

$isAdmin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if($Phase -eq 'Standard'){
    if(-not $DestructiveCleanVmAcknowledged){throw 'Standard phase modifies disposable installer and rollback fixtures. Pass -DestructiveCleanVmAcknowledged only on a clean disposable Windows snapshot.'}
    if($isAdmin){throw 'Standard phase must run from a non-elevated Windows user session.'}
}
if($Phase -eq 'Elevated'){
    if(-not $DestructiveCleanVmAcknowledged){throw 'Elevated phase modifies isolated ProgramData and installer fixtures. Pass -DestructiveCleanVmAcknowledged only on a clean disposable Windows snapshot.'}
    if(-not $isAdmin){throw 'Elevated phase must run from an elevated Windows PowerShell 5.1 session.'}
}

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$work=Join-Path $env:TEMP ("Nyx_PC_Checkup_QA14_Windows_{0}_{1}" -f $Phase,$stamp)
$sourceExtract=Join-Path $work 'source'
$evidence=Join-Path $HandoffRoot ("QA15_WINDOWS_EVIDENCE_{0}_{1}" -f $Phase,$stamp)
New-Item -ItemType Directory -Path $sourceExtract,$evidence -Force|Out-Null
Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourceExtract -Force
$sourceIdentity=Get-ChildItem -LiteralPath $sourceExtract -Filter 'SOURCE_TREE_IDENTITY.json' -File -Recurse -ErrorAction Stop|Select-Object -First 1
if($null -eq $sourceIdentity){throw 'SOURCE_TREE_IDENTITY.json was not found after extracting the QA14 source ZIP.'}
$sourceRoot=$sourceIdentity.Directory.FullName
$appRoot=Join-Path $sourceRoot 'src\app'
if(-not(Test-Path -LiteralPath $appRoot -PathType Container)){throw ("Source app root is missing: {0}" -f $appRoot)}

$environment=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.qa14-windows-orchestration.v1'
    Phase=$Phase
    HarnessRevision=$script:ExpectedHarnessRevision
    CapturedUtc=(Get-Date).ToUniversalTime().ToString('o')
    ComputerName=$env:COMPUTERNAME
    WindowsVersion=[Environment]::OSVersion.VersionString
    PowerShellVersion=$PSVersionTable.PSVersion.ToString()
    PSEdition=$PSVersionTable.PSEdition
    IsAdministrator=$isAdmin
    Build=$script:ExpectedBuild
    SetupSha256=(Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
    PortableSha256=(Get-FileHash -LiteralPath $portable -Algorithm SHA256).Hash
    SourceSha256=(Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash
    QA2SetupSha256=(Get-FileHash -LiteralPath $qa2Setup -Algorithm SHA256).Hash
    QA2SourceSha256=(Get-FileHash -LiteralPath $qa2Source -Algorithm SHA256).Hash
    NestedRunnerSha256=(Get-FileHash -LiteralPath $nestedRunner -Algorithm SHA256).Hash
    InstallerDiagnosticsHelperSha256=(Get-FileHash -LiteralPath $installerDiagnosticsHelper -Algorithm SHA256).Hash
    AppRoot=$appRoot
}
$environment|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $evidence 'environment.json') -Encoding UTF8

function Invoke-PowerShellParsePreflight {
    param([Parameter(Mandatory=$true)][string]$RuntimeRoot)
    $files=[System.Collections.Generic.List[string]]::new()
    foreach($item in @(Get-ChildItem -LiteralPath $RuntimeRoot -Recurse -File -ErrorAction Stop|Where-Object{$_.Extension -in @('.ps1','.psm1')}|Sort-Object FullName)){
        $files.Add($item.FullName)
    }
    foreach($name in $harnessNames){$files.Add([string]$harnessPaths[$name])}
    $files.Add([string]$nestedRunner)
    $files.Add([string]$installerDiagnosticsHelper)

    $findings=[System.Collections.Generic.List[object]]::new()
    $fileRecords=[System.Collections.Generic.List[object]]::new()
    foreach($file in $files.ToArray()){
        $parserTokens=$null
        $parserDiagnostics=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$parserTokens,[ref]$parserDiagnostics)
        $diagnosticCount=@($parserDiagnostics).Count
        $fileRecords.Add([pscustomobject][ordered]@{
            File=$file
            Sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
            DiagnosticCount=$diagnosticCount
        })
        foreach($diagnostic in @($parserDiagnostics)){
            $findings.Add([pscustomobject][ordered]@{
                File=$file
                Message=$diagnostic.Message
                Text=$diagnostic.Extent.Text
                StartLine=$diagnostic.Extent.StartLineNumber
                StartColumn=$diagnostic.Extent.StartColumnNumber
            })
        }
    }
    $preflight=[pscustomobject][ordered]@{
        Schema='dietrich-ai-labs.nyx-pc-checkup.qa14-powershell51-parse-preflight.v1'
        Build=$script:ExpectedBuild
        HarnessRevision=$script:ExpectedHarnessRevision
        CapturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        PowerShellVersion=$PSVersionTable.PSVersion.ToString()
        PSEdition=$PSVersionTable.PSEdition
        Passed=($findings.Count -eq 0)
        FileCount=$fileRecords.Count
        DiagnosticCount=$findings.Count
        Files=@($fileRecords.ToArray())
        Diagnostics=@($findings.ToArray())
    }
    $preflightPath=Join-Path $evidence 'QA15_WINDOWS_PARSE_PREFLIGHT.json'
    $preflight|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $preflightPath -Encoding UTF8
    return $preflight
}

function Invoke-ExactHarness {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$ExpectedReportPath,
        [string[]]$ArgumentList=@()
    )
    $scriptPath=[string]$harnessPaths[$Name]
    $console=Join-Path $evidence (($Name -replace '\.ps1$','')+'_console.txt')
    $oldPreference=$ErrorActionPreference
    $captured=@()
    $exitCode=999
    $launchError=''
    try{
        $ErrorActionPreference='Continue'
        $captured=@(& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File $scriptPath @ArgumentList 2>&1)
        $exitCode=$LASTEXITCODE
    }catch{
        $launchError=$_.Exception.ToString()
        $captured+=('ORCHESTRATOR CAUGHT: '+$launchError)
    }finally{
        $ErrorActionPreference=$oldPreference
    }
    $captured|Out-File -LiteralPath $console -Encoding Unicode -Force

    $reportExists=Test-Path -LiteralPath $ExpectedReportPath -PathType Leaf
    $reportRevision=''
    $reportPassed=$false
    $reportFailed=-1
    $reportTotal=-1
    $reportValidationError=''
    if(-not $reportExists){
        $reportValidationError='Expected harness JSON report was not created.'
    }else{
        try{
            $report=Get-Content -LiteralPath $ExpectedReportPath -Raw -Encoding UTF8|ConvertFrom-Json
            if($null -eq $report.PSObject.Properties['HarnessRevision']){throw 'HarnessRevision is missing.'}
            $reportRevision=[string]$report.HarnessRevision
            if($reportRevision -ne $script:ExpectedHarnessRevision){throw ("Unexpected HarnessRevision: {0}" -f $reportRevision)}
            if($null -eq $report.PSObject.Properties['Passed']){throw 'Passed is missing.'}
            if($null -eq $report.PSObject.Properties['Failed']){throw 'Failed is missing.'}
            if($null -eq $report.PSObject.Properties['Total']){throw 'Total is missing.'}
            $reportPassed=[bool]$report.Passed
            $reportFailed=[int]$report.Failed
            $reportTotal=[int]$report.Total
            if($reportTotal -lt 1){throw 'Harness report contains no executed assertions.'}
            if($reportFailed -lt 0 -or $reportFailed -gt $reportTotal){throw 'Harness Failed/Total values are invalid.'}
            if(-not $reportPassed){$reportValidationError='Harness report verdict is FAIL.'}
            elseif($reportFailed -ne 0){$reportValidationError='Harness report says Passed but Failed is nonzero.'}
        }catch{
            $reportValidationError=$_.Exception.Message
        }
    }

    $passed=($exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($launchError) -and [string]::IsNullOrWhiteSpace($reportValidationError) -and $reportPassed)
    $script:RunResults.Add([pscustomobject][ordered]@{
        Harness=$Name
        ExactHarnessSha256=(Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash
        ExitCode=$exitCode
        Passed=$passed
        LaunchError=$launchError
        ConsoleLog=$console
        ReportPath=$ExpectedReportPath
        ReportExists=$reportExists
        ReportRevision=$reportRevision
        ReportPassed=$reportPassed
        ReportFailed=$reportFailed
        ReportTotal=$reportTotal
        ReportValidationError=$reportValidationError
    })
}

$parsePreflight=$null
try{
    $parsePreflight=Invoke-PowerShellParsePreflight -RuntimeRoot $appRoot
    if(-not [bool]$parsePreflight.Passed){
        $script:RunnerFailures.Add(("Windows PowerShell 5.1 parse preflight failed with {0} diagnostic(s)." -f [int]$parsePreflight.DiagnosticCount))
    }elseif($Phase -eq 'Smoke'){
        $out=Join-Path $evidence 'Nyx_PC_Checkup_Windows_Smoke.json'
        Invoke-ExactHarness -Name 'Run-WindowsSmokeTests.ps1' -ExpectedReportPath $out -ArgumentList @('-AppRoot',$appRoot,'-OutputPath',$out)
    }elseif($Phase -eq 'Standard'){
        $smokeOut=Join-Path $evidence 'Nyx_PC_Checkup_Windows_Smoke.json'
        Invoke-ExactHarness -Name 'Run-WindowsSmokeTests.ps1' -ExpectedReportPath $smokeOut -ArgumentList @('-AppRoot',$appRoot,'-OutputPath',$smokeOut)

        $privOut=Join-Path $evidence 'Nyx_PC_Checkup_Privilege_Standard.json'
        Invoke-ExactHarness -Name 'Run-WindowsElevatedStartupRollback.ps1' -ExpectedReportPath $privOut -ArgumentList @('-AppRoot',$appRoot,'-OutputPath',$privOut)

        $migrationOut=Join-Path $evidence 'Nyx_PC_Checkup_QA2_Migration.json'
        Invoke-ExactHarness -Name 'Run-WindowsQA2MigrationRegression.ps1' -ExpectedReportPath $migrationOut -ArgumentList @('-QA2SetupPath',$qa2Setup,'-CorrectedSetupPath',$setup,'-OutputPath',$migrationOut,'-DestructiveCleanVmAcknowledged')

        $lifeOut=Join-Path $evidence 'Nyx_PC_Checkup_Installer_Lifecycle_Standard.json'
        Invoke-ExactHarness -Name 'Run-WindowsInstallerLifecycle.ps1' -ExpectedReportPath $lifeOut -ArgumentList @('-SetupPath',$setup,'-OutputPath',$lifeOut,'-DestructiveCleanVmAcknowledged')

        # QA12-F-011: validate the actual installed desktop shortcut/native launcher,
        # visible main window, singleton behavior, clean close, and fresh relaunch.
        $launchOut=Join-Path $evidence 'Nyx_PC_Checkup_F011_Installed_Launch.json'
        Invoke-ExactHarness -Name 'Run-WindowsInstalledLaunchRegression.ps1' -ExpectedReportPath $launchOut -ArgumentList @('-SetupPath',$setup,'-OutputPath',$launchOut,'-DestructiveCleanVmAcknowledged')
    }else{
        $privOut=Join-Path $evidence 'Nyx_PC_Checkup_Privilege_Elevated.json'
        Invoke-ExactHarness -Name 'Run-WindowsElevatedStartupRollback.ps1' -ExpectedReportPath $privOut -ArgumentList @('-AppRoot',$appRoot,'-OutputPath',$privOut,'-DestructiveCleanVmAcknowledged')

        $lifeOut=Join-Path $evidence 'Nyx_PC_Checkup_Installer_Lifecycle_Elevated.json'
        Invoke-ExactHarness -Name 'Run-WindowsInstallerLifecycle.ps1' -ExpectedReportPath $lifeOut -ArgumentList @('-SetupPath',$setup,'-OutputPath',$lifeOut,'-DestructiveCleanVmAcknowledged')
    }
}catch{
    $script:RunnerFailures.Add($_.Exception.ToString())
}

$failed=@($script:RunResults.ToArray()|Where-Object{-not $_.Passed})
$parsePassed=($null -ne $parsePreflight -and [bool]$parsePreflight.Passed)
$summary=[pscustomobject][ordered]@{
    Schema='dietrich-ai-labs.nyx-pc-checkup.qa14-windows-run-summary.v1'
    Build=$script:ExpectedBuild
    HarnessRevision=$script:ExpectedHarnessRevision
    Phase=$Phase
    CompletedUtc=(Get-Date).ToUniversalTime().ToString('o')
    ParsePreflightPassed=$parsePassed
    ParsePreflightReport=(Join-Path $evidence 'QA15_WINDOWS_PARSE_PREFLIGHT.json')
    Passed=($parsePassed -and $failed.Count -eq 0 -and $script:RunnerFailures.Count -eq 0 -and $script:RunResults.Count -gt 0)
    Total=$script:RunResults.Count
    Failed=$failed.Count
    RunnerFailures=@($script:RunnerFailures.ToArray())
    Results=@($script:RunResults.ToArray())
}
$summary|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $evidence 'QA15_WINDOWS_RUN_SUMMARY.json') -Encoding UTF8

$zipPath=$evidence+'.zip'
if(Test-Path -LiteralPath $zipPath){Remove-Item -LiteralPath $zipPath -Force}
Compress-Archive -LiteralPath $evidence -DestinationPath $zipPath -CompressionLevel Optimal
Write-Host ("QA11 Windows evidence ZIP: {0}" -f $zipPath)
Write-Host ("Runner verdict: {0}" -f $(if($summary.Passed){'PASS'}else{'FAIL'}))
if(-not $summary.Passed){exit 1}
exit 0

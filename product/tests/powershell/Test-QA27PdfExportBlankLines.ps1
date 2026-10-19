[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$ScanPath,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'F-024 requires native Windows PowerShell 5.1 Desktop.'}
if(Test-Path -LiteralPath $OutputDirectory){throw 'Refuse repeat/overwrite: choose a fresh evidence directory.'}
$null=New-Item -ItemType Directory -Path $OutputDirectory
$started=[DateTime]::UtcNow
$checks=[System.Collections.Generic.List[object]]::new()
$outputs=[System.Collections.Generic.List[object]]::new()
$failure=$null
$originalLocalAppData=$env:LOCALAPPDATA
function Assert-F024([string]$Name,[bool]$Value){
    $checks.Add([pscustomobject]@{Name=$Name;Passed=$Value})
    if(-not $Value){throw ('F-024 product assertion failed: '+$Name)}
}
function Read-F024Pdf([string]$Path){
    Assert-F024 ('Exists: '+[IO.Path]::GetFileName($Path)) (Test-Path -LiteralPath $Path -PathType Leaf)
    $bytes=[IO.File]::ReadAllBytes($Path)
    Assert-F024 ('Nonzero: '+[IO.Path]::GetFileName($Path)) ($bytes.Length -gt 100)
    $raw=[Text.Encoding]::ASCII.GetString($bytes)
    Assert-F024 ('PDF header/trailer: '+[IO.Path]::GetFileName($Path)) ($raw.StartsWith('%PDF-1.4') -and $raw.EndsWith("%%EOF`n"))
    $outputs.Add([pscustomobject]@{Path=$Path;Bytes=$bytes.Length;SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash})
    return $raw
}
function Assert-F024Rejected([string]$Name,[scriptblock]$Action,[string]$Path){
    $rejected=$false
    try {& $Action}catch{$rejected=$true}
    Assert-F024 ($Name+' rejected without creating output') ($rejected -and -not(Test-Path -LiteralPath $Path))
}
try {
    $env:LOCALAPPDATA=Join-Path $OutputDirectory 'isolated-appdata'
    $versionPath=Join-Path $AppRoot '..\VERSION.json'
    $version=Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-F024 'Exact QA27 build identity' ($version.build -eq '2026.10.19-eng-qa27')
    # Load the real modules without modifying execution policy or extracting functions.
    Import-Module (Join-Path $AppRoot 'core\Models.psm1') -ErrorAction Stop
    Import-Module (Join-Path $AppRoot 'core\Privacy.psm1') -ErrorAction Stop
    Import-Module (Join-Path $AppRoot 'reports\PdfWriter.psm1') -ErrorAction Stop
    Import-Module (Join-Path $AppRoot 'reports\ReportExport.psm1') -ErrorAction Stop
    $normal=Join-Path $OutputDirectory 'normal.pdf'
    Write-NyxSimplePdf -Path $normal -Lines @('Ordinary first line','Ordinary second line')
    $raw=Read-F024Pdf $normal
    Assert-F024 'Ordinary text is retained' ($raw.Contains('(Ordinary first line) Tj T*') -and $raw.Contains('(Ordinary second line) Tj T*'))
    $single=Join-Path $OutputDirectory 'single-blank.pdf'
    Write-NyxSimplePdf -Path $single -Lines @('Before','','After')
    $raw=Read-F024Pdf $single
    Assert-F024 'Single blank advances an intentional line' ($raw.Contains("(Before) Tj T*`n() Tj T*`n(After) Tj T*"))
    $consecutive=Join-Path $OutputDirectory 'consecutive-blanks.pdf'
    Write-NyxSimplePdf -Path $consecutive -Lines @('Before','','','After')
    $raw=Read-F024Pdf $consecutive
    Assert-F024 'Consecutive blanks remain consecutive' ($raw.Contains("(Before) Tj T*`n() Tj T*`n() Tj T*`n(After) Tj T*"))
    $only=Join-Path $OutputDirectory 'single-empty-line.pdf'
    Write-NyxSimplePdf -Path $only -Lines @('')
    $raw=Read-F024Pdf $only
    Assert-F024 'Singleton blank is a blank row, not empty-collection fallback' ($raw.Contains('() Tj T*') -and -not $raw.Contains('(Nyx PC Checkup report)'))
    $empty=Join-Path $OutputDirectory 'empty-collection.pdf'
    Write-NyxSimplePdf -Path $empty -Lines @()
    $raw=Read-F024Pdf $empty
    Assert-F024 'Legal empty collection produces the existing fallback page' ($raw.Contains('(Nyx PC Checkup report) Tj T*'))
    $escape=Join-Path $OutputDirectory 'escaping-wrapping.pdf'
    $long='A'*120
    Write-NyxSimplePdf -Path $escape -Lines @('Literal (parentheses) and \ backslash','   ',$long)
    $raw=Read-F024Pdf $escape
    Assert-F024 'PDF escaping remains intact' ($raw.Contains('(Literal \(parentheses\) and \\ backslash) Tj T*'))
    Assert-F024 'Whitespace-only row is preserved' ($raw.Contains('(   ) Tj T*'))
    Assert-F024 'Long word retains existing 92-column wrapping' ($raw.Contains(('(' + ('A'*92) + ") Tj T*`n(" + ('A'*28) + ') Tj T*')))
    $pagination=Join-Path $OutputDirectory 'pagination.pdf'
    $rows=@(1..55|ForEach-Object {if($_ -in @(51,52,53)){''}else{'Row '+$_}})
    Write-NyxSimplePdf -Path $pagination -Lines $rows
    $raw=Read-F024Pdf $pagination
    Assert-F024 'Blank rows count toward page capacity' ($raw.Contains('/Count 2') -and ([regex]::Matches($raw,'\(\) Tj T\*').Count -eq 3))
    $nullPath=Join-Path $OutputDirectory 'rejected-null.pdf'
    Assert-F024Rejected 'Null collection' {Write-NyxSimplePdf -Path $nullPath -Lines $null} $nullPath
    $nullElementPath=Join-Path $OutputDirectory 'rejected-null-element.pdf'
    Assert-F024Rejected 'Null element' {Write-NyxSimplePdf -Path $nullElementPath -Lines @('Before',$null,'After')} $nullElementPath
    $invalidPath=Join-Path $OutputDirectory 'rejected-nonstring.pdf'
    Assert-F024Rejected 'Non-string element' {Write-NyxSimplePdf -Path $invalidPath -Lines @('Before',42,'After')} $invalidPath
    $badWidth=$false
    try {$null=Split-NyxReportLines -Lines @('text') -Width 0}catch{$badWidth=$true}
    Assert-F024 'Invalid wrapping width is rejected' $badWidth
    $scanHash=(Get-FileHash -LiteralPath $ScanPath -Algorithm SHA256).Hash
    Assert-F024 'Representative preserved Full scan hash' ($scanHash -eq '9EBD0A3DD3933AB3161AE1629E9E010A0805C4A177CC440E560BB1B67A4295DE')
    $scan=Get-Content -LiteralPath $ScanPath -Raw -Encoding UTF8|ConvertFrom-Json
    $report=New-NyxSafeReport -Scan $scan
    $expectedText=ConvertTo-NyxReportText -Report $report
    $reportPath=Join-Path $OutputDirectory 'representative-full.pdf'
    $result=Export-NyxReport -Scan $scan -Path $reportPath -Format PDF
    Assert-F024 'Actual scan-to-PDF returns success and bytes' ($result.Success -and $result.Bytes -gt 0 -and $result.Format -eq 'PDF' -and $result.Path -eq $reportPath)
    $raw=Read-F024Pdf $reportPath
    Assert-F024 'Actual PDF includes title, finding, and blank separators' ($raw.Contains('NYX PC CHECKUP - LOCAL DIAGNOSTIC SUMMARY') -and $raw.Contains('Finding:') -and $raw.Contains('() Tj T*'))
    $txt=Join-Path $OutputDirectory 'representative-full.txt'
    $txtResult=Export-NyxReport -Scan $scan -Path $txt -Format TXT
    Assert-F024 'TXT success and original intentional blank separators' ($txtResult.Success -and [IO.File]::ReadAllText($txt).TrimEnd("`r","`n") -eq $expectedText.TrimEnd("`r","`n"))
    $json=Join-Path $OutputDirectory 'representative-full.json'
    $jsonResult=Export-NyxReport -Scan $scan -Path $json -Format JSON
    $parsed=Get-Content -LiteralPath $json -Raw -Encoding UTF8|ConvertFrom-Json
    Assert-F024 'JSON export success and report schema/results preserved' ($jsonResult.Success -and $parsed.ReportSchema -eq 'dietrich-ai-labs.nyx-pc-checkup.report.v1' -and @($parsed.Results).Count -eq @($scan.Results).Count)
    Assert-F024 'Representative raw is never modified' ((Get-FileHash -LiteralPath $ScanPath -Algorithm SHA256).Hash -eq $scanHash)
}catch{
    $failure=$_.Exception.ToString()
}finally{
    $env:LOCALAPPDATA=$originalLocalAppData
    [pscustomobject]@{Schema='QA27-F024-NATIVE-REGRESSION-1';HarnessRevision='QA27-F024-PS51-27';Build='2026.10.19-eng-qa27';StartedUtc=$started.ToString('o');CompletedUtc=[DateTime]::UtcNow.ToString('o');PowerShellVersion=$PSVersionTable.PSVersion.ToString();PSEdition=$PSVersionTable.PSEdition;Checks=$checks.ToArray();Outputs=$outputs.ToArray();Passed=($null -eq $failure);Failure=$failure;NoDpiTesting=$true;NoPolicyChanges=$true}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $OutputDirectory 'F024_NATIVE_RESULT.json') -Encoding UTF8
}
if($null -ne $failure){throw $failure}

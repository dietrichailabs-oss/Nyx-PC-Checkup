$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$name = 'NyxQA26_MissingTarget_Fixture'
$expected = '"C:\Q26EvidenceHarness\QA26_INTENTIONALLY_MISSING.exe"'
$key = Get-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$existing = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
if ($null -ne $existing) {
    if ($existing -cne $expected) {
        throw 'Observer recovery blocked: test fixture value does not match its exact known target.'
    }
    if (Test-Path -LiteralPath 'C:\Q26EvidenceHarness\QA26_INTENTIONALLY_MISSING.exe') {
        throw 'Observer recovery blocked: intentionally missing fixture target now exists.'
    }
    Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name $name
}
& (Join-Path $PSScriptRoot 'QA26-Startup-Final-Fixture.ps1')

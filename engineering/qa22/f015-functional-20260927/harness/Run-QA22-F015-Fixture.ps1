$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
$evidence = Join-Path $env:LOCALAPPDATA ('NyxQA22Evidence\f015_' + (Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence | Out-Null
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$fixture = 'NyxQA22_MissingTarget_F015'
$created = $false
function Save-StartupRecord([string]$Name) {
    $run = Get-ItemProperty -LiteralPath $key
    $values = @{}
    foreach ($property in $run.PSObject.Properties) {
        if ($property.Name -notmatch '^PS') { $values[$property.Name] = $property.Value }
    }
    @{Utc=[DateTime]::UtcNow.ToString('o');Run=$values;Startup=[Environment]::GetFolderPath('Startup')} |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence $Name) -Encoding UTF8
}
try {
    if ($env:USERNAME -ne 'Nyx') { throw 'Expected disposable Nyx user' }
    if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'PowerShell 5.1 required' }
    $installed = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $exe = Join-Path $installed 'Nyx PC Checkup.exe'
    if (!(Test-Path -LiteralPath $exe)) { throw 'Installed QA22 app missing' }
    $existing = Get-ItemProperty -LiteralPath $key
    if ($existing.PSObject.Properties.Name -contains $fixture) { throw 'Fixture already exists; refusing overwrite' }
    if (Test-Path -LiteralPath 'C:\NyxQA22Nonexistent_F015\missing.exe') { throw 'Missing-target fixture unexpectedly exists' }
    Save-StartupRecord 'STARTUP_BEFORE.json'
    Get-ChildItem -LiteralPath $installed -File -Recurse | ForEach-Object {
        @{Path=$_.FullName.Substring($installed.Length + 1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'INSTALLED_HASHES_BEFORE.json') -Encoding UTF8
    New-ItemProperty -LiteralPath $key -Name $fixture -Value '"C:\NyxQA22Nonexistent_F015\missing.exe"' -PropertyType String | Out-Null
    $created = $true
    Save-StartupRecord 'STARTUP_WITH_FIXTURE.json'
    $observer = Start-Process -FilePath "$PSHOME\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Q22F019\Observe-QA22-Installed.ps1" -Evidence "' + $evidence + '"') -PassThru
    Start-Sleep -Seconds 3
    $observerStatus = Get-Content -LiteralPath (Join-Path $evidence 'OBSERVER_STATUS.json') -Raw | ConvertFrom-Json
    if ($observerStatus.Status -ne 'MONITORING') { throw 'Observer not monitoring' }
    $launcher = Start-Process -FilePath $exe -PassThru
    @{Status='F015_FIXTURE_READY';Utc=[DateTime]::UtcNow.ToString('o');Build='2026.09.27-eng-qa22';ProductModified=$false;Fixture=$fixture;LauncherPid=$launcher.Id;ObserverPid=$observer.Id;PowerShell=$PSVersionTable.PSVersion.ToString()} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'F015_STATUS.json') -Encoding UTF8
    $seen = $false
    $deadline = (Get-Date).AddSeconds(60)
    do {
        Start-Sleep -Seconds 2
        $ui = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
            $_.CommandLine -and $_.CommandLine.Contains($installed) -and $_.CommandLine -match 'NyxPCCheckup\.ps1'
        })
        if ($ui.Count -gt 0) { $seen = $true }
        if (!$seen -and (Get-Date) -gt $deadline) { throw 'Installed app process not observed; inspect launcher evidence' }
    } while (!$seen -or $ui.Count -gt 0)
    Save-StartupRecord 'STARTUP_AFTER_UI_BEFORE_FIXTURE_REMOVAL.json'
    Remove-ItemProperty -LiteralPath $key -Name $fixture
    $created = $false
    Save-StartupRecord 'STARTUP_RESTORED.json'
    Get-ChildItem -LiteralPath $installed -File -Recurse | ForEach-Object {
        @{Path=$_.FullName.Substring($installed.Length + 1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'INSTALLED_HASHES_AFTER.json') -Encoding UTF8
    @{Status='UI_CLOSED_FIXTURE_REMOVED';Utc=[DateTime]::UtcNow.ToString('o');ProductModified=$false;Acceptance='NOT_AUTOMATICALLY_ASSERTED'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'F015_STATUS.json') -Encoding UTF8
} catch {
    @{Status='HARNESS_BLOCKED';Error=$_.Exception.ToString();Utc=[DateTime]::UtcNow.ToString('o');ProductModified=$false} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'F015_STATUS.json') -Encoding UTF8
    throw
} finally {
    if ($created) { Remove-ItemProperty -LiteralPath $key -Name $fixture -ErrorAction Stop }
}

Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$root='C:\Q19F016'
$evidence=$null
try{
    $evidence=Join-Path $env:LOCALAPPDATA ('NyxQA19Evidence\continuation_'+(Get-Date -Format yyyyMMdd_HHmmss_fff))
    New-Item -ItemType Directory -Path $evidence -Force|Out-Null
    @{Status='STARTING';User=$env:USERNAME;Time=(Get-Date).ToString('o');HarnessCorrection='observer-startup-2';ProductModified=$false}|ConvertTo-Json|Set-Content "$evidence\CONTINUATION_STATUS.json"
    $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $expected=Get-Content "$root\FROZEN_INSTALLED_HASHES.json" -Raw|ConvertFrom-Json
    foreach($entry in $expected){if((Get-FileHash -LiteralPath (Join-Path $install $entry.Path)).Hash -ne $entry.SHA256){throw "Installed mismatch: $($entry.Path)"}}
    $monitor=Start-Process "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -WindowStyle Hidden -ArgumentList ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "C:\Q19F016\Observe-QA19-Installed.ps1" -Evidence "'+$evidence+'"') -RedirectStandardOutput "$evidence\OBSERVER_STDOUT.txt" -RedirectStandardError "$evidence\OBSERVER_STDERR.txt" -PassThru
    $deadline=(Get-Date).AddSeconds(15)
    while(-not(Test-Path "$evidence\OBSERVER_STATUS.json") -and -not $monitor.HasExited -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 250;$monitor.Refresh()}
    if($monitor.HasExited -or -not(Test-Path "$evidence\OBSERVER_STATUS.json")){throw 'Observer did not start; inspect captured stdout/stderr. No test launch attempted.'}
    $status=Get-Content "$evidence\OBSERVER_STATUS.json" -Raw|ConvertFrom-Json
    if($status.Status -ne 'MONITORING'){throw 'Observer reported a startup failure; no test launch attempted.'}
    $launch=Start-Process -FilePath "$install\Nyx PC Checkup.exe" -PassThru
    @{Status='CONTINUATION_STARTED';MonitorPID=$monitor.Id;LauncherPID=$launch.Id;InstalledHashesMatched=$expected.Count;Reinstalled=$false;ProductModified=$false}|ConvertTo-Json|Set-Content "$evidence\CONTINUATION_STATUS.json"
}catch{
    $failure=@{Status='BLOCKED';Error=$_.Exception.ToString();Time=(Get-Date).ToString('o');ProductModified=$false}|ConvertTo-Json
    if($evidence -and (Test-Path -LiteralPath $evidence)){$failure|Set-Content "$evidence\CONTINUATION_STATUS.json"}
    else{$failure|Set-Content (Join-Path $env:TEMP 'QA19_CONTINUATION_STARTUP_FAILURE.json')}
}

$ErrorActionPreference='Stop'
$root='C:\Q19F016'
$evidence=Join-Path $root ('evidence_'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence|Out-Null
try {
    $identity=Get-Content "$root\CANDIDATE_IDENTITY.json" -Raw|ConvertFrom-Json
    foreach($kind in @('setup','portable','source')){
        $entry=$identity.$kind
        $file=Join-Path $root ([IO.Path]::GetFileName($entry.path))
        if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256){throw "Candidate mismatch: $kind"}
    }
    if(@(Get-Process powershell -ErrorAction SilentlyContinue|Where-Object MainWindowTitle -eq 'Nyx PC Checkup').Count){throw 'Existing Nyx instance: no installation attempted'}
    $setup=Start-Process "$root\Nyx_PC_Checkup_1.0.0_Setup.exe" -ArgumentList '/quiet /nolaunch /desktop' -Wait -PassThru
    [ordered]@{ExitCode=$setup.ExitCode;User=$env:USERNAME;PowerShell=$PSVersionTable.PSVersion.ToString();Time=(Get-Date).ToString('o');Environment='Disposable VM checkpointed before QA19 upgrade; focused regression, not clean Standard'}|ConvertTo-Json|Set-Content "$evidence\INSTALL_RESULT.json"
    if($setup.ExitCode -ne 0){throw "Setup failed: $($setup.ExitCode)"}
    $install="$env:LOCALAPPDATA\Programs\Dietrich AI Labs\Nyx PC Checkup"
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "$root\Test-QA19ProgressConcurrency.ps1" -AppRoot "$install\app" -OutputPath "$evidence\PROGRESS_CONCURRENCY.json"
    if($LASTEXITCODE -ne 0){throw 'Installed-source progress concurrency regression failed; no UI launch'}
    Get-ChildItem -LiteralPath $install -File -Recurse|ForEach-Object {[pscustomobject]@{Path=$_.FullName.Substring($install.Length+1);Size=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}}|ConvertTo-Json -Depth 4|Set-Content "$evidence\INSTALLED_HASHES.json"
    $launch=Start-Process -FilePath "$install\Nyx PC Checkup.exe" -PassThru
    [ordered]@{Status='NATIVE_EXE_STARTED_PENDING_INTERACTIVE_TEST';LauncherPID=$launch.Id;InstallRoot=$install;ObserverWrapper=$false;CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json"
}catch{
    [ordered]@{Status='STOPPED';Error=$_.Exception.ToString();CandidateModified=$false}|ConvertTo-Json|Set-Content "$evidence\RUN_STATUS.json"
}

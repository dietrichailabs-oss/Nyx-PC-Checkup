$ErrorActionPreference='Stop'
$root='C:\Q17F014'
try {
    $identity=Get-Content "$root\CANDIDATE_IDENTITY.json" -Raw|ConvertFrom-Json
    foreach($kind in @('setup','portable','source')){
        $entry=$identity.$kind
        $file=Join-Path $root ([IO.Path]::GetFileName($entry.path))
        if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256){throw "Candidate mismatch: $kind"}
    }
    if(@(Get-Process powershell -ErrorAction SilentlyContinue|Where-Object MainWindowTitle -eq 'Nyx PC Checkup').Count){throw 'Existing Nyx instance: stop before installation'}
    $setup=Start-Process "$root\Nyx_PC_Checkup_1.0.0_Setup.exe" -ArgumentList '/quiet /nolaunch /desktop' -Wait -PassThru
    [ordered]@{ExitCode=$setup.ExitCode;Environment='Disposable VM; checkpointed QA16 installation upgraded to QA17; focused UI test only';User=$env:USERNAME;Time=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content "$root\INSTALL_RESULT.json"
    if($setup.ExitCode -ne 0){throw "Setup failed: $($setup.ExitCode)"}
    & "$root\Run-QA17-InstalledDpi.ps1"
}catch{
    [ordered]@{Status='STOPPED';Error=$_.Exception.ToString()}|ConvertTo-Json|Set-Content "$root\BOOTSTRAP_STATUS.json"
}

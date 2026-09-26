$ErrorActionPreference='Stop'
$root='C:\Q15Bounds'
$evidence=Join-Path $root 'evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
try {
    $expected=@{
        'Nyx_PC_Checkup_1.0.0_Setup.exe'='B4F082A79D76E2A7E9452B2717D87698ED136E4D10CFF2D4232DB6E0BF02CD80'
        'Nyx_PC_Checkup_1.0.0_Portable.zip'='6262B9EF383BA3C6AAF0D7BF192B7104EA0CBB3C9799DF55EA30F44A005A370A'
        'Nyx_PC_Checkup_1.0.0_Source.zip'='E9D426CDCEB554AC071532C6079F421B47558A537A037CDC221958945E2AD62B'
    }
    $hashes=@(foreach($name in $expected.Keys){
        $file=Join-Path $root $name
        $actual=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        if($actual-ne$expected[$name]){throw "Frozen hash mismatch: $name"}
        [ordered]@{File=$name;SHA256=$actual;Matches=$true}
    })
    $hashes | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'CANDIDATE_HASHES.json') -Encoding UTF8
    $data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
    if(Test-Path -LiteralPath $data){throw 'Clean profile prerequisite failed: Nyx application data already exists.'}
    $install=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $setup=Start-Process -FilePath (Join-Path $root 'Nyx_PC_Checkup_1.0.0_Setup.exe') -ArgumentList '/quiet /nolaunch /desktop' -Wait -PassThru
    if($setup.ExitCode-ne0){throw "Setup exited $($setup.ExitCode)"}
    Get-ChildItem -LiteralPath $install -File -Recurse | ForEach-Object {
        [ordered]@{Path=$_.FullName.Substring($install.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidence 'INSTALLED_PAYLOAD_HASHES.json') -Encoding UTF8
    $args='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q15Bounds\Invoke-QA15-FirstCellBounds.ps1" -InstalledRoot "'+$install+'" -EvidenceDirectory "'+$evidence+'"'
    # Match the native launcher's console suppression without SW_HIDE, which
    # can hide the first WinForms window and invalidate visible-UI evidence.
    $startInfo=New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $startInfo.Arguments=$args
    $startInfo.WorkingDirectory=$install
    $startInfo.UseShellExecute=$false
    $startInfo.CreateNoWindow=$true
    $startInfo.WindowStyle=[Diagnostics.ProcessWindowStyle]::Normal
    $process=[Diagnostics.Process]::Start($startInfo)
    [ordered]@{Status='OBSERVER_STARTED';ProcessId=$process.Id;Arguments=$args;User=$env:USERNAME;CandidateModified=$false;StartedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'RUN_STATUS.json') -Encoding UTF8
} catch {
    [ordered]@{Status='ENVIRONMENT_OR_HARNESS_BLOCKED';Error=$_.Exception.ToString();CandidateModified=$false} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'RUN_STATUS.json') -Encoding UTF8
}

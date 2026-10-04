$ErrorActionPreference = 'Stop'
Import-Module Hyper-V
$vm = Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
if ($vm.Name -ne 'Nyx') { throw 'Unexpected VM identity' }
$disk = @(Get-VMHardDiskDrive -VM $vm)
if ($disk.Count -ne 1) { throw 'Expected one disposable VM disk' }
$mounted = $false
try {
    if ($vm.State -ne 'Off') {
        Stop-VM -VM $vm
        $deadline = (Get-Date).AddMinutes(3)
        while ((Get-VM -Id $vm.Id).State -ne 'Off') {
            if ((Get-Date) -gt $deadline) { throw 'Graceful shutdown timed out' }
            Start-Sleep -Seconds 2
        }
    }
    $vhd = Mount-VHD -Path $disk[0].Path -PassThru
    $mounted = $true
    $roots = @($vhd | Get-Disk | Get-Partition | Get-Volume | Where-Object DriveLetter | ForEach-Object { "$($_.DriveLetter):\" } | Where-Object { (Test-Path -LiteralPath (Join-Path $_ 'Q26F023')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx')) })
    if ($roots.Count -ne 1) { throw 'Guest root identification is ambiguous' }
    $root = $roots[0]
    $startup = Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    $matches = @(Get-ChildItem -LiteralPath $startup -File -Filter '*.cmd' | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw) -match 'QA26-Startup-Final-Fixture\.ps1' })
    if ($matches.Count -ne 1) { throw 'Expected one original Startup observer command file' }
    $target = Join-Path $root 'Q26EvidenceHarness\Start-QA26-Startup-Observer3.ps1'
    $source = Join-Path $PSScriptRoot 'Start-QA26-Startup-Observer3.ps1'
    Copy-Item -LiteralPath $source -Destination $target
    $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) { throw 'Observer copy hash mismatch' }
    '@echo off' + "`r`n" + 'start "" /b C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q26EvidenceHarness\Start-QA26-Startup-Observer3.ps1"' | Set-Content -LiteralPath $matches[0].FullName -Encoding ASCII
    @{ Status='STAGED'; Utc=[DateTime]::UtcNow.ToString('o'); ProductModified=$false; ObserverWrapperSHA256=$hash; Scope='Exact own-fixture recovery; existing observer and QA26 product unchanged' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'STARTUP_OBSERVER3_STAGING_STATUS.json') -Encoding UTF8
} finally {
    if ($mounted) { Dismount-VHD -Path $disk[0].Path }
    Start-VM -Id $vm.Id | Out-Null
}

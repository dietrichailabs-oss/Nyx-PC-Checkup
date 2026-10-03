Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module Hyper-V
$vm = Get-VM -Name 'Nyx'
if ($vm.Id.ToString() -ne '275a191c-cf8a-4929-9849-b9a293e9149d') { throw 'Unexpected VM identity' }
if ($vm.State -ne 'Off') {
    Stop-VM -VM $vm
    $limit = (Get-Date).AddMinutes(3)
    while ((Get-VM -Id $vm.Id).State -ne 'Off') {
        if ((Get-Date) -gt $limit) { throw 'Normal VM shutdown timed out' }
        Start-Sleep -Seconds 2
    }
}
$drives = @(Get-VMHardDiskDrive -VM $vm)
if ($drives.Count -ne 1) { throw 'Expected exactly one VM disk' }
$diskPath = $drives[0].Path
$mounted = $false
try {
    $vhd = Mount-VHD -Path $diskPath -PassThru
    $mounted = $true
    $roots = @($vhd | Get-Disk | Get-Partition | Get-Volume | Where-Object DriveLetter | ForEach-Object { $_.DriveLetter.ToString() + ':\' } | Where-Object { (Test-Path -LiteralPath (Join-Path $_ 'Windows')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx')) })
    if ($roots.Count -ne 1) { throw 'Could not uniquely identify disposable Nyx guest volume' }
    $root = $roots[0]
    $harness = Join-Path $root 'Q26EvidenceHarness'
    New-Item -ItemType Directory -Path $harness -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Observe-QA26-InstalledGeometry.ps1') -Destination (Join-Path $harness 'Observe-QA26-InstalledGeometry.ps1')
    $startup = Join-Path $root 'Users\Nyx\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (!(Test-Path -LiteralPath $startup)) { throw 'Guest Startup folder unavailable' }
    # The ordinary frozen native app starts first. This observer waits for its
    # normal closure, then launches the installed script in a separate session.
    $waiter = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Start-Sleep -Seconds 30
$seen=$false
$empty=0
while($true){
 $live=@(Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'powershell.exe' -and $_.CommandLine -like '*Programs*Dietrich AI Labs*Nyx PC Checkup*NyxPCCheckup.ps1*' })
 if($live.Count){$seen=$true;$empty=0}else{$empty++}
 if($seen -and $empty -ge 5){break}
 Start-Sleep -Seconds 2
}
& 'C:\Q26EvidenceHarness\Observe-QA26-InstalledGeometry.ps1'
'@
    Set-Content -LiteralPath (Join-Path $harness 'Wait-And-Observe.ps1') -Value $waiter -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $startup 'QA26_Evidence_Geometry.cmd') -Encoding ASCII -Value '@start "" /min C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Q26EvidenceHarness\Wait-And-Observe.ps1'
    [pscustomobject]@{ Status='STAGED_EVIDENCE_ONLY'; Utc=[DateTime]::UtcNow.ToString('o'); VM=$vm.Id.ToString(); ProductModified=$false; Observer='Observe-QA26-InstalledGeometry.ps1' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'GEOMETRY_STAGING_STATUS.json') -Encoding UTF8
} finally {
    if ($mounted) { Dismount-VHD -Path $diskPath }
    Start-VM -VM $vm | Out-Null
}

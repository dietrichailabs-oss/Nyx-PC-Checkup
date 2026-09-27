$ErrorActionPreference = 'Stop'
$mounted = $false
$statusPath = Join-Path $PSScriptRoot 'F016_STAGING_STATUS.json'
try {
    $workspace = Split-Path $PSScriptRoot
    $vm = Get-VM -Name Nyx
    if ([string]$vm.Id -ne '275a191c-cf8a-4929-9849-b9a293e9149d') { throw 'Wrong VM' }
    if ($vm.State -ne 'Off') { Stop-VM -VM $vm -Confirm:$false }
    if ((Get-VM -Name Nyx).State -ne 'Off') { throw 'Guest did not shut down gracefully' }
    $vhd = Get-VMHardDiskDrive -VMName Nyx | Select-Object -First 1 -ExpandProperty Path
    $disk = Mount-VHD -Path $vhd -PassThru
    $mounted = $true
    $vol = @($disk | Get-Disk | Get-Partition | Get-Volume | Where-Object { $_.DriveLetter -and (Test-Path "$($_.DriveLetter):\Q22F019") })
    if ($vol.Count -ne 1) { throw 'Ambiguous guest disk' }
    $drive = "$($vol[0].DriveLetter):"
    $dest = "$drive\Q22F019"
    Copy-Item -LiteralPath "$PSScriptRoot\Resume-QA22-F016.ps1" -Destination $dest
    Copy-Item -LiteralPath "$workspace\qa21_vm_automation\Observe-QA21-Installed.ps1" -Destination "$dest\Observe-QA22-Installed.ps1"
    $startup = "$drive\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\QA22 F019.lnk"
    $backup = "$dest\PRESERVED_F019_CONTROLLED_STARTUP_$(Get-Date -Format yyyyMMdd_HHmmss).lnk"
    Copy-Item -LiteralPath $startup -Destination $backup
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($startup)
    $shortcut.TargetPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut.Arguments = '-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q22F019\Resume-QA22-F016.ps1"'
    $shortcut.WorkingDirectory = 'C:\Q22F019'
    $shortcut.WindowStyle = 7
    $shortcut.Save()
    Dismount-VHD -Path $vhd
    $mounted = $false
    Start-VM -Name Nyx
    @{Status='F016_STAGED_AND_STARTED';ProductModified=$false;PersistedScanModified=$false;StartupBackup=$backup} | ConvertTo-Json | Set-Content -LiteralPath $statusPath
} catch {
    @{Status='EVIDENCE_HARNESS_BLOCKED';Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $statusPath
} finally {
    if ($mounted) { Dismount-VHD -Path $vhd }
}

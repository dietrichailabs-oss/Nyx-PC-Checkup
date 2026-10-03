$ErrorActionPreference = 'Stop'
$root = 'G:\Marks Apps 2\Nyx_PC_Checkup_1.0.0_Independent_QA5_HOLD_Master_Handoff(2)\qa26_vm_automation'
$dest = Join-Path $root ('launch_diagnostic_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $dest | Out-Null
$mounted = $null
try {
 Import-Module Hyper-V
 $vm = Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
 if ($vm.Name -ne 'Nyx') { throw 'VM identity mismatch' }
 if ($vm.State -ne 'Off') {
  Stop-VM -VM $vm -Confirm:$false
  $end = (Get-Date).AddMinutes(3)
  do { Start-Sleep 2; $vm = Get-VM -Id $vm.Id } until ($vm.State -eq 'Off' -or (Get-Date) -gt $end)
  if ($vm.State -ne 'Off') { throw 'Normal shutdown did not complete; no forced shutdown attempted' }
 }
 $disks = @(Get-VMHardDiskDrive -VM $vm)
 if ($disks.Count -ne 1) { throw 'Expected one guest disk' }
 $mounted = Mount-VHD -Path $disks[0].Path -ReadOnly -Passthru
 $drives = @($mounted | Get-Disk | Get-Partition | Get-Volume | Where-Object DriveLetter | ForEach-Object { "$($_.DriveLetter):\" } | Where-Object { (Test-Path (Join-Path $_ 'Windows')) -and (Test-Path (Join-Path $_ 'Users\Nyx')) })
 if ($drives.Count -ne 1) { throw 'Guest volume not unique' }
 $guest = $drives[0]
 foreach ($rel in @('Users\Nyx\AppData\Local\NyxQA26Evidence','Users\Nyx\AppData\Local\Dietrich AI Labs\Nyx PC Checkup')) {
  $src = Join-Path $guest $rel
  if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $dest -Recurse }
 }
 [pscustomobject]@{ Status='COLLECTED_READ_ONLY'; Destination=$dest; Utc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json | Set-Content (Join-Path $root 'LAUNCH_LOG_COLLECTION_STATUS.json')
} catch {
 [pscustomobject]@{ Status='BLOCKED'; Error=$_.ToString(); Destination=$dest } | ConvertTo-Json | Set-Content (Join-Path $root 'LAUNCH_LOG_COLLECTION_STATUS.json')
} finally {
 if ($mounted) { Dismount-VHD -Path $mounted.Path }
 if ($vm -and (Get-VM -Id $vm.Id).State -eq 'Off') { Start-VM -VM $vm | Out-Null }
}

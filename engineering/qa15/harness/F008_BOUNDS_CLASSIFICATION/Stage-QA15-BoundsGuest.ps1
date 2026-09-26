$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent $PSScriptRoot
$status=Join-Path $PSScriptRoot 'QA15_BOUNDS_STAGING.json'
$mounted=$false
try {
    $vm=Get-VM -Name Nyx
    if($vm.State-eq'Saved'){
        Remove-VMSavedState -VM $vm -Confirm:$false
        $deadline=[DateTime]::UtcNow.AddSeconds(30)
        do{Start-Sleep -Seconds 1;$vm=Get-VM -Name Nyx}while($vm.State-ne'Off'-and[DateTime]::UtcNow-lt$deadline)
    }
    if((Get-VM -Name Nyx).State-ne'Off'){throw 'Restored guest must be off for staging.'}
    $vhd=Get-VMHardDiskDrive -VMName Nyx | Select-Object -First 1 -ExpandProperty Path
    $disk=Mount-VHD -Path $vhd -Passthru
    $mounted=$true
    $volumes=@($disk | Get-Disk | Get-Partition | Get-Volume | Where-Object {$_.DriveLetter-and(Test-Path "$($_.DriveLetter):\Windows\System32")})
    if($volumes.Count-ne1){throw 'Exactly one guest Windows volume required.'}
    $drive="$($volumes[0].DriveLetter):"
    $dest=Join-Path $drive 'Q15Bounds'
    if(Test-Path -LiteralPath $dest){throw 'Guest staging path already exists; preserve it for review.'}
    New-Item -ItemType Directory -Path $dest | Out-Null
    Get-ChildItem -LiteralPath (Join-Path $workspace 'qa15_bounds_input') -File | Copy-Item -Destination $dest
    foreach($name in @('Invoke-QA15-FirstCellBounds.ps1','Start-QA15-BoundsGuest.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $dest}
    $startup=Join-Path $drive 'ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp'
    $shell=New-Object -ComObject WScript.Shell
    $shortcut=$shell.CreateShortcut((Join-Path $startup 'QA15 Bounds Observation.lnk'))
    $shortcut.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut.Arguments='-NoLogo -NoProfile -NonInteractive -STA -ExecutionPolicy Bypass -File "C:\Q15Bounds\Start-QA15-BoundsGuest.ps1"'
    $shortcut.WorkingDirectory='C:\Q15Bounds'
    $shortcut.Save()
    $profiles=@(Get-ChildItem -LiteralPath (Join-Path $drive 'Users') -Directory | Select-Object -ExpandProperty Name)
    Dismount-VHD -Path $vhd
    $mounted=$false
    Start-VM -Name Nyx
    [ordered]@{Status='STAGED_AND_STARTED';Profiles=$profiles;VHD=$vhd;CandidateModified=$false} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $status -Encoding UTF8
} catch {
    [ordered]@{Status='BLOCKED';Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8
} finally {if($mounted){Dismount-VHD -Path $vhd}}

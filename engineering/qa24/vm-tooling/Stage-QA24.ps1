Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent $PSScriptRoot
$status=Join-Path $PSScriptRoot 'STAGING_STATUS.json'
$mount=$null
function Write-Status {param([string]$State,[string]$Detail) @{State=$State;Detail=$Detail;Utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8}
try{
    Write-Status 'Starting' 'Preserving Nyx QA23 before staging immutable QA24'
    Import-Module Hyper-V
    $vm=Get-VM -Id '275a191c-cf8a-4929-9849-b9a293e9149d'
    if($vm.Name -ne 'Nyx'){throw 'VM identity mismatch'}
    if($vm.State -eq 'Running'){
        Stop-VM -VM $vm
        $deadline=(Get-Date).AddMinutes(2)
        do{Start-Sleep -Seconds 2;$vm=Get-VM -Id $vm.Id}while($vm.State -ne 'Off' -and (Get-Date) -lt $deadline)
    }
    if($vm.State -ne 'Off'){throw 'VM must shut down gracefully; no forced power-off performed'}
    $checkpoint='QA23_PRESERVED_BEFORE_QA24_'+(Get-Date -Format yyyyMMdd_HHmmss)
    Checkpoint-VM -VM $vm -SnapshotName $checkpoint
    $drives=@(Get-VMHardDiskDrive -VM $vm)
    if($drives.Count -ne 1){throw 'Expected one Nyx OS disk; refusing ambiguous disk selection'}
    $mount=Mount-VHD -Path $drives[0].Path -Passthru
    $disk=$mount | Get-Disk
    $roots=@(Get-Partition -DiskNumber $disk.Number | Where-Object DriveLetter | ForEach-Object {"$($_.DriveLetter):\"} | Where-Object {(Test-Path -LiteralPath (Join-Path $_ 'Windows\System32')) -and (Test-Path -LiteralPath (Join-Path $_ 'Users\Nyx'))})
    if($roots.Count -ne 1){throw 'Cannot identify unique mounted Nyx Windows volume; no formatting or drive repair performed'}
    $guestRoot=$roots[0]
    $oldEvidence=Join-Path $guestRoot 'Users\Nyx\AppData\Local\NyxQA23Evidence'
    if(Test-Path -LiteralPath $oldEvidence){Copy-Item -LiteralPath $oldEvidence -Destination (Join-Path $PSScriptRoot ('preserved-qa23-'+(Get-Date -Format yyyyMMdd_HHmmss))) -Recurse}
    $destination=Join-Path $guestRoot 'Q24F021'
    if(Test-Path -LiteralPath $destination){throw 'QA24 guest staging already exists; refusing overwrite'}
    [void][IO.Directory]::CreateDirectory($destination)
    $dist=Join-Path $workspace 'qa24_clean_source_01b082578f354645ac1d04c1d532cd15\dist'
    foreach($name in @('Nyx_PC_Checkup_1.0.0_Setup.exe','Nyx_PC_Checkup_1.0.0_Portable.zip','Nyx_PC_Checkup_1.0.0_Source.zip')){
        Copy-Item -LiteralPath (Join-Path $dist $name) -Destination $destination
        if((Get-FileHash -LiteralPath (Join-Path $dist $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $destination $name)).Hash){throw "Copied artifact mismatch: $name"}
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-QA24-Guest.ps1') -Destination $destination
    $startup=Join-Path $guestRoot 'ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    $backup=Join-Path $destination 'prior-qa-startup-links'
    [void][IO.Directory]::CreateDirectory($backup)
    $shell=New-Object -ComObject WScript.Shell
    foreach($link in Get-ChildItem -LiteralPath $startup -Filter '*.lnk'){
        $existing=$shell.CreateShortcut($link.FullName)
        if($existing.Arguments -like '*C:\Q23F020\Start-QA23-Guest.ps1*'){
            $resolved=[IO.Path]::GetFullPath($link.FullName)
            if(-not $resolved.StartsWith([IO.Path]::GetFullPath($startup)+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Startup path escaped mounted guest'}
            Move-Item -LiteralPath $resolved -Destination $backup
        }
    }
    $linkPath=Join-Path $startup 'QA24 F021.lnk'
    if(Test-Path -LiteralPath $linkPath){throw 'QA24 startup link already exists'}
    $link=$shell.CreateShortcut($linkPath)
    $link.TargetPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments='-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\Q24F021\Start-QA24-Guest.ps1"'
    $link.WorkingDirectory='C:\Q24F021'
    $link.Save()
    Dismount-VHD -Path $drives[0].Path
    $mount=$null
    Start-VM -VM $vm
    Write-Status 'ReadyForSignIn' ("QA24 staged; checkpoint $checkpoint preserved; sign in as Nyx")
}catch{Write-Status 'Blocked' ($_.Exception.ToString());throw}finally{if($null -ne $mount){Dismount-VHD -Path $mount.Path}}

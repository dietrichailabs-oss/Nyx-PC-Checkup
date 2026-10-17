Set-StrictMode -Version 2.0
function Get-NyxSystemInfoCheck {
    if (-not (Test-NyxWindowsPlatform)) {
        return New-NyxUnknownResult -CheckId 'system.overview' -Category 'System' -Name 'System overview' -Reason 'Version 1 supports Windows 10/11 x64.' -DataSource 'Platform adapter'
    }
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $drive = Get-NyxSystemDriveInfo
    $lastBoot = if ($os.LastBootUpTime -is [DateTime]) { [DateTime]$os.LastBootUpTime } else { [Management.ManagementDateTimeConverter]::ToDateTime([string]$os.LastBootUpTime) }
    $uptime = (Get-Date) - $lastBoot
    $batteryPresent = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0
    $portableTypes = @(2,8,9,10,11,14)
    $kind = if ($batteryPresent -or $portableTypes -contains [int]$cs.PCSystemType -or $portableTypes -contains [int]$cs.PCSystemTypeEx) { 'Laptop / portable device' } else { 'Desktop or fixed device' }
    $details = [pscustomobject][ordered]@{
        ComputerName = $env:COMPUTERNAME
        WindowsEdition = $(if (-not [string]::IsNullOrWhiteSpace([string]$os.Caption)) { [string]$os.Caption } else { Get-NyxWindowsEdition })
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        Is64Bit = [Environment]::Is64BitOperatingSystem
        Processor = [string]$cpu.Name
        InstalledRamBytes = [int64]$cs.TotalPhysicalMemory
        AvailableRamBytes = [int64]$os.FreePhysicalMemory * 1024
        SystemDrive = $drive.Name
        SystemDriveCapacityBytes = [int64]$drive.TotalSize
        SystemDriveFreeBytes = [int64]$drive.AvailableFreeSpace
        UptimeSeconds = [int64]$uptime.TotalSeconds
        DeviceClass = $kind
        Manufacturer = [string]$cs.Manufacturer
        Model = [string]$cs.Model
        BatteryPresent = $batteryPresent
    }
    return New-NyxCheckResult -CheckId 'system.overview' -Category 'System' -Name 'System overview' -Status 'Good' -Severity 'Info' `
        -Finding ("{0} with {1} RAM, running Windows build {2}." -f $kind,(ConvertTo-NyxBytesText $details.InstalledRamBytes),$details.WindowsBuild) `
        -Reason 'Basic system information was read successfully.' -Evidence $details `
        -Recommendation 'No action is required. Hardware serial numbers and unique identifiers are intentionally not collected.' `
        -DataSource 'Windows CIM / local environment' -Details $details
}

Export-ModuleMember -Function Get-NyxSystemInfoCheck

Set-StrictMode -Version 2.0
function Get-NyxDefaultConfiguration {
    $path = Join-Path $PSScriptRoot '..\config\defaults.json'
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function ConvertTo-NyxConfigurationBoolean {
    param([object]$Value,[bool]$Default)
    if ($Value -is [bool]) { return [bool]$Value }
    if ($null -ne $Value) {
        $text=[string]$Value
        if ([string]::Equals($text,'true',[StringComparison]::OrdinalIgnoreCase)) { return $true }
        if ([string]::Equals($text,'false',[StringComparison]::OrdinalIgnoreCase)) { return $false }
    }
    return $Default
}

function ConvertTo-NyxBoundedConfigurationInteger {
    param([object]$Value,[int64]$Default,[int64]$Minimum,[int64]$Maximum)
    $parsed=[int64]0
    if ($null -eq $Value -or -not [int64]::TryParse([string]$Value,[ref]$parsed)) { return $Default }
    if ($parsed -lt $Minimum) { return $Minimum }
    if ($parsed -gt $Maximum) { return $Maximum }
    return $parsed
}

function ConvertTo-NyxUtcTimestampText {
    param([object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    $parsed=[DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$parsed)) { return '' }
    return $parsed.ToUniversalTime().ToString('o')
}

function Repair-NyxConfiguration {
    [CmdletBinding()]
    param([object]$Configuration)
    $defaults=Get-NyxDefaultConfiguration
    if ($null -eq $Configuration) { $Configuration=$defaults }

    $theme=[string]$defaults.theme
    try {
        $candidate=[string]$Configuration.theme
        if ($candidate -in @('FollowWindows','Dark','Light')) { $theme=$candidate }
    } catch { }

    $scanInput=$null
    try { $scanInput=$Configuration.scan } catch { }
    if ($null -eq $scanInput) { $scanInput=$defaults.scan }
    $updatesInput=$null
    try { $updatesInput=$Configuration.updates } catch { }
    if ($null -eq $updatesInput) { $updatesInput=$defaults.updates }

    return [pscustomobject][ordered]@{
        theme=$theme
        notificationsEnabled=(ConvertTo-NyxConfigurationBoolean -Value $(try{$Configuration.notificationsEnabled}catch{$defaults.notificationsEnabled}) -Default ([bool]$defaults.notificationsEnabled))
        developerLogging=(ConvertTo-NyxConfigurationBoolean -Value $(try{$Configuration.developerLogging}catch{$defaults.developerLogging}) -Default ([bool]$defaults.developerLogging))
        maxLogBytes=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$Configuration.maxLogBytes}catch{$defaults.maxLogBytes}) -Default ([int64]$defaults.maxLogBytes) -Minimum 65536 -Maximum 10485760)
        maxLogFiles=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$Configuration.maxLogFiles}catch{$defaults.maxLogFiles}) -Default ([int64]$defaults.maxLogFiles) -Minimum 1 -Maximum 10)
        actionHistoryLimit=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$Configuration.actionHistoryLimit}catch{$defaults.actionHistoryLimit}) -Default ([int64]$defaults.actionHistoryLimit) -Minimum 10 -Maximum 1000)
        reportIncludeUserName=(ConvertTo-NyxConfigurationBoolean -Value $(try{$Configuration.reportIncludeUserName}catch{$defaults.reportIncludeUserName}) -Default ([bool]$defaults.reportIncludeUserName))
        reportIncludeIpAddresses=(ConvertTo-NyxConfigurationBoolean -Value $(try{$Configuration.reportIncludeIpAddresses}catch{$defaults.reportIncludeIpAddresses}) -Default ([bool]$defaults.reportIncludeIpAddresses))
        updates=[pscustomobject][ordered]@{
            enabled=(ConvertTo-NyxConfigurationBoolean -Value $(try{$updatesInput.enabled}catch{$defaults.updates.enabled}) -Default ([bool]$defaults.updates.enabled))
            lastCheckUtc=(ConvertTo-NyxUtcTimestampText -Value $(try{$updatesInput.lastCheckUtc}catch{$defaults.updates.lastCheckUtc}))
        }
        scan=[pscustomobject][ordered]@{
            maxFiles=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$scanInput.maxFiles}catch{$defaults.scan.maxFiles}) -Default ([int64]$defaults.scan.maxFiles) -Minimum 1000 -Maximum 2000000)
            maxSeconds=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$scanInput.maxSeconds}catch{$defaults.scan.maxSeconds}) -Default ([int64]$defaults.scan.maxSeconds) -Minimum 5 -Maximum 900)
            duplicateHashMaxBytes=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$scanInput.duplicateHashMaxBytes}catch{$defaults.scan.duplicateHashMaxBytes}) -Default ([int64]$defaults.scan.duplicateHashMaxBytes) -Minimum 1048576 -Maximum 1073741824)
            duplicateHashMaxFiles=(ConvertTo-NyxBoundedConfigurationInteger -Value $(try{$scanInput.duplicateHashMaxFiles}catch{$defaults.scan.duplicateHashMaxFiles}) -Default ([int64]$defaults.scan.duplicateHashMaxFiles) -Minimum 1 -Maximum 5000)
        }
    }
}

function Get-NyxConfiguration {
    $paths = Initialize-NyxDataDirectories
    $defaults = Repair-NyxConfiguration -Configuration (Get-NyxDefaultConfiguration)
    if (-not (Test-Path -LiteralPath $paths.Config)) {
        Save-NyxConfiguration -Configuration $defaults
        return $defaults
    }
    try {
        $item=Get-Item -LiteralPath $paths.Config -Force -ErrorAction Stop
        if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or $item.Length -gt 1048576) { throw 'The configuration file is not an ordinary bounded file.' }
        $stored = Get-Content -LiteralPath $paths.Config -Raw -Encoding UTF8 | ConvertFrom-Json
        $clean=Repair-NyxConfiguration -Configuration $stored
        if (($stored|ConvertTo-Json -Depth 8 -Compress) -ne ($clean|ConvertTo-Json -Depth 8 -Compress)) { Save-NyxConfiguration -Configuration $clean }
        return $clean
    } catch {
        $bad = "$($paths.Config).corrupt.$((Get-Date).ToString('yyyyMMddHHmmss'))"
        Move-Item -LiteralPath $paths.Config -Destination $bad -Force -ErrorAction SilentlyContinue
        Save-NyxConfiguration -Configuration $defaults
        return $defaults
    }
}

function Save-NyxConfiguration {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Configuration)
    $paths = Initialize-NyxDataDirectories
    $clean=Repair-NyxConfiguration -Configuration $Configuration
    if (Test-Path -LiteralPath $paths.Config) {
        $item=Get-Item -LiteralPath $paths.Config -Force -ErrorAction Stop
        if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The configuration destination is not an ordinary file.' }
    }
    $temp = "$($paths.Config).tmp.$([guid]::NewGuid().ToString('N'))"
    try {
        $clean | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
        Move-Item -LiteralPath $temp -Destination $paths.Config -Force -ErrorAction Stop
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Get-NyxDefaultConfiguration,ConvertTo-NyxUtcTimestampText,Repair-NyxConfiguration,Get-NyxConfiguration,Save-NyxConfiguration

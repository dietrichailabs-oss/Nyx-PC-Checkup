Set-StrictMode -Version 2.0
function Get-NyxInstalledApplications {
    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $map = @{}
    foreach ($root in $roots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace([string]$_.DisplayName)) { return }
            if ($_.SystemComponent -eq 1) { return }
            $key = ("{0}|{1}|{2}" -f $_.DisplayName,$_.DisplayVersion,$_.Publisher).ToLowerInvariant()
            if (-not $map.ContainsKey($key)) {
                $size = if ($_.EstimatedSize) { [int64]$_.EstimatedSize * 1024 } else { $null }
                $map[$key] = [pscustomobject][ordered]@{
                    Id=Get-NyxStableId -Text $key; Name=[string]$_.DisplayName; Publisher=[string]$_.Publisher;
                    Version=[string]$_.DisplayVersion; InstallDate=[string]$_.InstallDate; EstimatedSizeBytes=$size;
                    InstallLocation=[string]$_.InstallLocation; UninstallAvailable=(-not [string]::IsNullOrWhiteSpace([string]$_.UninstallString))
                }
            }
        }
    }
    return @($map.Values | Sort-Object Name)
}

function Get-NyxInstalledAppsCheck {
    $apps = @(Get-NyxInstalledApplications)
    $largest = @($apps | Where-Object { $_.EstimatedSizeBytes -ne $null } | Sort-Object EstimatedSizeBytes -Descending | Select-Object -First 10)
    if($apps.Count -eq 0){
        return New-NyxCheckResult -CheckId 'apps.inventory' -Category 'Applications' -Name 'Installed applications' -Status 'Unknown' -Severity 'Info' `
            -Finding 'Windows returned no supported installed-application records.' `
            -Reason 'An empty uninstall inventory is not enough evidence to say that the application review completed normally.' `
            -Evidence ([pscustomobject]@{Count=0;Applications=@();LargestByReportedSize=@()}) `
            -Recommendation 'Open Windows Installed Apps settings to review the operating system inventory.' -ActionSafetyLevel 'SafeRedirect' `
            -DataSource 'Current-user and machine uninstall registry records' -Complete $false -ErrorReason 'No uninstall records were returned.' -Details @()
    }
    return New-NyxCheckResult -CheckId 'apps.inventory' -Category 'Applications' -Name 'Installed applications' -Status 'Good' -Severity 'Info' `
        -Finding "$($apps.Count) installed application(s) were listed from supported uninstall records." `
        -Reason 'The list is informational; Nyx does not call applications junk or uninstall anything automatically.' `
        -Evidence ([pscustomobject]@{ Count=$apps.Count; Applications=$apps; LargestByReportedSize=$largest }) `
        -Recommendation 'Use Windows Installed Apps settings when you intentionally want to remove a program.' -ActionSafetyLevel 'SafeRedirect' `
        -DataSource 'Current-user and machine uninstall registry records' -Details $apps
}

Export-ModuleMember -Function Get-NyxInstalledApplications,Get-NyxInstalledAppsCheck

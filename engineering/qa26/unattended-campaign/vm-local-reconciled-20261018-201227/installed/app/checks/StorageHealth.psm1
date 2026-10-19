Set-StrictMode -Version 2.0
function Get-NyxStorageHealthCheck {
    $drive = Get-NyxSystemDriveInfo
    if (-not $drive.IsReady) {
        return New-NyxUnknownResult -CheckId 'storage.system-drive' -Category 'Storage' -Name 'System-drive free space' -Reason 'The system drive was not ready.' -DataSource '.NET DriveInfo'
    }
    $rule = Get-NyxStorageRuleResult -FreeBytes ([int64]$drive.AvailableFreeSpace) -TotalBytes ([int64]$drive.TotalSize)
    $percent = [math]::Round(($drive.AvailableFreeSpace / [double]$drive.TotalSize) * 100,1)
    $evidence = [pscustomobject]@{
        Drive = $drive.Name
        TotalBytes = [int64]$drive.TotalSize
        FreeBytes = [int64]$drive.AvailableFreeSpace
        FreePercent = $percent
        Format = $drive.DriveFormat
    }
    return New-NyxCheckResult -CheckId 'storage.system-drive' -Category 'Storage' -Name 'System-drive free space' `
        -Status $rule.Status -Severity $rule.Severity `
        -Finding ("{0} is free on {1}." -f (ConvertTo-NyxBytesText $drive.AvailableFreeSpace),$drive.Name) `
        -Reason $rule.Reason -Evidence $evidence -Recommendation $rule.Recommendation `
        -ActionSafetyLevel 'SafeRedirect' -DataSource '.NET DriveInfo'
}

Export-ModuleMember -Function Get-NyxStorageHealthCheck

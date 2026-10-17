Set-StrictMode -Version 2.0
function Get-NyxUptimeCheck {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $lastBoot = $os.LastBootUpTime
    if (-not ($lastBoot -is [datetime])) { $lastBoot = [Management.ManagementDateTimeConverter]::ToDateTime([string]$lastBoot) }
    $days = ((Get-Date) - [datetime]$lastBoot).TotalDays
    $restart = Get-NyxRestartPending
    $rule = Get-NyxUptimeRuleResult -Days $days -RestartPending ([bool]$restart.Pending)
    return New-NyxCheckResult -CheckId 'system.uptime' -Category 'System' -Name 'PC uptime' -Status $rule.Status -Severity $rule.Severity `
        -Finding ("Your PC has been running for {0:N1} days." -f $days) -Reason $rule.Reason `
        -Evidence ([pscustomobject]@{ LastBootUtc=([datetime]$lastBoot).ToUniversalTime().ToString('o'); UptimeDays=[math]::Round($days,2); RestartPending=[bool]$restart.Pending; RestartStatusComplete=[bool]$restart.Complete }) `
        -Recommendation $rule.Recommendation -ActionSafetyLevel 'SafeRedirect' -DataSource 'Win32_OperatingSystem and restart-pending markers'
}

Export-ModuleMember -Function Get-NyxUptimeCheck

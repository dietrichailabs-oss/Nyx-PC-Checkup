Set-StrictMode -Version 2.0

function Get-NyxRules {
    $path = Join-Path $PSScriptRoot 'rules.json'
    return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-NyxStorageRuleResult {
    [CmdletBinding()]
    param([int64]$FreeBytes,[int64]$TotalBytes)
    $rules = (Get-NyxRules).storage
    if ($TotalBytes -le 0) {
        return [pscustomobject]@{ Status='Unknown'; Severity='Info'; Reason='Drive capacity was unavailable.'; Recommendation='Open Windows Storage settings to review the drive.' }
    }
    $percent = [math]::Round(($FreeBytes / [double]$TotalBytes) * 100,1)
    $hardFloor = [int64]$rules.criticalFreeBytes / 2
    if ($FreeBytes -lt $hardFloor -or ($FreeBytes -lt [int64]$rules.criticalFreeBytes -and $percent -lt [double]$rules.criticalFreePercent)) {
        return [pscustomobject]@{ Status='NeedsAttention'; Severity='High'; Reason="The system drive has only $percent% free."; Recommendation='Free space soon so Windows can update and operate normally.' }
    }
    if ($FreeBytes -lt [int64]$rules.criticalFreeBytes -or ($FreeBytes -lt [int64]$rules.attentionFreeBytes -and $percent -lt [double]$rules.attentionFreePercent)) {
        return [pscustomobject]@{ Status='NeedsAttention'; Severity='Medium'; Reason="The system drive is getting low at $percent% free."; Recommendation='Review large files and optional cleanup opportunities.' }
    }
    return [pscustomobject]@{ Status='Good'; Severity='Info'; Reason="The system drive has $percent% free."; Recommendation='No storage action is required.' }
}

function Get-NyxUptimeRuleResult {
    [CmdletBinding()]
    param([double]$Days,[bool]$RestartPending)
    $rules = (Get-NyxRules).uptime
    if ($RestartPending -and $Days -ge [double]$rules.attentionDaysWithRestartPending) {
        return [pscustomobject]@{ Status='NeedsAttention'; Severity='Medium'; Reason='Windows reports a restart is pending and the PC has not restarted recently.'; Recommendation='Save your work and restart when convenient to finish updates.' }
    }
    if ($Days -ge [double]$rules.optionalDays) {
        return [pscustomobject]@{ Status='Optional'; Severity='Low'; Reason=("The PC has been running for {0:N1} days." -f $Days); Recommendation='A restart may help finish updates or clear temporary issues, but daily restarts are not necessary.' }
    }
    return [pscustomobject]@{ Status='Good'; Severity='Info'; Reason=("The PC has been running for {0:N1} days." -f $Days); Recommendation='No restart is needed based on uptime alone.' }
}

function Get-NyxBatteryRuleResult {
    [CmdletBinding()]
    param([double]$HealthPercent)
    $rules = (Get-NyxRules).battery
    if ($HealthPercent -le 0) {
        return [pscustomobject]@{ Status='Unknown'; Severity='Info'; Reason='Battery design or full-charge capacity was unavailable.'; Recommendation='Battery health cannot be estimated on this device.' }
    }
    if ($HealthPercent -lt [double]$rules.attentionHealthPercent) {
        return [pscustomobject]@{ Status='NeedsAttention'; Severity='Medium'; Reason=("The battery holds approximately {0:N0}% of its original designed capacity." -f $HealthPercent); Recommendation='Plan for battery replacement if runtime is no longer adequate.' }
    }
    if ($HealthPercent -lt [double]$rules.optionalHealthPercent) {
        return [pscustomobject]@{ Status='Optional'; Severity='Low'; Reason=("The battery holds approximately {0:N0}% of its original designed capacity." -f $HealthPercent); Recommendation='This is normal aging; replacement is optional unless runtime is inconvenient.' }
    }
    return [pscustomobject]@{ Status='Good'; Severity='Info'; Reason=("The battery holds approximately {0:N0}% of its original designed capacity." -f $HealthPercent); Recommendation='No battery action is required.' }
}

function Get-NyxPerformanceRuleResult {
    [CmdletBinding()]
    param([double]$CpuPercent,[double]$MemoryPercent)
    $rules = (Get-NyxRules).performance
    if ($CpuPercent -ge [double]$rules.highCpuPercent -or $MemoryPercent -ge [double]$rules.highMemoryPercent) {
        return [pscustomobject]@{ Status='Optional'; Severity='Low'; Reason='Current system use is high in this one-time snapshot.'; Recommendation='If the PC feels slow, review the listed processes. Nyx will not stop them automatically.' }
    }
    return [pscustomobject]@{ Status='Good'; Severity='Info'; Reason='Current CPU and memory use are within ordinary snapshot ranges.'; Recommendation='No performance action is required from this snapshot.' }
}

Export-ModuleMember -Function Get-NyxRules,Get-NyxStorageRuleResult,Get-NyxUptimeRuleResult,Get-NyxBatteryRuleResult,Get-NyxPerformanceRuleResult

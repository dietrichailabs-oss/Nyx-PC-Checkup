Set-StrictMode -Version 2.0
function Get-NyxBatteryChargingState {
    param([int]$BatteryStatus)
    switch($BatteryStatus){
        1 { return 'Discharging or other state' }
        2 { return 'Unknown' }
        3 { return 'Fully charged' }
        4 { return 'Low charge' }
        5 { return 'Critical charge' }
        6 { return 'Charging' }
        7 { return 'Charging, high charge' }
        8 { return 'Charging, low charge' }
        9 { return 'Charging, critical charge' }
        10 { return 'Undefined' }
        11 { return 'Partially charged' }
        default { return 'Unreported' }
    }
}

function Get-NyxBatteryHealthCheck {
    $battery = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($battery.Count -eq 0) { return $null }
    $design = $null; $full = $null; $cycle = $null
    try { $design = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity } catch { }
    try { $full = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity } catch { }
    try { $cycle = (Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryCycleCount -ErrorAction Stop | Select-Object -First 1).CycleCount } catch { }
    $rawHealth = 0.0;$health = 0.0
    if ($design -and $full -and [double]$design -gt 0) {
        $rawHealth = [math]::Round(([double]$full / [double]$design) * 100,0)
        $health = [math]::Min(100,[math]::Max(0,$rawHealth))
    }
    $rule = Get-NyxBatteryRuleResult -HealthPercent $health
    $charge = if ($battery[0].EstimatedChargeRemaining -ne $null) { [int]$battery[0].EstimatedChargeRemaining } else { -1 }
    $batteryStatus=[int]$battery[0].BatteryStatus;$chargingState=Get-NyxBatteryChargingState -BatteryStatus $batteryStatus
    $evidence = [pscustomobject]@{
        ChargePercent=$charge; DesignCapacity=$design; FullChargeCapacity=$full; EstimatedHealthPercent=$(if ($health -gt 0) { $health } else { $null });
        RawEstimatedHealthPercent=$(if ($rawHealth -gt 0) { $rawHealth } else { $null });CycleCount=$cycle; BatteryStatus=$batteryStatus;ChargingState=$chargingState
    }
    return New-NyxCheckResult -CheckId 'battery.health' -Category 'Battery' -Name 'Battery health' -Status $rule.Status -Severity $rule.Severity `
        -Finding $(if ($health -gt 0) { "$($rule.Reason) Current state: $chargingState." } elseif ($charge -ge 0) { "Battery charge is $charge%. Battery wear information is unavailable. Current state: $chargingState." } else { 'Battery health information is unavailable on this device.' }) `
        -Reason $rule.Reason -Evidence $evidence -Recommendation $rule.Recommendation -DataSource 'Win32_Battery and root\wmi battery classes' `
        -Complete ($health -gt 0) -ErrorReason $(if ($health -gt 0) { '' } else { 'Design/full-charge capacity unavailable.' })
}

Export-ModuleMember -Function Get-NyxBatteryChargingState,Get-NyxBatteryHealthCheck

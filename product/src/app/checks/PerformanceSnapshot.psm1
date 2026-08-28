Set-StrictMode -Version 2.0
function Get-NyxPerformanceSnapshotCheck {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cpuValues = @(Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object { [double]$_.LoadPercentage })
    $cpu = if ($cpuValues.Count -gt 0) { [math]::Round((($cpuValues | Measure-Object -Average).Average),0) } else { 0 }
    $total = [double]$os.TotalVisibleMemorySize * 1024
    $available = [double]$os.FreePhysicalMemory * 1024
    $memory = if ($total -gt 0) { [math]::Round((1 - ($available / $total)) * 100,0) } else { 0 }
    $topCpu = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object CPU -Descending | Select-Object -First 8 Name,Id,CPU,WorkingSet64)
    $topMemory = @(Get-Process -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 Name,Id,CPU,WorkingSet64)
    $disk = $null
    try {
        $sample = Get-Counter '\PhysicalDisk(_Total)\% Disk Time' -SampleInterval 1 -MaxSamples 1 -ErrorAction Stop
        $disk = [math]::Round([double]$sample.CounterSamples[0].CookedValue,0)
    } catch { }
    $rule = Get-NyxPerformanceRuleResult -CpuPercent $cpu -MemoryPercent $memory
    $evidence = [pscustomobject]@{ CpuPercent=$cpu; MemoryPercent=$memory; AvailableMemoryBytes=[int64]$available; DiskActivityPercent=$disk; TopCpu=$topCpu; TopMemory=$topMemory }
    return New-NyxCheckResult -CheckId 'performance.snapshot' -Category 'Performance' -Name 'Current performance snapshot' -Status $rule.Status -Severity $rule.Severity `
        -Finding ("CPU is about {0}% and memory use is about {1}% in this snapshot." -f $cpu,$memory) -Reason $rule.Reason -Evidence $evidence `
        -Recommendation $rule.Recommendation -ActionSafetyLevel 'None' -DataSource 'Windows CIM, process list, and optional performance counter' -Details $evidence
}

Export-ModuleMember -Function Get-NyxPerformanceSnapshotCheck

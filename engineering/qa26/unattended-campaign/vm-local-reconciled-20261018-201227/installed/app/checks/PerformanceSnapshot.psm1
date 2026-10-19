Set-StrictMode -Version 2.0
function Get-NyxProcessSnapshotField {
    param($Process,[string]$Name)
    try {
        $property=$Process.PSObject.Properties[$Name]
        if($null -eq $property){return $null}
        return $property.get_Value()
    } catch {
        $cause=$_.Exception.GetBaseException()
        if($cause -is [System.InvalidOperationException] -or $cause -is [System.ComponentModel.Win32Exception] -or $cause -is [System.UnauthorizedAccessException] -or $cause -is [System.NotSupportedException]){return $null}
        throw
    }
}
function ConvertTo-NyxProcessSnapshot {
    param($Process)
    $name=Get-NyxProcessSnapshotField $Process 'Name'
    $processId=Get-NyxProcessSnapshotField $Process 'Id'
    if([string]::IsNullOrWhiteSpace([string]$name) -or $null -eq $processId){return $null}
    $runtime=Get-NyxProcessSnapshotField $Process 'TotalProcessorTime'
    $workingSet=Get-NyxProcessSnapshotField $Process 'WorkingSet64'
    $seconds=$null
    if($runtime -is [TimeSpan] -and $runtime.Ticks -ge 0){$seconds=$runtime.TotalSeconds}
    $bytes=$null
    if($workingSet -is [long] -or $workingSet -is [int]){if($workingSet -ge 0){$bytes=[long]$workingSet}}
    return [pscustomobject]@{Name=[string]$name;Id=$processId;CPU=$seconds;WorkingSet64=$bytes}
}
function Get-NyxPerformanceSnapshotCheck {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cpuValues = @(Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object { [double]$_.LoadPercentage })
    $cpu = if ($cpuValues.Count -gt 0) { [math]::Round((($cpuValues | Measure-Object -Average).Average),0) } else { 0 }
    $total = [double]$os.TotalVisibleMemorySize * 1024
    $available = [double]$os.FreePhysicalMemory * 1024
    $memory = if ($total -gt 0) { [math]::Round((1 - ($available / $total)) * 100,0) } else { 0 }
    $snapshots = @(foreach($process in @(Get-Process -ErrorAction Stop)){
        $snapshot=ConvertTo-NyxProcessSnapshot $process
        if($null -ne $snapshot){$snapshot}
    })
    $topCpu = @($snapshots | Where-Object {$null -ne $_.CPU} | Sort-Object CPU -Descending | Select-Object -First 8)
    $topMemory = @($snapshots | Where-Object {$null -ne $_.WorkingSet64} | Sort-Object WorkingSet64 -Descending | Select-Object -First 8)
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

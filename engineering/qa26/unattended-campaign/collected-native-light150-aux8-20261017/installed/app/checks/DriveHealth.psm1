Set-StrictMode -Version 2.0
function Get-NyxDriveHealthCheck {
    try{$drives=@(Get-PhysicalDisk -ErrorAction Stop)}catch{return New-NyxUnknownResult -CheckId 'drive.health' -Category 'Drive Health' -Name 'Physical drive health' -Reason $_.Exception.Message -DataSource 'Windows Storage module'}
    if($drives.Count -eq 0){return New-NyxUnknownResult -CheckId 'drive.health' -Category 'Drive Health' -Name 'Physical drive health' -Reason 'Windows returned no physical-drive records.' -DataSource 'Get-PhysicalDisk'}
    $details=[System.Collections.Generic.List[object]]::new();$warning=$false;$unknown=$false
    foreach($drive in $drives){
        $temperature=$null;$wear=$null;$readErrors=$null
        try{$rel=Get-StorageReliabilityCounter -PhysicalDisk $drive -ErrorAction Stop;$temperature=$rel.Temperature;$wear=$rel.Wear;$readErrors=$rel.ReadErrorsTotal}catch{}
        $health=[string]$drive.HealthStatus;$ops=@($drive.OperationalStatus|ForEach-Object{[string]$_})
        if($health -in @('Warning','Unhealthy') -or @($ops|Where-Object{$_ -in @('Degraded','Error','Predictive Failure','Lost Communication','Stale Metadata','Starting','Stopping')}).Count -gt 0){$warning=$true}
        elseif([string]::IsNullOrWhiteSpace($health) -or $health -eq 'Unknown'){$unknown=$true}
        $details.Add([pscustomobject]@{FriendlyName=[string]$drive.FriendlyName;MediaType=[string]$drive.MediaType;CapacityBytes=[int64]$drive.Size;HealthStatus=$health;OperationalStatus=$ops;TemperatureC=$temperature;WearPercent=$wear;ReadErrorsTotal=$readErrors})
    }
    if($warning){return New-NyxCheckResult -CheckId 'drive.health' -Category 'Drive Health' -Name 'Physical drive health' -Status 'NeedsAttention' -Severity 'High' -Finding 'Windows reported a warning or non-healthy state for at least one physical drive.' -Reason 'Drive-health warnings can precede failure, but they are not a prediction of the exact failure time.' -Evidence @($details.ToArray()) -Recommendation 'Prioritize a current backup and have the affected drive evaluated.' -DataSource 'Get-PhysicalDisk / Get-StorageReliabilityCounter' -Details @($details.ToArray())}
    if($unknown){return New-NyxCheckResult -CheckId 'drive.health' -Category 'Drive Health' -Name 'Physical drive health' -Status 'Unknown' -Severity 'Info' -Finding 'Windows returned incomplete drive-health status for at least one physical drive.' -Reason 'No failure warning was reported, but the available status was not complete enough to call every drive healthy.' -Evidence @($details.ToArray()) -Recommendation 'Keep normal backups and consult the drive manufacturer tool if you need deeper diagnostics.' -DataSource 'Get-PhysicalDisk / Get-StorageReliabilityCounter' -Complete $false -ErrorReason 'One or more drive health states were Unknown.' -Details @($details.ToArray())}
    return New-NyxCheckResult -CheckId 'drive.health' -Category 'Drive Health' -Name 'Physical drive health' -Status 'Good' -Severity 'Info' -Finding 'No drive-health warning was reported.' -Reason 'All physical drives returned a Healthy state through the available Windows Storage interface.' -Evidence @($details.ToArray()) -Recommendation 'Continue normal backups. A healthy status does not guarantee that a drive cannot fail.' -DataSource 'Get-PhysicalDisk / Get-StorageReliabilityCounter' -Details @($details.ToArray())
}

Export-ModuleMember -Function Get-NyxDriveHealthCheck

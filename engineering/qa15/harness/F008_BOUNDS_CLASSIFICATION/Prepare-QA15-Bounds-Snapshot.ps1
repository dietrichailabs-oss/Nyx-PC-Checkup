$ErrorActionPreference = 'Stop'
$output = Join-Path $PSScriptRoot 'QA15_BOUNDS_VM_PREPARATION.json'
$record = [ordered]@{ StartedUtc = [DateTime]::UtcNow.ToString('o'); VM = 'Nyx'; Status = 'STARTED'; CandidateModified = $false }
try {
    $vm = Get-VM -Name 'Nyx'
    $baseline = Get-VMSnapshot -VM $vm | Where-Object Id -eq '07126637-ce84-43cc-a69b-fb4ae445f9ce'
    if (-not $baseline) { throw 'Specified pretest snapshot is unavailable.' }
    $name = 'QA15_BEFORE_BOUNDS_CLASSIFICATION_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
    $recovery = Checkpoint-VM -VM $vm -SnapshotName $name -Passthru
    $record.RecoveryCheckpoint = $recovery.Name
    $record.RecoveryCheckpointId = [string]$recovery.Id
    $record.Status = 'RECOVERY_CHECKPOINT_CREATED'
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding UTF8
    # Preserve the current guest before selecting the existing pretest baseline.
    Stop-VM -VM $vm -TurnOff -Confirm:$false
    Restore-VMSnapshot -VMSnapshot $baseline -Confirm:$false
    $record.Baseline = $baseline.Name
    $record.BaselineId = [string]$baseline.Id
    $record.Status = 'BASELINE_RESTORED_PENDING_INSPECTION'
    $record.Disks = @(Get-VMHardDiskDrive -VMName 'Nyx' | Select-Object Path,ControllerType,ControllerNumber,ControllerLocation)
} catch {
    $record.Status = 'BLOCKED'
    $record.Error = $_.Exception.ToString()
} finally {
    $record.CompletedUtc = [DateTime]::UtcNow.ToString('o')
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $output -Encoding UTF8
}

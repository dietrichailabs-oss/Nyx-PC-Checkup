$ErrorActionPreference='Stop'
$output=Join-Path $PSScriptRoot 'QA15_BOUNDS_RESTAGING.json'
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id-ne'275a191c-cf8a-4929-9849-b9a293e9149d'-or$vm.State-ne'Off'){throw 'Expected exact powered-off QA VM.'}
    $baseline=Get-VMSnapshot -VM $vm | Where-Object Id -eq '07126637-ce84-43cc-a69b-fb4ae445f9ce'
    if(-not$baseline){throw 'Pretest baseline missing.'}
    Restore-VMSnapshot -VMSnapshot $baseline -Confirm:$false
    & (Join-Path $PSScriptRoot 'Stage-QA15-BoundsGuest.ps1')
    if((Get-VM -Name Nyx).State-eq'Saved'){
        & (Join-Path $PSScriptRoot 'ColdStart-QA15-BoundsVM.ps1')
    }
    [ordered]@{Status='RESTAGING_FINISHED';RecordedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $output -Encoding UTF8
} catch {
    [ordered]@{Status='BLOCKED';Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $output -Encoding UTF8
}

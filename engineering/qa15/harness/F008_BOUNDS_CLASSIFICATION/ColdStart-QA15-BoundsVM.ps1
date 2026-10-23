$ErrorActionPreference='Stop'
$output=Join-Path $PSScriptRoot 'QA15_BOUNDS_COLD_START.json'
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id-ne'275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch.'}
    if($vm.State-ne'Saved'){throw "Expected Saved state; observed $($vm.State)."}
    Remove-VMSavedState -VM $vm -Confirm:$false
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    do {
        Start-Sleep -Seconds 1
        $vm=Get-VM -Name Nyx
    } while($vm.State-ne'Off'-and[DateTime]::UtcNow-lt$deadline)
    if($vm.State-ne'Off'){throw "Guest did not reach Off: $($vm.State)"}
    Start-VM -VM $vm
    [ordered]@{Status='COLD_START_REQUESTED';State=[string](Get-VM -Name Nyx).State} | ConvertTo-Json | Set-Content -LiteralPath $output -Encoding UTF8
} catch {
    [ordered]@{Status='BLOCKED';Error=$_.Exception.ToString()} | ConvertTo-Json | Set-Content -LiteralPath $output -Encoding UTF8
}

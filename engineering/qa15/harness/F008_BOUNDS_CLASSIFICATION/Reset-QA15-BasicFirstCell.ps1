$ErrorActionPreference='Stop'
$status=Join-Path $PSScriptRoot 'QA15_BASIC_FIRST_CELL_RESET.json'
try {
    $vm=Get-VM -Name Nyx
    if([string]$vm.Id-ne'275a191c-cf8a-4929-9849-b9a293e9149d'){throw 'VM identity mismatch.'}
    if($vm.State-ne'Off') {
        $job=Stop-VM -VM $vm -AsJob -Confirm:$false
        if(-not(Wait-Job -Job $job -Timeout 45)){throw 'Guest shutdown timed out; no snapshot restored.'}
        Receive-Job -Job $job -ErrorAction Stop | Out-Null
    }
    & (Join-Path $PSScriptRoot 'Restage-QA15-BoundsObserver.ps1')
    # Hyper-V can report the failed memory restore before publishing Saved.
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Seconds 2
        $vm=Get-VM -Name Nyx
        if($vm.State-eq'Saved') {
            & (Join-Path $PSScriptRoot 'ColdStart-QA15-BoundsVM.ps1')
            $vm=Get-VM -Name Nyx
        }
    } while($vm.State-ne'Running'-and[DateTime]::UtcNow-lt$deadline)
    if($vm.State-ne'Running'){throw "Guest state after reset: $($vm.State)"}
    [ordered]@{Status='RUNNING_AWAITING_BASIC_SESSION';VM='Nyx';TimeUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8
} catch {
    [ordered]@{Status='BLOCKED';Error=$_.Exception.ToString();TimeUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding UTF8
}

Set-StrictMode -Version 2.0
function Get-NyxPendingUpdateSnapshot {
    $job = Start-Job -ScriptBlock {
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $searcher.Online = $false
            $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
            [pscustomobject]@{ Success=$true; Count=[int]$result.Updates.Count; Error='' }
        } catch { [pscustomobject]@{ Success=$false; Count=0; Error=$_.Exception.Message } }
    }
    try {
        if (Wait-Job -Job $job -Timeout 12) {
            return Receive-Job -Job $job
        }
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        return [pscustomobject]@{ Success=$false; Count=0; Error='The local Windows Update query did not finish within 12 seconds.' }
    } finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
}

function Get-NyxWindowsUpdateChecks {
    $results = [System.Collections.Generic.List[object]]::new()
    $restart = Get-NyxRestartPending
    if ($restart.Pending) {
        $results.Add((New-NyxCheckResult -CheckId 'updates.restart' -Category 'Updates' -Name 'Update restart' -Status 'NeedsAttention' -Severity 'Medium' `
            -Finding 'A restart is required to finish one or more Windows changes.' -Reason 'Windows reported a pending restart.' -Evidence $restart `
            -Recommendation 'Save your work and restart when convenient.' -ActionSafetyLevel 'SafeRedirect' -DataSource 'Windows servicing registry' -Complete ([bool]$restart.Complete)))
    } elseif (-not [bool]$restart.Complete) {
        $results.Add((New-NyxUnknownResult -CheckId 'updates.restart' -Category 'Updates' -Name 'Update restart' -Reason 'One or more supported restart-pending markers could not be read.' -DataSource 'Windows servicing registry'))
    } else {
        $results.Add((New-NyxCheckResult -CheckId 'updates.restart' -Category 'Updates' -Name 'Update restart' -Status 'Good' -Severity 'Info' `
            -Finding 'Windows does not currently report a pending restart.' -Reason 'No supported restart-pending marker was found.' -Evidence $restart `
            -Recommendation 'No restart is required by the checked Windows servicing markers.' -ActionSafetyLevel 'SafeRedirect' -DataSource 'Windows servicing registry'))
    }
    $pending = Get-NyxPendingUpdateSnapshot
    if ($pending.Success) {
        if ([int]$pending.Count -gt 0) {
            $results.Add((New-NyxCheckResult -CheckId 'updates.pending' -Category 'Updates' -Name 'Windows updates' -Status 'NeedsAttention' -Severity 'Medium' `
                -Finding "$($pending.Count) software update(s) appear pending in the local Windows Update cache." `
                -Reason 'Windows Update returned locally cached, not-installed updates.' -Evidence $pending `
                -Recommendation 'Open Windows Update and let Windows verify and install the updates.' -ActionSafetyLevel 'SafeRedirect' -DataSource 'Microsoft.Update.Session local search'))
        } else {
            $results.Add((New-NyxCheckResult -CheckId 'updates.pending' -Category 'Updates' -Name 'Windows updates' -Status 'Good' -Severity 'Info' `
                -Finding 'No pending software update was found in the local Windows Update cache.' `
                -Reason 'The supported local update query returned zero not-installed software updates.' -Evidence $pending `
                -Recommendation 'Open Windows Update for an online check when you need full patch assurance.' -ActionSafetyLevel 'SafeRedirect' -DataSource 'Microsoft.Update.Session local search'))
        }
    } else {
        $results.Add((New-NyxUnknownResult -CheckId 'updates.pending' -Category 'Updates' -Name 'Windows updates' -Reason $pending.Error -DataSource 'Microsoft.Update.Session local search'))
    }
    try {
        $auto = New-Object -ComObject Microsoft.Update.AutoUpdate
        $last = $auto.Results.LastInstallationSuccessDate
        if ($last -and [datetime]$last -gt [datetime]'2000-01-01') {
            $results.Add((New-NyxCheckResult -CheckId 'updates.last-success' -Category 'Updates' -Name 'Last successful Windows update' -Status 'Good' -Severity 'Info' `
                -Finding ("Windows reports a successful installation on {0}." -f ([datetime]$last).ToString('D')) `
                -Reason 'The Windows Update automatic-update result exposed a last success date.' -Evidence ([pscustomobject]@{ LastSuccessUtc=([datetime]$last).ToUniversalTime().ToString('o') }) `
                -Recommendation 'No action is required based on this timestamp alone.' -DataSource 'Microsoft.Update.AutoUpdate'))
        }
    } catch { }
    return @($results.ToArray())
}

Export-ModuleMember -Function Get-NyxPendingUpdateSnapshot,Get-NyxWindowsUpdateChecks

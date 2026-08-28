Set-StrictMode -Version 2.0
function Get-NyxBackupStatusCheck {
    $evidence=[System.Collections.Generic.List[object]]::new()
    $detected=$false;$recentSuccess=$false;$sourcesAttempted=0;$sourcesAvailable=0
    $fileHistoryConfig=Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\FileHistory\Configuration'
    $sourcesAttempted++
    try{
        if(Test-Path -LiteralPath $fileHistoryConfig -PathType Container){
            $sourcesAvailable++
            $configs=@(Get-ChildItem -LiteralPath $fileHistoryConfig -Filter '*.xml' -File -ErrorAction Stop)
            if($configs.Count -gt 0){
                $detected=$true;$latest=$configs|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
                $evidence.Add([pscustomobject]@{Type='File History configuration';LastModifiedUtc=$latest.LastWriteTimeUtc.ToString('o');Note='Configuration activity is not treated as proof of a successful backup.'})
            }
        }else{$sourcesAvailable++}
    }catch{}
    $sourcesAttempted++
    try{
        $tasks=@(Get-ScheduledTask -TaskPath '\Microsoft\Windows\WindowsBackup\' -ErrorAction Stop);$sourcesAvailable++
        if($tasks.Count -gt 0){
            $detected=$true
            foreach($task in $tasks){
                $info=Get-ScheduledTaskInfo -InputObject $task -ErrorAction SilentlyContinue
                if($info -and $info.LastRunTime -gt [datetime]'2000-01-01'){
                    $isRecent=((Get-Date)-$info.LastRunTime).TotalDays -le 30
                    $succeeded=([int]$info.LastTaskResult -eq 0)
                    if($isRecent -and $succeeded){$recentSuccess=$true}
                    $evidence.Add([pscustomobject]@{Type='Windows Backup task';Name=$task.TaskName;LastRunUtc=$info.LastRunTime.ToUniversalTime().ToString('o');LastResult=[int]$info.LastTaskResult;RecentWithin30Days=$isRecent;ReportedSuccess=$succeeded})
                }
            }
        }
    }catch{}
    if($recentSuccess){
        return New-NyxCheckResult -CheckId 'backup.status' -Category 'Backup' -Name 'Backup checkup' -Status 'Good' -Severity 'Info' `
            -Finding 'A recent successful Windows Backup task indicator was detected.' -Reason 'A supported Windows Backup task reported result 0 within 30 days.' `
            -Evidence @($evidence.ToArray()) -Recommendation 'Confirm occasionally that the backup destination is available and that files can be restored.' `
            -ActionSafetyLevel 'SafeRedirect' -DataSource 'File History configuration and Windows Backup scheduled tasks'
    }
    if($detected){
        return New-NyxCheckResult -CheckId 'backup.status' -Category 'Backup' -Name 'Backup checkup' -Status 'NeedsAttention' -Severity 'Medium' `
            -Finding 'A Windows backup configuration was found, but a recent successful backup could not be confirmed.' `
            -Reason 'Configuration alone is not proof of a successful backup, and no supported task reported recent success.' -Evidence @($evidence.ToArray()) `
            -Recommendation 'Open Windows Backup or File History and verify that backups are completing and restorable.' -ActionSafetyLevel 'SafeRedirect' `
            -DataSource 'File History configuration and Windows Backup scheduled tasks' -Complete ($sourcesAvailable -eq $sourcesAttempted)
    }
    if($sourcesAvailable -eq 0){
        return New-NyxUnknownResult -CheckId 'backup.status' -Category 'Backup' -Name 'Backup checkup' -Reason 'Supported Windows backup indicators were unavailable. A third-party backup may also be in use.' -DataSource 'File History configuration and Windows Backup scheduled tasks'
    }
    return New-NyxCheckResult -CheckId 'backup.status' -Category 'Backup' -Name 'Backup checkup' -Status 'NeedsAttention' -Severity 'Medium' `
        -Finding 'No supported Windows backup configuration was detected.' `
        -Reason 'Nyx could not find File History or Windows Backup evidence. You may already use another backup service that Nyx PC Checkup cannot detect.' `
        -Evidence @($evidence.ToArray()) -Recommendation 'Verify that important files are backed up somewhere separate from this PC.' `
        -ActionSafetyLevel 'SafeRedirect' -DataSource 'File History configuration and Windows Backup scheduled tasks' -Complete ($sourcesAvailable -eq $sourcesAttempted)
}

Export-ModuleMember -Function Get-NyxBackupStatusCheck

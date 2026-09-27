param([Parameter(Mandatory=$true)][string]$Evidence)
Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$data=Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$temp=Join-Path $data 'temp'
$last=Join-Path $data 'scans\last-scan.json'
$seen=@{}
$counts=@{}
$nextProcess=[DateTime]::MinValue
$baseline=if(Test-Path -LiteralPath $last){(Get-FileHash -LiteralPath $last).Hash}else{''}
function Read-Shared([string]$Path){
    $stream=$null;$reader=$null
    try{
        $stream=[IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
        return $reader.ReadToEnd()
    }finally{if($reader){$reader.Dispose()}elseif($stream){$stream.Dispose()}}
}
function Record([string]$Name,$Value){
    $Value|ConvertTo-Json -Depth 12 -Compress|Add-Content -LiteralPath (Join-Path $Evidence $Name) -Encoding UTF8
}
try{
    [ordered]@{Status='MONITORING';PID=$PID;PS=$PSVersionTable.PSVersion.ToString();Started=(Get-Date).ToString('o');BaselineHash=$baseline;PollingDelayMs=10;ProductModified=$false}|ConvertTo-Json|Set-Content "$Evidence\OBSERVER_STATUS.json"
    while(-not(Test-Path -LiteralPath 'C:\Q19F016\STOP_OBSERVER')){
        if(Test-Path -LiteralPath $temp){
            foreach($file in @(Get-ChildItem -LiteralPath $temp -File -Filter '*.jsonl')){
                if(-not $counts.ContainsKey($file.Name)){$counts[$file.Name]=0}
                try{
                    $text=Read-Shared $file.FullName
                    $counts[$file.Name]++
                    if($counts[$file.Name] % 50 -eq 1){
                        Record 'PROGRESS_READS.jsonl' ([ordered]@{Time=(Get-Date).ToString('o');File=$file.Name;Reads=$counts[$file.Name];Characters=$text.Length;CompleteLines=@($text -split "`n").Count-1})
                        [IO.File]::WriteAllText((Join-Path $Evidence ($file.Name+'.snapshot')),$text)
                    }
                }catch{Record 'READ_ERRORS.jsonl' @{Time=(Get-Date).ToString('o');File=$file.Name;Error=$_.Exception.ToString()}}
            }
        }
        if([DateTime]::UtcNow -ge $nextProcess){
            $workers=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -match 'ScanWorker\.ps1'}|Select-Object ProcessId,ParentProcessId,CommandLine,CreationDate)
            $files=@(if(Test-Path -LiteralPath $temp){Get-ChildItem -LiteralPath $temp -File -Filter 'scan-*'|Select-Object Name,Length,LastWriteTimeUtc})
            Record 'LIVE_CLEANUP.jsonl' ([ordered]@{Time=(Get-Date).ToString('o');Workers=$workers;ScanArtifacts=$files;GuestRunning=$true;ObserverHandlesDisposed=$true})
            $counts|ConvertTo-Json|Set-Content "$Evidence\READ_COUNTS.json"
            if(Test-Path -LiteralPath $last){
                $raw=Read-Shared $last
                $sha=[Security.Cryptography.SHA256]::Create()
                try{$hash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw)))).Replace('-','')}finally{$sha.Dispose()}
                if(-not $seen.ContainsKey($hash)){
                    $seen[$hash]=$true
                    $capture=Join-Path $Evidence ("RESULT_"+$hash+'.json')
                    [IO.File]::WriteAllText($capture,$raw)
                    $errors=New-Object 'System.Collections.Generic.List[string]'
                    $scan=$null
                    try{
                        $scan=$raw|ConvertFrom-Json
                        foreach($field in @('Schema','Mode','StartedUtc','CompletedUtc','Cancelled','ReadOnly','Results')){if($scan.PSObject.Properties.Name -notcontains $field){$errors.Add("Missing $field")}}
                        if($errors.Count -eq 0){
                            if($scan.Schema -ne 'dietrich-ai-labs.nyx-pc-checkup.scan.v1'){$errors.Add('Schema')}
                            if($scan.Mode -notin @('Quick','Full')){$errors.Add('Mode')}
                            $start=[datetime]::MinValue;$end=[datetime]::MinValue
                            if(-not [datetime]::TryParse([string]$scan.StartedUtc,[ref]$start)){$errors.Add('StartedUtc')}
                            if(-not [datetime]::TryParse([string]$scan.CompletedUtc,[ref]$end)){$errors.Add('CompletedUtc')}
                            if($end -lt $start){$errors.Add('Timestamp order')}
                            if($scan.ReadOnly -isnot [bool] -or -not $scan.ReadOnly){$errors.Add('ReadOnly')}
                            if($scan.Cancelled -isnot [bool]){$errors.Add('Cancelled')}
                            if($null -eq $scan.Results){$errors.Add('Null Results')}
                            foreach($result in @($scan.Results)){
                                foreach($field in @('CheckId','Category','Name','Status','Severity','Finding','Reason','Recommendation','Complete')){if($null -eq $result -or $result.PSObject.Properties.Name -notcontains $field){$errors.Add("Result missing $field")}}
                                if($errors.Count -eq 0){
                                    if($result.Status -notin @('Good','NeedsAttention','Optional','Unknown')){$errors.Add('Result Status')}
                                    if($result.Severity -notin @('Info','Low','Medium','High')){$errors.Add('Result Severity')}
                                    if($result.Complete -isnot [bool]){$errors.Add('Result Complete')}
                                }
                            }
                        }
                        if($scan.PSObject.Properties.Name -contains 'WorkerError' -and $scan.WorkerError){$errors.Add('WorkerError: '+$scan.WorkerError)}
                    }catch{$errors.Add($_.Exception.Message)}
                    Record 'RESULT_VALIDATION.jsonl' ([ordered]@{Time=(Get-Date).ToString('o');File=[IO.Path]::GetFileName($capture);Hash=$hash;Errors=@($errors.ToArray());Valid=($errors.Count -eq 0);WorkersAtCapture=$workers;Note='First capture may be pre-existing baseline; expected cancellation must be correlated with UI evidence'})
                    if($errors.Count -gt 0 -and $workers.Count -eq 0){throw 'Invalid persisted result while worker absent; stop and review captured evidence'}
                }
            }
            $nextProcess=[DateTime]::UtcNow.AddSeconds(1)
        }
        Start-Sleep -Milliseconds 10
    }
}catch{[ordered]@{Status='STOPPED_REVIEW_REQUIRED';Error=$_.Exception.ToString();Time=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content "$Evidence\OBSERVER_STATUS.json"}

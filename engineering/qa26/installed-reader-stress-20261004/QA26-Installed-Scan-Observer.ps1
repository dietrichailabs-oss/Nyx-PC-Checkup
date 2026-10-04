Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($env:USERNAME -ne 'Nyx') { throw 'Disposable Nyx profile required.' }
$install = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$workerPath = Join-Path $install 'app\workers\ScanWorker.ps1'
$mainPath = Join-Path $install 'app\NyxPCCheckup.ps1'
if ((Get-FileHash -LiteralPath $workerPath).Hash -ne '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79') { throw 'Worker identity mismatch.' }
if ((Get-FileHash -LiteralPath $mainPath).Hash -ne 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC') { throw 'Main identity mismatch.' }
$data = Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$temp = Join-Path $data 'temp'
$out = Join-Path (Join-Path $env:LOCALAPPDATA 'NyxQA26InstalledScanObserver') (Get-Date -Format yyyyMMdd_HHmmss)
New-Item -ItemType Directory -Path $out -Force | Out-Null
$script:eventPath = Join-Path $out 'EVENTS.jsonl'
$script:utf8 = New-Object Text.UTF8Encoding($false)
function Write-Event($name, $details) {
    $line = [ordered]@{Utc=[DateTime]::UtcNow.ToString('o');Event=$name;Details=$details} | ConvertTo-Json -Depth 8 -Compress
    [IO.File]::AppendAllText($script:eventPath, $line + [Environment]::NewLine, $script:utf8)
}
function Read-SharedBytes([string]$path) {
    $stream = $null
    $memory = $null
    try {
        $stream = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $memory = New-Object IO.MemoryStream
        $stream.CopyTo($memory)
        return ,$memory.ToArray()
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($memory) { $memory.Dispose() }
    }
}
$lastScan = Join-Path $data 'scans\last-scan.json'
$start = [DateTime]::UtcNow
$end = $start.AddMinutes(30)
$workers = @{}
$seenResults = @{}
$reads = 0L
$bytesRead = 0L
$ioRetries = 0L
$sequence = 0
$nextPoll = $start
$nextHeartbeat = $start.AddSeconds(5)
$sha = [Security.Cryptography.SHA256]::Create()
Write-Event 'START' @{ProductModified=$false;ActualProgressDirectory=$temp;ReadShare='ReadWrite|Delete';MonitorMinutes=30;NoWorkerPause=$true}
try {
    while ([DateTime]::UtcNow -lt $end) {
        $now = [DateTime]::UtcNow
        if ($now -ge $nextPoll) {
            $processes = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'")
            $active = @($processes | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($workerPath,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
            foreach ($w in $active) {
                $parent = @($processes | Where-Object ProcessId -eq $w.ParentProcessId)
                if ($parent.Count -ne 1 -or !$parent[0].CommandLine -or $parent[0].CommandLine.IndexOf($mainPath,[StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
                $key = [string]$w.ProcessId + '|' + $w.CreationDate.ToUniversalTime().ToString('o')
                if (!$workers.ContainsKey($key)) {
                    $workers[$key] = @{Pid=[int]$w.ProcessId;Exited=$false;CreationUtc=$w.CreationDate.ToUniversalTime().ToString('o')}
                    Write-Event 'INSTALLED_WORKER_START' @{WorkerPid=$w.ProcessId;ParentPid=$w.ParentProcessId;CreationUtc=$workers[$key].CreationUtc;CommandLine=$w.CommandLine;ReadsSoFar=$reads}
                }
            }
            foreach ($key in @($workers.Keys)) {
                if (!$workers[$key].Exited -and @($active | Where-Object ProcessId -eq $workers[$key].Pid).Count -eq 0) {
                    $workers[$key].Exited = $true
                    Write-Event 'INSTALLED_WORKER_EXIT' @{WorkerPid=$workers[$key].Pid;CreationUtc=$workers[$key].CreationUtc;ReadsSoFar=$reads}
                }
            }
            if (Test-Path -LiteralPath $lastScan) {
                try {
                    $raw = Read-SharedBytes $lastScan
                    $hash = [BitConverter]::ToString($sha.ComputeHash($raw)).Replace('-','')
                    if (!$seenResults.ContainsKey($hash)) {
                        $json = [Text.Encoding]::UTF8.GetString($raw).TrimStart([char]0xFEFF) | ConvertFrom-Json
                        if ([DateTime]::Parse([string]$json.StartedUtc).ToUniversalTime() -ge $start.AddSeconds(-2)) {
                            $sequence++
                            $name = 'SCAN_' + $sequence.ToString('000') + '_RAW.json'
                            [IO.File]::WriteAllBytes((Join-Path $out $name),$raw)
                            $seenResults[$hash] = $true
                            Write-Event 'AUTHORITATIVE_RESULT_CAPTURE' @{RawPath=$name;SHA256=$hash;Mode=$json.Mode;StartedUtc=$json.StartedUtc;CompletedUtc=$json.CompletedUtc;Cancelled=$json.Cancelled;ReadOnly=$json.ReadOnly;Results=@($json.Results).Count;WorkerError=$json.WorkerError;Validation='Host contract validation required'}
                            if ($json.WorkerError) {
                                Write-Event 'PRODUCT_FAILURE_CANDIDATE_STOP' @{RawPath=$name;WorkerError=$json.WorkerError}
                                break
                            }
                        }
                    }
                } catch [IO.IOException] { $ioRetries++ }
                catch [ArgumentException] { Write-Event 'EVIDENCE_PARSE_RETRY' @{Error=$_.Exception.Message} }
            }
            $inventory = @(Get-ChildItem -LiteralPath $temp -File -ErrorAction Stop | Select-Object Name,Length)
            $app = @($processes | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainPath,[StringComparison]::OrdinalIgnoreCase) -ge 0 })
            Write-Event 'LIVE_STATE' @{ActiveInstalledWorkers=@($active | Select-Object ProcessId,ParentProcessId);AppPids=@($app | ForEach-Object ProcessId);TempArtifacts=$inventory;Reads=$reads;BytesRead=$bytesRead;IORetries=$ioRetries}
            $nextPoll = [DateTime]::UtcNow.AddMilliseconds(500)
        }
        $progress = @(Get-ChildItem -LiteralPath $temp -File -Filter '*-progress.jsonl' -ErrorAction Stop)
        foreach ($file in $progress) {
            for ($i=0; $i -lt 20; $i++) {
                try {
                    $rawProgress = Read-SharedBytes $file.FullName
                    $reads++
                    $bytesRead += $rawProgress.Length
                } catch [IO.IOException] { $ioRetries++ }
            }
        }
        if ([DateTime]::UtcNow -ge $nextHeartbeat) {
            Write-Event 'READER_HEARTBEAT' @{Reads=$reads;BytesRead=$bytesRead;IORetries=$ioRetries;TrackedWorkers=$workers.Count;SavedResults=$sequence}
            $nextHeartbeat = [DateTime]::UtcNow.AddSeconds(5)
        }
        Start-Sleep -Milliseconds 10
    }
} finally {
    $sha.Dispose()
    Write-Event 'END' @{Reads=$reads;BytesRead=$bytesRead;IORetries=$ioRetries;SavedResults=$sequence;ProductModified=$false}
}

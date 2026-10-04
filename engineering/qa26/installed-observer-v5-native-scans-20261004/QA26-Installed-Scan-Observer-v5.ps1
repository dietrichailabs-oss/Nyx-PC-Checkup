$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:USERNAME -ne 'Nyx') { throw 'Disposable Nyx guest required' }
$install = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$main = Join-Path $install 'app\NyxPCCheckup.ps1'
$worker = Join-Path $install 'app\workers\ScanWorker.ps1'
$exe = Join-Path $install 'Nyx PC Checkup.exe'
$expected = @{
    'app\NyxPCCheckup.ps1' = 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC'
    'app\workers\ScanWorker.ps1' = '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79'
    'Nyx PC Checkup.exe' = '9B20E399C090EEAC78F6B257610EF915852A30BAA52BB31D7546C5783052CB75'
}
foreach ($entry in $expected.GetEnumerator()) {
    if ((Get-FileHash -LiteralPath (Join-Path $install $entry.Key) -Algorithm SHA256).Hash -ne $entry.Value) { throw ('Frozen identity mismatch: ' + $entry.Key) }
}
$data = Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$temp = Join-Path $data 'temp'
$last = Join-Path $data 'scans\last-scan.json'
$out = Join-Path $env:LOCALAPPDATA ('NyxQA26InstalledScanObserverV5\' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $out -Force | Out-Null
$events = Join-Path $out 'EVENTS.jsonl'
$utf8 = New-Object Text.UTF8Encoding($false)
function Write-Event([string]$Name, $Details) {
    $line = [ordered]@{Utc=[DateTime]::UtcNow.ToString('o'); Event=$Name; Details=$Details} | ConvertTo-Json -Depth 15 -Compress
    [IO.File]::AppendAllText($events, $line + [Environment]::NewLine, $utf8)
}
function Read-Shared([string]$Path) {
    $stream = $null
    $memory = New-Object IO.MemoryStream
    try {
        $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $stream.CopyTo($memory)
        return ,$memory.ToArray()
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        $memory.Dispose()
    }
}
function Process-Record($Process) {
    return [ordered]@{Pid=[int]$Process.ProcessId; ParentPid=[int]$Process.ParentProcessId; Name=$Process.Name; ExecutablePath=$Process.ExecutablePath; CommandLine=$Process.CommandLine; CreationUtc=([DateTime]$Process.CreationDate).ToUniversalTime().ToString('o')}
}
$startup = [Environment]::GetFolderPath('Startup')
$startupEvidence = @()
if ($startup -and (Test-Path -LiteralPath $startup)) {
    foreach ($file in @(Get-ChildItem -LiteralPath $startup -File)) {
        $record = [ordered]@{Name=$file.Name; SHA256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash; Bytes=$file.Length}
        if ($file.Extension -in @('.cmd','.bat','.ps1')) { $record['Content'] = [IO.File]::ReadAllText($file.FullName) }
        $startupEvidence += $record
    }
}
$startupEvidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $out 'STARTUP_PROVENANCE.json') -Encoding UTF8
$began = [DateTime]::UtcNow
$deadline = $began.AddMinutes(30)
$knownWorkers = @{}
$seenResults = @{}
$sequence = 0
$reads = 0L
$bytesRead = 0L
$ioRetries = 0L
$parseRetries = 0L
$nextPoll = [DateTime]::MinValue
$nextLive = [DateTime]::MinValue
$allProcesses = @()
$activeWorkers = @()
$appCandidates = @()
$lastProcessFingerprint = ''
$sha = [Security.Cryptography.SHA256]::Create()
Write-Event 'START' @{ProductModified=$false; Revision='QA26-EVIDENCE-OBSERVER-V5'; InstalledMain=$main; InstalledWorker=$worker; InstalledExe=$exe; ExpectedHashes=$expected; ReadShare='ReadWrite|Delete'; NoWorkerPause=$true}
try {
    while ([DateTime]::UtcNow -lt $deadline) {
        if ([DateTime]::UtcNow -ge $nextPoll) {
            $allProcesses = @(Get-CimInstance Win32_Process)
            $byPid = @{}
            foreach ($process in $allProcesses) { $byPid[[int]$process.ProcessId] = $process }
            $powershell = @($allProcesses | Where-Object { $_.Name -ieq 'powershell.exe' })
            $activeWorkers = @($powershell | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($worker, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
            $appCandidates = @($powershell | Where-Object { $_.CommandLine -and $_.CommandLine -match '(?i)NyxPCCheckup\.ps1' })
            $processContext = @($appCandidates | ForEach-Object { Process-Record $_ })
            $fingerprint = ($processContext | ConvertTo-Json -Depth 8 -Compress)
            if ($fingerprint -ne $lastProcessFingerprint) {
                Write-Event 'APP_PROCESS_CONTEXT' @{Candidates=$processContext; NativeLaunchNotAssumedFromRelativeScriptName=$true}
                $lastProcessFingerprint = $fingerprint
            }
            foreach ($process in $activeWorkers) {
                $key = '{0}:{1}' -f $process.ProcessId, $process.CreationDate
                if (!$knownWorkers.ContainsKey($key)) {
                    $ancestry = @()
                    $ancestorId = [int]$process.ParentProcessId
                    $visited = @{}
                    for ($level=0; $level -lt 6; $level++) {
                        if (!$byPid.ContainsKey($ancestorId) -or $visited.ContainsKey($ancestorId)) { break }
                        $visited[$ancestorId] = $true
                        $ancestor = $byPid[$ancestorId]
                        $ancestry += (Process-Record $ancestor)
                        $ancestorId = [int]$ancestor.ParentProcessId
                    }
                    $nativeAncestor = @($ancestry | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -ieq $exe }).Count -gt 0
                    $detail = @{Worker=(Process-Record $process); Ancestors=$ancestry; ExactInstalledWorker=$true; InstalledNativeLauncherAncestorObserved=$nativeAncestor; ReadsSoFar=$reads}
                    $knownWorkers[$key] = @{Pid=[int]$process.ProcessId; Creation=$process.CreationDate; Exited=$false}
                    Write-Event 'INSTALLED_WORKER_START' $detail
                }
            }
            foreach ($key in @($knownWorkers.Keys)) {
                $record = $knownWorkers[$key]
                $sameProcess = $byPid.ContainsKey($record.Pid) -and $byPid[$record.Pid].CreationDate -eq $record.Creation
                if (!$record.Exited -and !$sameProcess) {
                    $record.Exited = $true
                    Write-Event 'INSTALLED_WORKER_EXIT' @{WorkerPid=$record.Pid; ReadsSoFar=$reads}
                }
            }
            $nextPoll = [DateTime]::UtcNow.AddMilliseconds(500)
        }
        if (Test-Path -LiteralPath $last) {
            try {
                $raw = Read-Shared $last
                $hash = ([BitConverter]::ToString($sha.ComputeHash($raw))).Replace('-','')
                if (!$seenResults.ContainsKey($hash)) {
                    try { $json = $utf8.GetString($raw).TrimStart([char]0xFEFF) | ConvertFrom-Json -ErrorAction Stop }
                    catch [ArgumentException] { $parseRetries++; $json=$null }
                    if ($null -ne $json -and [DateTimeOffset]::Parse([string]$json.StartedUtc, [Globalization.CultureInfo]::InvariantCulture).UtcDateTime -ge $began.AddSeconds(-2)) {
                        $sequence++
                        $file = 'SCAN_{0:000}_RAW.json' -f $sequence
                        [IO.File]::WriteAllBytes((Join-Path $out $file),$raw)
                        $seenResults[$hash] = $true
                        $workerError = $null
                        if ($null -ne $json.PSObject.Properties['WorkerError']) { $workerError = $json.PSObject.Properties['WorkerError'].Value }
                        Write-Event 'AUTHORITATIVE_RESULT_CAPTURE' @{RawPath=$file; SHA256=$hash; Mode=$json.Mode; StartedUtc=$json.StartedUtc; CompletedUtc=$json.CompletedUtc; Cancelled=$json.Cancelled; ReadOnly=$json.ReadOnly; Results=@($json.Results).Count; WorkerError=$workerError; Validation='Host contract validation required'}
                        if ($workerError) { Write-Event 'PRODUCT_WORKER_ERROR_STOP' @{WorkerError=$workerError}; break }
                    }
                }
            } catch { $cause=$_.Exception; while($null -ne $cause.InnerException){$cause=$cause.InnerException}; if($cause -is [IO.IOException] -or $cause -is [UnauthorizedAccessException]){ $ioRetries++; Write-Event 'SHARED_READ_RETRY' @{ErrorType=$cause.GetType().FullName; Message=$cause.Message; ProductModified=$false} }else{throw} }
        }
        foreach ($progress in @(Get-ChildItem -LiteralPath $temp -File -Filter '*-progress.jsonl' -ErrorAction SilentlyContinue)) {
            for ($read=0; $read -lt 20; $read++) {
                try { $buffer=Read-Shared $progress.FullName; $reads++; $bytesRead += $buffer.Length }
                catch { $cause=$_.Exception; while($null -ne $cause.InnerException){$cause=$cause.InnerException}; if($cause -is [IO.IOException] -or $cause -is [UnauthorizedAccessException]){ $ioRetries++; Write-Event 'SHARED_READ_RETRY' @{ErrorType=$cause.GetType().FullName; Message=$cause.Message; ProductModified=$false} }else{throw} }
            }
        }
        if ([DateTime]::UtcNow -ge $nextLive) {
            $artifacts = @(Get-ChildItem -LiteralPath $temp -File -ErrorAction SilentlyContinue | Select-Object Name,Length,LastWriteTimeUtc)
            Write-Event 'LIVE_STATE' @{AppCandidates=@($appCandidates | ForEach-Object { Process-Record $_ }); ActiveInstalledWorkers=@($activeWorkers | ForEach-Object { Process-Record $_ }); TempArtifacts=$artifacts; Reads=$reads; BytesRead=$bytesRead; IORetries=$ioRetries; ParseRetries=$parseRetries; SavedResults=$sequence; NoExclusiveProbeDuringPossibleWorkerStart=$true}
            $nextLive = [DateTime]::UtcNow.AddMilliseconds(500)
        }
        Start-Sleep -Milliseconds 10
    }
} catch {
    Write-Event 'OBSERVER_ERROR' @{Error=$_.Exception.ToString(); ProductModified=$false}
    throw
} finally {
    $sha.Dispose()
    Write-Event 'END' @{Reads=$reads; BytesRead=$bytesRead; IORetries=$ioRetries; ParseRetries=$parseRetries; SavedResults=$sequence; ProductModified=$false}
}



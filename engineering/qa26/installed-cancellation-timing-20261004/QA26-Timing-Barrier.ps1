Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($env:USERNAME -ne 'Nyx') { throw 'Timing barrier is restricted to disposable user Nyx.' }
$installed = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
$workerPath = Join-Path $installed 'app\workers\ScanWorker.ps1'
$mainPath = Join-Path $installed 'app\NyxPCCheckup.ps1'
if ((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne '6CD64C5492E8AC4F2B4335A2CC17B697FFBBDDDA39CB0C422E68263426C95F79') { throw 'Frozen worker mismatch.' }
if ((Get-FileHash -LiteralPath $mainPath -Algorithm SHA256).Hash -ne 'BFBD5ABAA4D619C64B3875B571E1129F4DCBA3B4E17C1E8221E21C595B0245AC') { throw 'Frozen application mismatch.' }
$data = Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup'
$temp = Join-Path $data 'temp'
$out = Join-Path (Join-Path $env:LOCALAPPDATA 'NyxQA26TimingBarrier') (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Path $out | Out-Null
$events = Join-Path $out 'EVENTS.jsonl'
function Write-Event([string]$name, $details) {
    $record = [ordered]@{ Utc = [DateTime]::UtcNow.ToString('o'); Event = $name; Details = $details }
    [IO.File]::AppendAllText($events, (($record | ConvertTo-Json -Depth 8 -Compress) + "`r`n"))
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class QA26BarrierNative {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
    [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
'@
$watchdog = Join-Path $PSScriptRoot 'QA26-Timing-Watchdog.ps1'
$started = [DateTime]::UtcNow
$deadline = $started.AddMinutes(15)
$seen = @{}
$cases = 0
Write-Event 'START' @{ MaxWorkers = 2; HoldSeconds = 30; IndependentWatchdogSeconds = 45; ProductModified = $false; WorkerHash = (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash }
while ($cases -lt 2 -and [DateTime]::UtcNow -lt $deadline) {
    $workers = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.IndexOf($workerPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $_.CreationDate.ToUniversalTime() -gt $started -and -not $seen.ContainsKey([string]$_.ProcessId)
    })
    if ($workers.Count -gt 1) { throw 'Multiple matching installed workers; refusing to suspend any.' }
    if ($workers.Count -eq 0) { Start-Sleep -Milliseconds 200; continue }
    $worker = $workers[0]
    if (([DateTime]::UtcNow - $worker.CreationDate.ToUniversalTime()).TotalSeconds -lt 3) { Start-Sleep -Milliseconds 100; continue }
    $progress = @(Get-ChildItem -LiteralPath $temp -File -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 0 })
    if ($progress.Count -eq 0) { Start-Sleep -Milliseconds 100; continue }
    $parent = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $worker.ParentProcessId)
    if ($null -eq $parent -or -not $parent.CommandLine -or $parent.CommandLine.IndexOf($mainPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Worker is not a child of the exact installed application.'
    }
    $cases++
    $seen[[string]$worker.ProcessId] = $true
    $creation = $worker.CreationDate.ToUniversalTime().ToString('o')
    $marker = Join-Path $out ('worker_' + $cases)
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $watchdog + '"'),
        '-WorkerId', [string]$worker.ProcessId, '-ExpectedCreationUtc', $creation, '-MarkerPrefix', ('"' + $marker + '"')
    ) -WindowStyle Hidden | Out-Null
    $readyUntil = [DateTime]::UtcNow.AddSeconds(10)
    while (-not (Test-Path -LiteralPath ($marker + '.ready')) -and [DateTime]::UtcNow -lt $readyUntil) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath ($marker + '.ready'))) { throw 'Independent resume watchdog was not ready; worker left running.' }
    $handle = [QA26BarrierNative]::OpenProcess(0x0800, $false, [int]$worker.ProcessId)
    if ($handle -eq [IntPtr]::Zero) { throw 'Could not open the exact installed worker; no privilege changes attempted.' }
    $suspended = $false
    try {
        $status = [QA26BarrierNative]::NtSuspendProcess($handle)
        if ($status -ne 0) { throw ('Suspend returned ' + $status) }
        $suspended = $true
        Write-Event 'SUSPENDED' @{ Case = $cases; WorkerPid = $worker.ProcessId; ParentPid = $worker.ParentProcessId; CreationUtc = $creation; CommandLine = $worker.CommandLine; Progress = @($progress | Select-Object Name, Length); HoldSeconds = 30 }
        Start-Sleep -Seconds 30
    } finally {
        if ($suspended) {
            $resumeStatus = [QA26BarrierNative]::NtResumeProcess($handle)
            Write-Event 'RESUMED' @{ Case = $cases; WorkerPid = $worker.ProcessId; Status = $resumeStatus }
            if ($resumeStatus -eq 0) { [IO.File]::WriteAllText($marker + '.resumed', [DateTime]::UtcNow.ToString('o')) }
        }
        [void][QA26BarrierNative]::CloseHandle($handle)
    }
    $exitUntil = [DateTime]::UtcNow.AddMinutes(4)
    while ($null -ne (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $worker.ProcessId)) -and [DateTime]::UtcNow -lt $exitUntil) { Start-Sleep -Milliseconds 200 }
    if ($null -ne (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $worker.ProcessId))) { throw 'Worker did not exit within the bounded observation period.' }
    Write-Event 'WORKER_EXIT' @{ Case = $cases; WorkerPid = $worker.ProcessId }
    $settleUntil = [DateTime]::UtcNow.AddSeconds(30)
    $saved = $false
    do {
        $artifacts = @(Get-ChildItem -LiteralPath $temp -File -ErrorAction SilentlyContinue | Select-Object Name, Length)
        $apps = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($mainPath, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
        $source = Join-Path $data 'scans\last-scan.json'
        if ($artifacts.Count -eq 0 -and (Test-Path -LiteralPath $source)) {
            $stream = $null
            $memory = New-Object IO.MemoryStream
            try {
                $stream = [IO.File]::Open($source, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                $stream.CopyTo($memory)
                $raw = $memory.ToArray()
                $scan = [Text.Encoding]::UTF8.GetString($raw).TrimStart([char]0xFEFF) | ConvertFrom-Json
                $scanStarted = [DateTime]::Parse($scan.StartedUtc).ToUniversalTime()
                if ([Math]::Abs(($scanStarted - $worker.CreationDate.ToUniversalTime()).TotalSeconds) -lt 10) {
                    [IO.File]::WriteAllBytes((Join-Path $out ('RUN_' + $cases + '_RAW.json')), $raw)
                    Write-Event 'LIVE_CLEANUP_AND_RESULT' @{ Case = $cases; WorkerExited = $true; AppPids = @($apps | ForEach-Object { $_.ProcessId }); TempDirectory = $temp; Artifacts = $artifacts; Mode = $scan.Mode; StartedUtc = $scan.StartedUtc; CompletedUtc = $scan.CompletedUtc; Cancelled = $scan.Cancelled; ReadOnly = $scan.ReadOnly; Results = @($scan.Results).Count; RawPath = ('RUN_' + $cases + '_RAW.json') }
                    $saved = $true
                }
            } catch [IO.IOException] { Write-Event 'EVIDENCE_READ_RETRY' @{ Case = $cases; Error = $_.Exception.Message } }
            finally { if ($null -ne $stream) { $stream.Dispose() }; $memory.Dispose() }
        }
        if (-not $saved) { Start-Sleep -Milliseconds 200 }
    } while (-not $saved -and [DateTime]::UtcNow -lt $settleUntil)
    if (-not $saved) { Write-Event 'EVIDENCE_INCOMPLETE' @{ Case = $cases; Artifacts = $artifacts }; break }
}
Write-Event 'END' @{ Cases = $cases; MaxWorkers = 2; ProductModified = $false; NormalPerformanceCredit = $false }

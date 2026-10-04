param([int]$WorkerId, [string]$ExpectedCreationUtc, [string]$MarkerPrefix)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$allowed = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'NyxQA26TimingBarrier')).TrimEnd('\') + '\'
if (-not [IO.Path]::GetFullPath($MarkerPrefix).StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Invalid watchdog marker directory.'
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class QA26WatchdogNative {
    [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
    [DllImport("ntdll.dll")] public static extern int NtResumeProcess(IntPtr handle);
}
'@
[IO.File]::WriteAllText($MarkerPrefix + '.ready', [DateTime]::UtcNow.ToString('o'))
Start-Sleep -Seconds 45
if (Test-Path -LiteralPath ($MarkerPrefix + '.resumed')) { return }
$worker = Get-CimInstance Win32_Process -Filter ('ProcessId=' + $WorkerId)
if ($null -eq $worker) { return }
if ($worker.CreationDate.ToUniversalTime().ToString('o') -ne $ExpectedCreationUtc) { return }
$installed = Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup\app\workers\ScanWorker.ps1'
if (-not $worker.CommandLine -or $worker.CommandLine.IndexOf($installed, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return }
$handle = [QA26WatchdogNative]::OpenProcess(0x0800, $false, $WorkerId)
if ($handle -eq [IntPtr]::Zero) { throw 'Watchdog could not open the exact worker.' }
try {
    $status = [QA26WatchdogNative]::NtResumeProcess($handle)
    [IO.File]::WriteAllText($MarkerPrefix + '.watchdog', ('ResumeStatus=' + $status + ';Utc=' + [DateTime]::UtcNow.ToString('o')))
} finally { [void][QA26WatchdogNative]::CloseHandle($handle) }

[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$checks=New-Object 'System.Collections.Generic.List[object]'
function Assert-F016([string]$Name,[bool]$Value){$checks.Add([pscustomobject]@{Name=$Name;Passed=$Value});if(-not $Value){throw $Name}}
function Import-ProbeFunction([string]$File,[string]$Name){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($File,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Parser diagnostics in product source'}
    $f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name},$true)
    if($null -eq $f){throw "Missing product function $Name"}
    return $f.Extent.Text
}
. ([scriptblock]::Create((Import-ProbeFunction (Join-Path $AppRoot 'workers\ScanWorker.ps1') 'Write-NyxProgressEvent')))
. ([scriptblock]::Create((Import-ProbeFunction (Join-Path $AppRoot 'ui\MainWindow.psm1') 'Read-NyxCompleteProgressLines')))
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Threading;
public sealed class NyxF016Lease : IDisposable {
 private FileStream stream;
 private Timer timer;
 public NyxF016Lease(string path, int milliseconds) {
  stream=new FileStream(path,FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
  timer=new Timer(_ => Dispose(),null,milliseconds,Timeout.Infinite);
 }
 public void Dispose() {
  var s=Interlocked.Exchange(ref stream,null); if(s!=null)s.Dispose();
  var t=Interlocked.Exchange(ref timer,null); if(t!=null)t.Dispose();
 }
}
'@
$root=Join-Path $env:TEMP ('Nyx_F016_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root|Out-Null
$ProgressPath=Join-Path $root 'progress.jsonl'
$script:NyxProgressInitialized=$false
$failure=$null;$lease=$null;$shared=$null
try {
    Write-NyxProgressEvent -Type Started -Percent 0 -Message 'begin'
    $lines=@(Read-NyxCompleteProgressLines -Path $ProgressPath)
    Assert-F016 'Initial event is complete valid JSON' ($lines.Count -eq 1 -and ($lines[0]|ConvertFrom-Json).Type -eq 'Started')
    $shared=[IO.FileStream]::new($ProgressPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    Write-NyxProgressEvent -Type Result -Percent 10 -Message 'while reader open'
    $shared.Dispose();$shared=$null
    Assert-F016 'Writer appends while shared reader remains open' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 2)
    $lease=[NyxF016Lease]::new($ProgressPath,80)
    Write-NyxProgressEvent -Type Result -Percent 20 -Message 'bounded retry after exclusive contention'
    $lease.Dispose();$lease=$null
    Assert-F016 'Bounded retry succeeds after deliberate exclusive lock' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 3)
    $lease=[NyxF016Lease]::new($ProgressPath,10000)
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $degraded=@(Write-NyxProgressEvent -Type Result -Percent 30 -Message 'degrade instead of abort' 3>&1)
    Assert-F016 'Persistent contention returns within bounded time' ($clock.ElapsedMilliseconds -lt 2000)
    Assert-F016 'Persistent contention emits explicit warning' (@($degraded).Count -eq 1)
    Assert-F016 'UI polling tolerates active exclusive contention' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 0)
    Write-NyxProgressEvent -Type Failed -Percent 100 -Message 'original failure preserved separately'
    Assert-F016 'Failed-event contention does not throw a secondary error' $true
    $lease.Dispose();$lease=$null
    Write-NyxProgressEvent -Type Completed -Percent 100 -Message 'resumed channel'
    Assert-F016 'Progress resumes after a dropped event' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 4)
    [IO.File]::AppendAllText($ProgressPath,'{"Type":"Result"',[Text.Encoding]::UTF8)
    Assert-F016 'UI ignores an incomplete final JSONL line' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 4)
    [IO.File]::AppendAllText($ProgressPath,',"Percent":100}'+[Environment]::NewLine,[Text.Encoding]::UTF8)
    Assert-F016 'Next poll recovers newly completed line exactly once' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 5)
    $shared=[IO.FileStream]::new($ProgressPath,[IO.FileMode]::Append,[IO.FileAccess]::Write,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    Assert-F016 'Reader works while writer handle remains open' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 5)
    $shared.Dispose();$shared=$null
    foreach($n in 1..100){Write-NyxProgressEvent -Type Result -Percent 50 -Message "rapid $n";foreach($poll in 1..3){$lines=@(Read-NyxCompleteProgressLines -Path $ProgressPath)}}
    Assert-F016 '100 writes and 300 rapid reads preserve all complete events' ($lines.Count -eq 105)
    foreach($line in $lines){$null=$line|ConvertFrom-Json}
    Assert-F016 'Every retained progress record parses as JSON' $true
    $saved=$ProgressPath;$ProgressPath=Join-Path $root 'absent-parent\progress.jsonl';$threw=$false
    try{Write-NyxProgressEvent -Type Result -Percent 0 -Message 'unexpected I/O must propagate'}catch{$threw=$true}
    $ProgressPath=$saved
    Assert-F016 'Non-sharing I/O errors are not suppressed' $threw
    Remove-Item -LiteralPath $ProgressPath -Force
    Assert-F016 'No leaked file handle prevents cleanup' (-not (Test-Path -LiteralPath $ProgressPath))
    Assert-F016 'Missing telemetry file is safe for UI poll' (@(Read-NyxCompleteProgressLines -Path $ProgressPath).Count -eq 0)
}catch{$failure=$_.Exception.ToString()}finally{
    if($null -ne $lease){$lease.Dispose()}
    if($null -ne $shared){$shared.Dispose()}
    [ordered]@{Harness='QA26-F023-PS51-26';Type='Deterministic extracted product progress-function regression; not installed scan stress';Passed=($null -eq $failure);Count=$checks.Count;Checks=$checks.ToArray();Failure=$failure}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Remove-Item -LiteralPath $root -Recurse -Force
}
if($failure){throw $failure}

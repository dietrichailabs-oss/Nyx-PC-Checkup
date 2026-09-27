$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$evidence=Join-Path $env:LOCALAPPDATA ('NyxQA22Evidence\timing_'+(Get-Date -Format yyyyMMdd_HHmmss))
New-Item -ItemType Directory -Path $evidence | Out-Null
$mutex=$null
$owned=$false
function Write-TimingJson($Name,$Value) {
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $evidence $Name) -Encoding UTF8
}
function Test-InstalledIdentity {
    $zipPath='C:\Q22F019\QA22_FROZEN_PORTABLE.zip'
    if((Get-FileHash -LiteralPath $zipPath).Hash -ne 'E607E726606B64BE3AE1F040587AE1866A90800066B78228D9130A9E32BFF4CF'){throw 'Frozen portable identity mismatch'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $main=@($zip.Entries | Where-Object { $_.FullName.Replace('\','/').EndsWith('app/ui/MainWindow.psm1') })
        if($main.Count -ne 1){throw 'Portable module root ambiguous'}
        $full=$main[0].FullName.Replace('\','/')
        $prefix=$full.Substring(0,$full.Length-'app/ui/MainWindow.psm1'.Length)
        $records=@(foreach($entry in $zip.Entries){
            $name=$entry.FullName.Replace('\','/')
            if(!$entry.Name -or !$name.StartsWith($prefix)){continue}
            $relative=$name.Substring($prefix.Length)
            $target=[IO.Path]::GetFullPath((Join-Path $global:NyxTiming.InstallRoot $relative))
            if(!$target.StartsWith($global:NyxTiming.InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe portable member'}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try {$expected=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
            $actual=(Get-FileHash -LiteralPath $target).Hash
            if($actual -ne $expected){throw ('Installed identity mismatch: '+$relative)}
            [pscustomobject]@{File=$relative;SHA256=$actual;Match=$true}
        })
        if($records.Count -lt 50){throw 'Incomplete installed identity coverage'}
        return $records
    } finally {$zip.Dispose()}
}
function Get-TimingUi {
    & $global:NyxTiming.Module { $script:NyxUi }
}
function Read-TimingShared([string]$Path) {
    $stream=$null;$reader=$null
    try {
        $stream=[IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader=[IO.StreamReader]::new($stream)
        return $reader.ReadToEnd()
    } catch [IO.FileNotFoundException] { return '' }
    finally {if($reader){$reader.Dispose()}elseif($stream){$stream.Dispose()}}
}
function Start-TimingScan([string]$Mode,[bool]$CancelExpected) {
    $h=$global:NyxTiming
    $requested=[DateTime]::UtcNow
    & $h.Module {param($m) Start-NyxScan -Mode $m} $Mode
    $ui=Get-TimingUi
    if($null -eq $ui.ScanProcess){throw 'PRODUCT: scan entry point did not start a worker'}
    $h.Current=[ordered]@{Mode=$Mode;CancelExpected=$CancelExpected;RequestedUtc=$requested.ToString('o');WorkerPid=$ui.ScanProcess.Id;Process=$ui.ScanProcess;Output=$ui.ScanOutput;Progress=$ui.ProgressPath;Cancel=$ui.CancelPath;Raw=$null;ProgressReads=0;ResultEvents=0;CancelRequestedUtc=$null;WorkerAliveAtCancel=$false;CleanupObservedUtc=$null;TransitionRequestedUtc=$null}
    $h.Runs.Add($h.Current)
    $h.Deadline=[DateTime]::UtcNow.AddMinutes(3)
}
function Validate-TimingRuns {
    $h=$global:NyxTiming
    $validations=@()
    for($i=0;$i -lt $h.Runs.Count;$i++){
        $r=$h.Runs[$i];$errors=[Collections.Generic.List[string]]::new()
        $s=$r.Raw | ConvertFrom-Json
        foreach($key in @('Schema','Mode','StartedUtc','CompletedUtc','Cancelled','ReadOnly','Results')){if($key -notin $s.PSObject.Properties.Name){$errors.Add('Missing '+$key)}}
        if($s.Schema -ne 'dietrich-ai-labs.nyx-pc-checkup.scan.v1'){$errors.Add('Schema')}
        if($s.Mode -ne $r.Mode -or $s.ReadOnly -ne $true -or $s.Cancelled -ne $r.CancelExpected){$errors.Add('Mode/read-only/cancellation mismatch')}
        if([datetimeoffset]$s.CompletedUtc -lt [datetimeoffset]$s.StartedUtc){$errors.Add('Timestamp order')}
        if($null -ne $s.PSObject.Properties['WorkerError']){$errors.Add('WorkerError')}
        if(@($s.Results).Count -eq 0){$errors.Add('No partial/results persisted')}
        foreach($result in @($s.Results)){
            foreach($key in @('CheckId','Category','Name','Status','Severity','Finding','Reason','Recommendation','Complete')){if($key -notin $result.PSObject.Properties.Name){$errors.Add('Result missing '+$key)}}
            if($result.Status -notin @('Good','NeedsAttention','Optional','Unknown')){$errors.Add('Result status')}
            if($result.Severity -notin @('Info','Low','Medium','High')){$errors.Add('Result severity')}
            if($result.Complete -isnot [bool]){$errors.Add('Result Complete type')}
        }
        if($r.CancelExpected -and (!$r.WorkerAliveAtCancel -or !$r.CancelRequestedUtc -or $r.ResultEvents -eq 0)){$errors.Add('Cancellation synchronization missing')}
        $file=('RESULT_{0}_{1}.json' -f ($i+1),$r.Mode)
        [IO.File]::WriteAllText((Join-Path $evidence $file),$r.Raw,[Text.UTF8Encoding]::new($false))
        $validations += [pscustomobject]@{Run=$i+1;File=$file;Mode=$s.Mode;Cancelled=$s.Cancelled;ReadOnly=$s.ReadOnly;ResultCount=@($s.Results).Count;StartedUtc=$s.StartedUtc;CompletedUtc=$s.CompletedUtc;RequestedUtc=$r.RequestedUtc;WorkerPid=$r.WorkerPid;WorkerAliveAtCancel=$r.WorkerAliveAtCancel;CancelRequestedUtc=$r.CancelRequestedUtc;CleanupObservedUtc=$r.CleanupObservedUtc;ProgressReads=$r.ProgressReads;Errors=@($errors.ToArray());Pass=($errors.Count -eq 0)}
    }
    $transitions=@(foreach($pair in @(@(1,2),@(2,3))){
        $a=$validations[$pair[0]];$b=$validations[$pair[1]]
        $dispatch=([datetimeoffset]$b.RequestedUtc-[datetimeoffset]$a.CleanupObservedUtc).TotalMilliseconds
        $total=([datetimeoffset]$b.StartedUtc-[datetimeoffset]$a.CompletedUtc).TotalMilliseconds
        [pscustomobject]@{From=$a.Mode;To=$b.Mode;CompletedUtc=$a.CompletedUtc;CleanupObservedUtc=$a.CleanupObservedUtc;NextRequestedUtc=$b.RequestedUtc;NextWorkerStartedUtc=$b.StartedUtc;HarnessDispatchMilliseconds=$dispatch;CompletionToWorkerStartMilliseconds=$total;NoDeliberateDelay=$true;Pass=($dispatch -ge 0 -and $dispatch -le 250 -and $total -ge 0 -and $total -le 3000)}
    })
    $productErrors=@($validations | Where-Object {!$_.Pass})
    $timingErrors=@($transitions | Where-Object {!$_.Pass})
    $status=if($productErrors.Count){'PRODUCT_FAILURE_STOP'}elseif($timingErrors.Count){'HARNESS_TIMING_INCOMPLETE'}else{'F016_THREE_CASES_PASS'}
    Write-TimingJson 'RESULTS.json' ([ordered]@{Status=$status;Build='2026.09.27-eng-qa22';Harness='QA22-F019-PS51-22';TimingHarness='QA22-F016-TIMING-1';ProductModified=$false;Method='Full installed runtime graph and real WinForms message loop/timers. Unchanged Start-NyxScan and Cancel-NyxScan entry points; no extracted functions, substituted worker, rewritten result, or scan delay. UI cleanup is performed by the product.';NativeLauncherGateClaimed=$false;Runs=$validations;Transitions=$transitions;QuickCancellationPass=$validations[0].Pass;AllThreeCasesPass=($status -eq 'F016_THREE_CASES_PASS');GuestRunningAtCleanup=$true})
    return $status
}
try {
    if($env:USERNAME -ne 'Nyx' -or $PSVersionTable.PSVersion.Major -ne 5 -or [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'Disposable Nyx profile / PS5.1 STA required'}
    $root=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
    $global:NyxTiming=@{InstallRoot=$root;Module=$null;Timer=$null;Current=$null;Runs=[Collections.Generic.List[object]]::new();Phase='Initialize';Deadline=[DateTime]::UtcNow.AddMinutes(3);Busy=$false}
    Write-TimingJson 'INSTALLED_IDENTITY_BEFORE.json' @(Test-InstalledIdentity)
    $mutex=[Threading.Mutex]::new($true,'Local\DietrichAI.NyxPCCheckup.v1',[ref]$owned)
    if(!$owned){throw 'Existing Nyx instance; harness will not interfere'}
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Import-Module (Join-Path $root 'app\core\RuntimeComposition.psm1')
    $composition=Import-NyxRuntimeGraph -AppRoot (Join-Path $root 'app') -Profile UI
    Write-TimingJson 'COMPOSITION.json' $composition
    $global:NyxTiming.Module=Get-Module MainWindow
    $paths=Initialize-NyxDataDirectories
    $global:NyxTiming.LastScan=Join-Path $paths.Scans 'last-scan.json'
    $global:NyxTiming.Temp=$paths.Temp
    $timer=New-Object Windows.Forms.Timer
    $timer.Interval=10
    $global:NyxTiming.Timer=$timer
    $timer.Add_Tick({
        $h=$global:NyxTiming
        if($h.Busy){return}
        $h.Busy=$true
        try {
            if([DateTime]::UtcNow -gt $h.Deadline){throw 'HARNESS: timed out; preserve running state for review'}
            $ui=Get-TimingUi
            if($null -eq $ui -or !$ui.Form.Visible){return}
            if($h.Phase -eq 'Initialize'){
                if(@(Get-ChildItem -LiteralPath $h.Temp -Filter 'scan-*' -File).Count){throw 'HARNESS: pre-existing scan artifacts'}
                & $h.Module {Show-NyxPage -Page 'Checkup'}
                Start-TimingScan 'Quick' $true
                $h.Phase='Running'
                return
            }
            if($h.Phase -ne 'Running'){return}
            $r=$h.Current
            if(Test-Path -LiteralPath $r.Progress){
                $text=Read-TimingShared $r.Progress
                $r.ProgressReads++
                if($text -match '"Type":"Result"'){$r.ResultEvents=([regex]::Matches($text,'"Type":"Result"')).Count}
                if($r.CancelExpected -and !$r.CancelRequestedUtc -and $r.ResultEvents -gt 0 -and !$r.Process.HasExited){
                    $r.WorkerAliveAtCancel=$true
                    $r.CancelRequestedUtc=[DateTime]::UtcNow.ToString('o')
                    & $h.Module {Cancel-NyxScan}
                    [IO.File]::WriteAllText((Join-Path $evidence 'CANCEL_PROGRESS_SNAPSHOT.jsonl'),$text)
                    if(!(Test-Path -LiteralPath $r.Cancel)){throw 'PRODUCT: real cancel entry point did not create the cancel marker'}
                }
            }
            if($r.Process.HasExited -and !$r.Raw){
                if(Test-Path -LiteralPath $r.Output){$r.Raw=Read-TimingShared $r.Output}
                elseif(Test-Path -LiteralPath $h.LastScan){$r.Raw=Read-TimingShared $h.LastScan}
                if(!$r.Raw){throw 'PRODUCT: worker exited without authoritative JSON'}
                if($r.Process.ExitCode -ne 0){throw ('PRODUCT: worker exit '+$r.Process.ExitCode)}
                $scan=$r.Raw | ConvertFrom-Json
                if($null -ne $scan.PSObject.Properties['WorkerError']){throw 'PRODUCT: worker reported WorkerError'}
                if($scan.Cancelled -ne $r.CancelExpected){throw 'PRODUCT: cancellation result differs from the synchronized request'}
            }
            if($null -eq $ui.ScanProcess -and $r.Process.HasExited){
                $left=@(Get-ChildItem -LiteralPath $h.Temp -Filter 'scan-*' -File)
                if($left.Count){throw 'PRODUCT: product UI completion left scan artifacts'}
                $r.CleanupObservedUtc=[DateTime]::UtcNow.ToString('o')
                # No sleeps, evidence serialization or validation between cleanup and next dispatch.
                if($h.Runs.Count -eq 1){Start-TimingScan 'Quick' $false;return}
                if($h.Runs.Count -eq 2){Start-TimingScan 'Full' $false;return}
                if($h.Runs.Count -eq 3){Start-TimingScan 'Quick' $false;return}
                $h.Phase='Complete';$h.Timer.Stop()
                $status=Validate-TimingRuns
                Write-TimingJson 'LIVE_CLEANUP.json' @{Time=[DateTime]::UtcNow.ToString('o');GuestRunning=$true;ScanProcess=$null;Artifacts=@();WorkerPids=@($h.Runs|ForEach-Object {$_.WorkerPid});AllWorkerProcessesExited=(@($h.Runs|Where-Object {!$_.Process.HasExited}).Count -eq 0);CleanupPerformedBy='Frozen product UI, not harness'}
                Write-TimingJson 'INSTALLED_IDENTITY_AFTER.json' @(Test-InstalledIdentity)
                Write-TimingJson 'RUN_STATUS.json' @{Status=$status;ProductModified=$false;Evidence=$evidence;CompletedUtc=[DateTime]::UtcNow.ToString('o')}
                if($status -eq 'F016_THREE_CASES_PASS'){$ui.Form.Close()}
            }
        } catch {
            $h.Timer.Stop();$h.Phase='Stopped'
            $kind=if($_.Exception.Message.StartsWith('PRODUCT:')){'PRODUCT_FAILURE_STOP'}else{'HARNESS_BLOCKED_STOP'}
            Write-TimingJson 'RUN_STATUS.json' @{Status=$kind;Error=$_.Exception.ToString();ProductModified=$false;Evidence=$evidence;Time=[DateTime]::UtcNow.ToString('o')}
            foreach($r in $h.Runs){if($r.Raw){[IO.File]::WriteAllText((Join-Path $evidence ('PRESERVED_'+$r.WorkerPid+'.json')),$r.Raw)}}
        } finally {$h.Busy=$false}
    })
    Write-TimingJson 'RUN_STATUS.json' @{Status='RUNNING';Evidence=$evidence;ProductModified=$false;PowerShell=$PSVersionTable.PSVersion.ToString()}
    $timer.Start()
    Show-NyxMainWindow
    $timer.Stop();$timer.Dispose()
} catch {
    Write-TimingJson 'RUN_STATUS.json' @{Status='HARNESS_BLOCKED_STOP';Error=$_.Exception.ToString();ProductModified=$false;Evidence=$evidence}
} finally {
    if($mutex){if($owned){$mutex.ReleaseMutex()};$mutex.Dispose()}
}

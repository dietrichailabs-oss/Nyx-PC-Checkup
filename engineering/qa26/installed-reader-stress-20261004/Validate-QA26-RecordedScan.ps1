param([Parameter(Mandatory=$true)][string]$InputPath,[Parameter(Mandatory=$true)][string]$OutputPath,[Parameter(Mandatory=$true)][ValidateSet('Quick','Full')][string]$Mode,[switch]$ExpectedCancelled)
$ErrorActionPreference='Stop'
$s=Get-Content -LiteralPath $InputPath -Raw|ConvertFrom-Json
$errors=[Collections.Generic.List[string]]::new()
$fields=@('CheckId','Category','Name','Status','Severity','Finding','Reason','Evidence','Recommendation','ActionSafetyLevel','Timestamp','DataSource','RequiresElevation','Complete','ErrorReason','Details')
$start=[datetimeoffset]::Parse($s.StartedUtc);$end=[datetimeoffset]::Parse($s.CompletedUtc)
if($s.Schema -ne 'dietrich-ai-labs.nyx-pc-checkup.scan.v1' -or $s.Mode -ne $Mode -or $s.ReadOnly -isnot [bool] -or !$s.ReadOnly -or $s.Cancelled -isnot [bool] -or $s.Cancelled -ne [bool]$ExpectedCancelled -or $end -lt $start -or $s.WorkerError){$errors.Add('Scan contract')}
foreach($r in $s.Results){
 foreach($f in $fields){if($r.PSObject.Properties.Name -notcontains $f){$errors.Add("Missing $f")}}
 foreach($f in @('CheckId','Category','Name')){if([string]::IsNullOrWhiteSpace($r.$f)){$errors.Add("Blank $f")}}
 foreach($f in @('CheckId','Category','Name','Finding','Reason','Recommendation','DataSource','ErrorReason')){if($r.$f -isnot [string]){$errors.Add("String type $f")}}
 if($r.Status -notin @('Good','NeedsAttention','Optional','Unknown') -or $r.Severity -notin @('Info','Low','Medium','High') -or $r.ActionSafetyLevel -notin @('None','SafeRedirect','ReversibleLocalChange','DestructiveAction')){$errors.Add('Result enum')}
 if($r.Complete -isnot [bool] -or $r.RequiresElevation -isnot [bool]){$errors.Add('Result boolean')}
 $t=[datetimeoffset]::Parse($r.Timestamp);if($t -lt $start -or $t -gt $end){$errors.Add('Result timestamp range')}
}
if($s.Summary.Total -ne @($s.Results).Count){$errors.Add('Summary total')}
foreach($st in @('Good','NeedsAttention','Optional','Unknown')){if($s.Summary.$st -ne @($s.Results|Where-Object Status -eq $st).Count){$errors.Add("Summary $st")}}
$r=[ordered]@{Result=if($errors.Count){'FAIL'}else{'PASS'};Mode=$s.Mode;StartedUtc=$s.StartedUtc;CompletedUtc=$s.CompletedUtc;Cancelled=$s.Cancelled;ReadOnly=$s.ReadOnly;ResultsValidated=@($s.Results).Count;RequiredResultFields=$fields;NullableEvidenceAllowed=$true;WorkerError=$s.WorkerError;Errors=@($errors);FrozenSource='0303a78a06f67252c86634cd73f1e4bda32dd3cc';Scope='Frozen Models shape and scan wrapper/summary contract; not live cleanup or execution proof'}
$r|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding utf8
$r|ConvertTo-Json -Depth 6

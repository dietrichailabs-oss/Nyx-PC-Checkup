param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$checks=New-Object 'System.Collections.Generic.List[object]'
function Assert-F017([string]$Name,[bool]$Passed){$checks.Add([pscustomobject]@{Name=$Name;Passed=$Passed});if(-not $Passed){throw $Name}}
foreach($file in @('PerformanceSnapshot.psm1','InstalledApps.psm1')){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $AppRoot "checks\$file"),[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Product parser errors'}
    foreach($function in $ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($function.Extent.Text))}
}
function Get-NyxStableId {param([string]$Text) return $Text}
$failure=$null
try{
    $valid=[pscustomobject]@{Name='readable';Id=42;TotalProcessorTime=[TimeSpan]::FromSeconds(12);WorkingSet64=[long]4096}
    $valid|Add-Member ScriptProperty CPU {throw [InvalidOperationException]::new('Legacy CPU getter must not be called')}
    $snapshot=ConvertTo-NyxProcessSnapshot $valid
    Assert-F017 'CPU getter is avoided; runtime snapshot is retained' ($snapshot.CPU -eq 12)
    Assert-F017 'Working set is retained' ($snapshot.WorkingSet64 -eq 4096)
    $exited=[pscustomobject]@{Id=43}
    $exited|Add-Member ScriptProperty Name {throw [InvalidOperationException]::new('Process exited')}
    Assert-F017 'Process exits before identity read' ($null -eq (ConvertTo-NyxProcessSnapshot $exited))
    $denied=[pscustomobject]@{Name='denied';Id=44;WorkingSet64=[long]8192}
    $denied|Add-Member ScriptProperty TotalProcessorTime {throw [ComponentModel.Win32Exception]::new(5)}
    $snapshot=ConvertTo-NyxProcessSnapshot $denied
    Assert-F017 'CPU runtime access failure affects only that field' ($null -eq $snapshot.CPU -and $snapshot.WorkingSet64 -eq 8192)
    $missing=[pscustomobject]@{Name='missing';Id=45}
    $snapshot=ConvertTo-NyxProcessSnapshot $missing
    Assert-F017 'Missing runtime is unknown, not fabricated zero' ($null -eq $snapshot.CPU)
    Assert-F017 'Missing working set is unknown' ($null -eq $snapshot.WorkingSet64)
    $mixed=@(foreach($p in @($valid,$exited,$denied,$missing)){$item=ConvertTo-NyxProcessSnapshot $p;if($null -ne $item){$item}})
    Assert-F017 'Mixed process records retain readable entries' ($mixed.Count -eq 3)
    Assert-F017 'CPU sort uses only captured readable values' (@($mixed|Where-Object {$null -ne $_.CPU}).Count -eq 1)
    $broken=[pscustomobject]@{Id=46}
    $broken|Add-Member ScriptProperty Name {throw [FormatException]::new('Unrelated defect')}
    $threw=$false;try{$null=ConvertTo-NyxProcessSnapshot $broken}catch{$threw=$true}
    Assert-F017 'Unrelated property errors propagate' $threw
    $app=ConvertTo-NyxInstalledApplication ([pscustomobject]@{DisplayName='Minimal'})
    Assert-F017 'Missing SystemComponent retains entry' ($app.Name -eq 'Minimal')
    Assert-F017 'Missing optional strings are empty' ($app.Publisher -eq '' -and $app.Version -eq '' -and $app.InstallDate -eq '' -and $app.InstallLocation -eq '')
    Assert-F017 'Missing size and uninstall are not invented' ($null -eq $app.EstimatedSizeBytes -and -not $app.UninstallAvailable)
    Assert-F017 'SystemComponent zero retained' ($null -ne (ConvertTo-NyxInstalledApplication ([pscustomobject]@{DisplayName='Normal';SystemComponent=0})))
    Assert-F017 'SystemComponent one excluded' ($null -eq (ConvertTo-NyxInstalledApplication ([pscustomobject]@{DisplayName='System';SystemComponent=1})))
    Assert-F017 'Missing display name skipped' ($null -eq (ConvertTo-NyxInstalledApplication ([pscustomobject]@{Publisher='Vendor'})))
    $app=ConvertTo-NyxInstalledApplication ([pscustomobject]@{DisplayName='Partial';EstimatedSize=2;Publisher='Vendor';UninstallString='uninstall.exe'})
    Assert-F017 'Partial entry preserves valid values' ($app.EstimatedSizeBytes -eq 2048 -and $app.Publisher -eq 'Vendor' -and $app.UninstallAvailable)
    $app=ConvertTo-NyxInstalledApplication ([pscustomobject]@{DisplayName='InvalidSize';EstimatedSize='unknown'})
    Assert-F017 'Malformed optional size does not discard application' ($app.Name -eq 'InvalidSize' -and $null -eq $app.EstimatedSizeBytes)
}catch{$failure=$_.Exception.ToString()}finally{
    @{Harness='QA25-F022-PS51-25';Type='Deterministic source-function regression, not installed acceptance';Passed=($null -eq $failure);Count=$checks.Count;Checks=$checks.ToArray();Failure=$failure}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

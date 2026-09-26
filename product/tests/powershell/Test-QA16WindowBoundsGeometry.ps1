param([string]$ModulePath=(Join-Path $PSScriptRoot '../../src/app/ui/MainWindow.psm1'))
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Resolve-Path $ModulePath).Path,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$function=$ast.Find({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-NyxClampedWindowBounds'},$true)
if($null -eq $function){throw 'Missing bounds helper'}
. ([scriptblock]::Create($function.Extent.Text))
$cases=@(
    @{Name='F013 reproduction';Window=@(362,210,992,688);Work=@(0,0,1024,720);Expected=@(32,32,992,688)},
    @{Name='Already contained';Window=@(20,30,800,600);Work=@(0,0,1366,720);Expected=@(20,30,800,600)},
    @{Name='Negative monitor origin';Window=@(-1800,-300,1000,700);Work=@(-1920,-200,1920,1040);Expected=@(-1800,-200,1000,700)},
    @{Name='Left top taskbar';Window=@(0,0,900,600);Work=@(48,40,1318,728);Expected=@(48,40,900,600)},
    @{Name='Oversized';Window=@(400,400,2500,1800);Work=@(0,0,1366,720);Expected=@(0,0,1366,720)}
)
foreach($dpi in @(96,120,144,192)){
    $cases+=@{Name="Scaled size $dpi DPI";Window=@(362,210,[int](1280*$dpi/96),[int](820*$dpi/96));Work=@(0,0,1366,720);Expected=@(0,0,[math]::Min([int](1280*$dpi/96),1366),720)}
    if($dpi -eq 96){$cases[-1].Expected[0]=86}
}
$results=foreach($case in $cases){
    $window=New-Object Drawing.Rectangle($case.Window[0],$case.Window[1],$case.Window[2],$case.Window[3])
    $work=New-Object Drawing.Rectangle($case.Work[0],$case.Work[1],$case.Work[2],$case.Work[3])
    $expected=New-Object Drawing.Rectangle($case.Expected[0],$case.Expected[1],$case.Expected[2],$case.Expected[3])
    $actual=Get-NyxClampedWindowBounds -Bounds $window -WorkingArea $work
    if($actual -ne $expected){throw "$($case.Name): expected $expected; actual $actual"}
    if((Get-NyxClampedWindowBounds -Bounds $actual -WorkingArea $work) -ne $actual){throw 'Clamp is not idempotent'}
    [pscustomobject]@{Name=$case.Name;Result='PASS';Bounds=$actual.ToString()}
}
[pscustomobject]@{Scope='Geometry only; not installed native launch or actual DPI coverage';Passed=@($results).Count;Results=@($results)}|ConvertTo-Json -Depth 5

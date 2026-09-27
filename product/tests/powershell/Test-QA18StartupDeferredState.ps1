[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
# Unit-level event regression: real WinForms controls and deferred handlers;
# inventory, actions, dialogs and Explorer are isolated test doubles. This is
# NOT a substitute for the installed interactive/native acceptance matrix.
Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Windows.Forms;
public static class F015Dialogs {
 public static int Count;
 public static DialogResult Show(params object[] args) { Count++; return DialogResult.Yes; }
}
'@
$script:checks=New-Object 'System.Collections.Generic.List[object]'
$script:loads=0
$script:actions=New-Object 'System.Collections.Generic.List[string]'
$script:opens=New-Object 'System.Collections.Generic.List[string]'
$script:enabled=$true
function Assert-F015([string]$Name,[bool]$Condition){
    $script:checks.Add([pscustomobject]@{Name=$Name;Passed=$Condition})
    if(-not $Condition){throw "F015 regression failed: $Name"}
}
function Get-NyxStartupApplications {
    $script:loads++
    foreach($kind in @('current','all-users','missing')){
        [pscustomobject]@{Id=$kind;Name=$kind;Publisher='Fixture';SourceLabel=$kind;CanModify=($kind -ne 'all-users');Enabled=$(if($kind -eq 'current'){$script:enabled}else{$true});FileExists=($kind -ne 'missing');Impact='Unknown';ExecutablePath=$(if($kind -eq 'missing'){Join-Path $env:TEMP 'Nyx_F015_absent_target.exe'}else{Join-Path $env:SystemRoot 'System32\notepad.exe'});RollbackActionId='fixture-rollback'}
    }
}
function Invoke-NyxUiAction($Request){
    $script:actions.Add([string]$Request.Operation)
    $script:enabled=($Request.Operation -eq 'EnableStartup')
    [pscustomobject]@{Message='Fixture action completed'}
}
function Invoke-NyxOpen($Program,$Arguments){$script:opens.Add([string]$Arguments)}
function Clear-NyxPage {foreach($item in @($script:NyxUi.Content.Controls)){$item.Dispose()};$script:NyxUi.Content.Controls.Clear()}
function Add-NyxPageHeading {param($Title,$Subtitle)}
function Get-NyxPageWidth {800}
function Set-NyxPageScrollExtent {param($Height)}
function New-NyxButton {param($Text,$X,$Y,$Width,$Palette,$Primary);$b=New-Object Windows.Forms.Button;$b.Text=$Text;return $b}
function New-NyxGrid {param($X,$Y,$Width,$Height,$Palette);$g=New-Object Windows.Forms.DataGridView;$g.AllowUserToAddRows=$false;$g.SelectionMode='FullRowSelect';return $g}
function New-NyxLabel {param($Text,$X,$Y,$Width,$Height,$Size,$Palette,$Color);return (New-Object Windows.Forms.Label)}
function Invoke-DeferredClick($Button){
    # OnClick is invoked only after Show-NyxStartupPage's function scope ended.
    $method=[Windows.Forms.Button].GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic')
    $method.Invoke($Button,@([EventArgs]::Empty))|Out-Null
}
function Select-Fixture($State,[int]$Index){$State.Grid.ClearSelection();$State.Grid.Rows[$Index].Selected=$true;Update-NyxStartupSelection -State $State}
$script:NyxUi=@{Content=(New-Object Windows.Forms.Panel);Palette=@{Optional=[Drawing.Color]::Orange;Muted=[Drawing.Color]::Gray}}
$failure=$null
try {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $AppRoot 'ui\MainWindow.psm1'),[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Product module parser diagnostics'}
    foreach($name in @('Update-NyxStartupSelection','Update-NyxStartupRows','Show-NyxStartupPage')){
        $f=$ast.Find({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name},$true)
        if($null -eq $f){throw "Missing required function $name"}
        # Replace only the dialog boundary so both confirmation paths can be
        # tested without clicking modal windows or changing actual startup.
        . ([scriptblock]::Create($f.Extent.Text.Replace('[Windows.Forms.MessageBox]::Show','[F015Dialogs]::Show')))
    }
    Show-NyxStartupPage
    $page=$script:NyxUi.Content.Controls[0].Tag
    Assert-F015 'Initial load contains all three fixtures' ($page.Grid.Rows.Count -eq 3 -and $script:loads -eq 1)
    foreach($repeat in 1..3){Invoke-DeferredClick $page.Refresh;Assert-F015 "Deferred Refresh $repeat reloads inventory" ($script:loads -eq (1+$repeat) -and $page.Grid.Rows.Count -eq 3)}
    Select-Fixture $page 0
    Assert-F015 'Current-user selection permits Disable only' ($page.Disable.Enabled -and -not $page.Enable.Enabled)
    Invoke-DeferredClick $page.Disable
    Invoke-DeferredClick $page.Refresh
    Select-Fixture $page 0
    Assert-F015 'Disable survives reload and enables Re-enable' (-not $page.Grid.Rows[0].Tag.Enabled -and $page.Enable.Enabled -and -not $page.Disable.Enabled)
    Invoke-DeferredClick $page.Enable
    Invoke-DeferredClick $page.Refresh
    Select-Fixture $page 0
    Assert-F015 'Re-enable survives reload' ($page.Grid.Rows[0].Tag.Enabled -and $page.Disable.Enabled)
    Select-Fixture $page 1
    Assert-F015 'all-users controls remain disabled' (-not $page.Disable.Enabled -and -not $page.Enable.Enabled)
    $before=$script:actions.Count
    Invoke-DeferredClick $page.Disable
    Invoke-DeferredClick $page.Enable
    Assert-F015 'all-users callback guards reject forced clicks' ($script:actions.Count -eq $before)
    Invoke-DeferredClick $page.Location
    Assert-F015 'Valid location opens Explorer selection' ($script:opens.Count -eq 1 -and $script:opens[0] -like '/select,*notepad.exe*')
    Select-Fixture $page 2
    $dialogs=[F015Dialogs]::Count
    Invoke-DeferredClick $page.Location
    Assert-F015 'Missing target reports unavailable without opening Explorer' ($script:opens.Count -eq 1 -and [F015Dialogs]::Count -eq ($dialogs+1))
    $old=$page
    Show-NyxStartupPage
    $page=$script:NyxUi.Content.Controls[0].Tag
    Assert-F015 'Navigation disposes prior page and creates separate state' ($old.Grid.IsDisposed -and -not [object]::ReferenceEquals($old,$page))
    $before=$script:loads
    Invoke-DeferredClick $page.Refresh
    Assert-F015 'Refresh after navigation loads new page only' ($script:loads -eq ($before+1) -and $page.Grid.Rows.Count -eq 3)
    Update-NyxStartupRows -State $old
    Assert-F015 'Late disposed-page reload cannot affect current page' ($script:loads -eq ($before+1))
} catch {$failure=$_.Exception.ToString()} finally {
    $script:NyxUi.Content.Dispose()
    [ordered]@{Harness='QA24-F021-PS51-24';Type='Isolated deferred WinForms event regression, not installed acceptance';Passed=($null -eq $failure);Checks=$script:checks.ToArray();Count=$script:checks.Count;Failure=$failure}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

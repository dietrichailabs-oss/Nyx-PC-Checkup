[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Native Windows PowerShell 5.1 required'}
if([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'STA required'}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::ThrowException)
$checks=New-Object 'Collections.Generic.List[object]'
$failure=$null;$form=$null
function Assert-Test([string]$Name,[bool]$Pass){
 $checks.Add([pscustomobject]@{Name=$Name;Pass=$Pass})
 if(-not $Pass){throw $Name}
}
function Settle {for($i=0;$i -lt 20;$i++){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 5}}
function Raise-Key([Windows.Forms.DataGridView]$Grid,[Windows.Forms.Keys]$Key){
 $flags=[Reflection.BindingFlags]'Instance,NonPublic'
 $preview=New-Object Windows.Forms.PreviewKeyDownEventArgs($Key)
 $arguments=New-Object 'object[]' 1
 $arguments[0]=$preview.PSObject.BaseObject
 [void][Windows.Forms.Control].GetMethod('OnPreviewKeyDown',$flags).Invoke($Grid,$arguments)
 $event=New-Object Windows.Forms.KeyEventArgs($Key)
 $arguments[0]=$event.PSObject.BaseObject
 [void][Windows.Forms.Control].GetMethod('OnKeyDown',$flags).Invoke($Grid,$arguments)
 return [pscustomobject]@{Input=$preview.IsInputKey;Handled=$event.Handled;Suppressed=$event.SuppressKeyPress}
}
try{
 Import-Module (Join-Path $AppRoot 'ui\Theme.psm1') -Force -DisableNameChecking
 Import-Module (Join-Path $AppRoot 'ui\Controls.psm1') -Force -DisableNameChecking
 $module=Import-Module (Join-Path $AppRoot 'ui\MainWindow.psm1') -Force -DisableNameChecking -PassThru
 $form=New-Object Windows.Forms.Form
 $form.ClientSize=New-Object Drawing.Size(900,480)
 $form.Text='QA26 real registered grid handlers - integration, not installed desktop acceptance'
 $panel=New-Object Windows.Forms.Panel
 $panel.Dock='Fill';$panel.AutoScroll=$true;$form.Controls.Add($panel)
 & $module {
  param($Panel)
  $script:NyxUi=@{Content=$Panel;Palette=(Get-NyxPalette 'Light');LayoutScale=1.0}
  $script:QA26Calls=New-Object 'Collections.Generic.List[object]'
  function script:Get-NyxStatusSymbol {param($Status) return 'OK'}
  function script:Get-NyxStatusLabel {param($Status) return [string]$Status}
  function script:Show-NyxResultDetailDialog {
   param($Result,$Palette)
   $script:QA26Calls.Add($Result)
   $dialog=New-Object Windows.Forms.Form
   $dialog.Text=[string]$Result.Name
   $timer=New-Object Windows.Forms.Timer
   $timer.Interval=80
   $timer.Tag=[pscustomobject]@{Dialog=$dialog;Grid=$script:QA26ActiveGrid}
   $timer.Add_Tick({
    param($sender,$eventArgs)
    $sender.Stop()
    # Reentrant activation while modal must not open a duplicate dialog.
    Invoke-NyxGridPrimaryAction -Grid $sender.Tag.Grid
    $sender.Tag.Dialog.Close()
   })
   try{$timer.Start();[void]$dialog.ShowDialog($script:QA26ActiveGrid.FindForm())}finally{$timer.Dispose();$dialog.Dispose()}
  }
  function script:ConvertTo-NyxBytesText {param([int64]$Bytes)return ([string]$Bytes+' bytes')}
  $script:QA26OpenCalls=New-Object 'Collections.Generic.List[object]'
  function script:Invoke-NyxOpen {param($Target,$Arguments)$script:QA26OpenCalls.Add([pscustomobject]@{Target=$Target;Arguments=$Arguments})}
 } $panel
 $results=@(foreach($i in 0..2){[pscustomobject]@{Status='Good';Category='System';Name=('Result '+$i);Finding=('Finding '+$i);CheckId=('qa26.fixture.'+$i)}})
 $form.Show();$form.Activate()
 foreach($cycle in 1..3){
  $grid=& $module {param($Results)New-NyxResultsGridControl -Results $Results -Y 10 -Height 350} $results
  & $module {param($Grid)$script:QA26ActiveGrid=$Grid} $grid
  $panel.Controls.Add($grid);Settle
  foreach($row in @(0,1,2,0)){
   $grid.CurrentCell=$grid.Rows[$row].Cells[1];[void]$grid.Focus();Settle
   $before=& $module {$script:QA26Calls.Count}
   $event=Raise-Key $grid ([Windows.Forms.Keys]::Enter);Settle
   $last=& $module {$script:QA26Calls[$script:QA26Calls.Count-1]}
   Assert-Test "cycle $cycle row $row exact result" ([object]::ReferenceEquals($last.PSObject.BaseObject,$results[$row].PSObject.BaseObject))
   Assert-Test "cycle $cycle row $row one activation" ((& $module {$script:QA26Calls.Count}) -eq $before+1)
   Assert-Test "cycle $cycle row $row Enter consumed" ($event.Input -and $event.Handled -and $event.Suppressed)
   Assert-Test "cycle $cycle row $row focus restored" ($grid.ContainsFocus -and $grid.CurrentCell.RowIndex -eq $row -and $grid.CurrentCell.ColumnIndex -eq 1)
  }
  $before=& $module {$script:QA26Calls.Count}
  foreach($key in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End,([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home),([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End),[Windows.Forms.Keys]::Tab,([Windows.Forms.Keys]::Shift -bor [Windows.Forms.Keys]::Tab))){
   $event=Raise-Key $grid $key
   Assert-Test "cycle $cycle navigation $key does not activate" ((& $module {$script:QA26Calls.Count}) -eq $before)
  }
  $args=New-Object Windows.Forms.DataGridViewCellEventArgs(2,1)
  $arguments=New-Object 'object[]' 1
  $arguments[0]=$args.PSObject.BaseObject
  [void][Windows.Forms.DataGridView].GetMethod('OnCellDoubleClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($grid,$arguments);Settle
  $last=& $module {$script:QA26Calls[$script:QA26Calls.Count-1]}
  Assert-Test "cycle $cycle double-click exact result" ([object]::ReferenceEquals($last.PSObject.BaseObject,$results[1].PSObject.BaseObject))
  $grid.CurrentCell=$null;$before=& $module {$script:QA26Calls.Count}
  [void](Raise-Key $grid ([Windows.Forms.Keys]::Enter))
  Assert-Test "cycle $cycle null current cell safe" ((& $module {$script:QA26Calls.Count}) -eq $before)
  $grid.Rows.Clear();[void](Raise-Key $grid ([Windows.Forms.Keys]::Enter))
  Assert-Test "cycle $cycle empty grid safe" ((& $module {$script:QA26Calls.Count}) -eq $before)
  # WinForms rejects out-of-range fabricated events before registered handlers.
  # A header row (-1) is a legal event with no actionable result.
  $invalid=New-Object Windows.Forms.DataGridViewCellEventArgs(0,-1)
  $arguments[0]=$invalid.PSObject.BaseObject
  [void][Windows.Forms.DataGridView].GetMethod('OnCellDoubleClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($grid,$arguments)
  Assert-Test "cycle $cycle invalid row safe" ((& $module {$script:QA26Calls.Count}) -eq $before)
  $grid.Dispose()
  & $module {param($Grid)Invoke-NyxGridPrimaryAction -Grid $Grid} $grid
  Assert-Test "cycle $cycle disposed grid safe" ((& $module {$script:QA26Calls.Count}) -eq $before)
 }
 # Construct the actual Storage page, including its registered largest-file action.
 # Discover existing storage IDs rather than inventing an unrelated constructor.
 $source=Get-Content -LiteralPath (Join-Path $AppRoot 'ui\MainWindow.psm1') -Raw
 $ids=@([regex]::Matches($source,"CheckId\s+-eq\s+'([^']+)'")|ForEach-Object {$_.Groups[1].Value}|Where-Object {$_ -like 'storage.*'}|Select-Object -Unique)
 Assert-Test 'Storage fixture resolves real result IDs' ($ids.Count -gt 0)
 $files=@([pscustomobject]@{Path='C:\Windows\System32\notepad.exe';SizeBytes=1024},[pscustomobject]@{Path='C:\Windows\System32\kernel32.dll';SizeBytes=2048})
 $storage=@(foreach($id in $ids){[pscustomobject]@{CheckId=$id;Status='Good';Category='Storage';Name='Storage fixture';Finding='Disposable action observation';Details=[pscustomobject]@{Folders=@([pscustomobject]@{Name='Fixture';Bytes=1024;Files=1;Complete=$true});LargestFiles=$files}}})
 & $module {param($Results)$script:NyxUi.Scan=[pscustomobject]@{Results=$Results};Show-NyxStoragePage} $storage
 Settle
 $fileGrids=@($panel.Controls|Where-Object {$_ -is [Windows.Forms.DataGridView] -and $_.Rows.Count -gt 0 -and $null -ne $_.Rows[0].Tag -and $null -ne $_.Rows[0].Tag.PSObject.Properties['Path']})
 Assert-Test 'Storage real largest-file grid exists' ($fileGrids.Count -eq 1)
 $grid=$fileGrids[0]
 foreach($row in @(0,1,0)){
  $grid.CurrentCell=$grid.Rows[$row].Cells[0];[void]$grid.Focus();Settle
  $before=& $module {$script:QA26OpenCalls.Count}
  $event=Raise-Key $grid ([Windows.Forms.Keys]::Enter);Settle
  $call=& $module {$script:QA26OpenCalls[$script:QA26OpenCalls.Count-1]}
  Assert-Test "Storage row $row exact Explorer action" ($call.Target -eq 'explorer.exe' -and $call.Arguments -eq ('/select,"'+$files[$row].Path+'"'))
  Assert-Test "Storage row $row single consumed activation" ((& $module {$script:QA26OpenCalls.Count}) -eq $before+1 -and $event.Handled -and $event.Suppressed)
  Assert-Test "Storage row $row focus preserved" ($grid.ContainsFocus -and $grid.CurrentCell.RowIndex -eq $row)
 }
 $args=New-Object Windows.Forms.DataGridViewCellEventArgs(0,1)
 $arguments=New-Object 'object[]' 1;$arguments[0]=$args.PSObject.BaseObject
 [void][Windows.Forms.DataGridView].GetMethod('OnCellDoubleClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($grid,$arguments)
 $call=& $module {$script:QA26OpenCalls[$script:QA26OpenCalls.Count-1]}
 Assert-Test 'Storage mouse uses same selected target' ($call.Arguments -eq ('/select,"'+$files[1].Path+'"'))
 $before=& $module {$script:QA26OpenCalls.Count}
 foreach($key in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End,([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home),([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End),[Windows.Forms.Keys]::Tab,([Windows.Forms.Keys]::Shift -bor [Windows.Forms.Keys]::Tab))){
  [void](Raise-Key $grid $key)
  Assert-Test "Storage navigation $key does not activate" ((& $module {$script:QA26OpenCalls.Count}) -eq $before)
 }
 $grid.CurrentCell=$null;[void](Raise-Key $grid ([Windows.Forms.Keys]::Enter))
 Assert-Test 'Storage null current cell safe' ((& $module {$script:QA26OpenCalls.Count}) -eq $before)
}catch{$failure=$_.Exception.ToString()}finally{
 if($null -ne $form){$form.Dispose()}
 $parent=Split-Path -Parent $OutputPath;if($parent){[void][IO.Directory]::CreateDirectory($parent)}
 [pscustomobject]@{Harness='QA26-F023-PS51-26';Kind='Native PS5.1 registered real grid handlers with observed action test double; not installed desktop acceptance';Passed=@($checks|Where-Object Pass).Count;Failed=@($checks|Where-Object {-not $_.Pass}).Count;Failure=$failure;Checks=$checks.ToArray();PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

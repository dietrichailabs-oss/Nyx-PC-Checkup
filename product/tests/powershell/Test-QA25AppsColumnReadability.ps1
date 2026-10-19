[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath,[switch]$MeasureOnly)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Windows PowerShell 5.1 required'}
if([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'STA required'}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
[Windows.Forms.Application]::SetUnhandledExceptionMode([Windows.Forms.UnhandledExceptionMode]::ThrowException)
$checks=New-Object 'Collections.Generic.List[object]'
$measurements=New-Object 'Collections.Generic.List[object]'
$failure=$null;$form=$null
function Settle { $end=[DateTime]::UtcNow.AddMilliseconds(80);do{[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 5}while([DateTime]::UtcNow -lt $end) }
function Assert-Readable([string]$Name,[bool]$Pass,$Detail){
    $checks.Add([pscustomobject]@{Name=$Name;Pass=$Pass;Detail=$Detail})
    if(-not $Pass -and -not $MeasureOnly){throw "F022: $Name"}
}
function Measure-Columns([string]$Stage){
    Settle
    $columns=@(foreach($column in $grid.Columns){[pscustomobject]@{Name=$column.Name;Width=$column.Width;MinimumWidth=$column.MinimumWidth;FillWeight=$column.FillWeight;AutoSizeMode=[string]$column.AutoSizeMode}})
    $measurements.Add([pscustomobject]@{Scale=$scale;Stage=$Stage;GridClientSize=$grid.ClientSize.ToString();Columns=$columns;OuterViewport=$panel.ClientSize.ToString();InternalOffset=$grid.HorizontalScrollingOffset})
    foreach($column in $grid.Columns){
        $min=[int][math]::Round($minimums[$column.Name]*$scale)
        Assert-Readable "$scale $Stage $($column.Name) practical Width" ($column.Width -ge $min) @{Actual=$column.Width;Required=$min}
        Assert-Readable "$scale $Stage $($column.Name) MinimumWidth" ($column.MinimumWidth -ge $min) @{Actual=$column.MinimumWidth;Required=$min}
    }
}
function Check-Focus([string]$Stage){
    Settle
    $cell=$grid.CurrentCell
    $whole=$grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$false)
    $clipped=$grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$true)
    $mapped=$panel.RectangleToClient($grid.RectangleToScreen($clipped))
    $visible=[Drawing.Rectangle]::Intersect($mapped,$panel.ClientRectangle)
    $detail=@{Row=$cell.RowIndex;Column=$cell.ColumnIndex;Whole=$whole.ToString();Clipped=$clipped.ToString();Visible=$visible.ToString();Width=$cell.OwningColumn.Width;InternalOffset=$grid.HorizontalScrollingOffset}
    Assert-Readable "$scale $Stage fully visible focused cell" ($grid.ContainsFocus -and $visible.Width -ge $whole.Width-2 -and $visible.Height -ge $whole.Height-2) $detail
    if($cell.OwningColumn.Name -eq 'Size'){
        $textWidth=[Windows.Forms.TextRenderer]::MeasureText([string]$cell.FormattedValue,$grid.Font).Width
        Assert-Readable "$scale $Stage size value readable without tooltip" ($visible.Width -ge $textWidth+8) @{Visible=$visible.Width;Text=$textWidth;Value=[string]$cell.FormattedValue}
    }
}
function Grid-Key([Windows.Forms.Keys]$Key){
    $args1=New-Object 'object[]' 1
    $event=New-Object Windows.Forms.KeyEventArgs($Key)
    $args1[0]=$event.PSObject.BaseObject
    $binding=[Reflection.BindingFlags]'Instance,NonPublic'
    [void][Windows.Forms.DataGridView].GetMethod('ProcessDataGridViewKey',$binding).Invoke($grid,$args1)
    [void][Windows.Forms.Control].GetMethod('OnKeyUp',$binding).Invoke($grid,$args1)
}
try{
    Import-Module (Join-Path $AppRoot 'ui\Theme.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $AppRoot 'ui\Controls.psm1') -Force -DisableNameChecking
    $module=Import-Module (Join-Path $AppRoot 'ui\MainWindow.psm1') -Force -DisableNameChecking -PassThru
    $minimums=@{Name=240;Publisher=200;Version=150;Date=130;Size=150}
    foreach($scale in @(1.0,1.25,1.5,2.0)){
        $form=New-Object Windows.Forms.Form
        $form.AutoScaleMode='None';$form.ClientSize=New-Object Drawing.Size(850,280)
        $form.Text='QA25 F022 source geometry, NOT installed DPI acceptance'
        $panel=New-Object Windows.Forms.Panel
        $panel.Bounds=New-Object Drawing.Rectangle(10,10,790,190);$panel.AutoScroll=$true
        $form.Controls.Add($panel);$form.Show();$form.Activate()
        & $module {
            param($Panel,$Scale)
            function script:ConvertTo-NyxBytesText {param([int64]$Bytes) return ('{0:N1} MB' -f ($Bytes/1MB))}
            $inventory=@(foreach($i in 0..29){[pscustomobject]@{Name=('Application {0:D2} with a realistic long display name' -f $i);Publisher='Dietrich AI Labs and Long Publisher Corporation';Version='145.0.3800.172';InstallDate='20260928';EstimatedSizeBytes=$(if($i%2){$null}else{123456789});InstallLocation=''}})
            $script:NyxUi=@{Content=$Panel;Palette=(Get-NyxPalette 'Light');LayoutScale=$Scale;HeaderTitle=(New-Object Windows.Forms.Label);NavButtons=@();CurrentPage='Home';Scan=[pscustomobject]@{Results=@([pscustomobject]@{CheckId='apps.inventory';Details=$inventory})}}
        } $panel $scale
        foreach($cycle in 1..2){
            & $module { Show-NyxPage -Page Apps }
            $grid=@($panel.Controls|Where-Object {$_ -is [Windows.Forms.DataGridView]})[0]
            $state=$grid.Tag
            Measure-Columns "page construction $cycle"
            if($MeasureOnly){continue}
            foreach($filter in @('','Application 2','Long Publisher','')){
                $state.Search.Text=$filter
                Measure-Columns "filter '$filter' cycle $cycle"
                [void]$state.Search.Focus();Settle
                [void]$panel.SelectNextControl($state.Search,$true,$true,$true,$false)
                Check-Focus 'Tab entry'
                foreach($key in @(([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End),[Windows.Forms.Keys]::End,([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home),([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End),[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown,[Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down)){
                    Grid-Key $key;Check-Focus "$key filter '$filter' cycle $cycle"
                }
                Assert-Readable "$scale internal horizontal scrolling used" ($grid.HorizontalScrollingOffset -gt 0) $grid.HorizontalScrollingOffset
                $panel.AutoScrollPosition=New-Object Drawing.Point(0,0);Settle
                Grid-Key End;Check-Focus 'End after manual outer scroll'
                Measure-Columns 'after navigation and filtering'
            }
            # Reconstruct the real page, not merely refocus the same grid.
            # Clear disposes the old page before the next real Apps construction.
            # Installed navigation away/back is a separate native acceptance case.
            & $module { Clear-NyxPage }
        }
        $form.Dispose();$form=$null
    }
}catch{$failure=$_.Exception.ToString()}finally{
    if($null -ne $form){$form.Dispose()}
    $parent=Split-Path -Parent $OutputPath;if($parent){[void][IO.Directory]::CreateDirectory($parent)}
    [pscustomobject]@{Harness='QA27-F024-PS51-27';Kind='Real Apps page source WinForms geometry, emulated scales; NOT installed native DPI acceptance';MeasureOnly=[bool]$MeasureOnly;Passed=@($checks|Where-Object Pass).Count;Failed=@($checks|Where-Object {-not $_.Pass}).Count;Failure=$failure;Measurements=$measurements.ToArray();Checks=$checks.ToArray();PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

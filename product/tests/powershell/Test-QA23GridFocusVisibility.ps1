[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Windows PowerShell 5.1 required'}
if([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'STA required'}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Import-Module (Join-Path $AppRoot 'ui\Theme.psm1') -Force
Import-Module (Join-Path $AppRoot 'ui\Controls.psm1') -Force
$checks=New-Object 'Collections.Generic.List[object]'
$failure=$null;$form=$null
function Settle-F020 {
    $end=[DateTime]::UtcNow.AddMilliseconds(65)
    do{[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 5}while([DateTime]::UtcNow -lt $end)
}
function Assert-F020([string]$Name,[bool]$Passed,$Geometry=$null){
    $checks.Add([pscustomobject]@{Name=$Name;Passed=$Passed;Geometry=$Geometry})
    if(-not $Passed){throw "F-020 source regression: $Name"}
}
function Test-CurrentVisibility([string]$Name){
    Settle-F020
    $cell=$grid.CurrentCell
    $rect=$grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$true)
    $mapped=$panel.RectangleToClient($grid.RectangleToScreen($rect))
    $intersection=[Drawing.Rectangle]::Intersect($mapped,$panel.ClientRectangle)
    $geometry=@{Row=$cell.RowIndex;Column=$cell.ColumnIndex;Cell=$mapped.ToString();Viewport=$panel.ClientRectangle.ToString();Intersection=$intersection.ToString();Outer=$panel.AutoScrollPosition.ToString();Internal=$grid.FirstDisplayedScrollingRowIndex}
    Assert-F020 $Name ($grid.ContainsFocus -and $intersection.Width -gt 0 -and $intersection.Height -ge [math]::Min($rect.Height,$panel.ClientSize.Height-8)) $geometry
    if($grid.FirstDisplayedScrollingRowIndex -gt 0){$script:internalSeen=$true}
    if($panel.AutoScrollPosition.Y -lt 0){$script:outerSeen=$true}
}
function Invoke-GridKey([Windows.Forms.Keys]$Key){
    $method=[Windows.Forms.DataGridView].GetMethod('ProcessDataGridViewKey',[Reflection.BindingFlags]'Instance,NonPublic')
    # Reflection does not unwrap PSObject arguments in Windows PowerShell 5.1.
    $arguments=New-Object 'object[]' 1
    $keyArgs=New-Object Windows.Forms.KeyEventArgs($Key)
    $arguments[0]=$keyArgs.PSObject.BaseObject
    [void]$method.Invoke($grid,$arguments)
    $up=[Windows.Forms.Control].GetMethod('OnKeyUp',[Reflection.BindingFlags]'Instance,NonPublic')
    [void]$up.Invoke($grid,$arguments)
}
try{
    foreach($scale in @(1.0,1.25,1.5,2.0)){
        $script:internalSeen=$false;$script:outerSeen=$false
        $form=New-Object Windows.Forms.Form
        $form.AutoScaleMode='None';$form.ClientSize=New-Object Drawing.Size(800,400)
        $form.Text='QA23 deterministic grid focus regression (source only)'
        $panel=New-Object Windows.Forms.Panel
        $panel.Bounds=New-Object Drawing.Rectangle(20,20,700,180);$panel.AutoScroll=$true
        $form.Controls.Add($panel)
        $before=New-Object Windows.Forms.Button
        $before.Text='Before';$before.Bounds=New-Object Drawing.Rectangle(24,24,130,35);$before.TabIndex=0
        $panel.Controls.Add($before)
        $grid=New-NyxGrid -X 24 -Y 160 -Width 850 -Height 400 -Palette (Get-NyxPalette -Theme Light)
        $grid.TabIndex=1;$grid.AutoSizeColumnsMode='None'
        foreach($i in 0..7){[void]$grid.Columns.Add("c$i","Column $i");$grid.Columns[$i].Width=180}
        foreach($i in 0..39){[void]$grid.Rows.Add("Row $i",'one','two','three','four','five','six','seven')}
        $panel.Controls.Add($grid)
        Set-NyxDeviceGeometry -Root $panel -Scale $scale -ChildrenOnly
        Set-NyxScrollExtentFromChildren -Root $panel
        Register-NyxScrollFocus -Root $panel
        $form.Show();$form.Activate();[void]$before.Focus();Settle-F020
        [void]$panel.SelectNextControl($before,$true,$true,$true,$false)
        Test-CurrentVisibility "$scale Tab entry"
        foreach($i in 1..39){Invoke-GridKey Down;Test-CurrentVisibility "$scale Down $i";Assert-F020 "$scale Down index $i" ($grid.CurrentCell.RowIndex -eq $i)}
        foreach($i in 38..0){Invoke-GridKey Up;Test-CurrentVisibility "$scale Up $i";Assert-F020 "$scale Up index $i" ($grid.CurrentCell.RowIndex -eq $i)}
        foreach($key in @([Windows.Forms.Keys]::PageDown,[Windows.Forms.Keys]::PageUp,([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::End),([Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Home),[Windows.Forms.Keys]::End,[Windows.Forms.Keys]::Home)){
            Invoke-GridKey $key;Test-CurrentVisibility "$scale $key"
        }
        foreach($i in 1..7){Invoke-GridKey Right;Test-CurrentVisibility "$scale Right $i"}
        foreach($i in 6..0){Invoke-GridKey Left;Test-CurrentVisibility "$scale Left $i"}
        foreach($repeat in 1..3){
            [void]$before.Focus();Settle-F020
            [void]$panel.SelectNextControl($before,$true,$true,$true,$false)
            Test-CurrentVisibility "$scale away/back $repeat"
        }
        $grid.Rows.Clear()
        foreach($i in 0..39){[void]$grid.Rows.Add("Reloaded $i",'one','two','three','four','five','six','seven')}
        $grid.CurrentCell=$grid.Rows[25].Cells[3]
        Test-CurrentVisibility "$scale Refresh/repopulation"
        $panel.AutoScrollPosition=New-Object Drawing.Point(0,0)
        Settle-F020
        Assert-F020 "$scale manual scroll not snapped back" ($panel.AutoScrollPosition.Y -eq 0)
        Invoke-GridKey Down;Test-CurrentVisibility "$scale navigation after manual scroll"
        Assert-F020 "$scale internal scrolling occurred" $script:internalSeen
        Assert-F020 "$scale outer scrolling occurred" $script:outerSeen
        $form.Close();$form.Dispose();$form=$null
    }
}catch{$failure=$_.Exception.ToString()}finally{
    if($null -ne $form){$form.Dispose()}
    @{Harness='QA25-F022-PS51-25';Kind='Native PS5.1 deterministic source WinForms geometry; scales emulate device geometry, NOT installed DPI acceptance';Passed=($null -eq $failure);Count=$checks.Count;Checks=$checks.ToArray();Failure=$failure;PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

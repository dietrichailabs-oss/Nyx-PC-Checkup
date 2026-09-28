Set-StrictMode -Version 2.0
function Get-NyxControlDpiScale {
    param([object]$Control)
    # DeviceDpi remains 96 in some inbox PowerShell WinForms hosts. Graphics
    # uses the actual window DC, matching the font rasterization in that host.
    $graphics=$Control.CreateGraphics()
    try {return ([double]$graphics.DpiX/96.0)} finally {$graphics.Dispose()}
}
function Register-NyxScrollFocus {
    param([object]$Root)
    foreach($control in @($Root.Controls)){
        if($control -is [Windows.Forms.DataGridView]){
            Register-NyxGridFocusVisibility -Grid $control
        }elseif($control.TabStop -and -not $control.PSObject.Properties['NyxFocusRegistered']){
            $control|Add-Member -NotePropertyName NyxFocusRegistered -NotePropertyValue $true
            $control.Add_Enter({
                param($sender,$eventArgs)
                $target=$sender
                while($null -ne $target.Parent){
                    $parent=$target.Parent
                    if($parent -is [Windows.Forms.ScrollableControl] -and $parent.AutoScroll){$parent.ScrollControlIntoView($target)}
                    $target=$parent
                }
            })
        }
        Register-NyxScrollFocus -Root $control
    }
}
function Show-NyxGridCurrentCell {
    param([Windows.Forms.DataGridView]$Grid)
    if($Grid.IsDisposed -or $Grid.Disposing -or -not $Grid.IsHandleCreated -or -not $Grid.ContainsFocus){return}
    $cell=$Grid.CurrentCell
    if($null -eq $cell -or -not $cell.Visible){return}
    $state=$Grid.NyxGridFocusState
    if($state.Adjusting){return}
    $state.Adjusting=$true
    try{
        # First let the grid reveal its cell within its own viewport. This is
        # independent of the (possibly much smaller) outer page viewport.
        $row=$Grid.Rows[$cell.RowIndex]
        if(-not $row.Displayed -and -not $row.Frozen){$Grid.FirstDisplayedScrollingRowIndex=$cell.RowIndex}
        $rect=$Grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$false)
        $dataLeft=if($Grid.RowHeadersVisible){$Grid.RowHeadersWidth}else{1}
        $dataBottom=$Grid.ClientSize.Height-1
        $dataRight=$Grid.ClientSize.Width-1
        foreach($bar in $Grid.Controls){
            if($bar.Visible -and $bar -is [Windows.Forms.HScrollBar]){$dataBottom-=$bar.Height}
            if($bar.Visible -and $bar -is [Windows.Forms.VScrollBar]){$dataRight-=$bar.Width}
        }
        if(-not $row.Frozen -and ($rect.Top -lt $Grid.ColumnHeadersHeight -or $rect.Bottom -gt $dataBottom)){
            $Grid.FirstDisplayedScrollingRowIndex=$cell.RowIndex
        }
        if(-not $Grid.Columns[$cell.ColumnIndex].Frozen){
            $rect=$Grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$false)
            $dx=0
            if($rect.Left -lt $dataLeft -or $rect.Width -gt ($dataRight-$dataLeft)){$dx=$rect.Left-$dataLeft}
            elseif($rect.Right -gt $dataRight){$dx=$rect.Right-$dataRight}
            if($dx -ne 0){$Grid.HorizontalScrollingOffset=[math]::Max(0,$Grid.HorizontalScrollingOffset+$dx)}
        }
        # Coordinates are actual device pixels. Recompute after each ancestor
        # moves: neither logical DPI assumptions nor a cached page origin work.
        $parent=$Grid.Parent
        while($null -ne $parent){
            if($parent -is [Windows.Forms.ScrollableControl] -and $parent.AutoScroll -and $parent.ClientSize.Width -gt 8 -and $parent.ClientSize.Height -gt 8){
                $rect=$Grid.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$true)
                if($rect.Width -le 0 -or $rect.Height -le 0){return}
                $visible=$parent.RectangleToClient($Grid.RectangleToScreen($rect))
                $width=[math]::Min($visible.Width,$parent.ClientSize.Width-8)
                $height=[math]::Min($visible.Height,$parent.ClientSize.Height-8)
                $dx=0;$dy=0
                if($visible.Left -lt 4){$dx=$visible.Left-4}
                elseif(($visible.Left+$width) -gt ($parent.ClientSize.Width-4)){$dx=$visible.Left+$width-$parent.ClientSize.Width+4}
                if($visible.Top -lt 4){$dy=$visible.Top-4}
                elseif(($visible.Top+$height) -gt ($parent.ClientSize.Height-4)){$dy=$visible.Top+$height-$parent.ClientSize.Height+4}
                if($dx -ne 0 -or $dy -ne 0){
                    $position=$parent.AutoScrollPosition
                    $parent.AutoScrollPosition=New-Object Drawing.Point(([math]::Max(0,-$position.X+$dx)),([math]::Max(0,-$position.Y+$dy)))
                }
            }
            $parent=$parent.Parent
        }
    }finally{$state.Adjusting=$false}
}
function Request-NyxGridFocusVisibility {
    param([Windows.Forms.DataGridView]$Grid)
    if($Grid.IsDisposed -or $Grid.Disposing -or -not $Grid.IsHandleCreated -or -not $Grid.ContainsFocus){return}
    if($Grid.NyxGridFocusState.Adjusting){return}
    # Coalesce until normal DataGridView key processing/internal scrolling has
    # settled. A per-grid timer carries explicit lifetime-safe sender state.
    $Grid.NyxGridFocusState.Timer.Start()
}
function Register-NyxGridFocusVisibility {
    param([Windows.Forms.DataGridView]$Grid)
    if($Grid.PSObject.Properties['NyxGridFocusState']){return}
    $timer=New-Object Windows.Forms.Timer
    $timer.Interval=15
    $timer.Tag=$Grid
    $Grid|Add-Member -NotePropertyName NyxGridFocusState -NotePropertyValue ([pscustomobject]@{Timer=$timer;Adjusting=$false})
    $timer.Add_Tick({
        param($sender,$eventArgs)
        $sender.Stop()
        Show-NyxGridCurrentCell -Grid $sender.Tag
    })
    $Grid.Add_Enter({param($sender,$eventArgs)Request-NyxGridFocusVisibility -Grid $sender})
    $Grid.Add_CurrentCellChanged({param($sender,$eventArgs)Request-NyxGridFocusVisibility -Grid $sender})
    $Grid.Add_KeyUp({
        param($sender,$eventArgs)
        if($eventArgs.KeyCode -in @([Windows.Forms.Keys]::Up,[Windows.Forms.Keys]::Down,[Windows.Forms.Keys]::Left,[Windows.Forms.Keys]::Right,[Windows.Forms.Keys]::PageUp,[Windows.Forms.Keys]::PageDown,[Windows.Forms.Keys]::Home,[Windows.Forms.Keys]::End,[Windows.Forms.Keys]::Tab)){
            Request-NyxGridFocusVisibility -Grid $sender
        }
    })
    $Grid.Add_SizeChanged({param($sender,$eventArgs)Request-NyxGridFocusVisibility -Grid $sender})
    $Grid.Add_Disposed({
        param($sender,$eventArgs)
        $sender.NyxGridFocusState.Timer.Stop()
        $sender.NyxGridFocusState.Timer.Dispose()
    })
}
function Set-NyxDeviceGeometry {
    param([object]$Root,[double]$Scale,[switch]$ChildrenOnly)
    if($Scale -le 0){throw 'Invalid UI scale'}
    $nodes=[Collections.Generic.List[object]]::new()
    $pending=[Collections.Generic.Queue[object]]::new()
    $pending.Enqueue($Root)
    while($pending.Count){
        $control=$pending.Dequeue()
        foreach($child in @($control.Controls)){$pending.Enqueue($child)}
        if($ChildrenOnly -and $control -eq $Root){continue}
        $previous=1.0
        if($control.PSObject.Properties['NyxGeometryScale']){$previous=[double]$control.NyxGeometryScale}
        $nodes.Add([pscustomobject]@{Control=$control;Bounds=$control.Bounds;Padding=$control.Padding;Margin=$control.Margin;Dock=$control.Dock;Anchor=$control.Anchor;Ratio=($Scale/$previous)})
        $control.SuspendLayout()
    }
    try{
        # Capture every rectangle before changing any parent. Disable anchors
        # during conversion so parent resizing cannot scale children twice.
        foreach($node in $nodes){$node.Control.Dock='None';$node.Control.Anchor='Top,Left'}
        foreach($node in $nodes){
            $c=$node.Control;$r=$node.Ratio;$b=$node.Bounds
            $c.Bounds=New-Object Drawing.Rectangle(([int][math]::Round($b.X*$r)),([int][math]::Round($b.Y*$r)),([int][math]::Round($b.Width*$r)),([int][math]::Round($b.Height*$r)))
            $p=$node.Padding;$m=$node.Margin
            $c.Padding=New-Object Windows.Forms.Padding(([int]($p.Left*$r)),([int]($p.Top*$r)),([int]($p.Right*$r)),([int]($p.Bottom*$r)))
            $c.Margin=New-Object Windows.Forms.Padding(([int]($m.Left*$r)),([int]($m.Top*$r)),([int]($m.Right*$r)),([int]($m.Bottom*$r)))
            if($c -is [Windows.Forms.DataGridView]){
                $c.RowTemplate.Height=[int][math]::Ceiling($c.RowTemplate.Height*$r)
                foreach($row in $c.Rows){$row.Height=[int][math]::Ceiling($row.Height*$r)}
                foreach($column in $c.Columns){
                    # Raising MinimumWidth can immediately clamp Width. Capture
                    # both original values before either setter changes them.
                    $scaledWidth=[int]($column.Width*$r)
                    $scaledMinimum=[math]::Max(2,[int]($column.MinimumWidth*$r))
                    $column.MinimumWidth=$scaledMinimum
                    $column.Width=[math]::Max($scaledMinimum,$scaledWidth)
                }
            }
            $c|Add-Member -NotePropertyName NyxGeometryScale -NotePropertyValue $Scale -Force
        }
        foreach($node in $nodes){$node.Control.Anchor=$node.Anchor;$node.Control.Dock=$node.Dock}
    }finally{
        for($i=$nodes.Count-1;$i -ge 0;$i--){$nodes[$i].Control.ResumeLayout($true)}
    }
    # Font sizes remain in points. Geometry alone is converted to device
    # pixels; changing point sizes here would double-scale text at high DPI.
}
function Set-NyxScrollExtentFromChildren {
    param([object]$Root,[int]$Padding=24)
    $right=0;$bottom=0
    foreach($child in @($Root.Controls)){$right=[math]::Max($right,$child.Right);$bottom=[math]::Max($bottom,$child.Bottom)}
    $Root.AutoScrollMinSize=New-Object Drawing.Size(($right+$Padding),($bottom+$Padding))
}
function Initialize-NyxScrollableDialog {
    param([object]$Form)
    $Form.AutoScaleMode='None';$Form.AutoScroll=$true
    $Form.Add_Shown({
        param($sender,$eventArgs)
        $scale=Get-NyxControlDpiScale -Control $sender
        foreach($child in @($sender.Controls)){$child.Anchor='Top,Left'}
        Set-NyxDeviceGeometry -Root $sender -Scale $scale -ChildrenOnly
        Set-NyxScrollExtentFromChildren -Root $sender -Padding ([int](24*$scale))
        $work=[Windows.Forms.Screen]::FromHandle($sender.Handle).WorkingArea
        $sender.MinimumSize=New-Object Drawing.Size([math]::Min($work.Width,[int](480*$scale)),[math]::Min($work.Height,[int](320*$scale)))
        $width=[math]::Min($work.Width,[int]($sender.Width*$scale))
        $height=[math]::Min($work.Height,[int]($sender.Height*$scale))
        $sender.Bounds=New-Object Drawing.Rectangle(($work.Left+[int](($work.Width-$width)/2)),($work.Top+[int](($work.Height-$height)/2)),$width,$height)
        Register-NyxScrollFocus -Root $sender
    })
}
function New-NyxLabel {
    param([string]$Text,[int]$X,[int]$Y,[int]$Width,[int]$Height=28,[float]$Size=10,[bool]$Bold=$false,[object]$Palette,[string]$Color='Text')
    $label=New-Object Windows.Forms.Label
    $label.Text=$Text;$label.Location=New-Object Drawing.Point($X,$Y);$label.Size=New-Object Drawing.Size($Width,$Height)
    $style=if($Bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
    $label.Font=New-Object Drawing.Font('Segoe UI',$Size,$style);$label.ForeColor=$Palette.$Color;$label.BackColor=[Drawing.Color]::Transparent;$label.AutoEllipsis=$false;$label.UseCompatibleTextRendering=$true
    return $label
}

function New-NyxButton {
    param([string]$Text,[int]$X,[int]$Y,[int]$Width=150,[int]$Height=38,[object]$Palette,[bool]$Primary=$false)
    $button=New-Object Windows.Forms.Button
    $button.Text=$Text;$button.Location=New-Object Drawing.Point($X,$Y);$button.Size=New-Object Drawing.Size($Width,$Height)
    $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=1;$button.Cursor=[Windows.Forms.Cursors]::Hand
    $button.Font=New-Object Drawing.Font('Segoe UI Semibold',10);$button.AutoEllipsis=$false
    if($Primary){$button.BackColor=$Palette.Accent;$button.ForeColor=$Palette.AccentText;$button.FlatAppearance.BorderColor=$Palette.Accent2}
    else{$button.BackColor=$Palette.Surface2;$button.ForeColor=$Palette.Text;$button.FlatAppearance.BorderColor=$Palette.Border}
    return $button
}

function New-NyxNavButton {
    param([string]$Text,[string]$Page,[int]$Y,[object]$Palette)
    $button=New-Object Windows.Forms.Button
    $button.Text=$Text;$button.Tag=$Page;$button.Location=New-Object Drawing.Point(14,$Y);$button.Size=New-Object Drawing.Size(182,42)
    $button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=0;$button.TextAlign='MiddleLeft';$button.Padding=New-Object Windows.Forms.Padding(14,0,0,0)
    $button.Font=New-Object Drawing.Font('Segoe UI Semibold',10);$button.AutoEllipsis=$false;$button.ForeColor=$Palette.Muted;$button.BackColor=$Palette.Rail;$button.Cursor=[Windows.Forms.Cursors]::Hand
    return $button
}

function New-NyxCard {
    param([int]$X,[int]$Y,[int]$Width,[int]$Height,[object]$Palette)
    $panel=New-Object Windows.Forms.Panel
    $panel.Location=New-Object Drawing.Point($X,$Y);$panel.Size=New-Object Drawing.Size($Width,$Height);$panel.BackColor=$Palette.Surface
    $panel.BorderStyle='FixedSingle'
    return $panel
}

function New-NyxGrid {
    param([int]$X,[int]$Y,[int]$Width,[int]$Height,[object]$Palette)
    $grid=New-Object Windows.Forms.DataGridView
    $grid.Location=New-Object Drawing.Point($X,$Y);$grid.Size=New-Object Drawing.Size($Width,$Height)
    $grid.ReadOnly=$true;$grid.AllowUserToAddRows=$false;$grid.AllowUserToDeleteRows=$false;$grid.AllowUserToResizeRows=$false
    $grid.SelectionMode='FullRowSelect';$grid.MultiSelect=$false;$grid.AutoSizeColumnsMode='Fill';$grid.RowTemplate.Height=32;$grid.ShowCellToolTips=$true;$grid.ColumnHeadersHeightSizeMode='AutoSize'
    Set-NyxGridTheme -Grid $grid -Palette $Palette
    Register-NyxGridFocusVisibility -Grid $grid
    return $grid
}

function New-NyxStatusPill {
    param([string]$Status,[int]$X,[int]$Y,[object]$Palette)
    $label=New-Object Windows.Forms.Label
    $label.Text=switch($Status){'Good'{([char]0x2713).ToString()+' Good'};'NeedsAttention'{'! Needs Attention'};'Optional'{([char]0x25CB).ToString()+' Optional'};default{'? Unknown'}}
    $label.Location=New-Object Drawing.Point($X,$Y);$label.Size=New-Object Drawing.Size(150,28)
    $label.Font=New-Object Drawing.Font('Segoe UI Semibold',9);$label.ForeColor=Get-NyxStatusColor -Status $Status -Palette $Palette;$label.BackColor=[Drawing.Color]::Transparent
    return $label
}

Export-ModuleMember -Function New-NyxLabel,New-NyxButton,New-NyxNavButton,New-NyxCard,New-NyxGrid,New-NyxStatusPill,Get-NyxControlDpiScale,Register-NyxScrollFocus,Set-NyxDeviceGeometry,Set-NyxScrollExtentFromChildren,Initialize-NyxScrollableDialog

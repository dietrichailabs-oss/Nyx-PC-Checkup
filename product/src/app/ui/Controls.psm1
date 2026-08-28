Set-StrictMode -Version 2.0
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

Export-ModuleMember -Function New-NyxLabel,New-NyxButton,New-NyxNavButton,New-NyxCard,New-NyxGrid,New-NyxStatusPill

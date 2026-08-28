Set-StrictMode -Version 2.0

function Get-NyxEffectiveTheme {
    param([string]$Preference='FollowWindows')
    if ($Preference -eq 'Dark' -or $Preference -eq 'Light') { return $Preference }
    try {
        $value=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
        if ([int]$value -eq 1) { return 'Light' }
    } catch { }
    return 'Dark'
}

function Get-NyxPalette {
    param([string]$Theme='Dark')
    Add-Type -AssemblyName System.Drawing
    function C([string]$Hex){return [Drawing.ColorTranslator]::FromHtml($Hex)}
    if ($Theme -eq 'Light') {
        return [pscustomobject]@{
            Window=(C '#F4F7FB'); Rail=(C '#E8EEF7'); Surface=(C '#FFFFFF'); Surface2=(C '#EEF3F9'); Border=(C '#CDD8E6');
            Text=(C '#142033'); Muted=(C '#5D6B7E'); Accent=(C '#0969DA'); Accent2=(C '#0B84F3'); AccentText=(C '#FFFFFF');
            Good=(C '#16845B'); Attention=(C '#C2412D'); Optional=(C '#8A5A00'); Unknown=(C '#64748B'); Hover=(C '#DCE8F8')
        }
    }
    return [pscustomobject]@{
        Window=(C '#090D14'); Rail=(C '#0B111B'); Surface=(C '#111A28'); Surface2=(C '#162235'); Border=(C '#26364D');
        Text=(C '#F3F7FC'); Muted=(C '#9DAEC4'); Accent=(C '#168BFF'); Accent2=(C '#4AB0FF'); AccentText=(C '#FFFFFF');
        Good=(C '#38D39F'); Attention=(C '#FF806B'); Optional=(C '#F4BE5B'); Unknown=(C '#8CA0B8'); Hover=(C '#1B2B42')
    }
}

function Get-NyxStatusColor {
    param([string]$Status,[object]$Palette)
    switch($Status){'Good'{return $Palette.Good};'NeedsAttention'{return $Palette.Attention};'Optional'{return $Palette.Optional};default{return $Palette.Unknown}}
}

function Set-NyxGridTheme {
    param([Windows.Forms.DataGridView]$Grid,[object]$Palette)
    $Grid.BackgroundColor=$Palette.Surface
    $Grid.GridColor=$Palette.Border
    $Grid.BorderStyle='None'
    $Grid.EnableHeadersVisualStyles=$false
    $Grid.ColumnHeadersDefaultCellStyle.BackColor=$Palette.Surface2
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor=$Palette.Text
    $Grid.ColumnHeadersDefaultCellStyle.SelectionBackColor=$Palette.Surface2
    $Grid.ColumnHeadersDefaultCellStyle.Font=New-Object Drawing.Font('Segoe UI Semibold',10)
    $Grid.DefaultCellStyle.BackColor=$Palette.Surface
    $Grid.DefaultCellStyle.ForeColor=$Palette.Text
    $Grid.DefaultCellStyle.SelectionBackColor=$Palette.Hover
    $Grid.DefaultCellStyle.SelectionForeColor=$Palette.Text
    $Grid.AlternatingRowsDefaultCellStyle.BackColor=$Palette.Surface2
    $Grid.RowHeadersVisible=$false
}

Export-ModuleMember -Function Get-NyxEffectiveTheme,Get-NyxPalette,Get-NyxStatusColor,Set-NyxGridTheme

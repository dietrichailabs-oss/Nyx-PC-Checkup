param(
    [string]$InstalledRoot = "$env:LOCALAPPDATA\Programs\Dietrich AI Labs\Nyx PC Checkup",
    [string]$EvidenceRoot = "$env:LOCALAPPDATA\NyxQA26Geometry"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class QA26ReadOnlyGeometry {
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hwnd);
 [DllImport("user32.dll")] public static extern IntPtr GetThreadDpiAwarenessContext();
 [DllImport("user32.dll")] public static extern bool AreDpiAwarenessContextsEqual(IntPtr a, IntPtr b);
}
'@
$entry = Join-Path $InstalledRoot 'app\NyxPCCheckup.ps1'
if (!(Test-Path -LiteralPath $entry)) { throw "Installed entry missing: $entry" }
$session = Join-Path $EvidenceRoot ('geometry_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $session -Force | Out-Null
$payload = @(Get-ChildItem -LiteralPath $InstalledRoot -Recurse -File | ForEach-Object {
    [pscustomobject]@{ Path=$_.FullName.Substring($InstalledRoot.Length+1); Bytes=$_.Length; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
})
$payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $session 'INSTALLED_HASHES.json') -Encoding UTF8
$global:QA26ObserverState = @{ Directory=$session; LastSignature=''; Samples=0 }
function Get-QA26RectangleRecord {
    param([System.Drawing.Rectangle]$Rectangle)
    [pscustomobject]@{ X=$Rectangle.X; Y=$Rectangle.Y; Width=$Rectangle.Width; Height=$Rectangle.Height }
}
function Get-QA26ControlRecords {
    param([System.Windows.Forms.Control]$Control, [string]$Path)
    if ($Control.IsDisposed) { return }
    $ancestors = @()
    $parent = $Control.Parent
    while ($null -ne $parent) {
        $ancestors += [pscustomobject]@{ Type=$parent.GetType().FullName; Name=$parent.Name; ClientScreen=(Get-QA26RectangleRecord $parent.RectangleToScreen($parent.ClientRectangle)); Visible=$parent.Visible }
        $parent = $parent.Parent
    }
    $grid = $null
    if ($Control -is [System.Windows.Forms.DataGridView]) {
        $columns = @($Control.Columns | ForEach-Object {
            [pscustomobject]@{ Index=$_.Index; Name=$_.Name; Header=$_.HeaderText; Width=$_.Width; MinimumWidth=$_.MinimumWidth; DisplayIndex=$_.DisplayIndex; Visible=$_.Visible; AutoSizeMode=[string]$_.AutoSizeMode; HeaderMeasuredWidth=[System.Windows.Forms.TextRenderer]::MeasureText([string]$_.HeaderText,$Control.Font).Width }
        })
        $cells = @()
        foreach ($row in $Control.Rows) {
            if ($row.IsNewRow) { continue }
            foreach ($cell in $row.Cells) {
                $rect = $Control.GetCellDisplayRectangle($cell.ColumnIndex,$cell.RowIndex,$false)
                if (!$row.Displayed -and !$cell.Selected) { continue }
                $text = [string]$cell.FormattedValue
                $cells += [pscustomobject]@{ Row=$cell.RowIndex; Column=$cell.ColumnIndex; Text=$text; Selected=$cell.Selected; Displayed=$row.Displayed; DisplayRectangle=(Get-QA26RectangleRecord $rect); ScreenRectangle=(Get-QA26RectangleRecord $Control.RectangleToScreen($rect)); MeasuredTextWidth=[System.Windows.Forms.TextRenderer]::MeasureText($text,$Control.Font).Width; Padding=[string]$cell.InheritedStyle.Padding; WrapMode=[string]$cell.InheritedStyle.WrapMode; ToolTip=$cell.ToolTipText }
            }
        }
        $current = $null
        if ($null -ne $Control.CurrentCell) { $current = [pscustomobject]@{ Row=$Control.CurrentCell.RowIndex; Column=$Control.CurrentCell.ColumnIndex } }
        $grid = [pscustomobject]@{ Columns=$columns; Cells=$cells; CurrentCell=$current; RowCount=$Control.RowCount; ScrollBars=[string]$Control.ScrollBars; HorizontalOffset=$Control.HorizontalScrollingOffset; FirstDisplayedRow=$Control.FirstDisplayedScrollingRowIndex }
    }
    [pscustomobject]@{ Path=$Path; Type=$Control.GetType().FullName; Name=$Control.Name; Text=$Control.Text; Visible=$Control.Visible; Enabled=$Control.Enabled; Focused=$Control.Focused; ContainsFocus=$Control.ContainsFocus; TabIndex=$Control.TabIndex; TabStop=$Control.TabStop; Bounds=(Get-QA26RectangleRecord $Control.Bounds); ClientScreen=(Get-QA26RectangleRecord $Control.RectangleToScreen($Control.ClientRectangle)); Font=[pscustomobject]@{ Name=$Control.Font.Name; Size=$Control.Font.Size; Unit=[string]$Control.Font.Unit }; Ancestors=$ancestors; Grid=$grid }
    $index = 0
    foreach ($child in $Control.Controls) {
        Get-QA26ControlRecords -Control $child -Path ($Path + '/' + $index)
        $index++
    }
}
function Save-QA26GeometrySample {
    $forms = @([System.Windows.Forms.Application]::OpenForms)
    if ($forms.Count -eq 0) { return }
    $records = @()
    foreach ($form in $forms) {
        if ($form.IsDisposed) { continue }
        $records += [pscustomobject]@{ Title=$form.Text; Dpi=[QA26ReadOnlyGeometry]::GetDpiForWindow($form.Handle); Bounds=(Get-QA26RectangleRecord $form.Bounds); WindowState=[string]$form.WindowState; Controls=@(Get-QA26ControlRecords -Control $form -Path $form.Name) }
    }
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $measurement = [pscustomobject]@{ Forms=$records; ScreenBounds=(Get-QA26RectangleRecord $screen.Bounds); WorkArea=(Get-QA26RectangleRecord $screen.WorkingArea); ObserverPerMonitorV2=[QA26ReadOnlyGeometry]::AreDpiAwarenessContextsEqual([QA26ReadOnlyGeometry]::GetThreadDpiAwarenessContext(),[IntPtr](-4)) }
    $signature = $measurement | ConvertTo-Json -Depth 30 -Compress
    if ($signature -eq $global:QA26ObserverState.LastSignature) { return }
    $global:QA26ObserverState.LastSignature = $signature
    $global:QA26ObserverState.Samples++
    [pscustomobject]@{ Utc=[DateTime]::UtcNow.ToString('o'); Sequence=$global:QA26ObserverState.Samples; Measurement=$measurement } | ConvertTo-Json -Depth 32 -Compress | Add-Content -LiteralPath (Join-Path $global:QA26ObserverState.Directory 'CONTROL_GEOMETRY.jsonl') -Encoding UTF8
}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1500
$timer.Add_Tick({ Save-QA26GeometrySample })
try {
    $timer.Start()
    # Read-only in-process diagnostics. No UI inputs, control mutation, source edits,
    # or product-file writes. This executes the exact installed script, not Setup.
    Set-Location -LiteralPath (Split-Path -Parent $entry)
    & $entry
    [pscustomobject]@{ Utc=[DateTime]::UtcNow.ToString('o'); Samples=$global:QA26ObserverState.Samples; Entry=$entry; Acceptance='NOT_AUTOMATICALLY_DECIDED'; LaunchMode='Evidence wrapper around exact installed script, not native EXE launch' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $session 'END.json') -Encoding UTF8
} catch {
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $session 'OBSERVER_ERROR.txt') -Encoding UTF8
    throw
} finally {
    $timer.Stop()
    $timer.Dispose()
}

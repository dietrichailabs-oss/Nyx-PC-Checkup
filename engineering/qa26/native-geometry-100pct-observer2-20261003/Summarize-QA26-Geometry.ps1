param([Parameter(Mandatory=$true)][string]$InputPath,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$records=@(Get-Content -LiteralPath $InputPath | ForEach-Object { $_ | ConvertFrom-Json })
if($records.Count-eq 0){throw 'No geometry samples'}
$headers=@()
$focused=@()
$textWarnings=@()
$fonts=@()
$grids=0
$apps=0
foreach($record in $records){
    if($record.Schema-ne 'QA26-GEOMETRY-READONLY-2'){throw 'Wrong observer schema'}
    foreach($form in $record.Measurement.Forms){
        foreach($control in $form.Controls){
            if($null-eq $control.Grid){continue}
            $grids++
            $isApps=@($control.Grid.Columns | Where-Object Header -eq 'Application').Count-gt 0
            if($isApps){$apps++}
            foreach($column in $control.Grid.Columns){
                $fonts += $column.HeaderFontSource
                $headers += [pscustomobject]@{Sequence=$record.Sequence;Dpi=$form.Dpi;Apps=$isApps;Header=$column.Header;Width=$column.Width;MinimumWidth=$column.MinimumWidth;MeasuredWidth=$column.HeaderMeasuredWidth;MeasuredHeight=$column.HeaderMeasuredHeight;Font=$column.HeaderFont;Wrap=$column.HeaderWrapMode;Rectangle=$column.HeaderScreenRectangle;PotentialOverflow=($column.HeaderMeasuredWidth-gt $column.Width)}
            }
            foreach($cell in $control.Grid.Cells){
                $fonts += $cell.FontSource
                if($cell.MeasuredTextWidth-gt $cell.DisplayRectangle.Width -and $cell.WrapMode-ne 'True'){
                    $textWarnings += [pscustomobject]@{Sequence=$record.Sequence;Apps=$isApps;Row=$cell.Row;Column=$cell.Column;Text=$cell.Text;MeasuredWidth=$cell.MeasuredTextWidth;CellWidth=$cell.DisplayRectangle.Width;Font=$cell.EffectiveFont;ToolTip=$cell.ToolTip;Classification='DIAGNOSTIC_ONLY_NOT_PRODUCT_FAIL'}
                }
                $current=$control.Grid.CurrentCell
                if(!$control.ContainsFocus -or $null-eq $current -or $cell.Row-ne $current.Row -or $cell.Column-ne $current.Column){continue}
                $rect=$cell.ScreenRectangle
                $left=[double]$rect.X;$top=[double]$rect.Y
                $right=$left+$rect.Width;$bottom=$top+$rect.Height
                $clips=@($control.ClientScreen)+@($control.Ancestors | ForEach-Object{$_.ClientScreen})
                foreach($clip in $clips){
                    $left=[Math]::Max($left,[double]$clip.X)
                    $top=[Math]::Max($top,[double]$clip.Y)
                    $right=[Math]::Min($right,([double]$clip.X+$clip.Width))
                    $bottom=[Math]::Min($bottom,([double]$clip.Y+$clip.Height))
                }
                $visibleWidth=[Math]::Max(0,$right-$left)
                $visibleHeight=[Math]::Max(0,$bottom-$top)
                $focused += [pscustomobject]@{Sequence=$record.Sequence;Apps=$isApps;Row=$cell.Row;Column=$cell.Column;Text=$cell.Text;Rectangle=$rect;VisibleWidth=$visibleWidth;VisibleHeight=$visibleHeight;FullyWithinClientAncestors=($visibleWidth-ge $rect.Width -and $visibleHeight-ge $rect.Height);Classification='GEOMETRY_OBSERVATION_NOT_FINAL_ACCESSIBILITY_VERDICT'}
            }
        }
    }
}
$summary=[pscustomobject]@{
    Schema='QA26-GEOMETRY-DIAGNOSTIC-1'
    Source=$InputPath
    SourceSHA256=(Get-FileHash -LiteralPath $InputPath -Algorithm SHA256).Hash
    Samples=$records.Count
    AllPerMonitorV2=(@($records | Where-Object { !$_.Measurement.ObserverPerMonitorV2 }).Count-eq 0)
    Dpi=@($records | ForEach-Object {$_.Measurement.Forms.Dpi} | Sort-Object -Unique)
    ScreenBounds=@($records | ForEach-Object {$_.Measurement.ScreenBounds | ConvertTo-Json -Compress} | Sort-Object -Unique)
    WorkAreas=@($records | ForEach-Object {$_.Measurement.WorkArea | ConvertTo-Json -Compress} | Sort-Object -Unique)
    GridSnapshots=$grids
    AppsGridSnapshots=$apps
    FontFallbackRecords=@($fonts | Where-Object {$_-like '*fallback*'}).Count
    HeaderMetrics=$headers
    FocusedCellGeometry=$focused
    PotentialTextOverflow=$textWarnings
    Acceptance='NOT_AUTOMATICALLY_DECIDED'
    Caveats=@('Measured text overflow requires tooltip/wrapping/action-access evaluation, not automatic product failure','Maximized outer form bounds alone do not establish visible-frame work-area containment','This diagnostic wrapper is not native EXE launch evidence','No completed F-008 matrix cells are inferred from these samples')
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
$summary | Select-Object Samples,AllPerMonitorV2,Dpi,ScreenBounds,WorkAreas,GridSnapshots,AppsGridSnapshots,FontFallbackRecords,Acceptance | ConvertTo-Json -Depth 5
$headers | Where-Object Apps | Select-Object Dpi,Header,Width,MinimumWidth,MeasuredWidth,PotentialOverflow | Sort-Object Dpi,Header,Width -Unique | Format-Table -AutoSize
$focused | Select-Object Sequence,Apps,Row,Column,VisibleWidth,VisibleHeight,FullyWithinClientAncestors | Format-Table -AutoSize

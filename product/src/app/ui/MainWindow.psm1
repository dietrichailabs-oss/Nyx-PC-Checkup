Set-StrictMode -Version 2.0
$script:NyxUi=$null

function Get-NyxPowerShellPath { return (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') }
function Invoke-NyxOpen {
    param([string]$Target,[string]$Arguments='')
    try { if($Arguments){Start-Process -FilePath $Target -ArgumentList $Arguments}else{Start-Process $Target} } catch { [Windows.Forms.MessageBox]::Show("Could not open the requested Windows page or folder.`r`n$($_.Exception.Message)",'Nyx PC Checkup','OK','Warning')|Out-Null }
}
function Clear-NyxPage {
    foreach($control in @($script:NyxUi.Content.Controls)){try{$control.Dispose()}catch{}}
    $script:NyxUi.Content.Controls.Clear()
    $script:NyxUi.Content.AutoScrollPosition=[Drawing.Point]::Empty
    $script:NyxUi.Content.AutoScrollMinSize=[Drawing.Size]::Empty
}
function Get-NyxPageWidth { return [math]::Max(430,([int]($script:NyxUi.Content.ClientSize.Width/$script:NyxUi.LayoutScale)-52)) }
function Set-NyxPageScrollExtent {
    param([int]$Height)
    if($null -eq $script:NyxUi -or $null -eq $script:NyxUi.Content){return}
    $minimum=[math]::Max($Height,$script:NyxUi.Content.ClientSize.Height)
    $script:NyxUi.Content.AutoScrollMinSize=New-Object Drawing.Size(0,$minimum)
}
function Register-NyxFocusScrollTree {
    param([object]$Root)
    if($null -eq $Root){return}
    foreach($control in @($Root.Controls)){
        # F-020: grids use Controls' current-cell/ancestor visibility helper.
        # Scrolling the whole oversized grid into view would reset that work.
        if([bool]$control.TabStop -and $control -isnot [Windows.Forms.DataGridView]){
            $control.Add_Enter({
                param($sender,$eventArgs)
                try{
                    $target=$sender
                    while($null -ne $target.Parent -and $target.Parent -ne $script:NyxUi.Content){$target=$target.Parent}
                    if($null -ne $target.Parent -and $target.Parent -eq $script:NyxUi.Content){
                        $script:NyxUi.Content.ScrollControlIntoView($target)
                    }
                }catch{}
            })
        }
        if($control.Controls.Count -gt 0){Register-NyxFocusScrollTree -Root $control}
    }
}
function Get-NyxResponsiveWindowSize {
    param([object]$Form)
    $working=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    if($Form.IsHandleCreated){$working=[Windows.Forms.Screen]::FromHandle($Form.Handle).WorkingArea}
    $dpi=96.0
    try{
        $graphics=$Form.CreateGraphics()
        $dpi=[double]$graphics.DpiX
        $graphics.Dispose()
    }catch{}
    if($dpi -lt 96.0){$dpi=96.0}
    $scale=$dpi/96.0
    $availableWidth=[math]::Max(1,$working.Width-32)
    $availableHeight=[math]::Max(1,$working.Height-32)
    $targetWidth=[math]::Min([int][math]::Ceiling(1280*$scale),$availableWidth)
    $targetHeight=[math]::Min([int][math]::Ceiling(820*$scale),$availableHeight)
    return (New-Object Drawing.Size($targetWidth,$targetHeight))
}
function Get-NyxClampedWindowBounds {
    param([Drawing.Rectangle]$Bounds,[Drawing.Rectangle]$WorkingArea)
    if($WorkingArea.Width -le 0 -or $WorkingArea.Height -le 0){return $Bounds}
    $width=[math]::Min($Bounds.Width,$WorkingArea.Width)
    $height=[math]::Min($Bounds.Height,$WorkingArea.Height)
    $left=[math]::Max($WorkingArea.Left,[math]::Min($Bounds.Left,$WorkingArea.Right-$width))
    $top=[math]::Max($WorkingArea.Top,[math]::Min($Bounds.Top,$WorkingArea.Bottom-$height))
    return (New-Object Drawing.Rectangle($left,$top,$width,$height))
}
function Set-NyxWindowWithinWorkingArea {
    param([object]$Form)
    if($Form.IsDisposed -or -not $Form.IsHandleCreated -or
        $Form.WindowState -ne [Windows.Forms.FormWindowState]::Normal){return}
    if($script:NyxUi.BoundsAdjusting){return}
    $working=[Windows.Forms.Screen]::FromHandle($Form.Handle).WorkingArea
    if($working.Width -le 0 -or $working.Height -le 0){return}
    $script:NyxUi.BoundsAdjusting=$true
    try{
        # MinimumSize participates in SetBounds. Reduce it before clamping an
        # autoscaled window onto a smaller monitor; restore it on larger ones.
        $scale=Get-NyxControlDpiScale -Control $Form
        $minimum=$script:NyxUi.BoundsMinimum96
        $Form.MinimumSize=New-Object Drawing.Size(
            [math]::Min($working.Width,[int][math]::Round($minimum.Width*$scale)),
            [math]::Min($working.Height,[int][math]::Round($minimum.Height*$scale)))
        $target=Get-NyxClampedWindowBounds -Bounds $Form.Bounds -WorkingArea $working
        if($Form.Bounds -ne $target){$Form.Bounds=$target}
    }finally{$script:NyxUi.BoundsAdjusting=$false}
}
function Add-NyxPageHeading {
    param([string]$Title,[string]$Subtitle)
    $w=Get-NyxPageWidth
    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text $Title -X 24 -Y 18 -Width $w -Height 42 -Size 21 -Bold $true -Palette $script:NyxUi.Palette))
    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text $Subtitle -X 24 -Y 61 -Width $w -Height 54 -Size 10 -Palette $script:NyxUi.Palette -Color 'Muted'))
}

function Get-NyxResultsByCategory {
    param([string[]]$Categories)
    if($null -eq $script:NyxUi.Scan){return @()}
    return @($script:NyxUi.Scan.Results|Where-Object{$Categories -contains [string]$_.Category})
}
function Get-NyxGroupStatus {
    param([object[]]$Results)
    $r=@($Results|Where-Object{$null -ne $_ -and $null -ne $_.PSObject.Properties['Status']})
    if(@($r|Where-Object{$_.Status -eq 'NeedsAttention'}).Count -gt 0){return 'NeedsAttention'}
    if($r.Count -eq 0 -or @($r|Where-Object{$_.Status -eq 'Unknown'}).Count -eq $r.Count){return 'Unknown'}
    if(@($r|Where-Object{$_.Status -eq 'Optional'}).Count -gt 0){return 'Optional'}
    return 'Good'
}
function Add-NyxScanButtons {
    param([int]$X,[int]$Y)
    $quick=New-NyxButton -Text 'Quick Check' -X $X -Y $Y -Width 150 -Palette $script:NyxUi.Palette -Primary $true
    $full=New-NyxButton -Text 'Full Check' -X ($X+164) -Y $Y -Width 150 -Palette $script:NyxUi.Palette
    $quick.Add_Click({Start-NyxScan -Mode 'Quick'});$full.Add_Click({Start-NyxScan -Mode 'Full'})
    $script:NyxUi.Content.Controls.AddRange(@($quick,$full))
}
function New-NyxResultsGridControl {
    param([object[]]$Results,[int]$Y,[int]$Height=420)
    $w=Get-NyxPageWidth
    $grid=New-NyxGrid -X 24 -Y $Y -Width $w -Height $Height -Palette $script:NyxUi.Palette
    $grid.Anchor='Top,Left,Right'
    [void]$grid.Columns.Add('Status','Status');[void]$grid.Columns.Add('Category','Category');[void]$grid.Columns.Add('Check','Check');[void]$grid.Columns.Add('Finding','What Nyx found')
    $grid.Columns['Status'].FillWeight=20;$grid.Columns['Category'].FillWeight=20;$grid.Columns['Check'].FillWeight=28;$grid.Columns['Finding'].FillWeight=80
    foreach($result in @($Results)){
        $symbol=Get-NyxStatusSymbol ([string]$result.Status);$label=Get-NyxStatusLabel ([string]$result.Status)
        $index=$grid.Rows.Add("$symbol $label",[string]$result.Category,[string]$result.Name,[string]$result.Finding)
        $grid.Rows[$index].Tag=$result;$grid.Rows[$index].Cells[0].Style.ForeColor=Get-NyxStatusColor -Status ([string]$result.Status) -Palette $script:NyxUi.Palette
    }
    $grid.Add_CellDoubleClick({param($sender,$eventArgs)if($eventArgs.RowIndex -ge 0){$r=$sender.Rows[$eventArgs.RowIndex].Tag;if($r){Show-NyxResultDetailDialog -Result $r -Palette $script:NyxUi.Palette}}})
    return $grid
}
function Add-NyxNoScanCard {
    param([int]$Y=125)
    $w=Get-NyxPageWidth
    $card=New-NyxCard -X 24 -Y $Y -Width $w -Height 218 -Palette $script:NyxUi.Palette
    $card.Anchor='Top,Left,Right'
    $card.Controls.Add((New-NyxLabel -Text 'No check has been run yet' -X 22 -Y 20 -Width ($w-50) -Height 38 -Size 16 -Bold $true -Palette $script:NyxUi.Palette))
    $card.Controls.Add((New-NyxLabel -Text 'Scanning is read-only, normally needs no administrator privileges, and never performs cleanup or changes startup settings.' -X 22 -Y 60 -Width ($w-50) -Height 68 -Size 10 -Palette $script:NyxUi.Palette -Color 'Muted'))
    $q=New-NyxButton -Text 'Check My PC' -X 22 -Y 148 -Width 170 -Palette $script:NyxUi.Palette -Primary $true
    $f=New-NyxButton -Text 'Run Full Check' -X 206 -Y 148 -Width 180 -Palette $script:NyxUi.Palette
    $q.Add_Click({Start-NyxScan -Mode 'Quick'})
    $f.Add_Click({Start-NyxScan -Mode 'Full'})
    $card.Controls.AddRange(@($q,$f))
    $script:NyxUi.Content.Controls.Add($card)
    Set-NyxPageScrollExtent -Height ($Y+246)
}

function Show-NyxHomePage {
    Clear-NyxPage
    Add-NyxPageHeading -Title 'Your PC' -Subtitle (Get-NyxPrivacyStatement)
    if($null -eq $script:NyxUi.Scan){Add-NyxNoScanCard -Y 124;return}
    $w=Get-NyxPageWidth;$summary=$script:NyxUi.Scan.Summary
    $card=New-NyxCard -X 24 -Y 122 -Width $w -Height 150 -Palette $script:NyxUi.Palette;$card.Anchor='Top,Left,Right'
    $card.Controls.Add((New-NyxStatusPill -Status ([string]$summary.OverallStatus) -X 22 -Y 18 -Palette $script:NyxUi.Palette))
    $card.Controls.Add((New-NyxLabel -Text ([string]$summary.Headline) -X 22 -Y 51 -Width ($w-250) -Height 44 -Size 18 -Bold $true -Palette $script:NyxUi.Palette))
    $card.Controls.Add((New-NyxLabel -Text ("Good {0}   |   Needs Attention {1}   |   Optional {2}   |   Unknown {3}" -f $summary.Good,$summary.NeedsAttention,$summary.Optional,$summary.Unknown) -X 22 -Y 101 -Width ($w-50) -Height 28 -Size 10 -Palette $script:NyxUi.Palette -Color 'Muted'))
    $check=New-NyxButton -Text 'Check My PC' -X ($w-190) -Y 48 -Width 150 -Palette $script:NyxUi.Palette -Primary $true;$check.Anchor='Top,Right';$check.Add_Click({Start-NyxScan -Mode 'Quick'});$card.Controls.Add($check)
    $script:NyxUi.Content.Controls.Add($card)
    $groups=[ordered]@{Storage=@('Storage','Downloads','Cleanup');Updates=@('Updates');Security=@('Security');Startup=@('Startup');Backup=@('Backup');System=@('System','Battery','Drive Health','Performance','Network','Applications')}
    $i=0
    foreach($name in $groups.Keys){
        $col=$i%3;$row=[math]::Floor($i/3);$x=24+($col*268);$y=292+($row*132);$groupResults=@(Get-NyxResultsByCategory -Categories $groups[$name]);$status=Get-NyxGroupStatus -Results $groupResults
        $c=New-NyxCard -X $x -Y $y -Width 250 -Height 112 -Palette $script:NyxUi.Palette
        $c.Controls.Add((New-NyxLabel -Text $name -X 16 -Y 14 -Width 205 -Height 28 -Size 12 -Bold $true -Palette $script:NyxUi.Palette))
        $c.Controls.Add((New-NyxStatusPill -Status $status -X 16 -Y 48 -Palette $script:NyxUi.Palette))
        $count=@($groupResults|Where-Object{$_.Status -eq 'NeedsAttention'}).Count
        $detail=if($count -gt 0){"$count recommended action(s)"}elseif($status -eq 'Optional'){'Optional items available'}elseif($status -eq 'Good'){'No action needed'}else{'Could not determine'}
        $c.Controls.Add((New-NyxLabel -Text $detail -X 16 -Y 78 -Width 210 -Height 24 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))
        $script:NyxUi.Content.Controls.Add($c);$i++
    }
    $findings=@($script:NyxUi.Scan.Results|Sort-Object @{Expression={switch($_.Status){'NeedsAttention'{0};'Optional'{1};'Unknown'{2};default{3}}}},Category|Where-Object{$_.Status -ne 'Good'}|Select-Object -First 6)
    $y=572;$title=if($findings.Count -gt 0){'Things worth looking at'}else{'No action list'}
    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text $title -X 24 -Y $y -Width $w -Height 36 -Size 16 -Bold $true -Palette $script:NyxUi.Palette));$y+=42
    if($findings.Count -eq 0){$script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'Your PC looks good. Nothing needs fixing.' -X 24 -Y $y -Width $w -Height 34 -Size 11 -Palette $script:NyxUi.Palette))}
    else{foreach($r in $findings){$symbol=Get-NyxStatusSymbol $r.Status;$label=New-NyxLabel -Text ("{0}  {1}: {2}" -f $symbol,$r.Name,$r.Finding) -X 30 -Y $y -Width ($w-30) -Height 42 -Size 10 -Palette $script:NyxUi.Palette;$label.ForeColor=Get-NyxStatusColor -Status $r.Status -Palette $script:NyxUi.Palette;$script:NyxUi.Content.Controls.Add($label);$y+=44}}
    $script:NyxUi.Content.AutoScrollMinSize=New-Object Drawing.Size(0,($y+60))
}

function Show-NyxCheckupPage {
    Clear-NyxPage;Add-NyxPageHeading -Title 'Checkup' -Subtitle 'Quick Check covers the most important common health indicators. Full Check adds storage analysis, Downloads, cleanup preview, battery, drives, performance, and installed applications.'
    Add-NyxScanButtons -X 24 -Y 116
    if($null -eq $script:NyxUi.Scan){Add-NyxNoScanCard -Y 174;return}
    $grid=New-NyxResultsGridControl -Results @($script:NyxUi.Scan.Results) -Y 174 -Height 396;$script:NyxUi.Content.Controls.Add($grid)
    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'Double-click any result to see evidence, limitations, and the exact recommendation.' -X 24 -Y 584 -Width (Get-NyxPageWidth) -Height 42 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))
}

function Show-NyxCategoryPage {
    param([string]$Title,[string]$Subtitle,[string[]]$Categories,[string]$ActionText='',[scriptblock]$Action=$null)
    Clear-NyxPage;Add-NyxPageHeading -Title $Title -Subtitle $Subtitle
    $y=116
    if($ActionText){$button=New-NyxButton -Text $ActionText -X 24 -Y $y -Width 205 -Palette $script:NyxUi.Palette -Primary $true;$button.Add_Click($Action);$script:NyxUi.Content.Controls.Add($button);$y+=56}
    if($null -eq $script:NyxUi.Scan){Add-NyxNoScanCard -Y $y;return}
    # F-019: function output is pipeline-enumerated even when the helper uses
    # return @(...). Preserve zero/one/many cardinality at the receiving boundary.
    $results=@(Get-NyxResultsByCategory -Categories $Categories)
    if($results.Count -eq 0){$script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'This module did not return a result in the last scan. Run a Full Check where applicable.' -X 24 -Y $y -Width (Get-NyxPageWidth) -Height 54 -Size 11 -Palette $script:NyxUi.Palette));Add-NyxScanButtons -X 24 -Y ($y+65);return}
    $grid=New-NyxResultsGridControl -Results $results -Y $y -Height 420;$script:NyxUi.Content.Controls.Add($grid)
}

function Show-NyxStoragePage {
    Clear-NyxPage;Add-NyxPageHeading -Title 'Storage' -Subtitle 'Nyx measures storage and shows opportunities. Large, old, or duplicated does not mean unwanted, and this page never deletes anything.'
    $open=New-NyxButton -Text 'Open Storage settings' -X 24 -Y 116 -Width 190 -Palette $script:NyxUi.Palette -Primary $true;$open.Add_Click({Invoke-NyxOpen 'ms-settings:storagesense'})
    $downloads=New-NyxButton -Text 'Open Downloads' -X 228 -Y 116 -Width 170 -Palette $script:NyxUi.Palette;$downloads.Add_Click({Invoke-NyxOpen 'explorer.exe' ('"'+(Get-NyxDownloadsPath)+'"')})
    $full=New-NyxButton -Text 'Run Full Check' -X 412 -Y 116 -Width 160 -Palette $script:NyxUi.Palette;$full.Add_Click({Start-NyxScan -Mode 'Full'})
    $script:NyxUi.Content.Controls.AddRange(@($open,$downloads,$full))
    if($null -eq $script:NyxUi.Scan){Add-NyxNoScanCard -Y 174;return}
    $results=@(Get-NyxResultsByCategory -Categories @('Storage','Downloads'));$grid=New-NyxResultsGridControl -Results $results -Y 174 -Height 280;$script:NyxUi.Content.Controls.Add($grid)
    $folderResult=@($script:NyxUi.Scan.Results|Where-Object{$_.CheckId -eq 'storage.user-folders'}|Select-Object -First 1)
    if($folderResult.Count -gt 0){
        $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'Measured user folders' -X 24 -Y 474 -Width 360 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
        $fg=New-NyxGrid -X 24 -Y 512 -Width (Get-NyxPageWidth) -Height 210 -Palette $script:NyxUi.Palette;[void]$fg.Columns.Add('Folder','Folder');[void]$fg.Columns.Add('Size','Size');[void]$fg.Columns.Add('Files','Files');[void]$fg.Columns.Add('Complete','Complete')
        foreach($f in @($folderResult[0].Details.Folders)){$fg.Rows.Add([string]$f.Name,(ConvertTo-NyxBytesText ([int64]$f.Bytes)),[string]$f.Files,[string]$f.Complete)|Out-Null};$script:NyxUi.Content.Controls.Add($fg)
        $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'Largest files found' -X 24 -Y 742 -Width 360 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
        $lg=New-NyxGrid -X 24 -Y 780 -Width (Get-NyxPageWidth) -Height 330 -Palette $script:NyxUi.Palette;[void]$lg.Columns.Add('Name','File');[void]$lg.Columns.Add('Size','Size');[void]$lg.Columns.Add('Folder','Folder')
        $lg.Columns['Name'].FillWeight=45;$lg.Columns['Size'].FillWeight=15;$lg.Columns['Folder'].FillWeight=70
        foreach($f in @($folderResult[0].Details.LargestFiles)){$i=$lg.Rows.Add([IO.Path]::GetFileName([string]$f.Path),(ConvertTo-NyxBytesText ([int64]$f.SizeBytes)),[IO.Path]::GetDirectoryName([string]$f.Path));$lg.Rows[$i].Tag=$f}
        $lg.Add_CellDoubleClick({param($s,$e)if($e.RowIndex -ge 0){$f=$s.Rows[$e.RowIndex].Tag;if($f){Invoke-NyxOpen 'explorer.exe' ('/select,"'+[string]$f.Path+'"')}}});$script:NyxUi.Content.Controls.Add($lg)
        $script:NyxUi.Content.AutoScrollMinSize=New-Object Drawing.Size(0,1140)
    }
}

function Invoke-NyxUiAction {
    param([Parameter(Mandatory=$true)][object]$Request)
    $paths=Initialize-NyxDataDirectories;$id=[guid]::NewGuid().ToString('N');$req=Join-Path $paths.Temp ("action-$id-request.json");$out=Join-Path $paths.Temp ("action-$id-result.json")
    if($null -eq $Request.PSObject.Properties['ConfirmedByUser']){$Request|Add-Member -NotePropertyName ConfirmedByUser -NotePropertyValue $true}else{$Request.ConfirmedByUser=$true}
    $requestJson=$Request|ConvertTo-Json -Depth 12 -Compress
    [IO.File]::WriteAllText($req,$requestJson,[Text.UTF8Encoding]::new($false))
    $requestHash=(Get-FileHash -LiteralPath $req -Algorithm SHA256 -ErrorAction Stop).Hash
    $worker=Join-Path $script:NyxUi.AppRoot 'workers\ActionWorker.ps1';$ps=Get-NyxPowerShellPath
    [void](Remove-NyxTemporaryArtifacts -Path @($out))
    $args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" -RequestPath `"$req`" -OutputPath `"$out`" -RequestSha256 $requestHash"
    $p=$null
    try{
        $p=Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden -PassThru
        $script:NyxUi.FooterProgress.Style='Marquee';$script:NyxUi.FooterLabel.Text='Applying the explicitly confirmed current-user action...';$script:NyxUi.Form.Enabled=$false
        while(-not $p.HasExited){[Windows.Forms.Application]::DoEvents();Start-Sleep -Milliseconds 90}
    }catch{
        [Windows.Forms.MessageBox]::Show("The action worker could not start.`r`n$($_.Exception.Message)",'Nyx PC Checkup','OK','Error')|Out-Null
    }finally{
        $script:NyxUi.Form.Enabled=$true;$script:NyxUi.Form.Activate();$script:NyxUi.FooterProgress.Style='Continuous';$script:NyxUi.FooterProgress.Value=0
    }
    $result=$null
    if(Test-Path -LiteralPath $out){try{$result=Get-Content -LiteralPath $out -Raw -Encoding UTF8|ConvertFrom-Json}catch{}}
    [void](Remove-NyxTemporaryArtifacts -Path @($req,$out))
    $script:NyxUi.FooterLabel.Text='Ready. No background monitor is running.'
    return $result
}

function Update-NyxStartupSelection {
    param([Parameter(Mandatory=$true)]$State)
    if($State.Grid.IsDisposed){return}
    $State.Disable.Enabled=$false
    $State.Enable.Enabled=$false
    $State.Location.Enabled=$false
    if($State.Loading -or $State.Grid.SelectedRows.Count -eq 0){return}
    $app=$State.Grid.SelectedRows[0].Tag
    if($null -eq $app){return}
    $State.Disable.Enabled=([bool]$app.Enabled -and [bool]$app.CanModify)
    $State.Enable.Enabled=(-not [bool]$app.Enabled -and [bool]$app.CanModify)
    $State.Location.Enabled=(-not [string]::IsNullOrWhiteSpace([string]$app.ExecutablePath))
}

function Update-NyxStartupRows {
    param([Parameter(Mandatory=$true)]$State)
    if($State.Grid.IsDisposed){return}
    $State.Loading=$true
    try {
        $State.Grid.Rows.Clear()
        $apps=@(Get-NyxStartupApplications)
        foreach($app in $apps){
            $control=if([bool]$app.CanModify){'Current user - reversible'}else{'All users - read-only'}
            $i=$State.Grid.Rows.Add($(if($app.Enabled){'Enabled'}else{'Disabled by Nyx'}),[string]$app.Name,[string]$app.Publisher,[string]$app.SourceLabel,$control,$(if($app.FileExists){'Yes'}else{'No / unknown'}),[string]$app.Impact)
            $State.Grid.Rows[$i].Tag=$app
            if(-not $app.Enabled){$State.Grid.Rows[$i].Cells[0].Style.ForeColor=$State.Palette.Optional}
            elseif(-not [bool]$app.CanModify){$State.Grid.Rows[$i].Cells['Control'].Style.ForeColor=$State.Palette.Muted}
        }
        $State.Grid.ClearSelection()
    } finally {
        $State.Loading=$false
        Update-NyxStartupSelection -State $State
    }
}

function Show-NyxStartupPage {
    Clear-NyxPage
    Add-NyxPageHeading -Title 'Startup apps' -Subtitle 'These programs are configured to start with Windows. Current-user entries can be changed reversibly; all-users entries are displayed read-only and never trigger elevation.'

    # QA10-F-008: keep every startup action in a visible top action row at
    # constrained DPI/resolution instead of placing actions below a tall grid.
    $refresh=New-NyxButton -Text 'Refresh list' -X 24 -Y 120 -Width 140 -Palette $script:NyxUi.Palette -Primary $true
    $disable=New-NyxButton -Text 'Disable selected' -X 178 -Y 120 -Width 165 -Palette $script:NyxUi.Palette
    $enable=New-NyxButton -Text 'Re-enable selected' -X 357 -Y 120 -Width 175 -Palette $script:NyxUi.Palette
    $location=New-NyxButton -Text 'Open file location' -X 546 -Y 120 -Width 190 -Palette $script:NyxUi.Palette
    $disable.Enabled=$false
    $enable.Enabled=$false
    $location.Enabled=$false
    $script:NyxUi.Content.Controls.AddRange(@($refresh,$disable,$enable,$location))

    $grid=New-NyxGrid -X 24 -Y 174 -Width (Get-NyxPageWidth) -Height 372 -Palette $script:NyxUi.Palette
    $grid.Anchor='Top,Left,Right'
    $grid.AutoSizeColumnsMode='None'
    $grid.ScrollBars='Both'
    [void]$grid.Columns.Add('State','State')
    [void]$grid.Columns.Add('Name','Application')
    [void]$grid.Columns.Add('Publisher','Publisher')
    [void]$grid.Columns.Add('Source','Startup source')
    [void]$grid.Columns.Add('Control','Nyx control')
    [void]$grid.Columns.Add('Exists','File exists')
    [void]$grid.Columns.Add('Impact','Impact')
    $grid.Columns['State'].Width=105
    $grid.Columns['Name'].Width=190
    $grid.Columns['Publisher'].Width=165
    $grid.Columns['Source'].Width=205
    $grid.Columns['Control'].Width=190
    $grid.Columns['Exists'].Width=110
    $grid.Columns['Impact'].Width=145
    $script:NyxUi.Content.Controls.Add($grid)

    # F-015: every deferred callback resolves its page instance from the sender.
    # No closure depends on Show-NyxStartupPage's expired function-local scope.
    $startupState=[pscustomobject]@{
        Grid=$grid;Refresh=$refresh;Disable=$disable;Enable=$enable
        Location=$location;Palette=$script:NyxUi.Palette;Loading=$false
    }
    foreach($control in @($grid,$refresh,$disable,$enable,$location)){$control.Tag=$startupState}
    $grid.Add_SelectionChanged({
        param($sender,$eventArgs)
        Update-NyxStartupSelection -State $sender.Tag
    })
    $refresh.Add_Click({
        param($sender,$eventArgs)
        Update-NyxStartupRows -State $sender.Tag
    })
    Update-NyxStartupRows -State $startupState

    $disable.Add_Click({
        param($sender,$eventArgs)
        $state=$sender.Tag
        if($state.Grid.IsDisposed -or $state.Loading -or $state.Grid.SelectedRows.Count -eq 0){return}
        $app=$state.Grid.SelectedRows[0].Tag
        if($null -eq $app){return}
        if(-not [bool]$app.CanModify){[Windows.Forms.MessageBox]::Show('All-users startup entries are read-only in Version 1. Nyx did not request elevation and made no change.','Nyx PC Checkup','OK','Information')|Out-Null;return}
        if(-not $app.Enabled){[Windows.Forms.MessageBox]::Show('The selected entry is already disabled.','Nyx PC Checkup')|Out-Null;return}
        $answer=[Windows.Forms.MessageBox]::Show("Disable '$($app.Name)' from starting automatically for this Windows user?`r`n`r`nNyx will write the exact rollback state before making the change.",'Confirm reversible startup change','YesNo','Warning')
        if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
        $r=Invoke-NyxUiAction -Request ([pscustomobject]@{Operation='DisableStartup';ApplicationId=[string]$app.Id})
        if($r){[Windows.Forms.MessageBox]::Show([string]$r.Message,'Nyx PC Checkup')|Out-Null}
        Update-NyxStartupRows -State $state
    })
    $enable.Add_Click({
        param($sender,$eventArgs)
        $state=$sender.Tag
        if($state.Grid.IsDisposed -or $state.Loading -or $state.Grid.SelectedRows.Count -eq 0){return}
        $app=$state.Grid.SelectedRows[0].Tag
        if($null -eq $app){return}
        if(-not [bool]$app.CanModify){return}
        if($app.Enabled){[Windows.Forms.MessageBox]::Show('The selected entry is already enabled.','Nyx PC Checkup')|Out-Null;return}
        $answer=[Windows.Forms.MessageBox]::Show("Restore '$($app.Name)' to its exact previous current-user startup location?",'Confirm startup restore','YesNo','Question')
        if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
        $r=Invoke-NyxUiAction -Request ([pscustomobject]@{Operation='EnableStartup';RollbackActionId=[string]$app.RollbackActionId})
        if($r){[Windows.Forms.MessageBox]::Show([string]$r.Message,'Nyx PC Checkup')|Out-Null}
        Update-NyxStartupRows -State $state
    })
    $location.Add_Click({
        param($sender,$eventArgs)
        $state=$sender.Tag
        if($state.Grid.IsDisposed -or $state.Loading -or $state.Grid.SelectedRows.Count -eq 0){return}
        $app=$state.Grid.SelectedRows[0].Tag
        if($null -eq $app){return}
        $path=[string]$app.ExecutablePath
        if($path -and(Test-Path -LiteralPath $path)){Invoke-NyxOpen 'explorer.exe' ('/select,"'+$path+'"')}
        else{[Windows.Forms.MessageBox]::Show('The executable location is unavailable.','Nyx PC Checkup')|Out-Null}
    })

    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'Every modification is explicit and limited to this Windows user. All-users Run keys and the Common Startup folder are visible for review but cannot be changed by Nyx PC Checkup 1.0.0.' -X 24 -Y 562 -Width (Get-NyxPageWidth) -Height 72 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))
    Set-NyxPageScrollExtent -Height 660
}

function Test-NyxDeferredPageState {
    param($State)
    if($null -eq $State -or -not $State.Active){return $false}
    foreach($control in $State.Controls){
        if($null -eq $control -or $control.IsDisposed -or $control.Disposing){return $false}
    }
    return $true
}

function Show-NyxPageMessage {
    param([string]$Text,[string]$Title='Nyx PC Checkup',[string]$Buttons='OK',[string]$Icon='None')
    return [Windows.Forms.MessageBox]::Show($Text,$Title,$Buttons,$Icon)
}

function Update-NyxAppsSelection {
    param($State)
    if(-not (Test-NyxDeferredPageState $State)){return}
    $State.Folder.Enabled=(-not $State.Loading -and $State.Grid.SelectedRows.Count -gt 0)
}

function Update-NyxAppsRows {
    param($State)
    if(-not (Test-NyxDeferredPageState $State)){return}
    $State.Loading=$true
    $State.Folder.Enabled=$false
    try{
        $State.Grid.Rows.Clear()
        $filter=[string]$State.Search.Text
        foreach($app in $State.Apps){
            if($filter -and (([string]$app.Name+' '+[string]$app.Publisher) -notmatch [regex]::Escape($filter))){continue}
            $size=if($null -ne $app.EstimatedSizeBytes){ConvertTo-NyxBytesText ([int64]$app.EstimatedSizeBytes)}else{'Unknown'}
            $i=$State.Grid.Rows.Add([string]$app.Name,[string]$app.Publisher,[string]$app.Version,[string]$app.InstallDate,$size)
            $State.Grid.Rows[$i].Tag=$app
        }
        $State.Grid.CurrentCell=$null
        $State.Grid.ClearSelection()
    }finally{
        $State.Loading=$false
        Update-NyxAppsSelection -State $State
    }
}

function Open-NyxAppsSelectedFolder {
    param($State)
    if(-not (Test-NyxDeferredPageState $State)){return}
    if($State.Loading -or $State.Grid.SelectedRows.Count -eq 0){return}
    $app=$State.Grid.SelectedRows[0].Tag
    if($null -eq $app){return}
    if($app.InstallLocation -and (Test-Path -LiteralPath ([string]$app.InstallLocation) -PathType Container)){
        Invoke-NyxOpen 'explorer.exe' ('"'+[string]$app.InstallLocation+'"')
    }else{Show-NyxPageMessage -Text 'No usable install folder was reported for this application.'|Out-Null}
}

function Show-NyxAppsPage {
    Clear-NyxPage
    Add-NyxPageHeading -Title 'Installed applications' -Subtitle 'Search the supported Windows uninstall inventory. Nyx does not call programs junk and does not uninstall anything automatically.'

    # QA10-F-008: primary actions stay above the data grid at all supported DPIs.
    $open=New-NyxButton -Text 'Open Installed Apps' -X 24 -Y 120 -Width 190 -Palette $script:NyxUi.Palette -Primary $true
    $full=New-NyxButton -Text 'Run Full Check' -X 228 -Y 120 -Width 175 -Palette $script:NyxUi.Palette
    $folder=New-NyxButton -Text 'Open selected folder' -X 417 -Y 120 -Width 220 -Palette $script:NyxUi.Palette
    $folder.Enabled=$false
    $open.Add_Click({Invoke-NyxOpen 'ms-settings:appsfeatures'})
    $full.Add_Click({Start-NyxScan -Mode 'Full'})
    $script:NyxUi.Content.Controls.AddRange(@($open,$full,$folder))

    $searchLabel=New-NyxLabel -Text 'Search applications' -X 24 -Y 168 -Width 150 -Height 28 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'
    $search=New-Object Windows.Forms.TextBox
    $search.Location=New-Object Drawing.Point(178,164)
    $search.Size=New-Object Drawing.Size([math]::Min(430,[math]::Max(220,(Get-NyxPageWidth)-180)),32)
    $search.Anchor='Top,Left,Right'
    $search.Font=New-Object Drawing.Font('Segoe UI',10)
    $search.BackColor=$script:NyxUi.Palette.Surface
    $search.ForeColor=$script:NyxUi.Palette.Text
    $search.BorderStyle='FixedSingle'
    $script:NyxUi.Content.Controls.AddRange(@($searchLabel,$search))

    $grid=New-NyxGrid -X 24 -Y 208 -Width (Get-NyxPageWidth) -Height 376 -Palette $script:NyxUi.Palette
    $grid.Anchor='Top,Left,Right'
    [void]$grid.Columns.Add('Name','Application')
    [void]$grid.Columns.Add('Publisher','Publisher')
    [void]$grid.Columns.Add('Version','Version')
    [void]$grid.Columns.Add('Date','Install date')
    [void]$grid.Columns.Add('Size','Reported size')
    $script:NyxUi.Content.Controls.Add($grid)

    $apps=@()
    if($script:NyxUi.Scan){
        $r=@($script:NyxUi.Scan.Results|Where-Object{$_.CheckId -eq 'apps.inventory'}|Select-Object -First 1)
        if($r.Count -gt 0){$apps=@($r[0].Details)}
    }
    # F-021: callbacks retain this page instance, never constructor locals.
    $appsState=[pscustomobject]@{
        Search=$search;Grid=$grid;Folder=$folder;Apps=$apps
        Controls=@($search,$grid,$folder);Loading=$false;Active=$true
    }
    foreach($control in $appsState.Controls){$control.Tag=$appsState}
    $search.Add_TextChanged({param($sender,$eventArgs)Update-NyxAppsRows -State $sender.Tag})
    $grid.Add_SelectionChanged({param($sender,$eventArgs)Update-NyxAppsSelection -State $sender.Tag})
    $grid.Add_Disposed({param($sender,$eventArgs)$sender.Tag.Active=$false})
    $folder.Add_Click({param($sender,$eventArgs)Open-NyxAppsSelectedFolder -State $sender.Tag})
    Update-NyxAppsRows -State $appsState

    if($apps.Count -eq 0){
        $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'No application inventory is loaded yet. Run Full Check using the visible action above to populate this list.' -X 24 -Y 598 -Width (Get-NyxPageWidth) -Height 48 -Size 10 -Palette $script:NyxUi.Palette -Color 'Muted'))
    }
    Set-NyxPageScrollExtent -Height 670
}

function Update-NyxCleanupSelection {
    param($State)
    if(-not (Test-NyxDeferredPageState $State)){return}
    $count=0;$bytes=[int64]0
    foreach($row in $State.Grid.Rows){
        if([bool]$row.Cells['Select'].Value){$count++;$bytes += [int64]$row.Tag.SizeBytes}
    }
    $State.Summary.Text="Selected: $count item(s), $(ConvertTo-NyxBytesText $bytes)"
}

function Invoke-NyxCleanupSelection {
    param($State)
    if(-not (Test-NyxDeferredPageState $State)){return}
    $ids=[System.Collections.Generic.List[string]]::new()
    $bytes=[int64]0;$recycle=$false
    foreach($row in $State.Grid.Rows){
        if([bool]$row.Cells['Select'].Value){
            $ids.Add([string]$row.Tag.Id);$bytes += [int64]$row.Tag.SizeBytes
            if($row.Tag.Category -eq 'Recycle Bin'){$recycle=$true}
        }
    }
    if($ids.Count -eq 0){Show-NyxPageMessage -Text 'Select at least one displayed item.'|Out-Null;return}
    $text="You selected $($ids.Count) item(s) totaling $(ConvertTo-NyxBytesText $bytes).`r`n`r`nFiles will be moved to the Windows Recycle Bin."
    if($recycle){$text+="`r`n`r`nThe Recycle Bin selection will be emptied permanently."}
    $text+="`r`n`r`nContinue?"
    $answer=Show-NyxPageMessage -Text $text -Title 'Confirm destructive cleanup action' -Buttons 'YesNo' -Icon 'Warning'
    if($answer -ne [Windows.Forms.DialogResult]::Yes){return}
    $res=Invoke-NyxUiAction -Request ([pscustomobject]@{Operation='Cleanup';CandidateIds=@($ids.ToArray())})
    if($res){
        Show-NyxPageMessage -Text ([string]$res.Message)|Out-Null
        if([string]$res.Status -in @('Completed','Partial')){
            $script:NyxUi.FooterLabel.Text='Cleanup finished. Refreshing the read-only cleanup preview.'
            Start-NyxScan -Mode 'Full';return
        }
    }
    Show-NyxCleanupPage
}

function Show-NyxCleanupPage {
    Clear-NyxPage
    Add-NyxPageHeading -Title 'Safe cleanup' -Subtitle 'Nothing is selected automatically. Nyx displays the exact supported items, total size, consequence, and confirmation before acting.'
    $full=New-NyxButton -Text 'Refresh with Full Check' -X 24 -Y 120 -Width 220 -Palette $script:NyxUi.Palette -Primary $true
    $full.Add_Click({Start-NyxScan -Mode 'Full'})
    $script:NyxUi.Content.Controls.Add($full)

    $result=$null
    if($script:NyxUi.Scan){
        $r=@($script:NyxUi.Scan.Results|Where-Object{$_.CheckId -eq 'cleanup.preview'}|Select-Object -First 1)
        if($r.Count -gt 0){$result=$r[0]}
    }
    if($null -eq $result){Add-NyxNoScanCard -Y 174;return}

    $grid=New-NyxGrid -X 24 -Y 174 -Width (Get-NyxPageWidth) -Height 326 -Palette $script:NyxUi.Palette
    $grid.Anchor='Top,Left,Right'
    $grid.ReadOnly=$false
    $grid.EditMode='EditOnEnter'
    $select=New-Object Windows.Forms.DataGridViewCheckBoxColumn
    $select.Name='Select'
    $select.HeaderText='Select'
    $select.FillWeight=14
    [void]$grid.Columns.Add($select)
    [void]$grid.Columns.Add('Category','Category')
    [void]$grid.Columns.Add('Name','Item')
    [void]$grid.Columns.Add('Age','Age')
    [void]$grid.Columns.Add('Size','Size')
    [void]$grid.Columns.Add('Consequence','What happens')
    $grid.Columns['Category'].FillWeight=32
    $grid.Columns['Name'].FillWeight=52
    $grid.Columns['Age'].FillWeight=14
    $grid.Columns['Size'].FillWeight=18
    $grid.Columns['Consequence'].FillWeight=62
    foreach($item in @($result.Details.Candidates)){
        $consequence=if($item.Category -eq 'Recycle Bin'){'Permanently empties items already in the Recycle Bin.'}else{'Moves this exact item to the Windows Recycle Bin.'}
        $i=$grid.Rows.Add($false,[string]$item.Category,[string]$item.Name,$(if([int]$item.AgeDays -gt 0){"$($item.AgeDays) days"}else{'-'}),(ConvertTo-NyxBytesText ([int64]$item.SizeBytes)),$consequence)
        $grid.Rows[$i].Tag=$item
        for($c=1;$c -lt $grid.Columns.Count;$c++){$grid.Rows[$i].Cells[$c].ReadOnly=$true}
    }
    $script:NyxUi.Content.Controls.Add($grid)

    $summary=New-NyxLabel -Text 'Selected: 0 items, 0 B' -X 24 -Y 516 -Width 420 -Height 32 -Size 10 -Bold $true -Palette $script:NyxUi.Palette
    $script:NyxUi.Content.Controls.Add($summary)
    $run=New-NyxButton -Text 'Review and clean selected' -X 24 -Y 556 -Width 245 -Palette $script:NyxUi.Palette -Primary $true
    $cleanupState=[pscustomobject]@{Grid=$grid;Summary=$summary;Run=$run;Controls=@($grid,$summary,$run);Active=$true}
    foreach($control in $cleanupState.Controls){$control.Tag=$cleanupState}
    $grid.Add_CellValueChanged({param($sender,$eventArgs)Update-NyxCleanupSelection -State $sender.Tag})
    $grid.Add_CurrentCellDirtyStateChanged({
        param($sender,$eventArgs)
        if((Test-NyxDeferredPageState $sender.Tag) -and $sender.IsCurrentCellDirty){[void]$sender.CommitEdit([Windows.Forms.DataGridViewDataErrorContexts]::Commit)}
    })
    $grid.Add_Disposed({param($sender,$eventArgs)$sender.Tag.Active=$false})
    $run.Add_Click({param($sender,$eventArgs)Invoke-NyxCleanupSelection -State $sender.Tag})
    $script:NyxUi.Content.Controls.Add($run)
    $script:NyxUi.Content.Controls.Add((New-NyxLabel -Text 'If a deletion fails, the file is preserved and the exact failure is reported. Nyx never touches Documents, Photos, Videos, browser profiles, update caches, restore points, or application databases through this module.' -X 288 -Y 548 -Width ([math]::Max(300,(Get-NyxPageWidth)-288)) -Height 88 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))
    Set-NyxPageScrollExtent -Height 660
}

function Show-NyxSettingsPage {
    Clear-NyxPage
    Add-NyxPageHeading -Title 'Settings & privacy' -Subtitle 'Nyx PC Checkup is local-first. Its optional update check fetches only a public JSON file from DietrichAILabs.com and never downloads or installs software.'
    $config=Get-NyxConfiguration
    $w=Get-NyxPageWidth
    $inner=[math]::Max(360,$w-44)

    $card=New-NyxCard -X 24 -Y 122 -Width $w -Height 522 -Palette $script:NyxUi.Palette
    $card.Anchor='Top,Left,Right'
    $card.Controls.Add((New-NyxLabel -Text 'Appearance' -X 22 -Y 18 -Width 300 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
    $card.Controls.Add((New-NyxLabel -Text 'Theme' -X 22 -Y 61 -Width 120 -Height 28 -Size 10 -Palette $script:NyxUi.Palette))
    $theme=New-Object Windows.Forms.ComboBox
    $theme.Location=New-Object Drawing.Point(160,57)
    $theme.Size=New-Object Drawing.Size(250,34)
    $theme.DropDownStyle='DropDownList'
    $theme.Font=New-Object Drawing.Font('Segoe UI',10)
    [void]$theme.Items.AddRange(@('FollowWindows','Dark','Light'))
    $theme.SelectedItem=[string]$config.theme
    $theme.BackColor=$script:NyxUi.Palette.Surface2
    $theme.ForeColor=$script:NyxUi.Palette.Text
    $card.Controls.Add($theme)

    $notify=New-Object Windows.Forms.CheckBox
    $notify.Text='Enable conservative in-app PC health notifications'
    $notify.Location=New-Object Drawing.Point(22,104)
    $notify.Size=New-Object Drawing.Size($inner,38)
    $notify.Checked=[bool]$config.notificationsEnabled
    $notify.ForeColor=$script:NyxUi.Palette.Text
    $notify.BackColor=$script:NyxUi.Palette.Surface
    $notify.Font=New-Object Drawing.Font('Segoe UI',10)
    $notify.UseCompatibleTextRendering=$true
    $card.Controls.Add($notify)
    $card.Controls.Add((New-NyxLabel -Text 'No resident PC-health monitor is installed. Health notifications can appear only while Nyx is open.' -X 45 -Y 142 -Width ([math]::Max(300,$w-90)) -Height 42 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))

    $card.Controls.Add((New-NyxLabel -Text 'Application updates' -X 22 -Y 188 -Width 300 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
    $autoUpdates=New-Object Windows.Forms.CheckBox
    $autoUpdates.Text='Automatically check for updates'
    $autoUpdates.Location=New-Object Drawing.Point(22,226)
    $autoUpdates.Size=New-Object Drawing.Size($inner,38)
    $autoUpdates.Checked=[bool]$config.updates.enabled
    $autoUpdates.ForeColor=$script:NyxUi.Palette.Text
    $autoUpdates.BackColor=$script:NyxUi.Palette.Surface
    $autoUpdates.Font=New-Object Drawing.Font('Segoe UI',10)
    $autoUpdates.UseCompatibleTextRendering=$true
    $card.Controls.Add($autoUpdates)
    $card.Controls.Add((New-NyxLabel -Text 'The request contains no username, machine name, hardware identifier, file names, scan results, telemetry, or application data. It only fetches the fixed public manifest over normal HTTPS.' -X 45 -Y 264 -Width ([math]::Max(300,$w-90)) -Height 58 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))

    $checkNow=New-NyxButton -Text 'Check for Updates Now' -X 22 -Y 326 -Width 255 -Palette $script:NyxUi.Palette
    $checkNow.Add_Click({Start-NyxUpdateCheck -Manual})
    $card.Controls.Add($checkNow)
    $lastText='Last attempted check: Never'
    if(-not [string]::IsNullOrWhiteSpace([string]$config.updates.lastCheckUtc)){$lastText='Last attempted check (UTC): '+[string]$config.updates.lastCheckUtc}
    $card.Controls.Add((New-NyxLabel -Text $lastText -X 294 -Y 329 -Width ([math]::Max(220,$w-326)) -Height 50 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))

    $card.Controls.Add((New-NyxLabel -Text 'Local data' -X 22 -Y 384 -Width 300 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
    $open=New-NyxButton -Text 'Open local data folder' -X 22 -Y 420 -Width 235 -Palette $script:NyxUi.Palette
    $logs=New-NyxButton -Text 'Delete local logs' -X 271 -Y 420 -Width 205 -Palette $script:NyxUi.Palette
    $open.Add_Click({$p=Initialize-NyxDataDirectories;Invoke-NyxOpen 'explorer.exe' ('"'+$p.Root+'"')})
    $logs.Add_Click({$a=[Windows.Forms.MessageBox]::Show('Delete all local Nyx diagnostic logs?','Nyx PC Checkup','YesNo','Question');if($a -eq [Windows.Forms.DialogResult]::Yes){Clear-NyxLogs;[Windows.Forms.MessageBox]::Show('Local logs were deleted.','Nyx PC Checkup')|Out-Null}})
    $card.Controls.AddRange(@($open,$logs))

    $save=New-NyxButton -Text 'Save settings' -X 22 -Y 466 -Width 180 -Palette $script:NyxUi.Palette -Primary $true
    $settingsState=[pscustomobject][ordered]@{
        Configuration=$config
        ThemeControl=$theme
        NotificationControl=$notify
        AutomaticUpdatesControl=$autoUpdates
    }
    $save.Tag=$settingsState
    $save.Add_Click({
        param($sender,$eventArgs)
        $state=$sender.Tag
        $selectedTheme=[string]$state.ThemeControl.SelectedItem
        if($selectedTheme -notin @('FollowWindows','Dark','Light')){throw 'Select a supported theme before saving settings.'}
        $state.Configuration.theme=$selectedTheme
        $state.Configuration.notificationsEnabled=[bool]$state.NotificationControl.Checked
        $state.Configuration.updates.enabled=[bool]$state.AutomaticUpdatesControl.Checked
        Save-NyxConfiguration -Configuration $state.Configuration
        [Windows.Forms.MessageBox]::Show('Settings were saved. Update-check and notification changes apply now; theme changes apply the next time Nyx is opened.','Nyx PC Checkup')|Out-Null
    })
    $card.Controls.Add($save)
    $script:NyxUi.Content.Controls.Add($card)

    $privacy=New-NyxCard -X 24 -Y 662 -Width $w -Height 224 -Palette $script:NyxUi.Palette
    $privacy.Anchor='Top,Left,Right'
    $privacy.Controls.Add((New-NyxLabel -Text 'Privacy promise' -X 22 -Y 18 -Width 300 -Height 32 -Size 14 -Bold $true -Palette $script:NyxUi.Palette))
    $privacy.Controls.Add((New-NyxLabel -Text (Get-NyxPrivacyStatement) -X 22 -Y 57 -Width ([math]::Max(300,$w-50)) -Height 52 -Size 11 -Bold $true -Palette $script:NyxUi.Palette))
    $privacy.Controls.Add((New-NyxLabel -Text 'Reports are previewed and structurally redact secret-bearing fields, usernames, email addresses, IPv4, and compressed or expanded IPv6 by default. Update checks never upload reports or inventory. Logs rotate locally and can be deleted here.' -X 22 -Y 116 -Width ([math]::Max(300,$w-50)) -Height 88 -Size 9 -Palette $script:NyxUi.Palette -Color 'Muted'))
    $script:NyxUi.Content.Controls.Add($privacy)
    Set-NyxPageScrollExtent -Height 910
}

function Export-NyxCurrentReport {
    if($null -eq $script:NyxUi.Scan){[Windows.Forms.MessageBox]::Show('Run a check before exporting a report.','Nyx PC Checkup')|Out-Null;return}
    try{$report=New-NyxSafeReport -Scan $script:NyxUi.Scan;$text=ConvertTo-NyxReportText -Report $report;if(-not(Show-NyxReportPreviewDialog -Text $text -Palette $script:NyxUi.Palette)){return};$dialog=New-Object Windows.Forms.SaveFileDialog;$dialog.Title='Export privacy-safe Nyx PC Checkup report';$dialog.Filter='Text report (*.txt)|*.txt|JSON report (*.json)|*.json|PDF summary (*.pdf)|*.pdf';$dialog.FileName='Nyx_PC_Checkup_Report_'+(Get-Date -Format 'yyyyMMdd_HHmmss');if($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){return};$format=switch($dialog.FilterIndex){1{'TXT'};2{'JSON'};3{'PDF'};default{'TXT'}};Export-NyxReport -Scan $script:NyxUi.Scan -Path $dialog.FileName -Format $format|Out-Null;[Windows.Forms.MessageBox]::Show("Report saved to:`r`n$($dialog.FileName)",'Nyx PC Checkup')|Out-Null}catch{[Windows.Forms.MessageBox]::Show("The report could not be exported.`r`n$($_.Exception.Message)",'Nyx PC Checkup','OK','Error')|Out-Null}
}

function Start-NyxUpdateCheck {
    [CmdletBinding()]
    param([switch]$Manual)
    if($script:NyxUi.UpdateProcess -and -not $script:NyxUi.UpdateProcess.HasExited){
        if($Manual){[Windows.Forms.MessageBox]::Show('An update check is already in progress.','Nyx PC Checkup','OK','Information')|Out-Null}
        return
    }
    if(-not $Manual){
        $configuration=Get-NyxConfiguration
        if(-not (Test-NyxAutomaticUpdateCheckDue -Configuration $configuration)){return}
    }
    $paths=Initialize-NyxDataDirectories;$id=[guid]::NewGuid().ToString('N');$output=Join-Path $paths.Temp ("update-$id-result.json")
    $worker=Join-Path $script:NyxUi.AppRoot 'workers\UpdateCheckWorker.ps1';$args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" -OutputPath `"$output`" -Manual $(if($Manual){1}else{0})"
    try{
        $script:NyxUi.UpdateOutput=$output;$script:NyxUi.UpdateManual=[bool]$Manual
        $script:NyxUi.UpdateProcess=Start-Process -FilePath (Get-NyxPowerShellPath) -ArgumentList $args -WindowStyle Hidden -PassThru
        if($Manual){$script:NyxUi.FooterLabel.Text='Checking the official Dietrich AI Labs update manifest...'}
        $script:NyxUi.UpdateTimer.Start()
    }catch{
        $script:NyxUi.UpdateProcess=$null;[void](Remove-NyxTemporaryArtifacts -Path @($output))
        if($Manual){[Windows.Forms.MessageBox]::Show('Unable to check for updates right now. Please try again later.','Nyx PC Checkup','OK','Warning')|Out-Null}
    }
}

function Update-NyxUpdateCheckProgress {
    try{
        if(-not $script:NyxUi.UpdateProcess -or -not $script:NyxUi.UpdateProcess.HasExited){return}
        $script:NyxUi.UpdateTimer.Stop();$result=$null
        if(Test-Path -LiteralPath $script:NyxUi.UpdateOutput){try{$result=Get-Content -LiteralPath $script:NyxUi.UpdateOutput -Raw -Encoding UTF8|ConvertFrom-Json}catch{}}
        $manual=[bool]$script:NyxUi.UpdateManual
        if($null -eq $result){
            if($manual){[Windows.Forms.MessageBox]::Show('Unable to check for updates right now. Please try again later.','Nyx PC Checkup','OK','Warning')|Out-Null}
        }else{
            switch([string]$result.State){
                'UPDATE_AVAILABLE' {
                    $version=[string]$result.Manifest.LatestVersion
                    if(-not [string]::Equals($version,[string]$script:NyxUi.ShownUpdateVersion,[StringComparison]::Ordinal)){
                        $script:NyxUi.ShownUpdateVersion=$version
                        $choice=Show-NyxUpdateAvailableDialog -Manifest $result.Manifest -Palette $script:NyxUi.Palette
                        if($choice -eq 'ViewUpdate' -and (Test-NyxUpdateDestinationUri -Value ([string]$result.Manifest.ReleaseUrl) -Purpose 'Release')){Invoke-NyxOpen ([string]$result.Manifest.ReleaseUrl)}
                    }elseif($manual){$script:NyxUi.FooterLabel.Text="Update $version was already shown during this session."}
                }
                'UP_TO_DATE' {if($manual){[Windows.Forms.MessageBox]::Show("Nyx PC Checkup is up to date.`r`n`r`nInstalled version: $($result.InstalledVersion)",'Check for Updates','OK','Information')|Out-Null}}
                'CHECK_FAILED' {if($manual){[Windows.Forms.MessageBox]::Show('Unable to check for updates right now. Please try again later.','Check for Updates','OK','Warning')|Out-Null}}
                'DISABLED' {if($manual){[Windows.Forms.MessageBox]::Show('Automatic update checks are disabled. Manual checks remain available.','Check for Updates','OK','Information')|Out-Null}}
            }
        }
        [void](Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.UpdateOutput))
        $script:NyxUi.UpdateProcess=$null;$script:NyxUi.UpdateOutput='';$script:NyxUi.UpdateManual=$false
        if(-not $script:NyxUi.ScanProcess -and ([string]$script:NyxUi.FooterLabel.Text -like 'Checking the official*')){$script:NyxUi.FooterLabel.Text='Ready. No background monitor is running.'}
    }catch{
        [void](Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.UpdateOutput))
        $script:NyxUi.UpdateProcess=$null;$script:NyxUi.UpdateTimer.Stop()
        Write-NyxLog -Level 'WARN' -Message ("Update-check UI completion failed: {0}" -f $_.Exception.Message)
    }
}

function Show-NyxConservativeNotification {
    param([Parameter(Mandatory=$true)][object]$Scan)
    try{
        $config=Get-NyxConfiguration
        if(-not [bool]$config.notificationsEnabled -or [bool]$Scan.Cancelled){return}
        if($null -ne $Scan.PSObject.Properties['WorkerError']){return}
        $important=@($Scan.Results|Where-Object{
            [string]$_.Status -eq 'NeedsAttention' -and (
                [string]$_.Severity -eq 'High' -or
                [string]$_.CheckId -in @('storage.system-drive','updates.restart','updates.pending','drive.health','backup.status')
            )
        }|Select-Object -First 4)
        if($important.Count -eq 0){return}
        $lines=@($important|ForEach-Object{"- $($_.Name): $($_.Finding)"})
        $message="Nyx found $($important.Count) important item(s) worth reviewing:`r`n`r`n"+($lines -join "`r`n")+"`r`n`r`nNo change was made automatically."
        [Windows.Forms.MessageBox]::Show($message,'Nyx PC Checkup - review recommended','OK','Information')|Out-Null
    }catch{Write-NyxLog -Level 'WARN' -Message ("In-app notification could not be shown: {0}" -f $_.Exception.Message)}
}

function Start-NyxScan {
    param([ValidateSet('Quick','Full')][string]$Mode)
    if($script:NyxUi.ScanProcess -and -not $script:NyxUi.ScanProcess.HasExited){return}
    $paths=Initialize-NyxDataDirectories;$id=[guid]::NewGuid().ToString('N');$script:NyxUi.ScanOutput=Join-Path $paths.Temp ("scan-$id.json");$script:NyxUi.ProgressPath=Join-Path $paths.Temp ("scan-$id-progress.jsonl");$script:NyxUi.CancelPath=Join-Path $paths.Temp ("scan-$id.cancel");$script:NyxUi.ProgressLineCount=0
    $worker=Join-Path $script:NyxUi.AppRoot 'workers\ScanWorker.ps1';$args="-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$worker`" -Mode $Mode -OutputPath `"$($script:NyxUi.ScanOutput)`" -ProgressPath `"$($script:NyxUi.ProgressPath)`" -CancelPath `"$($script:NyxUi.CancelPath)`""
    try{$script:NyxUi.ScanProcess=Start-Process -FilePath (Get-NyxPowerShellPath) -ArgumentList $args -WindowStyle Hidden -PassThru;$script:NyxUi.FooterProgress.Value=0;$script:NyxUi.FooterLabel.Text="$Mode check starting. Scanning is read-only.";$script:NyxUi.CancelButton.Enabled=$true;$script:NyxUi.ScanTimer.Start()}catch{[Windows.Forms.MessageBox]::Show("The scan could not start.`r`n$($_.Exception.Message)",'Nyx PC Checkup','OK','Error')|Out-Null}
}
function Read-NyxCompleteProgressLines {
    param([Parameter(Mandatory=$true)][string]$Path)
    $stream=$null;$reader=$null
    try {
        $stream=[IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8,$true)
        $text=$reader.ReadToEnd()
        # An append may be in flight. Do not consume its incomplete final line;
        # the next timer tick reads it after the writer has appended a newline.
        $last=$text.LastIndexOf("`n")
        if($last -ge 0){$text.Substring(0,$last) -split "`r?`n"}
    } catch {
        $cause=$_.Exception.GetBaseException()
        if($cause -is [IO.FileNotFoundException]){return}
        if($cause -is [IO.IOException] -and ($cause.HResult -band 0xFFFF) -in @(32,33)){return}
        throw
    } finally {
        if($null -ne $reader){$reader.Dispose()}
        elseif($null -ne $stream){$stream.Dispose()}
    }
}

function Update-NyxScanProgress {
    try{
        if($script:NyxUi.ProgressPath -and(Test-Path -LiteralPath $script:NyxUi.ProgressPath)){
            $lines=@(Read-NyxCompleteProgressLines -Path $script:NyxUi.ProgressPath)
            if($lines.Count -gt $script:NyxUi.ProgressLineCount){
                for($i=$script:NyxUi.ProgressLineCount;$i -lt $lines.Count;$i++){
                    try{$e=$lines[$i]|ConvertFrom-Json;$script:NyxUi.FooterLabel.Text=[string]$e.Message;$p=[int]$e.Percent;if($p -ge 0 -and $p -le 100){$script:NyxUi.FooterProgress.Value=$p}}catch{}
                }
                $script:NyxUi.ProgressLineCount=$lines.Count
            }
        }
        if($script:NyxUi.ScanProcess -and $script:NyxUi.ScanProcess.HasExited){
            $script:NyxUi.ScanTimer.Stop();$script:NyxUi.CancelButton.Enabled=$false
            if(Test-Path -LiteralPath $script:NyxUi.ScanOutput){
                $script:NyxUi.Scan=Get-Content -LiteralPath $script:NyxUi.ScanOutput -Raw -Encoding UTF8|ConvertFrom-Json
                if([bool]$script:NyxUi.Scan.Cancelled){$script:NyxUi.FooterLabel.Text='Check cancelled. Partial results were preserved.'}
                elseif($null -ne $script:NyxUi.Scan.PSObject.Properties['WorkerError']){$script:NyxUi.FooterLabel.Text='The check stopped unexpectedly. No changes were made.'}
                else{$script:NyxUi.FooterLabel.Text=[string]$script:NyxUi.Scan.Summary.Headline}
                $script:NyxUi.FooterProgress.Value=100
                Show-NyxPage -Page $script:NyxUi.CurrentPage
                Show-NyxConservativeNotification -Scan $script:NyxUi.Scan
            }else{$script:NyxUi.FooterLabel.Text='The check ended without a result file. No changes were made.'}
            [void](Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath))
            $script:NyxUi.ScanProcess=$null
        }
    }catch{Write-NyxLog -Level 'WARN' -Message ("UI progress update failed: {0}" -f $_.Exception.Message)}
}
function Cancel-NyxScan {
    if($script:NyxUi.ScanProcess -and -not $script:NyxUi.ScanProcess.HasExited){Set-Content -LiteralPath $script:NyxUi.CancelPath -Value 'cancel' -Encoding ASCII;$script:NyxUi.FooterLabel.Text='Cancelling safely. Partial results will remain visible.';$script:NyxUi.CancelButton.Enabled=$false}
}

function Show-NyxPage {
    param([string]$Page)
    $script:NyxUi.CurrentPage=$Page;$script:NyxUi.HeaderTitle.Text=$Page
    foreach($button in $script:NyxUi.NavButtons){if([string]$button.Tag -eq $Page){$button.BackColor=$script:NyxUi.Palette.Hover;$button.ForeColor=$script:NyxUi.Palette.Text}else{$button.BackColor=$script:NyxUi.Palette.Rail;$button.ForeColor=$script:NyxUi.Palette.Muted}}
    switch($Page){
        'Home'{Show-NyxHomePage};'Checkup'{Show-NyxCheckupPage};'Storage'{Show-NyxStoragePage};'Startup'{Show-NyxStartupPage};
        'Security'{Show-NyxCategoryPage -Title 'Security' -Subtitle 'Nyx reads Windows security status without disabling, replacing, or modifying protection.' -Categories @('Security') -ActionText 'Open Windows Security' -Action {Invoke-NyxOpen 'windowsdefender:'}};
        'Updates'{Show-NyxCategoryPage -Title 'Windows Updates' -Subtitle 'Nyx reports supported local indicators and opens the official Windows Update interface for action. It never claims full patch assurance from limited data.' -Categories @('Updates') -ActionText 'Open Windows Update' -Action {Invoke-NyxOpen 'ms-settings:windowsupdate'}};
        'Backup'{Show-NyxCategoryPage -Title 'Backup' -Subtitle 'Nyx checks supported Windows indicators and clearly acknowledges that third-party backup services may be undetectable.' -Categories @('Backup') -ActionText 'Open Windows Backup' -Action {Invoke-NyxOpen 'ms-settings:backup'}};
        'System'{Show-NyxCategoryPage -Title 'System details' -Subtitle 'Hardware class, uptime, battery, drive health, performance snapshot, and basic network status. Serial numbers and product keys are not collected.' -Categories @('System','Battery','Drive Health','Performance','Network') -ActionText 'Open Windows System About' -Action {Invoke-NyxOpen 'ms-settings:about'}};
        'Apps'{Show-NyxAppsPage};'Cleanup'{Show-NyxCleanupPage};'Settings'{Show-NyxSettingsPage};default{Show-NyxHomePage}
    }
    # Every page is authored in 96-DPI logical units, including dynamically
    # generated cards, grids, checkboxes and nested controls.
    foreach($child in @($script:NyxUi.Content.Controls)){$child.Anchor='Top,Left'}
    Set-NyxDeviceGeometry -Root $script:NyxUi.Content -Scale $script:NyxUi.LayoutScale -ChildrenOnly
    Set-NyxScrollExtentFromChildren -Root $script:NyxUi.Content -Padding ([int](24*$script:NyxUi.LayoutScale))
    Register-NyxFocusScrollTree -Root $script:NyxUi.Content
    Register-NyxScrollFocus -Root $script:NyxUi.Content
}

function Update-NyxDeviceLayout {
    $ui=$script:NyxUi;$scale=Get-NyxControlDpiScale -Control $ui.Form
    if($scale -ne $ui.LayoutScale){
        foreach($part in @($ui.Rail,$ui.Header,$ui.Footer)){Set-NyxDeviceGeometry -Root $part -Scale $scale}
        $ui.LayoutScale=$scale
        Set-NyxScrollExtentFromChildren -Root $ui.Rail -Padding ([int](12*$scale))
    }
    # Two footer rows keep status, progress and Cancel independent of the
    # former fixed 500-pixel right-hand strip.
    $ui.Footer.Height=[int](96*$scale)
    $ui.FooterLabel.Height=[int](42*$scale)
    $ui.FooterActions.Height=[int](54*$scale)
    $ui.CancelButton.Location=New-Object Drawing.Point([math]::Max(0,($ui.FooterActions.ClientSize.Width-[int](176*$scale))),([int](8*$scale)))
    $ui.FooterProgress.Location=New-Object Drawing.Point(([int](18*$scale)),([int](19*$scale)))
    $ui.FooterProgress.Width=[math]::Max(1,($ui.CancelButton.Left-[int](32*$scale)))
}

function Show-NyxMainWindow {
    [CmdletBinding()]
    param([switch]$AcceptanceCloseProbe)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()

    $config=Get-NyxConfiguration
    $theme=Get-NyxEffectiveTheme -Preference ([string]$config.theme)
    $palette=Get-NyxPalette -Theme $theme
    $appRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $installRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

    $form=New-Object Windows.Forms.Form
    $form.Text='Nyx PC Checkup'
    $form.StartPosition='CenterScreen'
    # QA12-F-011: the supported native launcher suppresses only the console.
    # The application form itself must remain a normal visible taskbar window.
    $form.ShowInTaskbar=$true
    $form.WindowState=[Windows.Forms.FormWindowState]::Normal
    $form.BackColor=$palette.Window
    $form.ForeColor=$palette.Text
    $form.AutoScaleMode='None'
    $form.Font=New-Object Drawing.Font('Segoe UI',10)

    # QA10-F-008: size the initial window for the active DPI while staying
    # inside the usable work area. A 150% / 1366x768-class desktop therefore
    # receives roughly the same usable logical canvas as the 100% design.
    $responsiveSize=Get-NyxResponsiveWindowSize -Form $form
    $form.Size=$responsiveSize
    $form.MinimumSize=New-Object Drawing.Size([math]::Min(1050,$responsiveSize.Width),[math]::Min(700,$responsiveSize.Height))

    $iconPath=Join-Path $appRoot 'assets\nyx_pc_checkup.ico'
    if(Test-Path -LiteralPath $iconPath){try{$form.Icon=New-Object Drawing.Icon($iconPath)}catch{}}

    $rail=New-Object Windows.Forms.Panel
    $rail.Dock='Left'
    $rail.Width=240
    $rail.AutoScroll=$true
    $rail.BackColor=$palette.Rail
    $brand=New-NyxLabel -Text 'NYX' -X 22 -Y 20 -Width 80 -Height 38 -Size 22 -Bold $true -Palette $palette
    $brand.ForeColor=$palette.Accent2
    $product=New-NyxLabel -Text 'PC Checkup' -X 22 -Y 57 -Width 176 -Height 28 -Size 11 -Bold $true -Palette $palette
    $rail.Controls.AddRange(@($brand,$product))

    $navNames=@('Home','Checkup','Storage','Startup','Security','Updates','Backup','System','Apps','Cleanup','Settings')
    $navButtons=[System.Collections.Generic.List[object]]::new()
    $y=105
    foreach($name in $navNames){
        $b=New-NyxNavButton -Text $name -Page $name -Y $y -Palette $palette
        $b.Add_Click({param($sender,$eventArgs)Show-NyxPage -Page ([string]$sender.Tag)})
        $rail.Controls.Add($b)
        $navButtons.Add($b)
        $y+=46
    }
    $version=New-NyxLabel -Text 'v1.0.0 - Local-first' -X 0 -Y 0 -Width 220 -Height 42 -Size 8 -Palette $palette -Color 'Muted'
    $version.Location=New-Object Drawing.Point(0,($y+8))
    $version.Padding=New-Object Windows.Forms.Padding(22,8,8,0)
    $rail.Controls.Add($version)

    # Header actions live in a docked right-side container so DPI autoscaling
    # cannot preserve a stale negative right margin from pre-layout geometry.
    $header=New-Object Windows.Forms.Panel
    $header.Dock='Top'
    $header.Height=76
    $header.BackColor=$palette.Window
    $headerActions=New-Object Windows.Forms.Panel
    $headerActions.Dock='Right'
    $headerActions.Width=205
    $headerActions.BackColor=$palette.Window
    $export=New-NyxButton -Text 'Export report' -X 16 -Y 18 -Width 170 -Palette $palette
    $export.Add_Click({Export-NyxCurrentReport})
    $headerActions.Controls.Add($export)
    $headerTitle=New-NyxLabel -Text 'Home' -X 28 -Y 20 -Width 500 -Height 38 -Size 16 -Bold $true -Palette $palette
    $headerTitle.Dock='Fill'
    $headerTitle.Padding=New-Object Windows.Forms.Padding(28,20,0,0)
    $header.Controls.Add($headerTitle)
    $header.Controls.Add($headerActions)

    # Footer actions are similarly docked. Cancel/progress never depend on a
    # right-anchor established while the footer still has its default width.
    $footer=New-Object Windows.Forms.Panel
    $footer.Dock='Bottom'
    $footer.Height=58
    $footer.BackColor=$palette.Rail
    $footerActions=New-Object Windows.Forms.Panel
    $footerActions.Dock='Bottom'
    $footerActions.Height=54
    $footerActions.Width=500
    $footerActions.BackColor=$palette.Rail
    $progress=New-Object Windows.Forms.ProgressBar
    $progress.Location=New-Object Drawing.Point(18,20)
    $progress.Size=New-Object Drawing.Size(292,18)
    $progress.Minimum=0
    $progress.Maximum=100
    $cancel=New-NyxButton -Text 'Cancel scan' -X 324 -Y 9 -Width 160 -Height 38 -Palette $palette
    $cancel.Enabled=$false
    $cancel.Add_Click({Cancel-NyxScan})
    $footerActions.Controls.AddRange(@($progress,$cancel))
    $footerLabel=New-NyxLabel -Text 'Ready. No background monitor is running.' -X 0 -Y 0 -Width 500 -Height 58 -Size 9 -Palette $palette -Color 'Muted'
    $footerLabel.Dock='Top'
    $footerLabel.Padding=New-Object Windows.Forms.Padding(22,16,12,0)
    $footer.Controls.Add($footerLabel)
    $footer.Controls.Add($footerActions)

    $content=New-Object Windows.Forms.Panel
    $content.Dock='Fill'
    $content.BackColor=$palette.Window
    $content.AutoScroll=$true
    $content.TabStop=$false

    $form.Controls.Add($content)
    $form.Controls.Add($footer)
    $form.Controls.Add($header)
    $form.Controls.Add($rail)

    $timer=New-Object Windows.Forms.Timer
    $timer.Interval=400
    $timer.Add_Tick({Update-NyxScanProgress})
    $updateTimer=New-Object Windows.Forms.Timer
    $updateTimer.Interval=300
    $updateTimer.Add_Tick({Update-NyxUpdateCheckProgress})
    $last=Get-NyxLastScan

    $script:NyxUi=[ordered]@{
        Form=$form
        Palette=$palette
        Theme=$theme
        AppRoot=$appRoot
        InstallRoot=$installRoot
        Rail=$rail
        Header=$header
        HeaderTitle=$headerTitle
        Footer=$footer
        FooterActions=$footerActions
        LayoutScale=0.0
        FooterLabel=$footerLabel
        FooterProgress=$progress
        CancelButton=$cancel
        Content=$content
        NavButtons=@($navButtons.ToArray())
        CurrentPage='Home'
        Scan=$last
        ScanProcess=$null
        ScanTimer=$timer
        ScanOutput=''
        ProgressPath=''
        CancelPath=''
        ProgressLineCount=0
        UpdateProcess=$null
        UpdateTimer=$updateTimer
        UpdateOutput=''
        UpdateManual=$false
        ShownUpdateVersion=''
        AcceptanceCloseProbe=[bool]$AcceptanceCloseProbe
        BoundsAdjusting=$false
        BoundsUserSizing=$false
        BoundsPending=$true
        BoundsEnvironment=''
        BoundsMinimum96=(New-Object Drawing.Size(
            ([int][math]::Round($form.MinimumSize.Width/(Get-NyxControlDpiScale -Control $form))),
            ([int][math]::Round($form.MinimumSize.Height/(Get-NyxControlDpiScale -Control $form)))))
    }

    # Use a UI-thread timer rather than SystemEvents callbacks on a worker
    # thread. It also observes taskbar/work-area changes without a DPI event.
    $boundsTimer=New-Object Windows.Forms.Timer
    $boundsTimer.Interval=200
    $boundsTimer.Add_Tick({
        $f=$script:NyxUi.Form
        if($f.IsDisposed -or -not $f.Visible -or $script:NyxUi.BoundsUserSizing){return}
        $screen=[Windows.Forms.Screen]::FromHandle($f.Handle)
        $environment='{0}|{1}|{2}' -f $screen.DeviceName,$screen.WorkingArea,(Get-NyxControlDpiScale -Control $f)
        if($script:NyxUi.BoundsPending -or $environment -ne $script:NyxUi.BoundsEnvironment){
            $script:NyxUi.BoundsPending=$false
            $script:NyxUi.BoundsEnvironment=$environment
            Set-NyxWindowWithinWorkingArea -Form $f
            $previousScale=$script:NyxUi.LayoutScale
            Update-NyxDeviceLayout
            if($previousScale -ne $script:NyxUi.LayoutScale){Show-NyxPage -Page $script:NyxUi.CurrentPage}
        }
    })
    $form.Add_ResizeBegin({$script:NyxUi.BoundsUserSizing=$true})
    $form.Add_SizeChanged({
        if(-not $script:NyxUi.BoundsAdjusting){$script:NyxUi.BoundsPending=$true}
    })
    $form.Add_FormClosed({$boundsTimer.Stop();$boundsTimer.Dispose()})
    $form.Add_Shown({
        # F-011 defense in depth: do not inherit a hidden/minimized startup state.
        $script:NyxUi.Form.ShowInTaskbar=$true
        if($script:NyxUi.Form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized){
            $script:NyxUi.Form.WindowState=[Windows.Forms.FormWindowState]::Normal
        }
        [void]$script:NyxUi.Form.Activate()
        $script:NyxUi.Form.BringToFront()
        Set-NyxWindowWithinWorkingArea -Form $script:NyxUi.Form
        $script:NyxUi.BoundsPending=$true
        $boundsTimer.Start()
        Start-NyxUpdateCheck
        if([bool]$script:NyxUi.AcceptanceCloseProbe){
            # Explicit QA-only close probe: exercise the real FormClosing path
            # after Shown/update-start without changing normal application flow.
            [void]$script:NyxUi.Form.BeginInvoke([System.Action]{ $script:NyxUi.Form.Close() })
        }
    })
    $form.Add_ResizeEnd({
        $script:NyxUi.BoundsUserSizing=$false
        Set-NyxWindowWithinWorkingArea -Form $script:NyxUi.Form
        if($script:NyxUi -and $script:NyxUi.Form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized){
            Show-NyxPage -Page $script:NyxUi.CurrentPage
        }
    })
    $form.Add_FormClosing({
        param($sender,$eventArgs)
        if($script:NyxUi.ScanProcess -and -not $script:NyxUi.ScanProcess.HasExited){
            $a=[Windows.Forms.MessageBox]::Show('A read-only check is still running. Cancel it and close Nyx?','Nyx PC Checkup','YesNo','Question')
            if($a -ne [Windows.Forms.DialogResult]::Yes){$eventArgs.Cancel=$true;return}
            Cancel-NyxScan
            try{
                [void]$script:NyxUi.ScanProcess.WaitForExit(5000)
                if(-not $script:NyxUi.ScanProcess.HasExited){
                    $script:NyxUi.ScanProcess.Kill()
                    [void]$script:NyxUi.ScanProcess.WaitForExit(2000)
                }
            }catch{}
        }
        $timer.Stop()
        $updateTimer.Stop()
        if($script:NyxUi.UpdateProcess -and -not $script:NyxUi.UpdateProcess.HasExited){
            try{$script:NyxUi.UpdateProcess.Kill();[void]$script:NyxUi.UpdateProcess.WaitForExit(1500)}catch{}
        }
        # QA10-F-009: optional UI paths are filtered and boundary-validated before deletion.
        [void](Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath,$script:NyxUi.UpdateOutput))
    })

    Update-NyxDeviceLayout
    Register-NyxScrollFocus -Root $form
    Show-NyxPage -Page 'Home'
    [void][Windows.Forms.Application]::Run($form)
}

Export-ModuleMember -Function Show-NyxMainWindow

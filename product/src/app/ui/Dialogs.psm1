Set-StrictMode -Version 2.0
function Show-NyxResultDetailDialog {
    param([Parameter(Mandatory=$true)][object]$Result,[object]$Palette)
    $form=New-Object Windows.Forms.Form
    $form.Text=[string]$Result.Name;$form.Size=New-Object Drawing.Size(760,650);$form.MinimumSize=New-Object Drawing.Size(640,520)
    $form.StartPosition='CenterParent';$form.BackColor=$Palette.Window;$form.ForeColor=$Palette.Text;$form.AutoScaleMode='None';$form.ShowIcon=$false
    $title=New-NyxLabel -Text ([string]$Result.Name) -X 24 -Y 20 -Width 680 -Height 42 -Size 18 -Bold $true -Palette $Palette
    $status=New-NyxStatusPill -Status ([string]$Result.Status) -X 26 -Y 67 -Palette $Palette
    $text=New-Object Windows.Forms.RichTextBox
    $text.Location=New-Object Drawing.Point(24,108);$text.Size=New-Object Drawing.Size(694,440);$text.Anchor='Top,Bottom,Left,Right';$text.ReadOnly=$true
    $text.BackColor=$Palette.Surface;$text.ForeColor=$Palette.Text;$text.BorderStyle='FixedSingle';$text.Font=New-Object Drawing.Font('Segoe UI',10)
    $evidence=''
    try{$evidence=$Result.Evidence|ConvertTo-Json -Depth 10}catch{$evidence='Evidence could not be formatted.'}
    $text.Text="WHAT WAS FOUND`r`n$($Result.Finding)`r`n`r`nWHY IT MATTERS`r`n$($Result.Reason)`r`n`r`nRECOMMENDED ACTION`r`n$($Result.Recommendation)`r`n`r`nACTION SAFETY`r`n$($Result.ActionSafetyLevel)`r`n`r`nDATA SOURCE`r`n$($Result.DataSource)`r`n`r`nCOMPLETE`r`n$($Result.Complete)`r`n`r`nTECHNICAL EVIDENCE`r`n$evidence"
    $close=New-NyxButton -Text 'Close' -X 598 -Y 562 -Width 120 -Palette $Palette -Primary $true;$close.Anchor='Bottom,Right';$close.Add_Click({$form.Close()})
    $form.Controls.AddRange(@($title,$status,$text,$close));Initialize-NyxScrollableDialog -Form $form;[void]$form.ShowDialog()
}

function Show-NyxReportPreviewDialog {
    param([Parameter(Mandatory=$true)][string]$Text,[object]$Palette)
    $form=New-Object Windows.Forms.Form
    $form.Text='Review report before export';$form.Size=New-Object Drawing.Size(840,700);$form.MinimumSize=New-Object Drawing.Size(680,540)
    $form.StartPosition='CenterParent';$form.BackColor=$Palette.Window;$form.ForeColor=$Palette.Text;$form.AutoScaleMode='None';$form.ShowIcon=$false
    $title=New-NyxLabel -Text 'Privacy-safe report preview' -X 24 -Y 18 -Width 760 -Height 38 -Size 17 -Bold $true -Palette $Palette
    $note=New-NyxLabel -Text 'Review exactly what will be written. Usernames, IP addresses, secrets, serial numbers, file contents, and detailed personal paths are excluded by default.' -X 24 -Y 58 -Width 760 -Height 50 -Size 9 -Palette $Palette -Color 'Muted'
    $box=New-Object Windows.Forms.RichTextBox;$box.Location=New-Object Drawing.Point(24,112);$box.Size=New-Object Drawing.Size(776,484);$box.Anchor='Top,Bottom,Left,Right';$box.ReadOnly=$true;$box.Text=$Text;$box.BackColor=$Palette.Surface;$box.ForeColor=$Palette.Text;$box.Font=New-Object Drawing.Font('Consolas',9);$box.BorderStyle='FixedSingle'
    $continue=New-NyxButton -Text 'Continue to save' -X 626 -Y 610 -Width 174 -Palette $Palette -Primary $true;$continue.Anchor='Bottom,Right';$continue.Add_Click({$form.Tag=$true;$form.Close()})
    $cancel=New-NyxButton -Text 'Cancel' -X 496 -Y 610 -Width 116 -Palette $Palette;$cancel.Anchor='Bottom,Right';$cancel.Add_Click({$form.Tag=$false;$form.Close()})
    $form.Controls.AddRange(@($title,$note,$box,$continue,$cancel));$form.Tag=$false;Initialize-NyxScrollableDialog -Form $form;[void]$form.ShowDialog();return [bool]$form.Tag
}


function Show-NyxUpdateAvailableDialog {
    param([Parameter(Mandatory=$true)][object]$Manifest,[object]$Palette)
    $form=New-Object Windows.Forms.Form
    $form.Text='Update Available';$form.Size=New-Object Drawing.Size(620,430);$form.MinimumSize=New-Object Drawing.Size(560,390)
    $form.StartPosition='CenterParent';$form.BackColor=$Palette.Window;$form.ForeColor=$Palette.Text;$form.AutoScaleMode='None';$form.ShowIcon=$false
    $title=New-NyxLabel -Text 'Update Available' -X 28 -Y 24 -Width 520 -Height 42 -Size 20 -Bold $true -Palette $Palette
    $release=New-NyxLabel -Text ("$($Manifest.ReleaseName) is now available.") -X 28 -Y 78 -Width 535 -Height 42 -Size 13 -Bold $true -Palette $Palette
    $message=[string]$Manifest.Message
    if([string]::IsNullOrWhiteSpace($message)){$message='View the official Dietrich AI Labs release page for details and downloads.'}
    $body=New-NyxLabel -Text $message -X 28 -Y 130 -Width 535 -Height 64 -Size 10 -Palette $Palette -Color 'Muted'
    $details=New-Object Windows.Forms.RichTextBox
    $details.Location=New-Object Drawing.Point(28,205);$details.Size=New-Object Drawing.Size(535,102);$details.ReadOnly=$true
    $details.BackColor=$Palette.Surface;$details.ForeColor=$Palette.Text;$details.BorderStyle='FixedSingle';$details.Font=New-Object Drawing.Font('Segoe UI',9)
    $detailText="Version: $($Manifest.LatestVersion)`r`nPublished: $($Manifest.PublishedAtUtc)"
    if(-not [string]::IsNullOrWhiteSpace([string]$Manifest.Sha256)){$detailText+="`r`nSHA-256: $($Manifest.Sha256)"}
    $details.Text=$detailText
    $view=New-NyxButton -Text 'View Update' -X 389 -Y 328 -Width 174 -Palette $Palette -Primary $true;$view.Anchor='Bottom,Right';$view.Add_Click({$form.Tag='ViewUpdate';$form.Close()})
    $later=New-NyxButton -Text 'Remind Me Later' -X 205 -Y 328 -Width 170 -Palette $Palette;$later.Anchor='Bottom,Right';$later.Add_Click({$form.Tag='Later';$form.Close()})
    $form.Add_FormClosing({if([string]::IsNullOrWhiteSpace([string]$form.Tag)){$form.Tag='Later'}})
    $form.Controls.AddRange(@($title,$release,$body,$details,$view,$later));$form.Tag='Later';Initialize-NyxScrollableDialog -Form $form;[void]$form.ShowDialog();return [string]$form.Tag
}

Export-ModuleMember -Function Show-NyxResultDetailDialog,Show-NyxReportPreviewDialog,Show-NyxUpdateAvailableDialog

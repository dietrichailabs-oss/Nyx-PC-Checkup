$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Import-Module (Join-Path $PSScriptRoot '../../src/app/ui/Controls.psm1') -Force
$panel=New-Object Windows.Forms.Panel
$panel.Size=New-Object Drawing.Size(400,300)
$button=New-Object Windows.Forms.Button
$button.Bounds=New-Object Drawing.Rectangle(20,30,150,38)
$button.Font=New-Object Drawing.Font('Segoe UI',10)
$panel.Controls.Add($button)
try{
    foreach($scale in @(1.0,1.25,1.5,2.0,1.0)){
        Set-NyxDeviceGeometry -Root $panel -Scale $scale
        $expected=New-Object Drawing.Rectangle(([int][math]::Round(20*$scale)),([int][math]::Round(30*$scale)),([int][math]::Round(150*$scale)),([int][math]::Round(38*$scale)))
        # Intermediate fractional rounding can accumulate at most one pixel.
        foreach($field in @('X','Y','Width','Height')){if([math]::Abs($button.Bounds.$field-$expected.$field)-gt1){throw "Geometry mismatch at $scale for $field"}}
        if($button.Font.SizeInPoints-ne10){throw 'Font point size was changed'}
        $before=$button.Bounds
        Set-NyxDeviceGeometry -Root $panel -Scale $scale
        if($button.Bounds-ne$before){throw 'Repeated scaling is not idempotent'}
    }
    Register-NyxScrollFocus -Root $panel
    Register-NyxScrollFocus -Root $panel
    if(-not $button.NyxFocusRegistered){throw 'Focus scrolling handler missing'}
    'PASS: geometry at four scale factors, round trip, idempotence, unchanged point fonts, focus registration. Not native installed acceptance.'
}finally{$panel.Dispose()}

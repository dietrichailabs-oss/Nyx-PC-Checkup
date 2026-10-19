[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$AppRoot,
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [string]$MainWindowPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1){throw 'Run under Windows PowerShell 5.1'}
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Import-Module (Join-Path $AppRoot 'ui\Theme.psm1') -Force
Import-Module (Join-Path $AppRoot 'ui\Controls.psm1') -Force
if(-not $MainWindowPath){$MainWindowPath=Join-Path $AppRoot 'ui\MainWindow.psm1'}
$checks=New-Object 'System.Collections.Generic.List[object]'
function Assert-F019([string]$Name,[bool]$Passed){
    $checks.Add([pscustomobject]@{Name=$Name;Passed=$Passed})
    if(-not $Passed){throw "F-019 regression: $Name"}
}
# These presentation dependencies do not affect filtering/cardinality. Product
# page functions and the real DataGridView implementation run unchanged.
function Get-NyxPrivacyStatement {return 'Local regression fixture'}
function Get-NyxStatusSymbol($Status){return '+'}
function Get-NyxStatusLabel($Status){return [string]$Status}
$script:NyxUi=@{
    Content=(New-Object Windows.Forms.Panel)
    Palette=(Get-NyxPalette -Theme Light)
    LayoutScale=1.0
    Scan=$null
}
$script:NyxUi.Content.Size=New-Object Drawing.Size(1000,700)
$failure=$null
try {
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($MainWindowPath,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw 'Product parser diagnostics'}
    foreach($name in @('Clear-NyxPage','Get-NyxPageWidth','Set-NyxPageScrollExtent','Add-NyxPageHeading','Get-NyxResultsByCategory','Get-NyxGroupStatus','Add-NyxScanButtons','New-NyxResultsGridControl','Add-NyxNoScanCard','Show-NyxCategoryPage','Show-NyxStoragePage','Show-NyxHomePage')){
        $f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
        if($null -eq $f){throw "Missing product function $name"}
        . ([scriptblock]::Create($f.Extent.Text))
    }
    foreach($representation in @('Native','Deserialized')){
        foreach($category in @('Backup','Security','Updates','System')){
            foreach($count in @(0,1,2,12)){
                $results=@(for($i=0;$i -lt $count;$i++){
                    [pscustomobject]@{CheckId="fixture.$i";Category=$category;Name="Fixture $i";Finding="Finding $i";Status='Good'}
                })
                # Keep an unrelated result to test filtering rather than just
                # an empty Scan.Results container.
                $results+= [pscustomobject]@{CheckId='unrelated';Category='Other';Name='Other';Finding='Other';Status='Good'}
                $scan=[pscustomobject]@{Results=$results;Summary=[pscustomobject]@{OverallStatus='Good';Headline='Fixture';Good=$results.Count;NeedsAttention=0;Optional=0;Unknown=0}}
                if($representation -eq 'Deserialized'){$scan=$scan|ConvertTo-Json -Depth 12|ConvertFrom-Json}
                $script:NyxUi.Scan=$scan
                foreach($repeat in 1..3){
                    Show-NyxCategoryPage -Title $category -Subtitle 'Fixture' -Categories @($category)
                    $grids=@($script:NyxUi.Content.Controls|Where-Object{$_ -is [Windows.Forms.DataGridView]})
                    $labels=@($script:NyxUi.Content.Controls|Where-Object{$_ -is [Windows.Forms.Label] -and $_.Text -like 'This module did not return*'})
                    $prefix="$representation/$category/$count/open-$repeat"
                    if($count -eq 0){
                        Assert-F019 "$prefix no-data label" ($labels.Count -eq 1)
                        Assert-F019 "$prefix no grid" ($grids.Count -eq 0)
                    }else{
                        Assert-F019 "$prefix exact rows" ($grids.Count -eq 1 -and $grids[0].Rows.Count -eq $count)
                        Assert-F019 "$prefix retains first result" ($grids[0].Rows[0].Tag.CheckId -eq 'fixture.0' -and $labels.Count -eq 0)
                    }
                    # Navigate to a different real page before returning.
                    Show-NyxHomePage
                }
                Assert-F019 "$representation/$category/$count Home returns" ($script:NyxUi.Content.Controls.Count -gt 0)
                # Exercise the third helper caller with matching storage data.
                foreach($result in $scan.Results){if($result.Category -eq $category){$result.Category='Storage'}}
                Show-NyxStoragePage
                $grids=@($script:NyxUi.Content.Controls|Where-Object{$_ -is [Windows.Forms.DataGridView]})
                Assert-F019 "$representation/$category/$count Storage rows" ($grids.Count -eq 1 -and $grids[0].Rows.Count -eq $count)
            }
        }
    }
    $script:NyxUi.Scan=[pscustomobject]@{Results=@()}
    Show-NyxCategoryPage -Title Backup -Subtitle Fixture -Categories @('Backup')
    Assert-F019 'Empty Results array renders no-data' (@($script:NyxUi.Content.Controls|Where-Object{$_.Text -like 'This module did not return*'}).Count -eq 1)
    $script:NyxUi.Scan=$null
    Show-NyxCategoryPage -Title Backup -Subtitle Fixture -Categories @('Backup')
    Assert-F019 'No scan renders scan card' (@($script:NyxUi.Content.Controls|Where-Object{$_ -is [Windows.Forms.Panel]}).Count -eq 1)
}catch{$failure=$_.Exception.ToString()}finally{
    $script:NyxUi.Content.Dispose()
    [ordered]@{Harness='QA27-F024-PS51-27';Type='Native PS5.1 source/WinForms cardinality regression; NOT installed acceptance';PowerShell=$PSVersionTable.PSVersion.ToString();Passed=($null -eq $failure);Count=$checks.Count;Checks=$checks.ToArray();Failure=$failure}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

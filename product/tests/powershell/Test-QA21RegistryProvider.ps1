param([Parameter(Mandatory=$true)][string]$AppRoot,[Parameter(Mandatory=$true)][string]$OutputPath)
Set-StrictMode -Version 2
$ErrorActionPreference='Stop'
$checks=New-Object 'System.Collections.Generic.List[object]'
function Assert-F018([string]$Name,[bool]$Passed){$checks.Add([pscustomobject]@{Name=$Name;Passed=$Passed});if(-not $Passed){throw $Name}}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $AppRoot 'checks\InstalledApps.psm1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Product parser errors'}
foreach($function in $ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($function.Extent.Text))}
function Get-NyxStableId {param([string]$Text) return $Text}
$key='HKCU:\Software\NyxQA21_F018_'+[guid]::NewGuid().ToString('N')
$failure=$null
try{
    New-Item -Path $key -Force|Out-Null
    $empty=Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    Assert-F018 'Real empty registry key is ignored' ($null -eq (ConvertTo-NyxInstalledApplication $empty))
    Assert-F018 'Null provider record is ignored' ($null -eq (ConvertTo-NyxInstalledApplication $null))
    New-ItemProperty -LiteralPath $key -Name DisplayName -Value 'QA21 Provider Fixture' -PropertyType String|Out-Null
    $record=Get-ItemProperty -LiteralPath $key -ErrorAction Stop
    foreach($name in @('SystemComponent','Publisher','DisplayVersion','InstallDate','EstimatedSize','InstallLocation','UninstallString')){
        Assert-F018 ("Actual provider missing $name returns null") ($null -eq (Get-NyxUninstallValue $record $name))
    }
    $app=ConvertTo-NyxInstalledApplication $record
    Assert-F018 'Minimal real provider application retained' ($app.Name -eq 'QA21 Provider Fixture' -and $app.Publisher -eq '' -and $null -eq $app.EstimatedSizeBytes)
    New-ItemProperty -LiteralPath $key -Name SystemComponent -Value 0 -PropertyType DWord|Out-Null
    Assert-F018 'Real provider SystemComponent zero retained' ($null -ne (ConvertTo-NyxInstalledApplication (Get-ItemProperty -LiteralPath $key)))
    Set-ItemProperty -LiteralPath $key -Name SystemComponent -Value 1
    Assert-F018 'Real provider SystemComponent one excluded' ($null -eq (ConvertTo-NyxInstalledApplication (Get-ItemProperty -LiteralPath $key)))
    Set-ItemProperty -LiteralPath $key -Name SystemComponent -Value 0
    New-ItemProperty -LiteralPath $key -Name Publisher -Value 'Fixture vendor' -PropertyType String|Out-Null
    New-ItemProperty -LiteralPath $key -Name EstimatedSize -Value 12 -PropertyType DWord|Out-Null
    $app=ConvertTo-NyxInstalledApplication (Get-ItemProperty -LiteralPath $key)
    Assert-F018 'Mixed provider values preserve application and size' ($app.Publisher -eq 'Fixture vendor' -and $app.EstimatedSizeBytes -eq 12288 -and $app.Version -eq '')
    Assert-F018 'Actual provider metadata is readable' (-not [string]::IsNullOrWhiteSpace([string](Get-NyxUninstallValue (Get-ItemProperty -LiteralPath $key) 'PSPath')))
    Set-ItemProperty -LiteralPath $key -Name DisplayName -Value ''
    Assert-F018 'Real provider empty DisplayName ignored' ($null -eq (ConvertTo-NyxInstalledApplication (Get-ItemProperty -LiteralPath $key)))
    $throwing=[pscustomobject]@{DisplayName='Throwing fixture'}
    $throwing|Add-Member ScriptProperty Publisher {throw [FormatException]::new('Unrelated getter failure')}
    $propagated=$false;try{$null=ConvertTo-NyxInstalledApplication $throwing}catch{$propagated=$true}
    Assert-F018 'Unrelated getter failure propagates' $propagated
    $roots=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach($root in $roots){
        $count=0
        if(Test-Path -LiteralPath $root -ErrorAction Stop){foreach($subkey in @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)){$actual=Get-ItemProperty -LiteralPath $subkey.PSPath -ErrorAction Stop;$null=ConvertTo-NyxInstalledApplication $actual;$count++}}
        Assert-F018 ("Actual uninstall provider root read: $root ($count records)") $true
    }
    $apps=@(Get-NyxInstalledApplications)
    Assert-F018 'Integrated real registry inventory retains entries' ($apps.Count -gt 0)
    function Get-ItemProperty {param($LiteralPath,$ErrorAction) throw [UnauthorizedAccessException]::new('Fixture provider denial')}
    function Test-Path {param($LiteralPath,$ErrorAction) return $true}
    function Get-ChildItem {param($LiteralPath,$ErrorAction) return [pscustomobject]@{PSPath='FixtureRegistryKey'}}
    $propagated=$false;try{$null=Get-NyxInstalledApplications}catch{$propagated=$true}
    Assert-F018 'Genuine registry provider failure propagates' $propagated
}catch{$failure=$_.Exception.ToString()}finally{
    if($key -notmatch '^HKCU:\\Software\\NyxQA21_F018_[0-9a-f]{32}$'){throw 'Unsafe fixture cleanup path'}
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $key -Recurse -Force -ErrorAction SilentlyContinue
    @{Harness='QA21-F018-PS51-21';Type='Native registry-provider source regression; not installed acceptance';Passed=($null -eq $failure);Count=$checks.Count;Checks=$checks.ToArray();Failure=$failure;PowerShell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding UTF8
}
if($failure){throw $failure}

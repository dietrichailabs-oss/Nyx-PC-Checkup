Set-StrictMode -Version 2.0
function Get-NyxUninstallValue {
    param($Record,[string]$Name)
    $property=$Record.PSObject.Properties[$Name]
    if($null -eq $property){return $null}
    return $property.get_Value()
}
function ConvertTo-NyxInstalledApplication {
    param($Record)
    $name=[string](Get-NyxUninstallValue $Record 'DisplayName')
    if([string]::IsNullOrWhiteSpace($name)){return $null}
    if((Get-NyxUninstallValue $Record 'SystemComponent') -eq 1){return $null}
    $version=[string](Get-NyxUninstallValue $Record 'DisplayVersion')
    $publisher=[string](Get-NyxUninstallValue $Record 'Publisher')
    $key=("{0}|{1}|{2}" -f $name,$version,$publisher).ToLowerInvariant()
    $size=$null;$kilobytes=[long]0
    $rawSize=Get-NyxUninstallValue $Record 'EstimatedSize'
    if($null -ne $rawSize -and [long]::TryParse([string]$rawSize,[ref]$kilobytes) -and $kilobytes -ge 0 -and $kilobytes -le ([long]::MaxValue / 1024)){$size=$kilobytes * [long]1024}
    return [pscustomobject][ordered]@{
        Id=Get-NyxStableId -Text $key;Name=$name;Publisher=$publisher;Version=$version
        InstallDate=[string](Get-NyxUninstallValue $Record 'InstallDate');EstimatedSizeBytes=$size
        InstallLocation=[string](Get-NyxUninstallValue $Record 'InstallLocation')
        UninstallAvailable=(-not [string]::IsNullOrWhiteSpace([string](Get-NyxUninstallValue $Record 'UninstallString')))
    }
}
function Get-NyxInstalledApplications {
    $roots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $map = @{}
    foreach ($root in $roots) {
        $parent=$root.Substring(0,$root.Length-2)
        if(-not(Test-Path -LiteralPath $parent -ErrorAction Stop)){continue}
        foreach($subkey in @(Get-ChildItem -LiteralPath $parent -ErrorAction Stop)){
            $record=Get-ItemProperty -LiteralPath $subkey.PSPath -ErrorAction Stop
            $app=ConvertTo-NyxInstalledApplication $record
            if($null -ne $app -and -not $map.ContainsKey($app.Id)){$map[$app.Id]=$app}
        }
    }
    return @($map.Values | Sort-Object Name)
}

function Get-NyxInstalledAppsCheck {
    $apps = @(Get-NyxInstalledApplications)
    $largest = @($apps | Where-Object { $_.EstimatedSizeBytes -ne $null } | Sort-Object EstimatedSizeBytes -Descending | Select-Object -First 10)
    if($apps.Count -eq 0){
        return New-NyxCheckResult -CheckId 'apps.inventory' -Category 'Applications' -Name 'Installed applications' -Status 'Unknown' -Severity 'Info' `
            -Finding 'Windows returned no supported installed-application records.' `
            -Reason 'An empty uninstall inventory is not enough evidence to say that the application review completed normally.' `
            -Evidence ([pscustomobject]@{Count=0;Applications=@();LargestByReportedSize=@()}) `
            -Recommendation 'Open Windows Installed Apps settings to review the operating system inventory.' -ActionSafetyLevel 'SafeRedirect' `
            -DataSource 'Current-user and machine uninstall registry records' -Complete $false -ErrorReason 'No uninstall records were returned.' -Details @()
    }
    return New-NyxCheckResult -CheckId 'apps.inventory' -Category 'Applications' -Name 'Installed applications' -Status 'Good' -Severity 'Info' `
        -Finding "$($apps.Count) installed application(s) were listed from supported uninstall records." `
        -Reason 'The list is informational; Nyx does not call applications junk or uninstall anything automatically.' `
        -Evidence ([pscustomobject]@{ Count=$apps.Count; Applications=$apps; LargestByReportedSize=$largest }) `
        -Recommendation 'Use Windows Installed Apps settings when you intentionally want to remove a program.' -ActionSafetyLevel 'SafeRedirect' `
        -DataSource 'Current-user and machine uninstall registry records' -Details $apps
}

Export-ModuleMember -Function Get-NyxInstalledApplications,Get-NyxInstalledAppsCheck

Set-StrictMode -Version 2.0
function Test-NyxAutomaticUpdateCheckDue {
    [CmdletBinding()]
    param([object]$Configuration=$null,[DateTimeOffset]$NowUtc=[DateTimeOffset]::UtcNow)
    if($null -eq $Configuration){$Configuration=Get-NyxConfiguration}
    if(-not [bool]$Configuration.updates.enabled){return $false}
    $lastText=[string]$Configuration.updates.lastCheckUtc
    if([string]::IsNullOrWhiteSpace($lastText)){return $true}
    $last=[DateTimeOffset]::MinValue
    if(-not [DateTimeOffset]::TryParse($lastText,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$last)){return $true}
    return $NowUtc.ToUniversalTime() -ge $last.ToUniversalTime().AddDays(7)
}

function Set-NyxUpdateCheckAttemptUtc {
    [CmdletBinding()]
    param([DateTimeOffset]$NowUtc=[DateTimeOffset]::UtcNow)
    $configuration=Get-NyxConfiguration
    $configuration.updates.lastCheckUtc=$NowUtc.ToUniversalTime().ToString('o')
    Save-NyxConfiguration -Configuration $configuration
    return $configuration
}

Export-ModuleMember -Function Test-NyxAutomaticUpdateCheckDue,Set-NyxUpdateCheckAttemptUtc

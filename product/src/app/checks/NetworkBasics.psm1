Set-StrictMode -Version 2.0
function Get-NyxNetworkBasicsCheck {
    $adapters=@();$profiles=@();$adapterAvailable=$true;$profileAvailable=$true
    try{$adapters=@(Get-NetAdapter -Physical -ErrorAction Stop|Select-Object Name,InterfaceDescription,Status,LinkSpeed,MediaType)}catch{$adapterAvailable=$false}
    try{$profiles=@(Get-NetConnectionProfile -ErrorAction Stop|Select-Object Name,InterfaceAlias,NetworkCategory,IPv4Connectivity,IPv6Connectivity)}catch{$profileAvailable=$false}
    $up=@($adapters|Where-Object{$_.Status -eq 'Up'})
    $internet=@($profiles|Where-Object{$_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet'}).Count -gt 0
    $dns=$false;$dnsComplete=$false
    try{
        $job=Start-Job -ScriptBlock {try{[Net.Dns]::GetHostAddresses('dns.msftncsi.com')|Out-Null;[pscustomobject]@{Complete=$true;Success=$true}}catch{[pscustomobject]@{Complete=$true;Success=$false}}}
        if(Wait-Job $job -Timeout 4){$answer=Receive-Job $job|Select-Object -Last 1;$dnsComplete=[bool]$answer.Complete;$dns=[bool]$answer.Success}else{Stop-Job $job -ErrorAction SilentlyContinue}
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    }catch{}
    $evidence=[pscustomobject]@{Adapters=$adapters;Profiles=$profiles;AdapterStatusAvailable=$adapterAvailable;ProfileStatusAvailable=$profileAvailable;DnsCheckComplete=$dnsComplete;DnsResolutionSucceeded=$dns}
    if(-not $adapterAvailable){
        return New-NyxCheckResult -CheckId 'network.basics' -Category 'Network' -Name 'Network basics' -Status 'Unknown' -Severity 'Info' `
            -Finding 'Windows adapter status could not be determined.' -Reason 'The supported adapter interface was unavailable. No network setting was changed.' `
            -Evidence $evidence -Recommendation 'Retry the check or open Windows Network settings.' -ActionSafetyLevel 'SafeRedirect' `
            -DataSource 'Get-NetAdapter / Get-NetConnectionProfile / bounded DNS lookup' -Complete $false -ErrorReason 'Adapter status unavailable.' -Details $evidence
    }
    if($up.Count -eq 0){
        return New-NyxCheckResult -CheckId 'network.basics' -Category 'Network' -Name 'Network basics' -Status 'NeedsAttention' -Severity 'Medium' `
            -Finding 'No active physical network adapter was detected.' -Reason 'The supported adapter API returned no physical adapter in the Up state.' `
            -Evidence $evidence -Recommendation 'Connect Wi-Fi or Ethernet and retry. Nyx did not change DNS, proxy, firewall, or adapter settings.' `
            -ActionSafetyLevel 'None' -DataSource 'Get-NetAdapter, Get-NetConnectionProfile, and one bounded DNS resolution test' -Complete $adapterAvailable -Details $evidence
    }
    if(-not $profileAvailable -or -not $dnsComplete){
        return New-NyxCheckResult -CheckId 'network.basics' -Category 'Network' -Name 'Network basics' -Status 'Unknown' -Severity 'Info' `
            -Finding 'A network adapter is connected, but the complete Internet check was unavailable.' `
            -Reason 'Nyx will not call the connection broken when Windows connectivity-profile or bounded DNS evidence is incomplete.' `
            -Evidence $evidence -Recommendation 'Retry the check or use Windows Network Troubleshooter if Internet access is actually failing.' `
            -ActionSafetyLevel 'SafeRedirect' -DataSource 'Get-NetAdapter, Get-NetConnectionProfile, and one bounded DNS resolution test' -Complete $false `
            -ErrorReason 'Connectivity-profile or DNS evidence was incomplete.' -Details $evidence
    }
    if($internet -and $dns){$status='Good';$finding='Windows reports an Internet-connected network and DNS resolution succeeded.';$reason='The active connection profile and a bounded DNS lookup both succeeded.';$recommend='No network action is required.'}
    else{$status='NeedsAttention';$finding='A network adapter is connected, but Internet access did not pass both supported checks.';$reason='The Windows connectivity profile or bounded DNS lookup reported no Internet access.';$recommend='Check the router or Internet service. Nyx did not change DNS, proxy, firewall, or adapter settings.'}
    return New-NyxCheckResult -CheckId 'network.basics' -Category 'Network' -Name 'Network basics' -Status $status -Severity $(if($status -eq 'Good'){'Info'}else{'Medium'}) `
        -Finding $finding -Reason $reason -Evidence $evidence -Recommendation $recommend -ActionSafetyLevel 'None' `
        -DataSource 'Get-NetAdapter, Get-NetConnectionProfile, and one bounded DNS resolution test' -Complete $true -Details $evidence
}

Export-ModuleMember -Function Get-NyxNetworkBasicsCheck

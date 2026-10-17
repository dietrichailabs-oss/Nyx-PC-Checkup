Set-StrictMode -Version 2.0
function Get-NyxSecurityStatusChecks {
    $results=[System.Collections.Generic.List[object]]::new()
    $defender=$null;$antivirus=@()
    try{$defender=Get-MpComputerStatus -ErrorAction Stop}catch{}
    try{$antivirus=@(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntivirusProduct -ErrorAction Stop|Select-Object displayName,productState)}catch{}
    if($defender){
        $active=[bool]$defender.AntivirusEnabled -and [bool]$defender.RealTimeProtectionEnabled
        if($active){$status='Good';$severity='Info';$finding='Windows reports that Microsoft Defender antivirus and real-time protection are active.';$reason='Defender status APIs reported protection enabled.';$recommend='No antivirus action is required.'}
        elseif($antivirus.Count -gt 0){$status='Unknown';$severity='Info';$finding=("Microsoft Defender is not the active real-time provider; Windows has {0} registered antivirus product(s)." -f $antivirus.Count);$reason='The registered product list was available, but its live real-time state could not be reliably decoded.';$recommend='Open Windows Security to confirm that the intended antivirus product is active.'}
        else{$status='NeedsAttention';$severity='High';$finding='Windows did not report active Microsoft Defender real-time protection, and no other antivirus product was registered.';$reason='The available local protection indicators did not show an active antivirus provider.';$recommend='Open Windows Security and enable or repair trusted antivirus protection.'}
        $results.Add((New-NyxCheckResult -CheckId 'security.antivirus' -Category 'Security' -Name 'Antivirus protection' -Status $status -Severity $severity `
            -Finding $finding -Reason $reason -Evidence ([pscustomobject]@{DefenderAntivirusEnabled=[bool]$defender.AntivirusEnabled;DefenderRealTimeProtectionEnabled=[bool]$defender.RealTimeProtectionEnabled;RegisteredProducts=@($antivirus.displayName)}) `
            -Recommendation $recommend -ActionSafetyLevel 'SafeRedirect' -DataSource 'Get-MpComputerStatus and SecurityCenter2' -Complete ($status -ne 'Unknown')))
    }elseif($antivirus.Count -gt 0){
        $results.Add((New-NyxCheckResult -CheckId 'security.antivirus' -Category 'Security' -Name 'Antivirus protection' -Status 'Unknown' -Severity 'Info' `
            -Finding ("Windows has {0} registered antivirus product(s): {1}." -f $antivirus.Count,($antivirus.displayName -join ', ')) `
            -Reason 'A product is registered, but its real-time state could not be reliably confirmed through the available interface.' `
            -Evidence ([pscustomobject]@{RegisteredProducts=@($antivirus)}) -Recommendation 'Open Windows Security to confirm current protection.' `
            -ActionSafetyLevel 'SafeRedirect' -DataSource 'SecurityCenter2' -Complete $false))
    }else{$results.Add((New-NyxUnknownResult -CheckId 'security.antivirus' -Category 'Security' -Name 'Antivirus protection' -Reason 'No supported antivirus status source was available.' -DataSource 'Defender / SecurityCenter2'))}

    try{
        $profiles=@(Get-NetFirewallProfile -ErrorAction Stop|Select-Object Name,Enabled)
        if($profiles.Count -eq 0){
            $results.Add((New-NyxUnknownResult -CheckId 'security.firewall' -Category 'Security' -Name 'Windows Firewall' -Reason 'Windows returned no firewall-profile records.' -DataSource 'Get-NetFirewallProfile'))
        }else{
            $disabled=@($profiles|Where-Object{-not $_.Enabled});$status=if($disabled.Count -gt 0){'NeedsAttention'}else{'Good'}
            $results.Add((New-NyxCheckResult -CheckId 'security.firewall' -Category 'Security' -Name 'Windows Firewall' -Status $status -Severity $(if($status -eq 'Good'){'Info'}else{'High'}) `
                -Finding $(if($status -eq 'Good'){'Windows Firewall is enabled for all reported profiles.'}else{"Windows Firewall is disabled for: $($disabled.Name -join ', ')."}) `
                -Reason 'Firewall profile states were read without changing them.' -Evidence $profiles -Recommendation $(if($status -eq 'Good'){'No firewall action is required.'}else{'Open Windows Security and review firewall settings.'}) `
                -ActionSafetyLevel 'SafeRedirect' -DataSource 'Get-NetFirewallProfile'))
        }
    }catch{$results.Add((New-NyxUnknownResult -CheckId 'security.firewall' -Category 'Security' -Name 'Windows Firewall' -Reason $_.Exception.Message -DataSource 'Get-NetFirewallProfile'))}

    $securityServices=[System.Collections.Generic.List[object]]::new()
    foreach($serviceName in @('SecurityHealthService','wscsvc')){
        try{$service=Get-Service -Name $serviceName -ErrorAction Stop;$securityServices.Add([pscustomobject]@{Name=$serviceName;Status=[string]$service.Status;StartType=[string]$service.StartType})}catch{}
    }
    if($securityServices.Count -eq 0){
        $results.Add((New-NyxUnknownResult -CheckId 'security.windows-security-service' -Category 'Security' -Name 'Windows Security services' -Reason 'Supported Windows Security service states were unavailable.' -DataSource 'Get-Service'))
    }else{
        $running=@($securityServices|Where-Object{$_.Status -eq 'Running'}).Count -gt 0
        $results.Add((New-NyxCheckResult -CheckId 'security.windows-security-service' -Category 'Security' -Name 'Windows Security services' -Status $(if($running){'Good'}else{'NeedsAttention'}) -Severity $(if($running){'Info'}else{'High'}) `
            -Finding $(if($running){'A supported Windows Security service is running.'}else{'Windows did not report either supported Windows Security service as running.'}) `
            -Reason 'Service state was read without changing service configuration.' -Evidence @($securityServices.ToArray()) `
            -Recommendation $(if($running){'No action is required.'}else{'Open Windows Security and restart Windows. If the warning remains, use Windows support or a trusted technician.'}) `
            -ActionSafetyLevel 'SafeRedirect' -DataSource 'Get-Service'))
    }

    try{
        $secureBoot=Confirm-SecureBootUEFI -ErrorAction Stop
        $results.Add((New-NyxCheckResult -CheckId 'security.secure-boot' -Category 'Security' -Name 'Secure Boot' -Status $(if($secureBoot){'Good'}else{'Optional'}) -Severity 'Low' `
            -Finding $(if($secureBoot){'Secure Boot is enabled.'}else{'Secure Boot is not enabled on this supported firmware configuration.'}) `
            -Reason 'Secure Boot helps protect the startup process, but availability depends on firmware and installation mode.' -Evidence ([pscustomobject]@{Enabled=[bool]$secureBoot}) `
            -Recommendation $(if($secureBoot){'No action is required.'}else{'Treat this as optional unless your device or organization specifically requires Secure Boot.'}) -ActionSafetyLevel 'None' -DataSource 'Confirm-SecureBootUEFI'))
    }catch{$results.Add((New-NyxUnknownResult -CheckId 'security.secure-boot' -Category 'Security' -Name 'Secure Boot' -Reason 'Secure Boot status was unavailable. This is common on unsupported firmware or without sufficient access.' -DataSource 'Confirm-SecureBootUEFI'))}

    try{
        $tpm=Get-Tpm -ErrorAction Stop
        if(-not [bool]$tpm.TpmPresent){$tpmStatus='Optional';$tpmFinding='Windows did not report a TPM on this device.';$tpmRecommendation='A TPM is useful for some security features, but its absence is not treated as a critical failure for every home PC.'}
        elseif([bool]$tpm.TpmReady){$tpmStatus='Good';$tpmFinding='Windows reports that the TPM is present and ready.';$tpmRecommendation='No TPM action is required.'}
        else{$tpmStatus='Optional';$tpmFinding='A TPM is present, but Windows does not report it as ready.';$tpmRecommendation='Review Windows Security device-security details before changing firmware or TPM settings.'}
        $results.Add((New-NyxCheckResult -CheckId 'security.tpm' -Category 'Security' -Name 'Trusted Platform Module' -Status $tpmStatus -Severity 'Low' `
            -Finding $tpmFinding -Reason 'TPM presence and readiness were read without changing TPM ownership or firmware state.' `
            -Evidence ([pscustomobject]@{Present=[bool]$tpm.TpmPresent;Ready=[bool]$tpm.TpmReady;Enabled=[bool]$tpm.TpmEnabled;Activated=[bool]$tpm.TpmActivated}) `
            -Recommendation $tpmRecommendation -ActionSafetyLevel 'None' -DataSource 'Get-Tpm'))
    }catch{$results.Add((New-NyxUnknownResult -CheckId 'security.tpm' -Category 'Security' -Name 'Trusted Platform Module' -Reason 'TPM status was unavailable through the supported local interface.' -DataSource 'Get-Tpm'))}

    try{
        $vol=Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop;$enabled=$vol.ProtectionStatus -eq 'On'
        $results.Add((New-NyxCheckResult -CheckId 'security.encryption' -Category 'Security' -Name 'Drive encryption' -Status $(if($enabled){'Good'}else{'Optional'}) -Severity 'Low' `
            -Finding $(if($enabled){'Protection is active for the system drive.'}else{'Drive encryption protection is not active on the system drive.'}) `
            -Reason 'Encryption can protect files if a device is lost, but it is not a critical failure for every home PC.' -Evidence ([pscustomobject]@{ProtectionStatus=[string]$vol.ProtectionStatus;VolumeStatus=[string]$vol.VolumeStatus}) `
            -Recommendation $(if($enabled){'No action is required.'}else{'Consider device encryption if this is a portable PC and you understand recovery-key storage.'}) `
            -ActionSafetyLevel 'SafeRedirect' -DataSource 'Get-BitLockerVolume'))
    }catch{$results.Add((New-NyxUnknownResult -CheckId 'security.encryption' -Category 'Security' -Name 'Drive encryption' -Reason 'Drive-encryption status was unavailable through the supported local interface.' -DataSource 'Get-BitLockerVolume'))}
    return @($results.ToArray())
}

Export-ModuleMember -Function Get-NyxSecurityStatusChecks

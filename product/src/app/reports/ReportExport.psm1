Set-StrictMode -Version 2.0
function Get-NyxVersionMetadata {
    $path = Join-Path $PSScriptRoot '..\..\VERSION.json'
    if (Test-Path -LiteralPath $path) { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
    return [pscustomobject]@{ product='Nyx PC Checkup'; version='1.0.0'; build='Unknown'; publisher='Dietrich AI Labs' }
}

function Get-NyxReportEvidence {
    param([object]$Result)
    if ($null -eq $Result.Evidence) { return $null }
    switch ([string]$Result.CheckId) {
        'system.overview' {
            $e=$Result.Evidence
            return [pscustomobject]@{ WindowsEdition=$e.WindowsEdition; WindowsVersion=$e.WindowsVersion; WindowsBuild=$e.WindowsBuild; Is64Bit=$e.Is64Bit; Processor=$e.Processor; InstalledRamBytes=$e.InstalledRamBytes; SystemDriveCapacityBytes=$e.SystemDriveCapacityBytes; SystemDriveFreeBytes=$e.SystemDriveFreeBytes; DeviceClass=$e.DeviceClass }
        }
        'storage.system-drive' { return $Result.Evidence }
        'storage.user-folders' { return [pscustomobject]@{ Folders=@($Result.Evidence.Folders | ForEach-Object { [pscustomobject]@{ Name=$_.Name; Bytes=$_.Bytes; Files=$_.Files; Complete=$_.Complete } }); FilesScanned=$Result.Evidence.FilesScanned; AccessDenied=$Result.Evidence.AccessDenied } }
        'downloads.analysis' { return [pscustomobject]@{ TotalBytes=$Result.Evidence.TotalBytes; FileCount=@($Result.Evidence.Files).Count; DuplicateGroupCount=@($Result.Evidence.DuplicateGroups).Count; AccessDenied=$Result.Evidence.AccessDenied } }
        'startup.entries' { return [pscustomobject]@{ EnabledCount=$Result.Evidence.EnabledCount; DisabledByNyxCount=$Result.Evidence.DisabledByNyxCount; BrokenPathCount=$Result.Evidence.BrokenPathCount } }
        'apps.inventory' { return [pscustomobject]@{ Count=$Result.Evidence.Count } }
        'cleanup.preview' { return [pscustomobject]@{ CandidateCount=@($Result.Evidence.Candidates).Count; TotalBytes=$Result.Evidence.TotalBytes; Limited=$Result.Evidence.Limited } }
        'network.basics' { return [pscustomobject]@{ ActiveAdapterCount=@($Result.Evidence.Adapters | Where-Object { $_.Status -eq 'Up' }).Count; InternetProfileCount=@($Result.Evidence.Profiles | Where-Object { $_.IPv4Connectivity -eq 'Internet' -or $_.IPv6Connectivity -eq 'Internet' }).Count; DnsResolutionSucceeded=$Result.Evidence.DnsResolutionSucceeded } }
        default { return $Result.Evidence }
    }
}

function New-NyxSafeReport {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Scan,[switch]$IncludeUserName,[switch]$IncludeIpAddresses)
    $version=Get-NyxVersionMetadata
    $safeResults=[System.Collections.Generic.List[object]]::new()
    foreach ($result in @($Scan.Results)) {
        $safeResults.Add([pscustomobject][ordered]@{
            CheckId=[string]$result.CheckId; Category=[string]$result.Category; Name=[string]$result.Name;
            Status=[string]$result.Status; StatusLabel=Get-NyxStatusLabel ([string]$result.Status); Severity=[string]$result.Severity;
            Finding=[string]$result.Finding; Reason=[string]$result.Reason; Recommendation=[string]$result.Recommendation;
            ActionSafetyLevel=[string]$result.ActionSafetyLevel; Complete=[bool]$result.Complete; ErrorReason=[string]$result.ErrorReason;
            DataSource=[string]$result.DataSource; Evidence=(Get-NyxReportEvidence -Result $result)
        })
    }
    $report=[pscustomobject][ordered]@{
        ReportSchema='dietrich-ai-labs.nyx-pc-checkup.report.v1'; Product=[string]$version.product; Version=[string]$version.version; Build=[string]$version.build;
        ScanMode=[string]$Scan.Mode; ScanStartedUtc=[string]$Scan.StartedUtc; ScanCompletedUtc=[string]$Scan.CompletedUtc;
        Summary=$Scan.Summary; Results=@($safeResults.ToArray()); Privacy='This report excludes usernames, hardware serial numbers, product keys, browser data, document contents, passwords, tokens, and IP addresses by default.'
    }
    return Protect-NyxObject -InputObject $report -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses
}

function ConvertTo-NyxReportText {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Report)
    $lines=[System.Collections.Generic.List[string]]::new()
    $lines.Add('NYX PC CHECKUP - LOCAL DIAGNOSTIC SUMMARY')
    $lines.Add('Dietrich AI Labs')
    $lines.Add(('Version {0} | Build {1}' -f $Report.Version,$Report.Build))
    $lines.Add(('Scan: {0} | Completed: {1}' -f $Report.ScanMode,$Report.ScanCompletedUtc))
    $lines.Add('')
    $lines.Add(('Overall: {0}' -f (Get-NyxStatusLabel ([string]$Report.Summary.OverallStatus))))
    $lines.Add([string]$Report.Summary.Headline)
    $lines.Add(('Good {0} | Needs Attention {1} | Optional {2} | Unknown {3}' -f $Report.Summary.Good,$Report.Summary.NeedsAttention,$Report.Summary.Optional,$Report.Summary.Unknown))
    $lines.Add('')
    foreach ($r in @($Report.Results)) {
        $lines.Add(('[{0}] {1} - {2}' -f $r.StatusLabel,$r.Category,$r.Name))
        $lines.Add(('Finding: {0}' -f $r.Finding))
        $lines.Add(('Why: {0}' -f $r.Reason))
        $lines.Add(('Recommendation: {0}' -f $r.Recommendation))
        $lines.Add(('Source: {0} | Complete: {1}' -f $r.DataSource,$r.Complete))
        if (-not [string]::IsNullOrWhiteSpace([string]$r.ErrorReason)) { $lines.Add(('Could not check: {0}' -f $r.ErrorReason)) }
        $lines.Add('')
    }
    $lines.Add('Privacy: Everything analyzed by PC Checkup stays on this computer unless you explicitly export it.')
    $lines.Add([string]$Report.Privacy)
    return ($lines -join [Environment]::NewLine)
}

function Export-NyxReport {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Scan,[Parameter(Mandatory=$true)][string]$Path,[ValidateSet('TXT','JSON','PDF')][string]$Format,[switch]$IncludeUserName,[switch]$IncludeIpAddresses)
    $report=New-NyxSafeReport -Scan $Scan -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses
    $text=ConvertTo-NyxReportText -Report $report
    switch ($Format) {
        'TXT' { Set-Content -LiteralPath $Path -Value $text -Encoding UTF8 }
        'JSON' { $report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8 }
        'PDF' { Write-NyxSimplePdf -Path $Path -Lines @($text -split "`r?`n") }
    }
    return [pscustomobject]@{ Success=$true; Path=$Path; Format=$Format; Bytes=(Get-Item -LiteralPath $Path).Length }
}

Export-ModuleMember -Function Get-NyxVersionMetadata,Get-NyxReportEvidence,New-NyxSafeReport,ConvertTo-NyxReportText,Export-NyxReport

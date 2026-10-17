Set-StrictMode -Version 2.0
function Get-NyxDownloadItemsTotalBytes {
    param([System.Collections.IEnumerable]$Items)
    [int64]$total=0
    if($null -eq $Items){return $total}
    foreach($item in $Items){
        if($null -eq $item){continue}
        $size=[int64]$item.SizeBytes
        if($size -lt 0){throw 'Downloads item size cannot be negative.'}
        if($total -gt ([int64]::MaxValue - $size)){throw 'Downloads byte total exceeds the supported Int64 range.'}
        $total += $size
    }
    return $total
}

function New-NyxDownloadsAnalysisResult {
    param(
        [Parameter(Mandatory=$true)][string]$Downloads,
        [Parameter(Mandatory=$true)][System.Collections.IEnumerable]$Items,
        [int]$Denied=0,
        [bool]$Cancelled=$false,
        [string]$CancelFile=''
    )
    $rules = Get-NyxRules
    $config = Get-NyxConfiguration
    $materialized=[System.Collections.Generic.List[object]]::new()
    foreach($entry in $Items){if($null -ne $entry){$materialized.Add($entry)}}
    $itemArray=$materialized.ToArray()
    $total = Get-NyxDownloadItemsTotalBytes -Items $Items
    $duplicates = Get-NyxDuplicateCandidates -Files $itemArray -MaxBytes ([int64]$config.scan.duplicateHashMaxBytes) -MaxFiles ([int]$config.scan.duplicateHashMaxFiles) -CancelFile $CancelFile
    $complete=(-not $Cancelled -and $Denied -eq 0)
    $hasOpportunity=($total -ge [int64]$rules.storage.downloadsOptionalBytes -or @($itemArray | Where-Object CleanupCandidate).Count -gt 0)
    $status = if ($hasOpportunity) { 'Optional' } elseif($complete) { 'Good' } else { 'Unknown' }
    $finding = if ($itemArray.Count -eq 0 -and $complete) { 'The Downloads folder is empty.' } elseif($itemArray.Count -eq 0) { 'The Downloads folder could not be checked completely.' } else { "Downloads contains at least $($itemArray.Count) readable file(s) using $(ConvertTo-NyxBytesText $total)." }
    $reason=if($status -eq 'Optional'){'Some readable files are old, large, or installer/archive candidates worth reviewing.'}elseif($status -eq 'Good'){'No notable Downloads cleanup opportunity was found.'}else{'One or more Downloads items could not be read, so Nyx will not report the folder as fully checked.'}
    $errorReason=if($Cancelled){'The Downloads analysis was cancelled.'}elseif($Denied -gt 0){"$Denied Downloads item(s) could not be read."}else{''}
    return New-NyxCheckResult -CheckId 'downloads.analysis' -Category 'Downloads' -Name 'Downloads checkup' -Status $status -Severity 'Low' `
        -Finding $finding -Reason $reason `
        -Evidence ([pscustomobject]@{ Path=$Downloads; TotalBytes=$total; Files=$itemArray; DuplicateGroups=@($duplicates); AccessDenied=$Denied }) `
        -Recommendation 'Review files yourself. Nyx never assumes that an old file is unwanted.' -ActionSafetyLevel 'DestructiveAction' `
        -DataSource 'Top-level Downloads file metadata and bounded SHA-256 duplicate comparison' -Complete $complete -ErrorReason $errorReason -Details ([pscustomobject]@{ Files=$itemArray; DuplicateGroups=@($duplicates) })
}

function Get-NyxDownloadCategory {
    param([System.IO.FileInfo]$File)
    $ext = $File.Extension.ToLowerInvariant()
    if (@('.exe','.msi','.msix','.appx','.appxbundle','.msixbundle') -contains $ext) { return 'Installer' }
    if (@('.zip','.7z','.rar','.tar','.gz','.bz2','.xz') -contains $ext) { return 'Archive' }
    if (@('.doc','.docx','.pdf','.txt','.rtf','.odt','.xls','.xlsx','.ods','.ppt','.pptx','.odp') -contains $ext) { return 'Document' }
    if (@('.jpg','.jpeg','.png','.gif','.bmp','.webp','.tif','.tiff','.heic') -contains $ext) { return 'Image' }
    if (@('.mp4','.mkv','.avi','.mov','.wmv','.webm','.m4v') -contains $ext) { return 'Video' }
    return 'Other'
}

function Get-NyxDuplicateCandidates {
    [CmdletBinding()]
    param([object[]]$Files,[int64]$MaxBytes=268435456,[int]$MaxFiles=500,[string]$CancelFile='')
    $groups = @($Files | Where-Object { $_.SizeBytes -ge 1048576 -and $_.SizeBytes -le $MaxBytes } | Group-Object SizeBytes | Where-Object { $_.Count -gt 1 })
    $hashed = 0
    $map = @{}
    foreach ($group in $groups) {
        foreach ($item in $group.Group) {
            if ($hashed -ge $MaxFiles -or ($CancelFile -and (Test-Path -LiteralPath $CancelFile))) { break }
            try {
                $hash = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256 -ErrorAction Stop).Hash
                if (-not $map.ContainsKey($hash)) { $map[$hash] = [System.Collections.Generic.List[object]]::new() }
                $map[$hash].Add($item); $hashed++
            } catch { }
        }
    }
    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($key in $map.Keys) {
        if ($map[$key].Count -gt 1) {
            $result.Add([pscustomobject]@{ Hash=$key; SizeBytes=[int64]$map[$key][0].SizeBytes; Files=@($map[$key].ToArray()) })
        }
    }
    return @($result.ToArray())
}

function Get-NyxDownloadsAnalysisCheck {
    [CmdletBinding()]
    param([string]$CancelFile='')
    $downloads = Get-NyxDownloadsPath
    if (-not (Test-Path -LiteralPath $downloads -PathType Container)) {
        return New-NyxUnknownResult -CheckId 'downloads.analysis' -Category 'Downloads' -Name 'Downloads checkup' -Reason 'The Downloads folder was not found.' -DataSource 'Windows known folder / file system'
    }
    try { $downloadsInfo=Get-Item -LiteralPath $downloads -Force -ErrorAction Stop } catch { return New-NyxUnknownResult -CheckId 'downloads.analysis' -Category 'Downloads' -Name 'Downloads checkup' -Reason $_.Exception.Message -DataSource 'Windows known folder / file system' }
    if (Test-NyxReparsePoint -Item $downloadsInfo) { return New-NyxUnknownResult -CheckId 'downloads.analysis' -Category 'Downloads' -Name 'Downloads checkup' -Reason 'The Downloads folder is a junction or symbolic link and was not followed.' -DataSource 'Windows known folder / file system' }
    $rules = Get-NyxRules
    $config = Get-NyxConfiguration
    $items = [System.Collections.Generic.List[object]]::new()
    $denied = 0
    $cancelled = $false
    try {
        foreach ($path in [IO.Directory]::EnumerateFiles($downloads,'*',[IO.SearchOption]::TopDirectoryOnly)) {
            if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { $cancelled=$true; break }
            try {
                $f = [IO.FileInfo]::new($path)
                if (Test-NyxReparsePoint -Item $f) { continue }
                $age = [int][math]::Floor(((Get-Date).ToUniversalTime() - $f.LastWriteTimeUtc).TotalDays)
                $category = Get-NyxDownloadCategory -File $f
                $items.Add([pscustomobject]@{
                    Path=$f.FullName; Name=$f.Name; Category=$category; SizeBytes=[int64]$f.Length; AgeDays=$age;
                    OlderThan30Days=($age -ge [int]$rules.downloads.oldDays);
                    OlderThan90Days=($age -ge [int]$rules.downloads.veryOldDays);
                    OlderThanOneYear=($age -ge [int]$rules.downloads.yearDays);
                    LargerThan100MB=($f.Length -ge [int64]$rules.downloads.largeBytes);
                    LargerThan1GB=($f.Length -ge [int64]$rules.downloads.veryLargeBytes);
                    CleanupCandidate=(($category -eq 'Installer' -and $age -ge [int]$rules.downloads.installerOldDays) -or ($category -eq 'Archive' -and $age -ge [int]$rules.downloads.archiveOldDays))
                })
            } catch { $denied++ }
        }
    } catch {
        return New-NyxUnknownResult -CheckId 'downloads.analysis' -Category 'Downloads' -Name 'Downloads checkup' -Reason $_.Exception.Message -DataSource 'File system'
    }
    return New-NyxDownloadsAnalysisResult -Downloads $downloads -Items $items -Denied $denied -Cancelled $cancelled -CancelFile $CancelFile
}

Export-ModuleMember -Function Get-NyxDownloadCategory,Get-NyxDuplicateCandidates,Get-NyxDownloadsAnalysisCheck

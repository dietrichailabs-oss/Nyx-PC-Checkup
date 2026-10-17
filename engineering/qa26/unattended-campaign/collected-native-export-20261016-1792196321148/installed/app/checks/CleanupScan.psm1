Set-StrictMode -Version 2.0
function Get-NyxCleanupItemsTotalBytes {
    param([System.Collections.IEnumerable]$Items)
    [int64]$total=0
    if($null -eq $Items){return $total}
    foreach($item in $Items){
        if($null -eq $item){continue}
        $size=[int64]$item.SizeBytes
        if($size -lt 0){throw 'Cleanup candidate size cannot be negative.'}
        if($total -gt ([int64]::MaxValue - $size)){throw 'Cleanup candidate byte total exceeds the supported Int64 range.'}
        $total += $size
    }
    return $total
}

function New-NyxCleanupCandidate {
    param([string]$Path,[string]$Category,[string]$Reason,[int64]$SizeBytes,[int]$AgeDays,[string]$LastWriteUtc='',[bool]$SelectedByDefault=$false,[string]$Kind='File')
    # Identity includes the displayed metadata so a file replaced or changed
    # after preview cannot be deleted under a stale confirmation.
    $identity="cleanup|{0}|{1}|{2}|{3}|{4}" -f $Category,$Path.ToLowerInvariant(),$SizeBytes,$LastWriteUtc,$Kind
    return [pscustomobject][ordered]@{
        Id=Get-NyxStableId -Text $identity; Path=$Path; Name=$(if ($Kind -eq 'Special') { $Path } else { [IO.Path]::GetFileName($Path) });
        Category=$Category; Reason=$Reason; SizeBytes=$SizeBytes; AgeDays=$AgeDays; LastWriteUtc=$LastWriteUtc; SelectedByDefault=$SelectedByDefault; Kind=$Kind
    }
}

function Get-NyxRecycleBinSummary {
    $size=[int64]0; $count=0
    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.Namespace(10)
        foreach ($item in @($folder.Items())) { try { $size += [int64]$item.Size; $count++ } catch { } }
        [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) | Out-Null
    } catch { return [pscustomobject]@{ Available=$false; Bytes=0; Count=0 } }
    return [pscustomobject]@{ Available=$true; Bytes=$size; Count=$count }
}

function Get-NyxCleanupStopReason {
    param(
        [string]$CancelFile,
        [int]$CandidateCount,
        [int]$CandidateLimit,
        [int]$VisitedFiles,
        [int]$MaxVisitedFiles,
        [Diagnostics.Stopwatch]$Stopwatch,
        [int]$MaxSeconds
    )
    if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { return 'Cancelled' }
    if ($CandidateCount -ge $CandidateLimit) { return 'CandidateLimit' }
    if ($VisitedFiles -ge $MaxVisitedFiles) { return 'VisitedFileLimit' }
    if ($Stopwatch.Elapsed.TotalSeconds -ge $MaxSeconds) { return 'TimeLimit' }
    return ''
}

function Get-NyxCleanupCandidates {
    [CmdletBinding()]
    param(
        [string]$CancelFile='',
        [ValidateRange(1,50000)][int]$Limit=5000,
        [ValidateRange(1,1000000)][int]$MaxVisitedFiles=100000,
        [ValidateRange(1,600)][int]$MaxSeconds=30
    )
    $items = [System.Collections.Generic.List[object]]::new()
    $now = (Get-Date).ToUniversalTime()
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $visitedFiles=0
    $accessDenied=0
    $stopReason=''
    $tempRoots = @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp')) | Where-Object { $_ } | Select-Object -Unique

    foreach ($root in $tempRoots) {
        $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
        if ($stopReason) { break }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $rootInfo=$null
        try { $rootInfo=Get-Item -LiteralPath $root -Force -ErrorAction Stop } catch { $accessDenied++; continue }
        if ($null -eq $rootInfo -or (Test-NyxReparsePoint -Item $rootInfo)) { $accessDenied++; continue }
        $stack=New-Object 'System.Collections.Generic.Stack[string]'
        $stack.Push([string]$rootInfo.FullName)
        while ($stack.Count -gt 0) {
            $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
            if ($stopReason) { break }
            $current=$stack.Pop()
            try {
                foreach ($path in [IO.Directory]::EnumerateFiles($current)) {
                    $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
                    if ($stopReason) { break }
                    $visitedFiles++
                    try {
                        $f=[IO.FileInfo]::new($path)
                        if (Test-NyxReparsePoint -Item $f) { continue }
                        $age=[int][math]::Floor(($now-$f.LastWriteTimeUtc).TotalDays)
                        if ($age -ge 1) {
                            $items.Add((New-NyxCleanupCandidate -Path $f.FullName -Category 'User temporary files' -Reason 'Temporary file older than one day.' -SizeBytes $f.Length -AgeDays $age -LastWriteUtc ($f.LastWriteTimeUtc.ToString('o')) -SelectedByDefault $false))
                        }
                    } catch { $accessDenied++ }
                }
                if ($stopReason) { break }
                foreach ($dirPath in [IO.Directory]::EnumerateDirectories($current)) {
                    $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
                    if ($stopReason) { break }
                    try {
                        $dir=[IO.DirectoryInfo]::new($dirPath)
                        if (-not (Test-NyxReparsePoint -Item $dir)) { $stack.Push($dir.FullName) }
                    } catch { $accessDenied++ }
                }
            } catch { $accessDenied++ }
        }
        if ($stopReason) { break }
    }

    $downloads = Get-NyxDownloadsPath
    if (-not $stopReason -and (Test-Path -LiteralPath $downloads -PathType Container)) {
        try {
            $downloadsInfo=Get-Item -LiteralPath $downloads -Force -ErrorAction Stop
            if (Test-NyxReparsePoint -Item $downloadsInfo) { throw 'The Downloads folder is a reparse point and was not followed.' }
            foreach ($path in [IO.Directory]::EnumerateFiles($downloadsInfo.FullName,'*',[IO.SearchOption]::TopDirectoryOnly)) {
                $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
                if ($stopReason) { break }
                $visitedFiles++
                try {
                    $f=[IO.FileInfo]::new($path)
                    if (Test-NyxReparsePoint -Item $f) { continue }
                    $age=[int][math]::Floor(($now-$f.LastWriteTimeUtc).TotalDays)
                    $cat=Get-NyxDownloadCategory -File $f
                    if ($cat -eq 'Installer' -and $age -ge 30) {
                        $items.Add((New-NyxCleanupCandidate -Path $f.FullName -Category 'Old installer in Downloads' -Reason 'Installer is at least 30 days old; keep it if you still need it.' -SizeBytes $f.Length -AgeDays $age -LastWriteUtc ($f.LastWriteTimeUtc.ToString('o')) -SelectedByDefault $false))
                    } elseif ($cat -eq 'Archive' -and $age -ge 90) {
                        $items.Add((New-NyxCleanupCandidate -Path $f.FullName -Category 'Old archive in Downloads' -Reason 'Archive is at least 90 days old; age does not mean unwanted.' -SizeBytes $f.Length -AgeDays $age -LastWriteUtc ($f.LastWriteTimeUtc.ToString('o')) -SelectedByDefault $false))
                    }
                } catch { $accessDenied++ }
            }
        } catch { $accessDenied++ }
    }

    if (-not $stopReason) {
        $recycle = Get-NyxRecycleBinSummary
        if ($recycle.Available -and $recycle.Count -gt 0 -and $items.Count -lt $Limit) {
            $items.Add((New-NyxCleanupCandidate -Path 'Recycle Bin' -Category 'Recycle Bin' -Reason 'Items already placed in the Windows Recycle Bin.' -SizeBytes $recycle.Bytes -AgeDays 0 -LastWriteUtc '' -SelectedByDefault $false -Kind 'Special'))
        }
    }

    $watch.Stop()
    if (-not $stopReason) {
        $stopReason=Get-NyxCleanupStopReason -CancelFile $CancelFile -CandidateCount $items.Count -CandidateLimit $Limit -VisitedFiles $visitedFiles -MaxVisitedFiles $MaxVisitedFiles -Stopwatch $watch -MaxSeconds $MaxSeconds
    }
    $total=Get-NyxCleanupItemsTotalBytes -Items $items
    $limited=$stopReason -in @('CandidateLimit','VisitedFileLimit','TimeLimit')
    $cancelled=$stopReason -eq 'Cancelled'
    $complete=(-not $limited -and -not $cancelled -and $accessDenied -eq 0)
    $reason=switch($stopReason){
        'CandidateLimit' { "The preview reached its $Limit-item candidate safety limit." }
        'VisitedFileLimit' { "The preview reached its $MaxVisitedFiles-file traversal safety limit." }
        'TimeLimit' { "The preview reached its $MaxSeconds-second traversal safety limit." }
        'Cancelled' { 'The cleanup preview was cancelled.' }
        default { if($accessDenied -gt 0){"$accessDenied file-system location(s) could not be read."}else{''} }
    }
    if($reason -and $accessDenied -gt 0 -and $stopReason){$reason += " $accessDenied additional location(s) could not be read."}
    return [pscustomobject][ordered]@{
        Candidates=@($items.ToArray()); TotalBytes=$total; Limited=$limited; Limit=$Limit; VisitedFiles=$visitedFiles;
        MaxVisitedFiles=$MaxVisitedFiles; ElapsedMilliseconds=[int64]$watch.ElapsedMilliseconds; MaxSeconds=$MaxSeconds;
        AccessDeniedCount=$accessDenied; Cancelled=$cancelled; Complete=$complete; LimitReason=$stopReason; IncompleteReason=$reason
    }
}

function Get-NyxCleanupPreviewCheck {
    [CmdletBinding()]
    param([string]$CancelFile='')
    $scan=Get-NyxCleanupCandidates -CancelFile $CancelFile
    $status=if ($scan.Candidates.Count -gt 0) { 'Optional' } elseif(-not $scan.Complete) { 'Unknown' } else { 'Good' }
    $reason=if($scan.IncompleteReason){
        $scan.IncompleteReason+' Only the displayed, revalidated items can be selected.'
    }else{
        'Only user temporary files, selected old installers/archives, and the Recycle Bin are included.'
    }
    return New-NyxCheckResult -CheckId 'cleanup.preview' -Category 'Cleanup' -Name 'Safe cleanup preview' -Status $status -Severity 'Low' `
        -Finding $(if ($scan.Candidates.Count -gt 0) { "$($scan.Candidates.Count) optional item(s) totaling $(ConvertTo-NyxBytesText $scan.TotalBytes) are available for review." } elseif(-not $scan.Complete) { 'The supported cleanup locations could not be checked completely.' } else { 'No supported cleanup candidates were found.' }) `
        -Reason $reason -Evidence $scan -Recommendation 'Nothing is selected automatically. Review each item and confirm before moving files to the Recycle Bin or emptying it.' `
        -ActionSafetyLevel 'DestructiveAction' -DataSource 'User temp, top-level Downloads metadata, and Recycle Bin shell view' -Complete ([bool]$scan.Complete) -ErrorReason ([string]$scan.IncompleteReason) -Details $scan
}

Export-ModuleMember -Function New-NyxCleanupCandidate,Get-NyxRecycleBinSummary,Get-NyxCleanupCandidates,Get-NyxCleanupPreviewCheck

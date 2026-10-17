Set-StrictMode -Version 2.0
function Get-NyxTopFiles {
    [CmdletBinding()]
    param([string[]]$Roots,[string]$CancelFile='',[int]$MaxFiles=1000000,[int]$MaxSeconds=180,[int]$Limit=50)
    $items = [System.Collections.Generic.List[object]]::new()
    $count = 0
    $denied = 0
    $complete = $true
    $halted = $false
    $cancelled = $false
    $started = Get-Date
    foreach ($root in $Roots) {
        if($halted){break}
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { $complete=$false;continue }
        try { $rootInfo=Get-Item -LiteralPath $root -Force -ErrorAction Stop } catch { $denied++;$complete=$false;continue }
        if (Test-NyxReparsePoint -Item $rootInfo) { $denied++;$complete=$false;continue }
        $stack = New-Object 'System.Collections.Generic.Stack[string]'
        $stack.Push($rootInfo.FullName)
        while ($stack.Count -gt 0 -and -not $halted) {
            if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { $complete=$false;$cancelled=$true;$halted=$true;break }
            if ($count -ge $MaxFiles -or ((Get-Date)-$started).TotalSeconds -ge $MaxSeconds) { $complete=$false;$halted=$true;break }
            $dir = $stack.Pop()
            try {
                foreach ($filePath in [IO.Directory]::EnumerateFiles($dir)) {
                    if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { $complete=$false;$cancelled=$true;$halted=$true;break }
                    try {
                        $f = [IO.FileInfo]::new($filePath)
                        if (Test-NyxReparsePoint -Item $f) { continue }
                        $items.Add([pscustomobject]@{ Path=$f.FullName; SizeBytes=[int64]$f.Length; ModifiedUtc=$f.LastWriteTimeUtc.ToString('o'); Extension=$f.Extension.ToLowerInvariant() })
                        $count++
                        if ($items.Count -gt ($Limit * 4)) {
                            $trimmed = @($items | Sort-Object SizeBytes -Descending | Select-Object -First ($Limit * 2))
                            $items.Clear(); foreach ($x in $trimmed) { $items.Add($x) }
                        }
                    } catch { $denied++;$complete=$false }
                    if ($count -ge $MaxFiles -or ((Get-Date)-$started).TotalSeconds -ge $MaxSeconds) { $complete=$false;$halted=$true;break }
                }
                if ($halted) { break }
                foreach ($subPath in [IO.Directory]::EnumerateDirectories($dir)) {
                    try {
                        $sub = [IO.DirectoryInfo]::new($subPath)
                        if (-not (Test-NyxReparsePoint -Item $sub)) { $stack.Push($subPath) }
                    } catch { $denied++;$complete=$false }
                }
            } catch { $denied++;$complete=$false }
        }
    }
    $reason=if($cancelled){'Scan was cancelled.'}elseif($halted){'Scan reached its file-count or time safety limit.'}elseif($denied -gt 0){"$denied file-system location(s) could not be read."}else{''}
    return [pscustomobject]@{ Items=@($items | Sort-Object SizeBytes -Descending | Select-Object -First $Limit); FilesScanned=$count; AccessDenied=$denied; Complete=$complete; Reason=$reason }
}

function Get-NyxStorageScanCheck {
    [CmdletBinding()]
    param([string]$CancelFile='')
    $config = Get-NyxConfiguration
    $profilePath=$env:USERPROFILE
    if([string]::IsNullOrWhiteSpace($profilePath)){$profilePath=[Environment]::GetFolderPath('UserProfile')}
    $folders = [ordered]@{
        Downloads = Get-NyxDownloadsPath
        Desktop = [Environment]::GetFolderPath('Desktop')
        Documents = [Environment]::GetFolderPath('MyDocuments')
        Pictures = [Environment]::GetFolderPath('MyPictures')
        Videos = [Environment]::GetFolderPath('MyVideos')
    }
    $profileScan=Get-NyxFolderSize -Path $profilePath -CancelFile $CancelFile -MaxFiles ([int]$config.scan.maxFiles) -MaxSeconds ([int]$config.scan.maxSeconds)
    $profileResult=[pscustomobject]@{Name='User profile';Path=$profilePath;Bytes=$profileScan.Bytes;Files=$profileScan.Files;Complete=$profileScan.Complete;AccessDenied=$profileScan.AccessDenied}
    $folderResults = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $folders.GetEnumerator()) {
        if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { break }
        $scan = Get-NyxFolderSize -Path $entry.Value -CancelFile $CancelFile -MaxFiles ([int]$config.scan.maxFiles) -MaxSeconds ([int]$config.scan.maxSeconds)
        $folderResults.Add([pscustomobject]@{ Name=$entry.Key; Path=$entry.Value; Bytes=$scan.Bytes; Files=$scan.Files; Complete=$scan.Complete; AccessDenied=$scan.AccessDenied })
    }
    $top = Get-NyxTopFiles -Roots @($folders.Values) -CancelFile $CancelFile -MaxFiles ([int]$config.scan.maxFiles) -MaxSeconds ([int]$config.scan.maxSeconds) -Limit 50
    $largest = @($folderResults | Sort-Object Bytes -Descending | Select-Object -First 1)
    $complete = [bool]$profileResult.Complete -and @($folderResults | Where-Object { -not $_.Complete }).Count -eq 0 -and $top.Complete
    if(-not [string]::IsNullOrWhiteSpace($profilePath) -and [int64]$profileResult.Bytes -gt 0){
        $finding="The checked user profile uses $(ConvertTo-NyxBytesText $profileResult.Bytes)."
        if($largest.Count -gt 0){$finding+=" The largest named user folder is $($largest[0].Name) at $(ConvertTo-NyxBytesText $largest[0].Bytes)."}
    }elseif($largest.Count -gt 0){$finding="The largest checked user folder is $($largest[0].Name) at $(ConvertTo-NyxBytesText $largest[0].Bytes). User-profile total size was unavailable."}
    else{$finding='No user folders could be measured.'}
    $status = if ($complete) { 'Good' } else { 'Unknown' }
    return New-NyxCheckResult -CheckId 'storage.user-folders' -Category 'Storage' -Name 'User profile, folders, and largest files' `
        -Status $status -Severity 'Info' -Finding $finding `
        -Reason $(if ($complete) { 'The user profile and selected user folders were measured without following junctions or symbolic links.' } else { 'Some profile data could not be fully measured, the scan was cancelled, or a safety limit was reached.' }) `
        -Evidence ([pscustomobject]@{ UserProfile=$profileResult; Folders=@($folderResults.ToArray()); LargestFiles=@($top.Items); FilesScanned=$top.FilesScanned; AccessDenied=([int]$profileResult.AccessDenied+[int]$top.AccessDenied) }) `
        -Recommendation 'Review large items before deciding whether anything should be moved or removed. Old or large does not mean unwanted.' `
        -ActionSafetyLevel 'None' -DataSource '.NET file-system enumeration' -Complete $complete -Details ([pscustomobject]@{ UserProfile=$profileResult; Folders=@($folderResults.ToArray()); LargestFiles=@($top.Items) })
}

Export-ModuleMember -Function Get-NyxTopFiles,Get-NyxStorageScanCheck

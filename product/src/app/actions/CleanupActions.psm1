Set-StrictMode -Version 2.0
function Get-NyxCleanupRootsForCategory {
    param([Parameter(Mandatory=$true)][string]$Category)
    switch($Category){
        'User temporary files' {
            return @($env:TEMP,(Join-Path $env:LOCALAPPDATA 'Temp')) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique
        }
        'Old installer in Downloads' { return @(Get-NyxDownloadsPath) }
        'Old archive in Downloads' { return @(Get-NyxDownloadsPath) }
        default { return @() }
    }
}

function Test-NyxPathInsideRoot {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Root,[switch]$DirectChildOnly)
    $trimChars=[char[]]@('\','/')
    $full=[IO.Path]::GetFullPath($Path)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd($trimChars)
    $parent=[IO.Path]::GetDirectoryName($full).TrimEnd($trimChars)
    if($DirectChildOnly){return [string]::Equals($parent,$rootFull,[StringComparison]::OrdinalIgnoreCase)}
    if([string]::Equals($parent,$rootFull,[StringComparison]::OrdinalIgnoreCase)){return $true}
    $prefix=$rootFull+[IO.Path]::DirectorySeparatorChar
    return $parent.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
}

function Assert-NyxCleanupParentChain {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Root)
    $trimChars=[char[]]@('\','/')
    $full=[IO.Path]::GetFullPath($Path)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd($trimChars)
    $rootItem=Get-Item -LiteralPath $rootFull -Force -ErrorAction Stop
    if(-not $rootItem.PSIsContainer -or (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The approved cleanup root is not an ordinary local folder.'}
    $parent=[IO.Path]::GetDirectoryName($full).TrimEnd($trimChars)
    if(-not(Test-NyxPathInsideRoot -Path $full -Root $rootFull)){throw 'The cleanup item is outside its approved local root.'}
    if([string]::Equals($parent,$rootFull,[StringComparison]::OrdinalIgnoreCase)){return $true}
    $relative=$parent.Substring($rootFull.Length).TrimStart($trimChars)
    $current=$rootFull
    foreach($segment in $relative.Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries)){
        $current=Join-Path $current $segment
        $part=Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if(-not $part.PSIsContainer -or (($part.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'A parent folder became a junction or symbolic link. The file was preserved.'}
    }
    return $true
}

function Get-NyxValidatedCleanupFile {
    param([Parameter(Mandatory=$true)][object]$Candidate)
    if([string]$Candidate.Kind -ne 'File'){throw 'Only ordinary files from the displayed allowlist are eligible for this cleanup action.'}
    $roots=@(Get-NyxCleanupRootsForCategory -Category ([string]$Candidate.Category))
    if($roots.Count -eq 0){throw 'The cleanup category is outside the Nyx destructive-action allowlist.'}
    $path=[IO.Path]::GetFullPath([string]$Candidate.Path)
    $matched=$null
    foreach($root in $roots){
        if([string]::IsNullOrWhiteSpace([string]$root)){continue}
        $direct=[string]$Candidate.Category -in @('Old installer in Downloads','Old archive in Downloads')
        if(Test-NyxPathInsideRoot -Path $path -Root ([string]$root) -DirectChildOnly:$direct){$matched=[string]$root;break}
    }
    if($null -eq $matched){throw 'The cleanup item is outside its approved local root.'}
    [void](Assert-NyxCleanupParentChain -Path $path -Root $matched)
    $info=Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if($info.PSIsContainer -or (($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'Reparse points and directories are not eligible for cleanup.'}
    return [pscustomobject]@{Info=$info;Root=$matched}
}

function Invoke-NyxCleanup {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string[]]$CandidateIds,[switch]$Confirmed)
    if (-not $Confirmed) { return [pscustomobject]@{ Success=$false; Status='ConfirmationRequired'; Message='Cleanup requires explicit confirmation.'; Items=@() } }
    if ($CandidateIds.Count -eq 0) { return [pscustomobject]@{ Success=$false; Status='NoSelection'; Message='No cleanup items were selected.'; Items=@() } }
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
    $fresh=Get-NyxCleanupCandidates -Limit 5000 -MaxVisitedFiles 100000 -MaxSeconds 30
    $allowed=@{}
    foreach ($item in $fresh.Candidates) { $allowed[[string]$item.Id]=$item }
    $results=[System.Collections.Generic.List[object]]::new()
    $bytes=[int64]0
    foreach ($id in $CandidateIds | Select-Object -Unique) {
        if (-not $allowed.ContainsKey([string]$id)) { $results.Add([pscustomobject]@{ Id=$id; Success=$false; Message='The item changed or is no longer an approved cleanup candidate.' }); continue }
        $item=$allowed[[string]$id]
        try {
            if ($item.Kind -eq 'Special' -and $item.Category -eq 'Recycle Bin') {
                Clear-RecycleBin -Force -ErrorAction Stop
            } else {
                $validated=Get-NyxValidatedCleanupFile -Candidate $item
                $info=$validated.Info
                $currentWrite=$info.LastWriteTimeUtc.ToString('o')
                if([int64]$info.Length -ne [int64]$item.SizeBytes -or $currentWrite -ne [string]$item.LastWriteUtc){throw 'The item changed after cleanup revalidation. It was preserved.'}
                # Revalidate the complete parent chain immediately before the
                # destructive operation so a replaced parent junction is not followed.
                $validated=Get-NyxValidatedCleanupFile -Candidate $item
                $info=$validated.Info
                $currentWrite=$info.LastWriteTimeUtc.ToString('o')
                if([int64]$info.Length -ne [int64]$item.SizeBytes -or $currentWrite -ne [string]$item.LastWriteUtc){throw 'The item changed after cleanup revalidation. It was preserved.'}
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($info.FullName,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
            }
            $bytes += [int64]$item.SizeBytes
            $results.Add([pscustomobject]@{ Id=$id; Success=$true; Name=[string]$item.Name; Category=[string]$item.Category; SizeBytes=[int64]$item.SizeBytes; Message='Completed' })
        } catch {
            $results.Add([pscustomobject]@{ Id=$id; Success=$false; Name=[string]$item.Name; Category=[string]$item.Category; SizeBytes=0; Message=$_.Exception.Message })
        }
    }
    $ok=@($results | Where-Object Success).Count
    $failed=@($results | Where-Object { -not $_.Success }).Count
    $actionId=[guid]::NewGuid().ToString('N')
    Add-NyxActionHistory -Action ([pscustomobject][ordered]@{
        ActionId=$actionId; ActionType='Cleanup'; RelatedActionId=''; Success=($failed -eq 0); DisplayName="Cleanup: $ok completed, $failed failed";
        DisplaySource='Recycle Bin / explicitly selected items'; UndoAvailable=$false; ProtectedState=''; BytesProcessed=$bytes;
        Timestamp=(Get-Date).ToUniversalTime().ToString('o')
    })
    Write-NyxLog -Level 'INFO' -Message ("Cleanup action {0}: {1} completed, {2} failed, {3} bytes." -f $actionId,$ok,$failed,$bytes)
    return [pscustomobject][ordered]@{ Success=($failed -eq 0); Status=$(if ($failed -eq 0) {'Completed'} elseif ($ok -gt 0) {'Partial'} else {'Failed'}); Message="$ok item(s) completed; $failed failed."; ActionId=$actionId; BytesProcessed=$bytes; Items=@($results.ToArray()) }
}

Export-ModuleMember -Function Invoke-NyxCleanup

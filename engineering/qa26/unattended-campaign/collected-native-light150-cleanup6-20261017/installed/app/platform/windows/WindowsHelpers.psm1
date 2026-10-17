Set-StrictMode -Version 2.0

function Test-NyxWindowsPlatform {
    return ($env:OS -eq 'Windows_NT')
}

function ConvertTo-NyxBytesText {
    [CmdletBinding()]
    param([int64]$Bytes)
    if ($Bytes -lt 0) { return 'Unknown' }
    $units = @('B','KB','MB','GB','TB','PB')
    $value = [double]$Bytes
    $index = 0
    while ($value -ge 1024 -and $index -lt $units.Count - 1) { $value /= 1024; $index++ }
    if ($index -eq 0) { return ("{0} {1}" -f [int64]$value,$units[$index]) }
    return ("{0:N1} {1}" -f $value,$units[$index])
}

function Get-NyxStableId {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0,24)
    } finally { $sha.Dispose() }
}

function Get-NyxDownloadsPath {
    try {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
        $value = (Get-ItemProperty -LiteralPath $key -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}'
        return [Environment]::ExpandEnvironmentVariables([string]$value)
    } catch {
        return (Join-Path $env:USERPROFILE 'Downloads')
    }
}

function Test-NyxReparsePoint {
    param([Parameter(Mandatory=$true)][System.IO.FileSystemInfo]$Item)
    return (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Get-NyxSystemDriveInfo {
    $root = [IO.Path]::GetPathRoot($env:SystemRoot)
    return [IO.DriveInfo]::new($root)
}

function Get-NyxRestartPending {
    $pending = $false
    $sources = [System.Collections.Generic.List[string]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    foreach ($key in $keys) {
        try { if (Test-Path -LiteralPath $key -ErrorAction Stop) { $pending = $true; $sources.Add($key) } } catch { $errors.Add($_.Exception.Message) }
    }
    try {
        $session = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop
        if ($session.PendingFileRenameOperations) { $pending = $true; $sources.Add('PendingFileRenameOperations') }
    } catch [System.Management.Automation.PSArgumentException] {
        # The value not existing is an ordinary "not pending" result.
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch { $errors.Add($_.Exception.Message) }
    return [pscustomobject]@{ Pending=$pending; Sources=@($sources.ToArray()); Complete=($errors.Count -eq 0); Errors=@($errors.ToArray()) }
}

function Get-NyxFolderSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$CancelFile = '',
        [int]$MaxFiles = 1000000,
        [int]$MaxSeconds = 180
    )
    $size = [int64]0
    $count = 0
    $denied = 0
    $complete = $true
    $halted = $false
    $cancelled = $false
    $started = Get-Date
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return [pscustomobject]@{ Path=$Path; Bytes=0; Files=0; AccessDenied=0; Complete=$false; Reason='Folder does not exist.' }
    }
    try {
        $rootItem=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if (Test-NyxReparsePoint -Item $rootItem) { return [pscustomobject]@{ Path=$Path; Bytes=0; Files=0; AccessDenied=0; Complete=$false; Reason='The folder root is a junction or symbolic link and was not followed.' } }
    } catch { return [pscustomobject]@{ Path=$Path; Bytes=0; Files=0; AccessDenied=1; Complete=$false; Reason=$_.Exception.Message } }
    $stack = New-Object 'System.Collections.Generic.Stack[string]'
    $stack.Push($rootItem.FullName)
    while ($stack.Count -gt 0 -and -not $halted) {
        if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { $complete=$false;$cancelled=$true;$halted=$true;break }
        if ($count -ge $MaxFiles -or ((Get-Date) - $started).TotalSeconds -ge $MaxSeconds) { $complete=$false;$halted=$true;break }
        $current = $stack.Pop()
        try {
            foreach ($filePath in [IO.Directory]::EnumerateFiles($current)) {
                if ($CancelFile -and (Test-Path -LiteralPath $CancelFile)) { $complete=$false;$cancelled=$true;$halted=$true;break }
                try {
                    $info = [IO.FileInfo]::new($filePath)
                    if (-not (Test-NyxReparsePoint -Item $info)) { $size += $info.Length; $count++ }
                } catch { $denied++;$complete=$false }
                if ($count -ge $MaxFiles -or ((Get-Date) - $started).TotalSeconds -ge $MaxSeconds) { $complete=$false;$halted=$true;break }
            }
            if ($halted) { break }
            foreach ($dirPath in [IO.Directory]::EnumerateDirectories($current)) {
                try {
                    $dir = [IO.DirectoryInfo]::new($dirPath)
                    if (-not (Test-NyxReparsePoint -Item $dir)) { $stack.Push($dirPath) }
                } catch { $denied++;$complete=$false }
            }
        } catch { $denied++;$complete=$false }
    }
    $reason=if($cancelled){'Scan was cancelled.'}elseif($halted){'Scan reached its file-count or time safety limit.'}elseif($denied -gt 0){"$denied file-system location(s) could not be read."}else{''}
    return [pscustomobject]@{ Path=$Path; Bytes=$size; Files=$count; AccessDenied=$denied; Complete=$complete; Reason=$reason }
}

function Get-NyxWindowsEdition {
    try {
        $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop|Select-Object -First 1
        if(-not [string]::IsNullOrWhiteSpace([string]$os.Caption)){return [string]$os.Caption}
    } catch { }
    try {
        $current=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $name=[string]$current.ProductName
        $edition=[string]$current.EditionID
        if ($name -and $edition) { return "$name ($edition)" }
        return $name
    } catch { return '' }
}

Export-ModuleMember -Function Test-NyxWindowsPlatform,ConvertTo-NyxBytesText,Get-NyxStableId,Get-NyxDownloadsPath,Test-NyxReparsePoint,Get-NyxSystemDriveInfo,Get-NyxRestartPending,Get-NyxFolderSize,Get-NyxWindowsEdition

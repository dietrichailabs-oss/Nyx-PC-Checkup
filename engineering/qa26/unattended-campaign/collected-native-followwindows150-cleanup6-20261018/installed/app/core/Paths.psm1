Set-StrictMode -Version 2.0

function Get-NyxDataRoot {
    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = [Environment]::GetFolderPath('LocalApplicationData')
    }
    if ([string]::IsNullOrWhiteSpace($base)) { throw 'Windows did not provide a local application-data folder.' }
    return (Join-Path $base 'Dietrich AI Labs\Nyx PC Checkup')
}

function Get-NyxPathMap {
    $root = Get-NyxDataRoot
    return [pscustomobject][ordered]@{
        Root = $root
        Config = Join-Path $root 'config.json'
        Logs = Join-Path $root 'logs'
        Scans = Join-Path $root 'scans'
        Actions = Join-Path $root 'actions'
        ActionHistory = Join-Path $root 'actions\history.jsonl'
        DisabledStartup = Join-Path $root 'actions\disabled-startup'
        Reports = Join-Path $root 'reports'
        Temp = Join-Path $root 'temp'
        LastScan = Join-Path $root 'scans\last-scan.json'
    }
}

function Assert-NyxOrdinaryDataDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw "The Nyx local-data path is not a directory: $Path" }
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "The Nyx local-data directory cannot be a junction or symbolic link: $Path"
    }
    return $item
}

function Initialize-NyxDataDirectories {
    $paths = Get-NyxPathMap
    @($paths.Root,$paths.Logs,$paths.Scans,$paths.Actions,$paths.DisabledStartup,$paths.Reports,$paths.Temp) | ForEach-Object {
        if (-not (Test-Path -LiteralPath $_)) {
            New-Item -ItemType Directory -Path $_ -Force -ErrorAction Stop | Out-Null
        }
        [void](Assert-NyxOrdinaryDataDirectory -Path $_)
    }
    return $paths
}


function Remove-NyxTemporaryArtifacts {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Path = @()
    )

    # Optional UI/acceptance cleanup is intentionally best-effort, but it is
    # also fail-closed: only ordinary files with known Nyx temporary names in
    # the exact per-user Nyx temp directory are eligible for deletion.
    $result = [ordered]@{
        Removed = 0
        Missing = 0
        EmptySkipped = 0
        UnsafeRejected = 0
        Failed = 0
        TempRoot = ''
    }

    $tempFull = ''
    try {
        $map = Get-NyxPathMap
        if ($null -eq $map -or [string]::IsNullOrWhiteSpace([string]$map.Temp)) {
            $result.Failed++
            return [pscustomobject]$result
        }
        $tempFull = [IO.Path]::GetFullPath([string]$map.Temp).TrimEnd('\')
        $result.TempRoot = $tempFull
        if (-not (Test-Path -LiteralPath $tempFull -PathType Container)) {
            foreach ($candidate in @($Path)) {
                if ($null -eq $candidate -or [string]::IsNullOrWhiteSpace([string]$candidate)) { $result.EmptySkipped++ }
                else { $result.Missing++ }
            }
            return [pscustomobject]$result
        }
        $tempItem = Get-Item -LiteralPath $tempFull -Force -ErrorAction Stop
        if (-not $tempItem.PSIsContainer -or (($tempItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            $result.UnsafeRejected += @($Path).Count
            return [pscustomobject]$result
        }
    } catch {
        $result.Failed++
        return [pscustomobject]$result
    }

    $allowedName = '^(?:scan-[a-f0-9]{32}(?:-progress\.jsonl|\.json|\.cancel)|update-[a-f0-9]{32}-result\.json|action-[a-f0-9]{32}-(?:request|result)\.json)$'
    foreach ($candidate in @($Path)) {
        if ($null -eq $candidate -or [string]::IsNullOrWhiteSpace([string]$candidate)) {
            $result.EmptySkipped++
            continue
        }
        try {
            $full = [IO.Path]::GetFullPath([string]$candidate)
            $parent = [IO.Path]::GetDirectoryName($full).TrimEnd('\')
            $name = [IO.Path]::GetFileName($full)
            if (-not [string]::Equals($parent,$tempFull,[StringComparison]::OrdinalIgnoreCase) -or $name -notmatch $allowedName) {
                $result.UnsafeRejected++
                continue
            }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                $result.Missing++
                continue
            }
            $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
            if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                $result.UnsafeRejected++
                continue
            }
            Remove-Item -LiteralPath $full -Force -ErrorAction Stop
            $result.Removed++
        } catch {
            $result.Failed++
        }
    }
    return [pscustomobject]$result
}

function Get-NyxInstallRoot {
    param([string]$ScriptRoot)
    return (Resolve-Path (Join-Path $ScriptRoot '..\..')).Path
}

Export-ModuleMember -Function Get-NyxDataRoot,Get-NyxPathMap,Assert-NyxOrdinaryDataDirectory,Initialize-NyxDataDirectories,Remove-NyxTemporaryArtifacts,Get-NyxInstallRoot

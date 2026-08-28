Set-StrictMode -Version 2.0
function Get-NyxCurrentUserSid {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User) { throw 'The current Windows user SID is unavailable.' }
    return [string]$identity.User.Value
}

function New-NyxActionResponse {
    param([bool]$Success,[string]$Status,[string]$Message,[string]$ActionId='', [object]$Details=$null)
    return [pscustomobject][ordered]@{
        Success=$Success
        Status=$Status
        Message=$Message
        ActionId=$ActionId
        Details=$Details
        Timestamp=(Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-NyxStartupBoundary {
    return [pscustomobject][ordered]@{
        WritableRegistry=@(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        )
        ReadOnlyRegistry=@(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
        )
        WritableFolder=[Environment]::GetFolderPath('Startup')
        ReadOnlyFolder=[Environment]::GetFolderPath('CommonStartup')
    }
}

function Test-NyxStartupStateBoundary {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$State)
    $versionProperty = $State.PSObject.Properties['JournalVersion']
    if ($null -eq $versionProperty -or $null -eq $versionProperty.Value) { throw 'Only Version 1 current-user rollback journals are accepted.' }
    $versionType = $versionProperty.Value.GetType().FullName
    if (@('System.Int32','System.Int64') -notcontains $versionType -or [int64]$versionProperty.Value -ne 1) { throw 'Only Version 1 current-user rollback journals are accepted.' }
    $requiresProperty = $State.PSObject.Properties['RequiresElevation']
    if ($null -eq $requiresProperty -or $requiresProperty.Value -isnot [bool] -or [bool]$requiresProperty.Value) { throw 'Version 1 does not modify all-users startup entries.' }
    if ([string]$State.JournalScope -ne 'User') { throw 'Only current-user rollback journals are accepted.' }
    if ([string]$State.OwnerSid -ne (Get-NyxCurrentUserSid)) { throw 'The rollback journal belongs to a different Windows user.' }
    $boundary = Get-NyxStartupBoundary
    if ([string]$State.SourceType -eq 'Registry') {
        $matched = $false
        foreach ($path in @($boundary.WritableRegistry)) {
            if ([string]::Equals([string]$path,[string]$State.SourcePath,[StringComparison]::OrdinalIgnoreCase)) { $matched=$true;break }
        }
        if (-not $matched) { throw 'The startup registry location is outside the current-user write allowlist.' }
        if ([string]::IsNullOrWhiteSpace([string]$State.ValueName) -or [string]$State.ValueName -match "[\r\n\x00]") { throw 'The startup registry value name is invalid.' }
        return $true
    }
    if ([string]$State.SourceType -eq 'StartupFile') {
        $full = [IO.Path]::GetFullPath([string]$State.SourcePath)
        $parent = [IO.Path]::GetDirectoryName($full).TrimEnd('\')
        $allowed = [IO.Path]::GetFullPath([string]$boundary.WritableFolder).TrimEnd('\')
        if (-not [string]::Equals($parent,$allowed,[StringComparison]::OrdinalIgnoreCase)) { throw 'The startup file is outside the current-user Startup folder.' }
        return $true
    }
    throw 'Unsupported startup source type.'
}

function Get-NyxLegacyMachineStartupRollbackRoot {
    $base = $env:ProgramData
    if ([string]::IsNullOrWhiteSpace($base)) { $base=[Environment]::GetFolderPath('CommonApplicationData') }
    if ([string]::IsNullOrWhiteSpace($base)) { throw 'The Windows common application-data folder is unavailable.' }
    return (Join-Path $base 'DietrichAI.NyxPCCheckup\startup-rollback')
}

function Get-NyxLegacyMachineRollbackObligations {
    [CmdletBinding()]
    param()
    $obligations = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    try {
        $rootPath = Get-NyxLegacyMachineStartupRollbackRoot
        try {
            $root = Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop
        } catch {
            # Only an actual ObjectNotFound result means there is no legacy
            # rollback root. PermissionDenied, malformed-provider, and other
            # failures remain Unknown so uninstall fails closed.
            if ($_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) {
                return [pscustomobject][ordered]@{Status='Clear';Obligations=@();Errors=@();Complete=$true;Root=$rootPath}
            }
            throw
        }
        if (-not $root.PSIsContainer -or (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The legacy machine rollback root is not an ordinary directory.' }
        $children = @(Get-ChildItem -LiteralPath $root.FullName -Force -ErrorAction Stop)
        foreach ($child in $children) {
            if (-not $child.PSIsContainer) {
                $errors.Add("Unexpected file exists in the legacy machine rollback root: $($child.Name)")
                continue
            }
            if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $errors.Add("Legacy machine rollback folder is a reparse point: $($child.Name)")
                continue
            }
            $actionId = [string]$child.Name
            if ($actionId -notmatch '^[a-f0-9]{32}$') {
                $errors.Add("Unexpected legacy machine rollback folder: $actionId")
                continue
            }
            $journalPath = Join-Path $child.FullName 'rollback.json'
            try {
                $journal = Get-Item -LiteralPath $journalPath -Force -ErrorAction Stop
                if ($journal.PSIsContainer -or (($journal.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or $journal.Length -le 0 -or $journal.Length -gt 1048576) { throw 'The machine journal is not an ordinary bounded file.' }
                $state = Get-Content -LiteralPath $journal.FullName -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
                if ([string]$state.ActionId -ne $actionId -or [string]$state.JournalScope -ne 'Machine' -or -not [bool]$state.RequiresElevation) { throw 'The machine journal identity or scope is invalid.' }
                $obligations.Add([pscustomobject][ordered]@{
                    ActionId=$actionId
                    DisplayName=[string]$state.Name
                    SourceLabel=[string]$state.SourceLabel
                    JournalPath=$journal.FullName
                })
            } catch {
                $errors.Add("Legacy machine rollback $actionId could not be validated: $($_.Exception.Message)")
            }
        }
    } catch {
        $errors.Add($_.Exception.Message)
    }
    $status = if ($errors.Count -gt 0) { 'Unknown' } elseif ($obligations.Count -gt 0) { 'Present' } else { 'Clear' }
    return [pscustomobject][ordered]@{
        Status=$status
        Obligations=@($obligations.ToArray())
        Errors=@($errors.ToArray())
        Complete=($errors.Count -eq 0)
        Root=$(try{Get-NyxLegacyMachineStartupRollbackRoot}catch{''})
    }
}

function New-NyxUserStartupRollbackJournal {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ActionId,[Parameter(Mandatory=$true)][object]$State)
    if ($ActionId -notmatch '^[a-f0-9]{32}$') { throw 'The rollback identifier is invalid.' }
    [void](Test-NyxCurrentUserRollbackState -State $State -ActionId $ActionId)
    [void](Test-NyxStartupStateBoundary -State $State)
    $paths = Initialize-NyxDataDirectories
    $root = Get-Item -LiteralPath $paths.DisabledStartup -Force -ErrorAction Stop
    if (-not $root.PSIsContainer -or (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The current-user rollback root is unsafe.' }
    $folder = Join-Path $root.FullName $ActionId
    if (Test-Path -LiteralPath $folder) { throw 'A rollback folder already exists for this action.' }
    New-Item -ItemType Directory -Path $folder -ErrorAction Stop | Out-Null
    $journal = Join-Path $folder 'rollback.dpapi'
    $temp = "$journal.tmp.$([guid]::NewGuid().ToString('N'))"
    try {
        $protected = Protect-NyxState -State $State
        [IO.File]::WriteAllText($temp,$protected,[Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temp -Destination $journal -Force -ErrorAction Stop
        return [pscustomobject][ordered]@{Folder=$folder;Journal=$journal;ProtectedState=$protected}
    } catch {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        try { Remove-Item -LiteralPath $folder -Force -ErrorAction SilentlyContinue } catch { }
        throw
    }
}

function Remove-NyxUserStartupRollbackJournal {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ActionId)
    if ($ActionId -notmatch '^[a-f0-9]{32}$') { throw 'The rollback identifier is invalid.' }
    $paths = Initialize-NyxDataDirectories
    $folderPath = Join-Path $paths.DisabledStartup $ActionId
    if (-not (Test-Path -LiteralPath $folderPath)) { return }
    $folder = Get-Item -LiteralPath $folderPath -Force -ErrorAction Stop
    if (-not $folder.PSIsContainer -or (($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The rollback folder is unsafe and was preserved.' }
    $journalPath = Join-Path $folder.FullName 'rollback.dpapi'
    if (Test-Path -LiteralPath $journalPath) {
        $journal = Get-Item -LiteralPath $journalPath -Force -ErrorAction Stop
        if ($journal.PSIsContainer -or (($journal.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The rollback journal is unsafe and was preserved.' }
        Remove-Item -LiteralPath $journal.FullName -Force -ErrorAction Stop
    }
    $payloadPath = Join-Path $folder.FullName 'payload'
    if (Test-Path -LiteralPath $payloadPath) {
        $payload = Get-Item -LiteralPath $payloadPath -Force -ErrorAction Stop
        if (-not $payload.PSIsContainer -or (($payload.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The rollback payload folder is unsafe and was preserved.' }
        if (@(Get-ChildItem -LiteralPath $payload.FullName -Force -ErrorAction Stop).Count -ne 0) { throw 'The rollback payload folder is not empty and was preserved.' }
        Remove-Item -LiteralPath $payload.FullName -Force -ErrorAction Stop
    }
    if (@(Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction Stop).Count -ne 0) { throw 'Unexpected rollback data remains; the folder was preserved.' }
    Remove-Item -LiteralPath $folder.FullName -Force -ErrorAction Stop
}

function Disable-NyxStartupApplication {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Application,[switch]$Confirmed)
    if (-not $Confirmed) { return New-NyxActionResponse -Success $false -Status 'ConfirmationRequired' -Message 'Disabling a startup entry requires explicit confirmation.' }
    if (-not [bool]$Application.Enabled) { return New-NyxActionResponse -Success $false -Status 'Rejected' -Message 'The startup entry is already disabled.' }
    if ([bool]$Application.RequiresElevation -or ($null -ne $Application.PSObject.Properties['CanModify'] -and -not [bool]$Application.CanModify)) {
        return New-NyxActionResponse -Success $false -Status 'ReadOnly' -Message 'All-users startup entries are displayed read-only in Version 1. Nyx did not request elevation and made no change.'
    }
    $actionId = [guid]::NewGuid().ToString('N')
    $state = [pscustomobject][ordered]@{
        JournalVersion=1
        JournalScope='User'
        ActionId=$actionId
        OwnerSid=(Get-NyxCurrentUserSid)
        Id=[string]$Application.Id
        Name=[string]$Application.Name
        Publisher=[string]$Application.Publisher
        SourceType=[string]$Application.SourceType
        SourcePath=[string]$Application.SourcePath
        SourceLabel=[string]$Application.SourceLabel
        ValueName=[string]$Application.ValueName
        ValueKind=''
        Command=[string]$Application.Command
        ExecutablePath=[string]$Application.ExecutablePath
        RequiresElevation=$false
        BackupPath=''
        SourceLength=$null
        SourceHash=''
    }
    try { [void](Test-NyxStartupStateBoundary -State $state) } catch { return New-NyxActionResponse -Success $false -Status 'Rejected' -Message $_.Exception.Message }

    $journal = $null
    $modified = $false
    try {
        $paths = Initialize-NyxDataDirectories
        if ($state.SourceType -eq 'Registry') {
            $key = Get-Item -LiteralPath $state.SourcePath -ErrorAction Stop
            $kind = [string]$key.GetValueKind($state.ValueName)
            if ($kind -notin @('String','ExpandString')) { throw 'Only string-based Windows Run values are supported.' }
            $state.ValueKind=$kind
            $current=(Get-ItemProperty -LiteralPath $state.SourcePath -Name $state.ValueName -ErrorAction Stop).($state.ValueName)
            if ([string]$current -ne [string]$state.Command) { throw 'The startup registry value changed after it was scanned. Refresh and try again.' }
        } elseif ($state.SourceType -eq 'StartupFile') {
            $source = Get-Item -LiteralPath $state.SourcePath -Force -ErrorAction Stop
            if ($source.PSIsContainer -or (($source.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Reparse points and directories are not supported startup-file actions.' }
            $folder = Join-Path $paths.DisabledStartup $actionId
            $state.BackupPath = Join-Path $folder ('payload\'+[IO.Path]::GetFileName($source.FullName))
            $state.SourceLength=[int64]$source.Length
            $state.SourceHash=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        }

        # Write-ahead rollback is durable before the user-requested mutation.
        $journal = New-NyxUserStartupRollbackJournal -ActionId $actionId -State $state
        if ($state.SourceType -eq 'Registry') {
            Remove-ItemProperty -LiteralPath $state.SourcePath -Name $state.ValueName -ErrorAction Stop
            $modified=$true
        } else {
            $backupParent = Split-Path -Parent $state.BackupPath
            New-Item -ItemType Directory -Path $backupParent -ErrorAction Stop | Out-Null
            $payload = Get-Item -LiteralPath $backupParent -Force -ErrorAction Stop
            if (($payload.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'The rollback payload folder became a reparse point.' }
            Move-Item -LiteralPath $state.SourcePath -Destination $state.BackupPath -ErrorAction Stop
            $modified=$true
        }
        Add-NyxActionHistory -Action ([pscustomobject][ordered]@{
            ActionId=$actionId;ActionType='StartupDisable';RelatedActionId='';Success=$true
            DisplayName=[string]$state.Name;DisplaySource=[string]$state.SourceLabel;UndoAvailable=$true
            ProtectedState='';Timestamp=(Get-Date).ToUniversalTime().ToString('o')
        })
        Write-NyxLog -Level 'INFO' -Message ("Disabled current-user startup entry '{0}' with rollback {1}." -f $state.Name,$actionId)
        return New-NyxActionResponse -Success $true -Status 'Completed' -Message 'The current-user startup entry was disabled after its exact rollback state was written.' -ActionId $actionId
    } catch {
        if (-not $modified -and $null -ne $journal) {
            # The action never changed Windows state. Close the write-ahead
            # journal, including an empty payload directory created before a
            # failed move, so a harmless failure cannot orphan recovery state.
            try { Remove-NyxUserStartupRollbackJournal -ActionId $actionId } catch { }
        }
        $message=$_.Exception.Message
        if ($modified) { $message += ' The rollback journal was preserved for recovery.' }
        Write-NyxLog -Level 'ERROR' -Message ("Startup disable failed: {0}" -f $message)
        return New-NyxActionResponse -Success $false -Status $(if($modified){'FailedWithRollback'}else{'Failed'}) -Message $message -ActionId $(if($modified){$actionId}else{''})
    }
}

function Enable-NyxStartupApplication {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RollbackActionId,[switch]$Confirmed)
    if (-not $Confirmed) { return New-NyxActionResponse -Success $false -Status 'ConfirmationRequired' -Message 'Re-enabling a startup entry requires explicit confirmation.' }
    if ($RollbackActionId -notmatch '^[a-f0-9]{32}$') { return New-NyxActionResponse -Success $false -Status 'Rejected' -Message 'The rollback identifier is invalid.' }
    $inventory = Get-NyxStartupRollbackInventory
    if (-not [bool]$inventory.Complete) { return New-NyxActionResponse -Success $false -Status 'Failed' -Message 'Current-user rollback storage could not be validated. No startup setting was changed.' -Details $inventory.Errors }
    $active = @($inventory.Entries | Where-Object { [string]$_.ActionId -eq $RollbackActionId } | Select-Object -First 1)
    if ($active.Count -eq 0) { return New-NyxActionResponse -Success $false -Status 'NotFound' -Message 'No active current-user rollback journal was found.' }
    try {
        $state = Unprotect-NyxState -ProtectedText ([string]$active[0].ProtectedState)
        $rollbackFolder = Join-Path (Initialize-NyxDataDirectories).DisabledStartup $RollbackActionId
        [void](Test-NyxCurrentUserRollbackState -State $state -ActionId $RollbackActionId -RollbackFolder $rollbackFolder)
        [void](Test-NyxStartupStateBoundary -State $state)
    } catch {
        return New-NyxActionResponse -Success $false -Status 'Failed' -Message ($_.Exception.Message+' No startup setting was changed.')
    }
    $newActionId = [guid]::NewGuid().ToString('N')
    try {
        if ($state.SourceType -eq 'Registry') {
            if (-not (Test-Path -LiteralPath $state.SourcePath)) { New-Item -Path $state.SourcePath -Force -ErrorAction Stop | Out-Null }
            $existing = $null
            try { $existing=(Get-ItemProperty -LiteralPath $state.SourcePath -Name $state.ValueName -ErrorAction Stop).($state.ValueName) } catch { }
            if ($null -eq $existing) {
                $kind=if([string]$state.ValueKind -eq 'ExpandString'){'ExpandString'}else{'String'}
                New-ItemProperty -LiteralPath $state.SourcePath -Name $state.ValueName -Value ([string]$state.Command) -PropertyType $kind -Force -ErrorAction Stop | Out-Null
            } elseif ([string]$existing -ne [string]$state.Command) {
                throw 'A different startup value now uses the same name. Nyx did not overwrite it.'
            }
        } elseif ($state.SourceType -eq 'StartupFile') {
            $sourceExists=Test-Path -LiteralPath ([string]$state.SourcePath) -PathType Leaf
            $backupExists=Test-Path -LiteralPath ([string]$state.BackupPath) -PathType Leaf
            if (-not $sourceExists -and $backupExists) {
                $backup=Get-Item -LiteralPath ([string]$state.BackupPath) -Force -ErrorAction Stop
                if (($backup.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'The startup backup became a reparse point.' }
                $expectedFolder = Join-Path (Join-Path (Initialize-NyxDataDirectories).DisabledStartup $RollbackActionId) 'payload'
                $actualParent=[IO.Path]::GetFullPath([IO.Path]::GetDirectoryName($backup.FullName)).TrimEnd('\')
                $expectedParent=[IO.Path]::GetFullPath($expectedFolder).TrimEnd('\')
                if (-not [string]::Equals($actualParent,$expectedParent,[StringComparison]::OrdinalIgnoreCase)) { throw 'The startup backup is outside its rollback folder.' }
                $hash=(Get-FileHash -LiteralPath $backup.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                if ([int64]$backup.Length -ne [int64]$state.SourceLength -or $hash -ne [string]$state.SourceHash) { throw 'The startup backup no longer matches its recorded identity.' }
                $parent=Split-Path -Parent ([string]$state.SourcePath)
                $parentItem=Get-Item -LiteralPath $parent -Force -ErrorAction Stop
                if (($parentItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'The original Startup folder became a reparse point.' }
                Move-Item -LiteralPath $backup.FullName -Destination ([string]$state.SourcePath) -ErrorAction Stop
            } elseif ($sourceExists -and -not $backupExists) {
                $source=Get-Item -LiteralPath ([string]$state.SourcePath) -Force -ErrorAction Stop
                if (($source.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'The restored startup file became a reparse point.' }
                $hash=(Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                if ([int64]$source.Length -ne [int64]$state.SourceLength -or $hash -ne [string]$state.SourceHash) { throw 'A different file exists at the original startup location. The rollback journal was preserved.' }
            } elseif ($sourceExists -and $backupExists) {
                throw 'A file already exists at the original startup location. Nyx did not overwrite it.'
            } else {
                throw 'The disabled startup file is no longer available.'
            }
        }
        Add-NyxActionHistory -Action ([pscustomobject][ordered]@{
            ActionId=$newActionId;ActionType='StartupEnable';RelatedActionId=$RollbackActionId;Success=$true
            DisplayName=[string]$state.Name;DisplaySource=[string]$state.SourceLabel;UndoAvailable=$false
            ProtectedState='';Timestamp=(Get-Date).ToUniversalTime().ToString('o')
        })
        Remove-NyxUserStartupRollbackJournal -ActionId $RollbackActionId
        Write-NyxLog -Level 'INFO' -Message ("Restored current-user startup entry '{0}' from rollback {1}." -f $state.Name,$RollbackActionId)
        return New-NyxActionResponse -Success $true -Status 'Completed' -Message 'The current-user startup entry was restored and its active rollback journal was closed.' -ActionId $newActionId
    } catch {
        Write-NyxLog -Level 'ERROR' -Message ("Startup restore failed: {0}" -f $_.Exception.Message)
        return New-NyxActionResponse -Success $false -Status 'Failed' -Message ($_.Exception.Message+' The rollback journal was preserved.')
    }
}

function Restore-AllNyxStartupApplications {
    [CmdletBinding()]
    param([switch]$Confirmed)
    $inventory = Get-NyxStartupRollbackInventory
    if (-not [bool]$inventory.Complete) {
        return @((New-NyxActionResponse -Success $false -Status 'Failed' -Message 'Current-user rollback storage could not be validated. Uninstall must stop before removing recovery code or data.' -Details $inventory.Errors))
    }
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in @($inventory.Entries)) {
        $results.Add((Enable-NyxStartupApplication -RollbackActionId ([string]$entry.ActionId) -Confirmed:$Confirmed))
    }
    return @($results.ToArray())
}

Export-ModuleMember -Function Get-NyxCurrentUserSid,Get-NyxStartupBoundary,Test-NyxStartupStateBoundary,Get-NyxLegacyMachineStartupRollbackRoot,Get-NyxLegacyMachineRollbackObligations,Disable-NyxStartupApplication,Enable-NyxStartupApplication,Restore-AllNyxStartupApplications

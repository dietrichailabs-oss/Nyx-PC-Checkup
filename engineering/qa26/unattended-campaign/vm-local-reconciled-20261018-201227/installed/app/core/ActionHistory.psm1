Set-StrictMode -Version 2.0
function Protect-NyxState {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$State)
    Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
    $json = $State | ConvertTo-Json -Depth 12 -Compress
    $plain = [Text.Encoding]::UTF8.GetBytes($json)
    if ($plain.Length -gt 1048576) { throw 'The rollback state exceeds the one-megabyte safety limit.' }
    $entropy = [Text.Encoding]::UTF8.GetBytes('DietrichAI.NyxPCCheckup.v1')
    $protected = [Security.Cryptography.ProtectedData]::Protect($plain,$entropy,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    return 'DPAPI1:' + [Convert]::ToBase64String($protected)
}

function Unprotect-NyxState {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$ProtectedText)
    if ([string]::IsNullOrWhiteSpace($ProtectedText) -or $ProtectedText.Length -gt 2097152) { throw 'The protected rollback state is empty or oversized.' }
    if (-not $ProtectedText.StartsWith('DPAPI1:')) { throw 'Unsupported protected-state format.' }
    Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue
    $cipher = [Convert]::FromBase64String($ProtectedText.Substring(7))
    $entropy = [Text.Encoding]::UTF8.GetBytes('DietrichAI.NyxPCCheckup.v1')
    $plain = [Security.Cryptography.ProtectedData]::Unprotect($cipher,$entropy,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    if ($plain.Length -gt 1048576) { throw 'The decrypted rollback state exceeds the safety limit.' }
    return ([Text.Encoding]::UTF8.GetString($plain) | ConvertFrom-Json)
}

function Get-NyxActionHistory {
    $paths = Initialize-NyxDataDirectories
    if (-not (Test-Path -LiteralPath $paths.ActionHistory)) { return @() }
    try {
        $item = Get-Item -LiteralPath $paths.ActionHistory -Force -ErrorAction Stop
        if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or $item.Length -gt 10485760) { return @() }
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($line in @(Get-Content -LiteralPath $item.FullName -Encoding UTF8 -ErrorAction Stop)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { $items.Add(($line | ConvertFrom-Json)) } catch { }
        }
        return @($items.ToArray())
    } catch { return @() }
}

function Add-NyxActionHistory {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Action)
    $paths = Initialize-NyxDataDirectories
    $config = Get-NyxConfiguration
    $safe = Protect-NyxObject -InputObject $Action -IncludeIpAddresses:$false -IncludeUserName:$false
    Add-Content -LiteralPath $paths.ActionHistory -Value ($safe | ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
    $all = @(Get-NyxActionHistory)
    $limit = [int]$config.actionHistoryLimit
    if ($all.Count -gt $limit) {
        $keep = @($all | Select-Object -Last $limit)
        $temp = "$($paths.ActionHistory).tmp.$([guid]::NewGuid().ToString('N'))"
        try {
            $keep | ForEach-Object { $_ | ConvertTo-Json -Compress -Depth 12 } | Set-Content -LiteralPath $temp -Encoding UTF8
            Move-Item -LiteralPath $temp -Destination $paths.ActionHistory -Force -ErrorAction Stop
        } finally {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-NyxRollbackCurrentUserSid {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User) { throw 'The current Windows user SID is unavailable.' }
    return [string]$identity.User.Value
}

function Test-NyxRollbackExactProperties {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$State,[Parameter(Mandatory=$true)][string[]]$Expected,[Parameter(Mandatory=$true)][string]$SchemaName)
    $actual = @($State.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    $difference = @(Compare-Object -ReferenceObject $wanted -DifferenceObject $actual)
    if ($difference.Count -ne 0) { throw "$SchemaName rollback journal does not match its exact property schema." }
    return $true
}

function Get-NyxRollbackStringProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$Name,
        [int]$MaximumLength=32768,
        [switch]$AllowEmpty,
        [switch]$AllowLineBreaks
    )
    $property = $State.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -isnot [string]) { throw "Rollback property '$Name' must be a string." }
    $value = [string]$property.Value
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) { throw "Rollback property '$Name' is empty." }
    if ($value.Length -gt $MaximumLength -or $value.IndexOf([char]0) -ge 0) { throw "Rollback property '$Name' is invalid or oversized." }
    if (-not $AllowLineBreaks -and $value -match "[\r\n]") { throw "Rollback property '$Name' contains an invalid line break." }
    return $value
}

function Test-NyxRollbackBooleanProperty {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$State,[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][bool]$Expected)
    $property = $State.PSObject.Properties[$Name]
    if ($null -eq $property -or $property.Value -isnot [bool] -or [bool]$property.Value -ne $Expected) {
        throw "Rollback property '$Name' has an invalid Boolean value."
    }
    return $true
}

function Test-NyxRollbackSourceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$ActionId,
        [string]$RollbackFolder=''
    )
    $sourceType = Get-NyxRollbackStringProperty -State $State -Name 'SourceType' -MaximumLength 32
    $sourcePath = Get-NyxRollbackStringProperty -State $State -Name 'SourcePath' -MaximumLength 32767
    [void](Get-NyxRollbackStringProperty -State $State -Name 'Id' -MaximumLength 128)
    [void](Get-NyxRollbackStringProperty -State $State -Name 'Name' -MaximumLength 4096 -AllowLineBreaks)
    [void](Get-NyxRollbackStringProperty -State $State -Name 'Publisher' -MaximumLength 4096 -AllowEmpty -AllowLineBreaks)
    [void](Get-NyxRollbackStringProperty -State $State -Name 'SourceLabel' -MaximumLength 4096 -AllowEmpty -AllowLineBreaks)
    [void](Get-NyxRollbackStringProperty -State $State -Name 'Command' -MaximumLength 32767 -AllowEmpty -AllowLineBreaks)
    [void](Get-NyxRollbackStringProperty -State $State -Name 'ExecutablePath' -MaximumLength 32767 -AllowEmpty)

    $folderFull = ''
    $folderItem = $null
    $folderChildren = @()
    if (-not [string]::IsNullOrWhiteSpace($RollbackFolder)) {
        $folderFull = [IO.Path]::GetFullPath($RollbackFolder).TrimEnd('\')
        $paths = Initialize-NyxDataDirectories
        $expectedFolder = [IO.Path]::GetFullPath((Join-Path $paths.DisabledStartup $ActionId)).TrimEnd('\')
        if (-not [string]::Equals($folderFull,$expectedFolder,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'The rollback folder is outside the current-user rollback root.'
        }
        $folderItem = Get-Item -LiteralPath $folderFull -Force -ErrorAction Stop
        if (-not $folderItem.PSIsContainer -or (($folderItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw 'The rollback folder is not an ordinary directory.'
        }
        $folderChildren = @(Get-ChildItem -LiteralPath $folderItem.FullName -Force -ErrorAction Stop)
    }

    if ($sourceType -eq 'Registry') {
        $allowed = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
        )
        if (@($allowed | Where-Object { [string]::Equals($_,$sourcePath,[StringComparison]::OrdinalIgnoreCase) }).Count -ne 1) {
            throw 'The rollback registry source is outside the current-user allowlist.'
        }
        [void](Get-NyxRollbackStringProperty -State $State -Name 'ValueName' -MaximumLength 16384)
        $valueKind = Get-NyxRollbackStringProperty -State $State -Name 'ValueKind' -MaximumLength 32
        if ($valueKind -notin @('String','ExpandString')) { throw 'The rollback registry value kind is invalid.' }
        $backupPath = Get-NyxRollbackStringProperty -State $State -Name 'BackupPath' -MaximumLength 32767 -AllowEmpty
        $sourceHash = Get-NyxRollbackStringProperty -State $State -Name 'SourceHash' -MaximumLength 64 -AllowEmpty
        if ($backupPath -ne '' -or $sourceHash -ne '') { throw 'A registry rollback journal contains unexpected file-backup metadata.' }
        $lengthProperty = $State.PSObject.Properties['SourceLength']
        if ($null -eq $lengthProperty -or $null -ne $lengthProperty.Value) { throw 'A registry rollback journal contains an unexpected source length.' }
        if ($null -ne $folderItem) {
            if ($folderChildren.Count -ne 1 -or $folderChildren[0].PSIsContainer -or $folderChildren[0].Name -ne 'rollback.dpapi' -or (($folderChildren[0].Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
                throw 'The registry rollback folder contains unexpected data.'
            }
        }
        return $true
    }

    if ($sourceType -ne 'StartupFile') { throw 'The rollback source type is unsupported.' }
    $valueName = Get-NyxRollbackStringProperty -State $State -Name 'ValueName' -MaximumLength 16384 -AllowEmpty
    $valueKind = Get-NyxRollbackStringProperty -State $State -Name 'ValueKind' -MaximumLength 32 -AllowEmpty
    if ($valueName -ne '' -or $valueKind -ne '') { throw 'A startup-file rollback journal contains unexpected registry metadata.' }

    $source = [IO.Path]::GetFullPath($sourcePath)
    $sourceParent = [IO.Path]::GetDirectoryName($source).TrimEnd('\')
    $startup = [Environment]::GetFolderPath('Startup')
    if ([string]::IsNullOrWhiteSpace($startup)) { throw 'The current-user Startup folder is unavailable.' }
    $allowedParent = [IO.Path]::GetFullPath($startup).TrimEnd('\')
    if (-not [string]::Equals($sourceParent,$allowedParent,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'The rollback startup file is outside the current-user Startup folder.'
    }

    $backupPath = Get-NyxRollbackStringProperty -State $State -Name 'BackupPath' -MaximumLength 32767
    $sourceHash = Get-NyxRollbackStringProperty -State $State -Name 'SourceHash' -MaximumLength 64
    if ($sourceHash -notmatch '^[A-Fa-f0-9]{64}$') { throw 'The startup-file rollback hash is invalid.' }
    $lengthProperty = $State.PSObject.Properties['SourceLength']
    if ($null -eq $lengthProperty -or $null -eq $lengthProperty.Value) { throw 'The startup-file rollback length is missing.' }
    $lengthType = $lengthProperty.Value.GetType().FullName
    if (@('System.Int32','System.Int64') -notcontains $lengthType -or [int64]$lengthProperty.Value -lt 0) {
        throw 'The startup-file rollback length is invalid.'
    }

    if ($null -eq $folderItem) { return $true }
    $expectedBackup = [IO.Path]::GetFullPath((Join-Path (Join-Path $folderFull 'payload') ([IO.Path]::GetFileName($source))))
    $actualBackup = [IO.Path]::GetFullPath($backupPath)
    if (-not [string]::Equals($actualBackup,$expectedBackup,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'The startup-file backup path is outside its exact rollback folder.'
    }

    foreach ($child in $folderChildren) {
        if ($child.Name -eq 'rollback.dpapi' -and -not $child.PSIsContainer) { continue }
        if ($child.Name -eq 'payload' -and $child.PSIsContainer) { continue }
        throw ("Unexpected data exists in rollback {0}: {1}" -f $ActionId,$child.Name)
    }

    $payloadPath = Join-Path $folderFull 'payload'
    $payloadChildren = @()
    if (Test-Path -LiteralPath $payloadPath) {
        $payloadItem = Get-Item -LiteralPath $payloadPath -Force -ErrorAction Stop
        if (-not $payloadItem.PSIsContainer -or (($payloadItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The startup-file rollback payload directory is unsafe.' }
        $payloadChildren = @(Get-ChildItem -LiteralPath $payloadItem.FullName -Force -ErrorAction Stop)
        foreach ($payloadChild in $payloadChildren) {
            if ($payloadChild.PSIsContainer -or (($payloadChild.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The startup-file rollback payload contains unsafe data.' }
            if (-not [string]::Equals([IO.Path]::GetFullPath($payloadChild.FullName),$actualBackup,[StringComparison]::OrdinalIgnoreCase)) { throw 'The startup-file rollback payload directory contains unexpected data.' }
        }
    }
    $backupExists = Test-Path -LiteralPath $actualBackup -PathType Leaf
    $sourceExists = Test-Path -LiteralPath $source -PathType Leaf
    if ($backupExists) {
        if ($payloadChildren.Count -ne 1) { throw 'The startup-file rollback payload directory does not contain exactly one backup.' }
        $backup = Get-Item -LiteralPath $actualBackup -Force -ErrorAction Stop
        if ($backup.PSIsContainer -or (($backup.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The startup-file rollback backup is not an ordinary file.' }
        $actualHash = (Get-FileHash -LiteralPath $backup.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        if ([int64]$backup.Length -ne [int64]$lengthProperty.Value -or -not [string]::Equals($actualHash,$sourceHash,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'The startup-file rollback backup no longer matches its recorded identity.'
        }
    } elseif ($sourceExists) {
        if ($payloadChildren.Count -ne 0) { throw 'The startup-file rollback payload directory contains unexpected data.' }
        $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
        if ($sourceItem.PSIsContainer -or (($sourceItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'The restored startup file is not an ordinary file.' }
        $actualHash = (Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
        if ([int64]$sourceItem.Length -ne [int64]$lengthProperty.Value -or -not [string]::Equals($actualHash,$sourceHash,[StringComparison]::OrdinalIgnoreCase)) {
            throw 'The restored startup file no longer matches the rollback identity.'
        }
    } else {
        throw 'Neither the original startup file nor its exact rollback backup is available.'
    }
    return $true
}

function Test-NyxCurrentUserRollbackState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$ActionId,
        [string]$RollbackFolder=''
    )
    $expected = @('JournalVersion','JournalScope','ActionId','OwnerSid','Id','Name','Publisher','SourceType','SourcePath','SourceLabel','ValueName','ValueKind','Command','ExecutablePath','RequiresElevation','BackupPath','SourceLength','SourceHash')
    [void](Test-NyxRollbackExactProperties -State $State -Expected $expected -SchemaName 'Version 1 current-user')
    $versionProperty = $State.PSObject.Properties['JournalVersion']
    if ($null -eq $versionProperty -or $null -eq $versionProperty.Value) { throw 'The rollback journal version is missing.' }
    $versionType = $versionProperty.Value.GetType().FullName
    if (@('System.Int32','System.Int64') -notcontains $versionType -or [int64]$versionProperty.Value -ne 1) { throw 'The rollback journal version is invalid.' }
    $stateActionId = Get-NyxRollbackStringProperty -State $State -Name 'ActionId' -MaximumLength 32
    if ($ActionId -notmatch '^[a-f0-9]{32}$' -or $stateActionId -ne $ActionId) { throw 'The rollback journal identity is invalid.' }
    $scope = Get-NyxRollbackStringProperty -State $State -Name 'JournalScope' -MaximumLength 16
    if ($scope -ne 'User') { throw 'Only non-elevated current-user rollback journals are accepted.' }
    [void](Test-NyxRollbackBooleanProperty -State $State -Name 'RequiresElevation' -Expected $false)
    $owner = Get-NyxRollbackStringProperty -State $State -Name 'OwnerSid' -MaximumLength 184
    if ($owner -ne (Get-NyxRollbackCurrentUserSid)) { throw 'The rollback journal belongs to a different Windows user.' }
    [void](Test-NyxRollbackSourceState -State $State -ActionId $ActionId -RollbackFolder $RollbackFolder)
    return $true
}

function ConvertFrom-NyxQA2CurrentUserRollbackState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$ActionId,
        [string]$RollbackFolder=''
    )
    # This compatibility path is intentionally limited to the exact QA2 user
    # schema. Successful DPAPI CurrentUser decryption happens before this
    # function is called and is the ownership proof for the legacy empty SID.
    $expected = @('JournalScope','ActionId','OwnerSid','Id','Name','Publisher','SourceType','SourcePath','SourceLabel','ValueName','ValueKind','Command','ExecutablePath','RequiresElevation','BackupPath','SourceLength','SourceHash')
    [void](Test-NyxRollbackExactProperties -State $State -Expected $expected -SchemaName 'QA2 current-user')
    $scope = Get-NyxRollbackStringProperty -State $State -Name 'JournalScope' -MaximumLength 16
    if ($scope -eq 'Machine') { throw 'A legacy machine rollback pointer cannot enter the current-user restore path.' }
    if ($scope -ne 'User') { throw 'The legacy rollback journal is not an exact QA2 current-user journal.' }
    [void](Test-NyxRollbackBooleanProperty -State $State -Name 'RequiresElevation' -Expected $false)
    $legacyOwner = Get-NyxRollbackStringProperty -State $State -Name 'OwnerSid' -MaximumLength 184 -AllowEmpty
    if ($legacyOwner -ne '') { throw 'The legacy QA2 current-user owner field is not in the exact expected form.' }
    $stateActionId = Get-NyxRollbackStringProperty -State $State -Name 'ActionId' -MaximumLength 32
    if ($ActionId -notmatch '^[a-f0-9]{32}$' -or $stateActionId -ne $ActionId) { throw 'The legacy rollback journal identity is invalid.' }
    # Validate the raw legacy property types and source/payload boundaries before
    # any cast into the normalized object. This prevents malformed legacy values
    # (for example numbers or arrays in string fields) from being coerced into an
    # apparently valid current-schema record.
    [void](Test-NyxRollbackSourceState -State $State -ActionId $ActionId -RollbackFolder $RollbackFolder)

    $normalized = [pscustomobject][ordered]@{
        JournalVersion=1
        JournalScope='User'
        ActionId=$stateActionId
        OwnerSid=(Get-NyxRollbackCurrentUserSid)
        Id=[string]$State.Id
        Name=[string]$State.Name
        Publisher=[string]$State.Publisher
        SourceType=[string]$State.SourceType
        SourcePath=[string]$State.SourcePath
        SourceLabel=[string]$State.SourceLabel
        ValueName=[string]$State.ValueName
        ValueKind=[string]$State.ValueKind
        Command=[string]$State.Command
        ExecutablePath=[string]$State.ExecutablePath
        RequiresElevation=$false
        BackupPath=[string]$State.BackupPath
        SourceLength=$State.SourceLength
        SourceHash=[string]$State.SourceHash
    }
    [void](Test-NyxCurrentUserRollbackState -State $normalized -ActionId $ActionId -RollbackFolder $RollbackFolder)
    return $normalized
}

function Resolve-NyxCurrentUserRollbackState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$State,
        [Parameter(Mandatory=$true)][string]$ActionId,
        [string]$RollbackFolder=''
    )
    $versionProperty = $State.PSObject.Properties['JournalVersion']
    if ($null -eq $versionProperty) {
        $normalized = ConvertFrom-NyxQA2CurrentUserRollbackState -State $State -ActionId $ActionId -RollbackFolder $RollbackFolder
        return [pscustomobject][ordered]@{State=$normalized;Schema='QA2-User';NormalizedInMemory=$true}
    }
    [void](Test-NyxCurrentUserRollbackState -State $State -ActionId $ActionId -RollbackFolder $RollbackFolder)
    return [pscustomobject][ordered]@{State=$State;Schema='V1';NormalizedInMemory=$false}
}

function Get-NyxStartupRollbackInventory {
    [CmdletBinding()]
    param()
    $entries = [System.Collections.Generic.List[object]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()
    try {
        $paths = Initialize-NyxDataDirectories
        $root = Get-Item -LiteralPath $paths.DisabledStartup -Force -ErrorAction Stop
        if (-not $root.PSIsContainer -or (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw 'The current-user startup rollback root is not an ordinary directory.'
        }
        foreach ($unexpected in @(Get-ChildItem -LiteralPath $root.FullName -File -Force -ErrorAction Stop)) {
            $errors.Add("Unexpected file exists in the current-user rollback root: $($unexpected.Name)")
        }
        foreach ($folder in @(Get-ChildItem -LiteralPath $root.FullName -Directory -Force -ErrorAction Stop)) {
            $actionId = [string]$folder.Name
            if ($actionId -notmatch '^[a-f0-9]{32}$') {
                $errors.Add("Unexpected rollback folder name: $actionId")
                continue
            }
            if (($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $errors.Add("Rollback folder is a reparse point: $actionId")
                continue
            }
            $journalPath = Join-Path $folder.FullName 'rollback.dpapi'
            try {
                $journal = Get-Item -LiteralPath $journalPath -Force -ErrorAction Stop
                if ($journal.PSIsContainer -or (($journal.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or $journal.Length -le 0 -or $journal.Length -gt 2097152) {
                    throw 'The rollback journal is not an ordinary bounded file.'
                }
                $protected = (Get-Content -LiteralPath $journal.FullName -Raw -Encoding UTF8 -ErrorAction Stop).Trim()
                # DPAPI CurrentUser decryption must succeed before any legacy
                # compatibility is considered. A QA2 machine pointer or a
                # malformed/ambiguous record remains rejected and preserved.
                $rawState = Unprotect-NyxState -ProtectedText $protected
                $resolved = Resolve-NyxCurrentUserRollbackState -State $rawState -ActionId $actionId -RollbackFolder $folder.FullName
                $state = $resolved.State
                $usableProtectedState = if ([bool]$resolved.NormalizedInMemory) { Protect-NyxState -State $state } else { $protected }
                $entries.Add([pscustomobject][ordered]@{
                    ActionId=$actionId
                    ActionType='StartupDisable'
                    RelatedActionId=''
                    Success=$true
                    DisplayName=[string]$state.Name
                    DisplaySource=[string]$state.SourceLabel
                    UndoAvailable=$true
                    ProtectedState=$usableProtectedState
                    JournalSchema=[string]$resolved.Schema
                    NormalizedInMemory=[bool]$resolved.NormalizedInMemory
                    Timestamp=$journal.LastWriteTimeUtc.ToString('o')
                })
            } catch {
                $errors.Add("Rollback $actionId could not be validated: $($_.Exception.Message)")
            }
        }
    } catch {
        $errors.Add($_.Exception.Message)
    }
    $status = if ($errors.Count -gt 0) { 'Unknown' } elseif ($entries.Count -gt 0) { 'Ready' } else { 'Clear' }
    return [pscustomobject][ordered]@{
        Status=$status
        Entries=@($entries.ToArray())
        Errors=@($errors.ToArray())
        Complete=($errors.Count -eq 0)
    }
}

function Get-NyxActiveStartupDisables {
    $inventory = Get-NyxStartupRollbackInventory
    return @($inventory.Entries)
}

Export-ModuleMember -Function Protect-NyxState,Unprotect-NyxState,Get-NyxActionHistory,Add-NyxActionHistory,Test-NyxCurrentUserRollbackState,ConvertFrom-NyxQA2CurrentUserRollbackState,Resolve-NyxCurrentUserRollbackState,Get-NyxStartupRollbackInventory,Get-NyxActiveStartupDisables

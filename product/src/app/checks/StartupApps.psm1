Set-StrictMode -Version 2.0
function Get-NyxExecutableFromCommand {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    if ($expanded.StartsWith('"')) {
        $end = $expanded.IndexOf('"',1)
        if ($end -gt 1) { return $expanded.Substring(1,$end-1) }
    }
    $match = [regex]::Match($expanded,'^(.*?\.(?:exe|com|bat|cmd|ps1|vbs))(?=\s|$)','IgnoreCase')
    if ($match.Success) { return $match.Groups[1].Value.Trim('"') }
    return ($expanded -split '\s+',2)[0].Trim('"')
}

function Get-NyxFilePublisher {
    param([string]$Path)
    try {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($Path)
            if ($version.CompanyName) { return [string]$version.CompanyName }
        }
    } catch { }
    return ''
}

function Get-NyxStartupApplications {
    $apps = [System.Collections.Generic.List[object]]::new()
    $registrySources = @(
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Label='Current user Run'; Elevated=$false },
        @{ Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Label='Current user RunOnce'; Elevated=$false },
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'; Label='All users Run'; Elevated=$true },
        @{ Path='HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Label='All users RunOnce'; Elevated=$true },
        @{ Path='HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Label='All users 32-bit Run'; Elevated=$true }
    )
    foreach ($source in $registrySources) {
        if (-not (Test-Path -LiteralPath $source.Path)) { continue }
        try {
            $item = Get-ItemProperty -LiteralPath $source.Path -ErrorAction Stop
            foreach ($property in $item.PSObject.Properties) {
                if ($property.Name.StartsWith('PS')) { continue }
                $command = [string]$property.Value
                $exe = Get-NyxExecutableFromCommand -Command $command
                $id = Get-NyxStableId -Text ("registry|{0}|{1}" -f $source.Path,$property.Name)
                $editable = -not [bool]$source.Elevated
                $apps.Add([pscustomobject][ordered]@{
                    Id=$id;Name=$property.Name;Publisher=(Get-NyxFilePublisher -Path $exe);SourceType='Registry'
                    SourcePath=$source.Path;SourceLabel=$source.Label;ValueName=$property.Name;Command=$command
                    ExecutablePath=$exe;FileExists=$(if($exe){Test-Path -LiteralPath $exe -PathType Leaf}else{$false})
                    Enabled=$true;RequiresElevation=[bool]$source.Elevated;CanModify=$editable
                    ReadOnlyReason=$(if($editable){''}else{'All-users startup entries are displayed read-only in Version 1.'})
                    Impact='Not measured';RollbackActionId=''
                })
            }
        } catch { }
    }
    $startupFolders = @(
        @{ Path=[Environment]::GetFolderPath('Startup');Label='Current user Startup folder';Elevated=$false },
        @{ Path=[Environment]::GetFolderPath('CommonStartup');Label='All users Startup folder';Elevated=$true }
    )
    foreach ($source in $startupFolders) {
        if ([string]::IsNullOrWhiteSpace([string]$source.Path) -or -not (Test-Path -LiteralPath $source.Path -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $source.Path -File -Force -ErrorAction SilentlyContinue)) {
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            $id = Get-NyxStableId -Text ("file|{0}" -f $file.FullName)
            $editable = -not [bool]$source.Elevated
            $apps.Add([pscustomobject][ordered]@{
                Id=$id;Name=$file.BaseName;Publisher=(Get-NyxFilePublisher -Path $file.FullName);SourceType='StartupFile'
                SourcePath=$file.FullName;SourceLabel=$source.Label;ValueName='';Command=$file.FullName;ExecutablePath=$file.FullName
                FileExists=$true;Enabled=$true;RequiresElevation=[bool]$source.Elevated;CanModify=$editable
                ReadOnlyReason=$(if($editable){''}else{'All-users startup entries are displayed read-only in Version 1.'})
                Impact='Not measured';RollbackActionId=''
            })
        }
    }

    $inventory = Get-NyxStartupRollbackInventory
    foreach ($disabled in @($inventory.Entries)) {
        try {
            $state = Unprotect-NyxState -ProtectedText ([string]$disabled.ProtectedState)
            $apps.Add([pscustomobject][ordered]@{
                Id=[string]$state.Id;Name=[string]$state.Name;Publisher=[string]$state.Publisher;SourceType=[string]$state.SourceType
                SourcePath=[string]$state.SourcePath;SourceLabel=[string]$state.SourceLabel;ValueName=[string]$state.ValueName
                Command=[string]$state.Command;ExecutablePath=[string]$state.ExecutablePath
                FileExists=$(if($state.ExecutablePath){Test-Path -LiteralPath ([string]$state.ExecutablePath) -PathType Leaf}else{$false})
                Enabled=$false;RequiresElevation=$false;CanModify=$true;ReadOnlyReason=''
                Impact='Not measured';RollbackActionId=[string]$disabled.ActionId
            })
        } catch { }
    }
    return @($apps | Sort-Object -Property @{Expression='Enabled';Descending=$true},@{Expression='Name';Descending=$false})
}

function Get-NyxStartupAppsCheck {
    $inventory = Get-NyxStartupRollbackInventory
    $apps = @(Get-NyxStartupApplications)
    $enabled = @($apps | Where-Object Enabled)
    $editable = @($enabled | Where-Object CanModify)
    $readOnly = @($enabled | Where-Object { -not $_.CanModify })
    $broken = @($enabled | Where-Object { $_.ExecutablePath -and -not $_.FileExists })
    if (-not [bool]$inventory.Complete) {
        $status='Unknown'
        $finding='Startup entries were listed, but Nyx could not validate all current-user rollback records.'
        $reason='Nyx fails closed when reversible-action recovery state is unreadable or malformed.'
    } else {
        $status=if($broken.Count -gt 0 -or $enabled.Count -gt 0){'Optional'}else{'Good'}
        $finding=if($enabled.Count -eq 0){'No startup applications were found in the supported locations.'}else{"$($enabled.Count) program(s) start automatically with Windows."}
        $reason=if($broken.Count -gt 0){"$($broken.Count) startup entry or entries point to a file that no longer exists. This is not automatically malicious."}elseif($enabled.Count -gt 0){'Startup programs may be useful; review is optional.'}else{'No supported startup entries require review.'}
    }
    return New-NyxCheckResult -CheckId 'startup.entries' -Category 'Startup' -Name 'Startup applications' -Status $status -Severity 'Low' `
        -Finding $finding -Reason $reason -Evidence ([pscustomobject]@{
            EnabledCount=$enabled.Count
            EditableCurrentUserCount=$editable.Count
            ReadOnlyAllUsersCount=$readOnly.Count
            DisabledByNyxCount=@($apps|Where-Object{-not $_.Enabled}).Count
            BrokenPathCount=$broken.Count
            RollbackInventoryStatus=[string]$inventory.Status
            RollbackInventoryErrors=@($inventory.Errors)
            Applications=$apps
        }) `
        -Recommendation 'Review startup apps only if useful. Version 1 can reversibly change current-user entries; all-users entries are visible but read-only and never trigger an elevation prompt.' `
        -ActionSafetyLevel 'ReversibleLocalChange' -DataSource 'Windows Run registry keys and Startup folders' -Details $apps -Complete ([bool]$inventory.Complete) `
        -ErrorReason $(if([bool]$inventory.Complete){''}else{'Current-user rollback storage could not be fully validated.'})
}

Export-ModuleMember -Function Get-NyxExecutableFromCommand,Get-NyxStartupApplications,Get-NyxStartupAppsCheck

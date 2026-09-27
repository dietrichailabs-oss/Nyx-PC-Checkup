Set-StrictMode -Version 2.0

function Get-NyxPathComponentEvidence {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path)
    $full=[IO.Path]::GetFullPath($Path)
    $root=[IO.Path]::GetPathRoot($full)
    $records=[System.Collections.Generic.List[object]]::new()
    $current=$root
    $relative=$full.Substring($root.Length)
    $parts=@($relative.Split(@('\'),[StringSplitOptions]::RemoveEmptyEntries))
    $candidates=[System.Collections.Generic.List[string]]::new()
    $candidates.Add($root)
    foreach($part in $parts){$current=Join-Path $current $part;$candidates.Add($current)}
    foreach($candidate in $candidates.ToArray()){
        $exists=Test-Path -LiteralPath $candidate
        $attributes='';$isDirectory=$false;$isReparse=$false;$resolved='';$owner='';$sddl='';$diagnosticError=''
        if($exists){
            try{
                $item=Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
                $attributes=[string]$item.Attributes
                $isDirectory=[bool]$item.PSIsContainer
                $isReparse=(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
                $resolved=(Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
                try{
                    $acl=Get-Acl -LiteralPath $candidate -ErrorAction Stop
                    $owner=[string]$acl.Owner
                    $sddl=$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)
                }catch{$diagnosticError='ACL: '+$_.Exception.Message}
            }catch{$diagnosticError=$_.Exception.Message}
        }
        $records.Add([pscustomobject][ordered]@{Path=$candidate;Exists=$exists;ResolvedPath=$resolved;Attributes=$attributes;IsDirectory=$isDirectory;IsReparsePoint=$isReparse;AclOwner=$owner;AclSddl=$sddl;Error=$diagnosticError})
    }
    return @($records.ToArray())
}

function Test-NyxInstallerParentWriteCapability {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$IntendedParent)
    $candidate=[IO.Path]::GetFullPath($IntendedParent)
    while(-not(Test-Path -LiteralPath $candidate -PathType Container)){
        $next=[IO.Path]::GetDirectoryName($candidate)
        if([string]::IsNullOrWhiteSpace($next) -or [string]::Equals($next,$candidate,[StringComparison]::OrdinalIgnoreCase)){break}
        $candidate=$next
    }
    $attempted=$false;$succeeded=$false;$diagnosticError='';$probe=''
    try{
        $item=Get-Item -LiteralPath $candidate -Force -ErrorAction Stop
        if(-not $item.PSIsContainer){throw 'Nearest existing ancestor is not a directory.'}
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Nearest existing ancestor is reparse-backed.'}
        $probe=Join-Path $candidate ('.nyx-pc-checkup-installer-preflight-'+[guid]::NewGuid().ToString('N'))
        $attempted=$true
        New-Item -ItemType Directory -Path $probe -ErrorAction Stop|Out-Null
        $probeFile=Join-Path $probe 'write-test.txt'
        [IO.File]::WriteAllText($probeFile,'Nyx PC Checkup installer preflight',[Text.Encoding]::ASCII)
        if(-not(Test-Path -LiteralPath $probeFile -PathType Leaf)){throw 'Write probe file did not exist after creation.'}
        $succeeded=$true
    }catch{$diagnosticError=$_.Exception.ToString()}
    finally{if(-not [string]::IsNullOrWhiteSpace($probe)){Remove-Item -LiteralPath $probe -Recurse -Force -ErrorAction SilentlyContinue}}
    return [pscustomobject][ordered]@{IntendedParent=[IO.Path]::GetFullPath($IntendedParent);NearestExistingAncestor=$candidate;Attempted=$attempted;Succeeded=$succeeded;Error=$diagnosticError}
}

function New-NyxInstallerEnvironmentPreflight {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$InstallParent)
    $environmentValue=[string]$env:LOCALAPPDATA
    $specialFolder=[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $components=@(Get-NyxPathComponentEvidence -Path $InstallParent)
    $localRecord=@()
    $valuesMatch=$false
    if(-not [string]::IsNullOrWhiteSpace($environmentValue)){
        $environmentFull=[IO.Path]::GetFullPath($environmentValue)
        $localRecord=@($components|Where-Object{[string]::Equals([IO.Path]::GetFullPath([string]$_.Path),$environmentFull,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1)
        if(-not [string]::IsNullOrWhiteSpace($specialFolder)){$valuesMatch=[string]::Equals($environmentFull,[IO.Path]::GetFullPath($specialFolder),[StringComparison]::OrdinalIgnoreCase)}
    }
    return [pscustomobject][ordered]@{
        Schema='dietrich-ai-labs.nyx-pc-checkup.installer-environment-preflight.v1'
        CapturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        ComputerName=$env:COMPUTERNAME
        UserIdentity=[Security.Principal.WindowsIdentity]::GetCurrent().Name
        IsAdministrator=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        LocalAppDataEnvironment=$environmentValue
        LocalAppDataSpecialFolder=$specialFolder
        ValuesMatch=$valuesMatch
        IntendedInstallParent=[IO.Path]::GetFullPath($InstallParent)
        IntendedInstallTarget=[IO.Path]::GetFullPath((Join-Path $InstallParent 'Nyx PC Checkup'))
        LocalAppDataRecord=$(if($localRecord.Count -eq 1){$localRecord[0]}else{$null})
        PathComponents=$components
        WriteCapability=(Test-NyxInstallerParentWriteCapability -IntendedParent $InstallParent)
    }
}

function New-NyxSetupDiagnosticPath {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$EvidenceDirectory,[Parameter(Mandatory=$true)][string]$Label)
    if(-not(Test-Path -LiteralPath $EvidenceDirectory -PathType Container)){New-Item -ItemType Directory -Path $EvidenceDirectory -Force -ErrorAction Stop|Out-Null}
    $safe=($Label -replace '[^A-Za-z0-9_-]','_')
    return Join-Path $EvidenceDirectory ('Nyx_PC_Checkup_Setup_Diagnostics_'+$safe+'_'+[guid]::NewGuid().ToString('N')+'.json')
}

function Read-NyxSetupDiagnostic {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][int]$ExpectedExitCode)
    $exists=Test-Path -LiteralPath $Path -PathType Leaf
    $record=$null;$diagnosticError='';$valid=$false
    if($exists){
        try{
            $raw=[IO.File]::ReadAllText($Path,[Text.Encoding]::Unicode)
            $record=$raw|ConvertFrom-Json
            if([string]$record.schema -ne 'dietrich-ai-labs.nyx-pc-checkup.setup-diagnostics.v1'){throw 'Unexpected diagnostics schema.'}
            if([string]$record.build -ne '2026.09.27-eng-qa21'){throw 'Unexpected diagnostics build identity.'}
            if([int]$record.exitCode -ne $ExpectedExitCode){throw ('Diagnostics exit code does not match process exit code: '+$record.exitCode)}
            if([string]::IsNullOrWhiteSpace([string]$record.branchId)){throw 'Diagnostics branchId is missing.'}
            $valid=$true
        }catch{$diagnosticError=$_.Exception.ToString()}
    }else{$diagnosticError='The setup did not create the requested branch-specific diagnostics file.'}
    return [pscustomobject][ordered]@{Path=$Path;Exists=$exists;Valid=$valid;ValidationError=$diagnosticError;Record=$record}
}

function Invoke-NyxSetupWithDiagnostics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SetupPath,
        [Parameter(Mandatory=$true)][string]$BaseArguments,
        [Parameter(Mandatory=$true)][string]$EvidenceDirectory,
        [Parameter(Mandatory=$true)][string]$Label
    )
    $diagnosticPath=New-NyxSetupDiagnosticPath -EvidenceDirectory $EvidenceDirectory -Label $Label
    $arguments=($BaseArguments.Trim()+' /diagnostics:"'+$diagnosticPath+'"').Trim()
    $started=(Get-Date).ToUniversalTime()
    $process=Start-Process -FilePath $SetupPath -ArgumentList $arguments -Wait -PassThru
    $stopped=(Get-Date).ToUniversalTime()
    $diagnostics=Read-NyxSetupDiagnostic -Path $diagnosticPath -ExpectedExitCode ([int]$process.ExitCode)
    return [pscustomobject][ordered]@{
        Label=$Label
        SetupPath=$SetupPath
        Arguments=$arguments
        StartedUtc=$started.ToString('o')
        CompletedUtc=$stopped.ToString('o')
        ExitCode=[int]$process.ExitCode
        DiagnosticPath=$diagnosticPath
        DiagnosticExists=[bool]$diagnostics.Exists
        DiagnosticValid=[bool]$diagnostics.Valid
        DiagnosticValidationError=[string]$diagnostics.ValidationError
        Diagnostic=$diagnostics.Record
    }
}

function Format-NyxSetupRunDetail {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Run)
    $branch='';$stage='';$native=''
    if($null -ne $Run.Diagnostic){$branch=[string]$Run.Diagnostic.branchId;$stage=[string]$Run.Diagnostic.stage;$native=[string]$Run.Diagnostic.nativeError}
    return ('ExitCode={0}; DiagnosticValid={1}; BranchId={2}; Stage={3}; NativeError={4}; DiagnosticPath={5}; ValidationError={6}' -f $Run.ExitCode,$Run.DiagnosticValid,$branch,$stage,$native,$Run.DiagnosticPath,$Run.DiagnosticValidationError)
}

function New-NyxQA2ExitInference {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][int]$ExitCode,[Parameter(Mandatory=$true)][object]$Preflight,[Parameter(Mandatory=$true)][string]$Label)
    $branches=@();$reason=''
    if($ExitCode -eq 11){
        $branches=@('LOCALAPPDATA_MISSING','INSTALL_PARENT_UNSAFE')
        $reason='The immutable QA2 source maps exit 11 to either missing/truncated LOCALAPPDATA or a non-ordinary/reparse-backed install parent. QA2 has no native branch diagnostics.'
    }
    return [pscustomobject][ordered]@{Label=$Label;Source='HarnessInferenceFromImmutableQA2Source';ExitCode=$ExitCode;CandidateBranchIds=$branches;Reason=$reason;PreflightLocalAppData=[string]$Preflight.LocalAppDataEnvironment;PreflightInstallParent=[string]$Preflight.IntendedInstallParent;PreflightWriteSucceeded=[bool]$Preflight.WriteCapability.Succeeded}
}

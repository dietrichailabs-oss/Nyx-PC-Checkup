[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallRoot,[int]$Confirmed=0,[int]$Quiet=0,[int]$PurgeData=0)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Windows.Forms
$expected=Join-Path $env:LOCALAPPDATA 'Programs\Dietrich AI Labs\Nyx PC Checkup'
try{$actualFull=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\');$expectedFull=[IO.Path]::GetFullPath($expected).TrimEnd('\')}catch{exit 2}
if(-not [string]::Equals($actualFull,$expectedFull,[StringComparison]::OrdinalIgnoreCase)){if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('The uninstall location failed its safety boundary check. Nothing was removed.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null};exit 2}
$InstallRoot=$actualFull
try{
    $installItem=Get-Item -LiteralPath $InstallRoot -Force -ErrorAction Stop
    if(-not $installItem.PSIsContainer -or (($installItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The installation directory is not an ordinary directory.'}
}catch{if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('The uninstall location is missing, invalid, or reparse-backed. Nothing was removed.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null};exit 2}
$AppRoot=Join-Path $InstallRoot 'app'
try{
    $appItem=Get-Item -LiteralPath $AppRoot -Force -ErrorAction Stop
    if(-not $appItem.PSIsContainer -or (($appItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The application directory is not ordinary.'}
}catch{if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('The application directory failed its safety boundary check. Nothing was removed.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null};exit 2}
Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
[void](Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Uninstall)
if($Confirmed -ne 1 -and $Quiet -ne 1){
    $answer=[Windows.Forms.MessageBox]::Show('Uninstall Nyx PC Checkup? Reversible current-user startup changes made by Nyx will be restored first.','Nyx PC Checkup Uninstaller','YesNo','Question')
    if($answer -ne [Windows.Forms.DialogResult]::Yes){exit 0}
}

# QA2 could create machine-level rollback journals. QA6 no longer creates,
# reads, modifies, or restores all-users startup entries, but it discovers that
# protected root independently of per-user pointers. Any present, malformed,
# or inaccessible legacy obligation blocks uninstall before code or data moves.
$legacy=Get-NyxLegacyMachineRollbackObligations
if([string]$legacy.Status -ne 'Clear'){
    if($Quiet -ne 1){
        $detail=if([string]$legacy.Status -eq 'Present'){'A legacy all-users startup rollback obligation still exists.'}else{'Legacy all-users rollback storage could not be validated.'}
        [Windows.Forms.MessageBox]::Show("$detail`r`n`r`nUninstall stopped before removing the application, shortcuts, registration, or local recovery data. Independent repair of the legacy machine-level rollback is required.",'Nyx PC Checkup Uninstaller','OK','Warning')|Out-Null
    }
    exit 7
}
$currentUserInventory=Get-NyxStartupRollbackInventory
if(-not [bool]$currentUserInventory.Complete){
    if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('Current-user rollback storage could not be fully validated. Uninstall stopped before removing the application or recovery data.','Nyx PC Checkup Uninstaller','OK','Warning')|Out-Null}
    exit 6
}
$restores=@(Restore-AllNyxStartupApplications -Confirmed)
$failed=@($restores|Where-Object{-not $_.Success})
if($failed.Count -gt 0){
    if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('One or more current-user startup entries could not be restored. Uninstall stopped before removing the application, shortcuts, registration, or local recovery data.','Nyx PC Checkup Uninstaller','OK','Warning')|Out-Null}
    exit 6
}
$paths=Get-NyxPathMap
$removeData=$false
if($PurgeData -eq 1){$removeData=$true}
elseif($Quiet -ne 1){
    $dataAnswer=[Windows.Forms.MessageBox]::Show('Also remove local settings, logs, scan history, and action history?','Nyx PC Checkup Uninstaller','YesNo','Question')
    $removeData=($dataAnswer -eq [Windows.Forms.DialogResult]::Yes)
}
Remove-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\NyxPCCheckup' -Recurse -Force -ErrorAction SilentlyContinue
$startFolder=Join-Path ([Environment]::GetFolderPath('Programs')) 'Dietrich AI Labs'
$start=Join-Path $startFolder 'Nyx PC Checkup.lnk'
Remove-Item -LiteralPath $start -Force -ErrorAction SilentlyContinue
try{if((Test-Path -LiteralPath $startFolder -PathType Container) -and @(Get-ChildItem -LiteralPath $startFolder -Force -ErrorAction Stop).Count -eq 0){Remove-Item -LiteralPath $startFolder -Force -ErrorAction Stop}}catch{}
$desktop=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Nyx PC Checkup.lnk'
Remove-Item -LiteralPath $desktop -Force -ErrorAction SilentlyContinue
# Final application-root deletion must run from a directory outside the tree
# being removed.  The native uninstaller also launches this worker from
# System32, but the detached cleanup process receives its own explicit safe
# working directory so it never inherits InstallRoot.
try {
    if([string]::IsNullOrWhiteSpace($env:SystemRoot)){throw 'SystemRoot is unavailable.'}
    $safeWorkingDirectory=[IO.Path]::GetFullPath((Join-Path $env:SystemRoot 'System32')).TrimEnd('\')
    $safeItem=Get-Item -LiteralPath $safeWorkingDirectory -Force -ErrorAction Stop
    if(-not $safeItem.PSIsContainer -or (($safeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The cleanup working directory is not an ordinary directory.'}
    if($safeWorkingDirectory.StartsWith($InstallRoot+'\',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($safeWorkingDirectory,$InstallRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'The cleanup working directory is inside the install root.'}
} catch {
    if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('The final uninstall cleanup could not be scheduled from a safe Windows directory. The application files were left in place.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null}
    exit 8
}

# Purge is constrained to Nyx's exact per-user data root and refuses a
# reparse-backed root.  Default uninstall intentionally preserves this data.
$dataRootToRemove=$null
if($removeData){
    try {
        $expectedDataRoot=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Dietrich AI Labs\Nyx PC Checkup')).TrimEnd('\')
        $actualDataRoot=[IO.Path]::GetFullPath([string]$paths.Root).TrimEnd('\')
        if(-not [string]::Equals($actualDataRoot,$expectedDataRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unexpected Nyx data root.'}
        if(Test-Path -LiteralPath $actualDataRoot){
            $dataItem=Get-Item -LiteralPath $actualDataRoot -Force -ErrorAction Stop
            if(-not $dataItem.PSIsContainer -or (($dataItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'Nyx data root is not an ordinary directory.'}
            $dataRootToRemove=$actualDataRoot
        }
    } catch {
        if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('Local-data purge failed its safety boundary check. Nothing was scheduled for deletion.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null}
        exit 8
    }
}

$cleanupFailureMarker=Join-Path ([IO.Path]::GetTempPath()) ('Nyx_PC_Checkup_Uninstall_Cleanup_{0}_{1}.failed' -f $PID,[guid]::NewGuid().ToString('N'))
$commands=[System.Collections.Generic.List[string]]::new()
$commands.Add('ping 127.0.0.1 -n 3 >nul')
$commands.Add("rmdir /s /q `"$InstallRoot`"")
if($dataRootToRemove){$commands.Add("rmdir /s /q `"$dataRootToRemove`"")}
$commands.Add("if exist `"$InstallRoot`" ( > `"$cleanupFailureMarker`" echo INSTALL_ROOT_REMOVE_FAILED )")
try {
    $cleanup=Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList ('/d /c '+($commands -join ' & ')) -WorkingDirectory $safeWorkingDirectory -WindowStyle Hidden -PassThru -ErrorAction Stop
    if($null -eq $cleanup -or $cleanup.Id -le 0){throw 'Detached cleanup process did not return a valid process identity.'}
} catch {
    if($Quiet -ne 1){[Windows.Forms.MessageBox]::Show('The final uninstall cleanup process could not be started. The application files were left in place.','Nyx PC Checkup Uninstaller','OK','Error')|Out-Null}
    exit 8
}
exit 0

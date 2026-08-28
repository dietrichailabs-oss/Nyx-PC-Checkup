[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RequestPath,[Parameter(Mandatory=$true)][string]$OutputPath,[Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$RequestSha256)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$AppRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
[void](Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Actions)

function Get-NyxValidatedActionFiles {
    param([string]$Request,[string]$Output)
    $paths=Initialize-NyxDataDirectories
    $tempItem=Get-Item -LiteralPath $paths.Temp -Force -ErrorAction Stop
    if(($tempItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'The Nyx action workspace cannot be a reparse point.'}
    $requestFull=[IO.Path]::GetFullPath($Request)
    $outputFull=[IO.Path]::GetFullPath($Output)
    $requestParent=[IO.Path]::GetDirectoryName($requestFull)
    $outputParent=[IO.Path]::GetDirectoryName($outputFull)
    $tempFull=[IO.Path]::GetFullPath($paths.Temp).TrimEnd('\')
    if(-not [string]::Equals($requestParent.TrimEnd('\'),$tempFull,[StringComparison]::OrdinalIgnoreCase) -or -not [string]::Equals($outputParent.TrimEnd('\'),$tempFull,[StringComparison]::OrdinalIgnoreCase)){throw 'Action input and output must remain inside the Nyx action workspace.'}
    $requestName=[IO.Path]::GetFileName($requestFull);$outputName=[IO.Path]::GetFileName($outputFull)
    $requestMatch=[regex]::Match($requestName,'^action-([a-f0-9]{32})-request\.json$','IgnoreCase')
    $outputMatch=[regex]::Match($outputName,'^action-([a-f0-9]{32})-result\.json$','IgnoreCase')
    if(-not $requestMatch.Success -or -not $outputMatch.Success -or $requestMatch.Groups[1].Value -ne $outputMatch.Groups[1].Value){throw 'The Nyx action file names do not match.'}
    $requestItem=Get-Item -LiteralPath $requestFull -Force -ErrorAction Stop
    if(($requestItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $requestItem.Length -gt 1048576){throw 'The action request is invalid or too large.'}
    if(Test-Path -LiteralPath $outputFull){
        $outputItem=Get-Item -LiteralPath $outputFull -Force -ErrorAction Stop
        if(($outputItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'The action result file cannot be a reparse point.'}
    }else{
        New-Item -ItemType File -Path $outputFull -Force -ErrorAction Stop|Out-Null
    }
    return [pscustomobject]@{Request=$requestFull;Output=$outputFull}
}

$files=$null
try{
    $files=Get-NyxValidatedActionFiles -Request $RequestPath -Output $OutputPath
    # Read once, hash those exact bytes, and parse only the verified copy. This
    # binds the user-confirmed request to this non-elevated worker launch and
    # prevents a user-writable IPC file from being swapped after confirmation.
    # Version 1 never elevates this worker and rejects all-users startup changes.
    $requestBytes=[IO.File]::ReadAllBytes($files.Request)
    if($requestBytes.Length -gt 1048576){throw 'The action request is too large.'}
    $hasher=[Security.Cryptography.SHA256]::Create()
    try{$actualHash=([BitConverter]::ToString($hasher.ComputeHash($requestBytes))).Replace('-','')}finally{$hasher.Dispose()}
    if(-not [string]::Equals($actualHash,$RequestSha256,[StringComparison]::OrdinalIgnoreCase)){throw 'The confirmed action request changed before execution. No action was performed.'}
    $requestText=[Text.Encoding]::UTF8.GetString($requestBytes).TrimStart([char]0xFEFF)
    $request=$requestText|ConvertFrom-Json
    if($null -eq $request.PSObject.Properties['ConfirmedByUser'] -or -not [bool]$request.ConfirmedByUser){throw 'The action request is missing the explicit user-confirmation marker.'}
    switch([string]$request.Operation){
        'DisableStartup' {
            $id=[string]$request.ApplicationId
            if($id -notmatch '^[a-f0-9]{24}$'){throw 'The startup application identifier is invalid.'}
            $matches=@(Get-NyxStartupApplications|Where-Object{[string]$_.Id -eq $id -and [bool]$_.Enabled})
            if($matches.Count -ne 1){throw 'The selected startup application changed or is no longer available. Refresh and try again.'}
            $result=Disable-NyxStartupApplication -Application $matches[0] -Confirmed
        }
        'EnableStartup' { $result=Enable-NyxStartupApplication -RollbackActionId ([string]$request.RollbackActionId) -Confirmed }
        'Cleanup' { $result=Invoke-NyxCleanup -CandidateIds @($request.CandidateIds|ForEach-Object{[string]$_}) -Confirmed }
        default { throw 'Unsupported action operation.' }
    }
    $json=$result|ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($files.Output,$json,[Text.Encoding]::UTF8)
    exit $(if($result.Success){0}else{2})
}catch{
    try{Write-NyxLog -Level 'ERROR' -Message ("Action worker failed: {0}" -f $_.Exception.Message)}catch{}
    if($null -ne $files){
        try{$json=[pscustomobject]@{Success=$false;Status='Failed';Message=$_.Exception.Message;Timestamp=(Get-Date).ToUniversalTime().ToString('o')}|ConvertTo-Json;[IO.File]::WriteAllText($files.Output,$json,[Text.Encoding]::UTF8)}catch{}
    }
    exit 1
}

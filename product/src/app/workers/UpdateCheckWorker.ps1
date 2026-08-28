[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [ValidateSet(0,1)][int]$Manual=0
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2.0
$AppRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Import-Module -Name (Join-Path $AppRoot 'core\RuntimeComposition.psm1') -ErrorAction Stop
[void](Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Update)

function Get-NyxValidatedUpdateOutputPath {
    param([Parameter(Mandatory=$true)][string]$Candidate)
    $paths=Initialize-NyxDataDirectories
    $temp=Get-Item -LiteralPath $paths.Temp -Force -ErrorAction Stop
    if(-not $temp.PSIsContainer -or (($temp.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)){throw 'The update worker temp root is unsafe.'}
    $full=[IO.Path]::GetFullPath($Candidate)
    $parent=[IO.Path]::GetDirectoryName($full).TrimEnd('\')
    $expected=[IO.Path]::GetFullPath($temp.FullName).TrimEnd('\')
    if(-not [string]::Equals($parent,$expected,[StringComparison]::OrdinalIgnoreCase)){throw 'The update result path is outside the Nyx temp boundary.'}
    if([IO.Path]::GetFileName($full) -notmatch '^update-[a-f0-9]{32}-result\.json$'){throw 'The update result filename is invalid.'}
    return $full
}

$output=Get-NyxValidatedUpdateOutputPath -Candidate $OutputPath
$tempPath="$output.tmp.$([guid]::NewGuid().ToString('N'))"
try{
    $result=Invoke-NyxUpdateCheck -Manual:($Manual -eq 1)
    $json=$result|ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($tempPath,$json,[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $output -Force -ErrorAction Stop
    exit 0
}catch{
    try{
        $failure=[pscustomobject][ordered]@{
            State='CHECK_FAILED';Message='Unable to check for updates right now. Please try again later.'
            Product='Nyx PC Checkup';ProductId='nyx-pc-checkup';InstalledVersion='1.0.0'
            ManifestUrl='https://www.dietrichailabs.com/updates/nyx-pc-checkup.json';Manifest=$null
            ErrorCode='WORKER_FAILURE';Manual=($Manual -eq 1);CheckedUtc=(Get-Date).ToUniversalTime().ToString('o')
        }
        [IO.File]::WriteAllText($tempPath,($failure|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempPath -Destination $output -Force -ErrorAction Stop
    }catch{}
    exit 1
}finally{
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
}

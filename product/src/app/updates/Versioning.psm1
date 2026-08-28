Set-StrictMode -Version 2.0

function ConvertTo-NyxSemanticVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Version)
    $value=$Version.Trim()
    $pattern='^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    $match=[regex]::Match($value,$pattern,[Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if(-not $match.Success){throw "Unsupported version value: $Version"}
    $major=[int64]0;$minor=[int64]0;$patch=[int64]0
    if(-not [int64]::TryParse($match.Groups[1].Value,[ref]$major) -or
       -not [int64]::TryParse($match.Groups[2].Value,[ref]$minor) -or
       -not [int64]::TryParse($match.Groups[3].Value,[ref]$patch)) { throw "Version component is too large: $Version" }
    $pre=@()
    if($match.Groups[4].Success){$pre=@($match.Groups[4].Value.Split('.'))}
    foreach($identifier in $pre){
        if([string]::IsNullOrWhiteSpace($identifier)){throw "Invalid prerelease identifier: $Version"}
        if($identifier -match '^\d+$' -and $identifier.Length -gt 1 -and $identifier.StartsWith('0')){throw "Numeric prerelease identifiers cannot contain leading zeroes: $Version"}
    }
    return [pscustomobject][ordered]@{Original=$value;Major=$major;Minor=$minor;Patch=$patch;Prerelease=$pre}
}

function Compare-NyxSemanticVersion {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Left,[Parameter(Mandatory=$true)][string]$Right)
    $a=ConvertTo-NyxSemanticVersion -Version $Left
    $b=ConvertTo-NyxSemanticVersion -Version $Right
    foreach($name in @('Major','Minor','Patch')){
        if([int64]$a.$name -lt [int64]$b.$name){return -1}
        if([int64]$a.$name -gt [int64]$b.$name){return 1}
    }
    $ap=@($a.Prerelease);$bp=@($b.Prerelease)
    if($ap.Count -eq 0 -and $bp.Count -eq 0){return 0}
    if($ap.Count -eq 0){return 1}
    if($bp.Count -eq 0){return -1}
    $limit=[math]::Min($ap.Count,$bp.Count)
    for($i=0;$i -lt $limit;$i++){
        $ai=[string]$ap[$i];$bi=[string]$bp[$i]
        $an=[int64]0;$bn=[int64]0
        $aNumeric=[int64]::TryParse($ai,[ref]$an);$bNumeric=[int64]::TryParse($bi,[ref]$bn)
        if($aNumeric -and $bNumeric){
            if($an -lt $bn){return -1};if($an -gt $bn){return 1}
        }elseif($aNumeric -and -not $bNumeric){return -1}
        elseif(-not $aNumeric -and $bNumeric){return 1}
        else{
            $comparison=[string]::Compare($ai,$bi,[StringComparison]::Ordinal)
            if($comparison -lt 0){return -1};if($comparison -gt 0){return 1}
        }
    }
    if($ap.Count -lt $bp.Count){return -1}
    if($ap.Count -gt $bp.Count){return 1}
    return 0
}

Export-ModuleMember -Function ConvertTo-NyxSemanticVersion,Compare-NyxSemanticVersion

Set-StrictMode -Version 2.0
function Get-NyxUpdateProductConfiguration {
    return [pscustomobject][ordered]@{
        DisplayName='Nyx PC Checkup'
        ProductId='nyx-pc-checkup'
        CurrentVersion='1.0.0'
        ManifestSlug='nyx-pc-checkup'
        ManifestUrl='https://www.dietrichailabs.com/updates/nyx-pc-checkup.json'
        AllowedHost='www.dietrichailabs.com'
        MaximumResponseBytes=65536
        TimeoutMilliseconds=5000
    }
}

function ConvertTo-NyxAbsoluteHttpsUri {
    param([Parameter(Mandatory=$true)][string]$Value)
    $uri=$null
    if(-not [Uri]::TryCreate($Value,[UriKind]::Absolute,[ref]$uri)){throw 'The manifest contains an invalid absolute URL.'}
    if(-not [string]::Equals($uri.Scheme,'https',[StringComparison]::OrdinalIgnoreCase)){throw 'Only HTTPS update destinations are allowed.'}
    if(-not [string]::Equals($uri.Host,'www.dietrichailabs.com',[StringComparison]::OrdinalIgnoreCase)){throw 'The update destination host is not allowlisted.'}
    if(-not $uri.IsDefaultPort -and $uri.Port -ne 443){throw 'The update destination port is not allowed.'}
    if(-not [string]::IsNullOrWhiteSpace($uri.UserInfo)){throw 'Update URLs cannot contain user information.'}
    if(-not [string]::IsNullOrWhiteSpace($uri.Fragment)){throw 'Update URLs cannot contain fragments.'}
    return $uri
}

function Test-NyxUpdateDestinationUri {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Value,[ValidateSet('Manifest','Release','Download')][string]$Purpose)
    try{
        $uri=ConvertTo-NyxAbsoluteHttpsUri -Value $Value
        if(-not [string]::IsNullOrWhiteSpace($uri.Query)){return $false}
        switch($Purpose){
            'Manifest' { return [string]::Equals($uri.AbsoluteUri,'https://www.dietrichailabs.com/updates/nyx-pc-checkup.json',[StringComparison]::Ordinal) }
            'Release' {
                $path=$uri.AbsolutePath.TrimEnd('/')
                return [string]::Equals($path,'/apps/nyx-pc-checkup',[StringComparison]::OrdinalIgnoreCase)
            }
            'Download' {
                return $uri.AbsolutePath.StartsWith('/downloads/',[StringComparison]::OrdinalIgnoreCase) -or [string]::Equals($uri.AbsolutePath.TrimEnd('/'),'/downloads',[StringComparison]::OrdinalIgnoreCase)
            }
        }
    }catch{return $false}
    return $false
}

function Test-NyxManifestObjectShape {
    param([Parameter(Mandatory=$true)][object]$Manifest)
    if($Manifest -is [string] -or $Manifest -is [Collections.IEnumerable]){throw 'The update manifest root must be a JSON object.'}
    foreach($field in @('schema_version','product','latest_version','release_name','published_at','release_url','download_url')){
        if($null -eq $Manifest.PSObject.Properties[$field]){throw "The update manifest is missing required field '$field'."}
    }
}

function Test-NyxManifestDisplayText {
    param([AllowNull()][string]$Value,[Parameter(Mandatory=$true)][string]$Field,[int]$MaximumLength=200,[switch]$AllowEmpty)
    if(-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value)){throw "The update $Field is empty."}
    if($null -ne $Value -and $Value.Length -gt $MaximumLength){throw "The update $Field is too long."}
    if($null -ne $Value -and $Value -match '[\x00-\x1F\x7F]'){throw "The update $Field contains unsupported control characters."}
    return $true
}

function ConvertTo-NyxValidatedUpdateManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Manifest)
    Test-NyxManifestObjectShape -Manifest $Manifest
    $schemaValue=$Manifest.schema_version
    $schemaType=if($null -eq $schemaValue){''}else{$schemaValue.GetType().FullName}
    if(@('System.Int32','System.Int64') -notcontains $schemaType -or [int64]$schemaValue -ne 1){throw 'The update manifest schema version is unsupported.'}
    $config=Get-NyxUpdateProductConfiguration
    if(-not [string]::Equals([string]$Manifest.product,[string]$config.ProductId,[StringComparison]::Ordinal)){throw 'The update manifest belongs to a different product.'}
    $latestVersion=[string]$Manifest.latest_version
    [void](Test-NyxManifestDisplayText -Value $latestVersion -Field 'version' -MaximumLength 64)
    [void](ConvertTo-NyxSemanticVersion -Version $latestVersion)
    $releaseName=[string]$Manifest.release_name
    [void](Test-NyxManifestDisplayText -Value $releaseName -Field 'release name' -MaximumLength 200)
    $published=[DateTimeOffset]::MinValue
    if(-not [DateTimeOffset]::TryParse([string]$Manifest.published_at,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal,[ref]$published)){throw 'The update publication timestamp is invalid.'}
    if(-not (Test-NyxUpdateDestinationUri -Value ([string]$Manifest.release_url) -Purpose 'Release')){throw 'The update release URL is not an approved Dietrich AI Labs destination.'}
    if(-not (Test-NyxUpdateDestinationUri -Value ([string]$Manifest.download_url) -Purpose 'Download')){throw 'The update download URL is not an approved Dietrich AI Labs destination.'}
    $message='';if($null -ne $Manifest.PSObject.Properties['message']){$message=[string]$Manifest.message;[void](Test-NyxManifestDisplayText -Value $message -Field 'message' -MaximumLength 500 -AllowEmpty)}
    $sha='';if($null -ne $Manifest.PSObject.Properties['sha256']){$sha=([string]$Manifest.sha256).Trim();if($sha -and $sha -notmatch '^[A-Fa-f0-9]{64}$'){throw 'The update SHA-256 value is malformed.'};$sha=$sha.ToUpperInvariant()}
    $channel='';if($null -ne $Manifest.PSObject.Properties['release_channel']){$channel=[string]$Manifest.release_channel;[void](Test-NyxManifestDisplayText -Value $channel -Field 'release channel' -MaximumLength 40 -AllowEmpty)}
    return [pscustomobject][ordered]@{
        SchemaVersion=1
        Product=[string]$Manifest.product
        LatestVersion=$latestVersion
        ReleaseName=$releaseName
        ReleaseChannel=$channel
        PublishedAtUtc=$published.ToUniversalTime().ToString('o')
        ReleaseUrl=[string]$Manifest.release_url
        DownloadUrl=[string]$Manifest.download_url
        Sha256=$sha
        Message=$message
    }
}

Export-ModuleMember -Function Get-NyxUpdateProductConfiguration,Test-NyxUpdateDestinationUri,Test-NyxManifestDisplayText,ConvertTo-NyxValidatedUpdateManifest

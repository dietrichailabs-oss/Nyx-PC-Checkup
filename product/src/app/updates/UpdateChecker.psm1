Set-StrictMode -Version 2.0
function New-NyxUpdateCheckResult {
    param(
        [Parameter(Mandatory=$true)][ValidateSet('UP_TO_DATE','UPDATE_AVAILABLE','CHECK_FAILED','SKIPPED','DISABLED')][string]$State,
        [string]$Message,
        [object]$Manifest=$null,
        [string]$ErrorCode='',
        [bool]$Manual=$false
    )
    $config=Get-NyxUpdateProductConfiguration
    return [pscustomobject][ordered]@{
        State=$State
        Message=$Message
        Product=[string]$config.DisplayName
        ProductId=[string]$config.ProductId
        InstalledVersion=[string]$config.CurrentVersion
        ManifestUrl=[string]$config.ManifestUrl
        Manifest=$Manifest
        ErrorCode=$ErrorCode
        Manual=$Manual
        CheckedUtc=(Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-NyxUpdateManifestText {
    [CmdletBinding()]
    param()
    $config=Get-NyxUpdateProductConfiguration
    if(-not (Test-NyxUpdateDestinationUri -Value ([string]$config.ManifestUrl) -Purpose 'Manifest')){throw 'The compiled update manifest endpoint failed its allowlist check.'}
    $request=$null;$response=$null;$stream=$null;$memory=$null
    try{
        $request=[Net.HttpWebRequest]::Create([string]$config.ManifestUrl)
        $request.Method='GET'
        $request.Accept='application/json'
        $request.UserAgent='NyxPCCheckup/1.0.0'
        $request.AllowAutoRedirect=$false
        $request.Timeout=[int]$config.TimeoutMilliseconds
        $request.ReadWriteTimeout=[int]$config.TimeoutMilliseconds
        $request.KeepAlive=$false
        $response=[Net.HttpWebResponse]$request.GetResponse()
        if([int]$response.StatusCode -ne 200){throw 'The update service returned a non-success status.'}
        if($response.ContentLength -gt [int64]$config.MaximumResponseBytes){throw 'The update manifest response is oversized.'}
        $contentType=[string]$response.ContentType
        if([string]::IsNullOrWhiteSpace($contentType) -or -not $contentType.StartsWith('application/json',[StringComparison]::OrdinalIgnoreCase)){throw 'The update service returned an unexpected content type.'}
        $stream=$response.GetResponseStream()
        if($null -eq $stream){throw 'The update service returned no response body.'}
        $memory=New-Object IO.MemoryStream
        $buffer=[byte[]]::new(4096)
        $total=0
        while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
            $total += $read
            if($total -gt [int]$config.MaximumResponseBytes){throw 'The update manifest response is oversized.'}
            $memory.Write($buffer,0,$read)
        }
        if($total -le 0){throw 'The update manifest response is empty.'}
        $utf8=[Text.UTF8Encoding]::new($false,$true)
        return $utf8.GetString($memory.ToArray())
    }finally{
        if($null -ne $memory){$memory.Dispose()}
        if($null -ne $stream){$stream.Dispose()}
        if($null -ne $response){$response.Dispose()}
    }
}

function Invoke-NyxUpdateCheck {
    [CmdletBinding()]
    param(
        [switch]$Manual,
        [DateTimeOffset]$NowUtc=[DateTimeOffset]::UtcNow,
        [scriptblock]$TestManifestTextProvider=$null
    )
    $configuration=Get-NyxConfiguration
    if(-not $Manual){
        if(-not [bool]$configuration.updates.enabled){return New-NyxUpdateCheckResult -State 'DISABLED' -Message 'Automatic update checks are disabled.' -Manual:$false}
        if(-not (Test-NyxAutomaticUpdateCheckDue -Configuration $configuration -NowUtc $NowUtc)){return New-NyxUpdateCheckResult -State 'SKIPPED' -Message 'A weekly update check is not due yet.' -Manual:$false}
    }

    # Record the bounded attempt before networking so offline/TLS/HTTP failures
    # cannot create a startup retry loop. Manual checks always bypass this gate.
    [void](Set-NyxUpdateCheckAttemptUtc -NowUtc $NowUtc)
    try{
        # The optional provider exists only so the shipped module can be tested
        # deterministically for timeout, DNS, TLS, HTTP, and malformed-response
        # paths without changing the compiled production endpoint. UI/worker code
        # never supplies it. The returned value is still treated as untrusted data.
        $text=if($null -ne $TestManifestTextProvider){& $TestManifestTextProvider}else{Get-NyxUpdateManifestText}
        $config=Get-NyxUpdateProductConfiguration
        if($null -eq $text){throw 'The update manifest response is empty.'}
        $text=[string]$text
        $textBytes=[Text.UTF8Encoding]::new($false).GetByteCount($text)
        if($textBytes -le 0){throw 'The update manifest response is empty.'}
        if($textBytes -gt [int]$config.MaximumResponseBytes){throw 'The update manifest response is oversized.'}
        $raw=$text|ConvertFrom-Json -ErrorAction Stop
        $manifest=ConvertTo-NyxValidatedUpdateManifest -Manifest $raw
        $comparison=Compare-NyxSemanticVersion -Left ([string]$config.CurrentVersion) -Right ([string]$manifest.LatestVersion)
        if($comparison -lt 0){
            return New-NyxUpdateCheckResult -State 'UPDATE_AVAILABLE' -Message ("$($manifest.ReleaseName) is now available.") -Manifest $manifest -Manual:$Manual
        }
        return New-NyxUpdateCheckResult -State 'UP_TO_DATE' -Message ("$($config.DisplayName) is up to date.") -Manifest $manifest -Manual:$Manual
    }catch [Net.WebException]{
        return New-NyxUpdateCheckResult -State 'CHECK_FAILED' -Message 'Unable to check for updates right now. Please try again later.' -ErrorCode 'NETWORK_OR_TLS_FAILURE' -Manual:$Manual
    }catch [Text.DecoderFallbackException]{
        return New-NyxUpdateCheckResult -State 'CHECK_FAILED' -Message 'Unable to check for updates right now. Please try again later.' -ErrorCode 'INVALID_UTF8' -Manual:$Manual
    }catch{
        return New-NyxUpdateCheckResult -State 'CHECK_FAILED' -Message 'Unable to check for updates right now. Please try again later.' -ErrorCode 'INVALID_RESPONSE_OR_METADATA' -Manual:$Manual
    }
}

Export-ModuleMember -Function New-NyxUpdateCheckResult,Get-NyxUpdateManifestText,Invoke-NyxUpdateCheck

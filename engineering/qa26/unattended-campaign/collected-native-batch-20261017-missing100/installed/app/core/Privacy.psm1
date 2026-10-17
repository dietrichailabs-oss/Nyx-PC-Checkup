Set-StrictMode -Version 2.0

function Test-NyxSensitivePropertyName {
    [CmdletBinding()]
    param([AllowNull()][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    $normalized = ($Name -replace '[^A-Za-z0-9]','').ToLowerInvariant()
    return $normalized -match '^(?:password|passwd|pwd|token|accesstoken|refreshtoken|authtoken|sessiontoken|idtoken|apikey|accesskey|secret|secretkey|clientsecret|authorization|authheader|bearertoken|cookie|setcookie|credential|credentials|privatekey|connectionstring|protectedstate)$'
}

function Remove-NyxIpAddresses {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Text)

    $evaluator = [Text.RegularExpressions.MatchEvaluator]{
        param([Text.RegularExpressions.Match]$Match)
        $candidate = $Match.Value
        $address = $null
        if ([Net.IPAddress]::TryParse($candidate,[ref]$address)) { return '[IP REDACTED]' }
        return $candidate
    }

    $value = [regex]::Replace(
        $Text,
        '(?<![A-Za-z0-9])(?:\d{1,3}\.){3}\d{1,3}(?![A-Za-z0-9])',
        $evaluator
    )

    # Capture the complete colon-bearing token first, then let the platform
    # address parser decide whether it is IPv6. This covers compressed forms
    # such as ::1 and 2001:db8::1, IPv4-mapped IPv6 such as
    # ::ffff:192.0.2.128, and loopback without hand-coding IPv6.
    $ipv6Candidate = '(?<![A-Za-z0-9])(?=[A-Fa-f0-9:.]{2,45}(?![A-Za-z0-9]))(?=[A-Fa-f0-9.]*:)[A-Fa-f0-9:.]{2,45}(?![A-Za-z0-9])'
    return [regex]::Replace($value,$ipv6Candidate,$evaluator)
}

function Protect-NyxText {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$InputObject,
        [switch]$IncludeUserName,
        [switch]$IncludeIpAddresses
    )
    if ($null -eq $InputObject) { return $null }
    $text = [string]$InputObject

    $userProfile = $env:USERPROFILE
    if (-not [string]::IsNullOrWhiteSpace($userProfile)) {
        $text = [regex]::Replace($text,[regex]::Escape($userProfile),'%USERPROFILE%',[Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    if (-not $IncludeUserName -and -not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
        $userPattern = '(?i)(?<![A-Za-z0-9_])' + [regex]::Escape($env:USERNAME) + '(?![A-Za-z0-9_])'
        $text = [regex]::Replace($text,$userPattern,'[USER]')
    }
    if (-not $IncludeIpAddresses) {
        $text = Remove-NyxIpAddresses -Text $text
    }

    $secretAssignment = '(?i)(["'']?\b(?:authorization|password|passwd|pwd|token|access[_-]?token|refresh[_-]?token|session[_-]?token|id[_-]?token|api[_-]?key|access[_-]?key|secret|secret[_-]?key|client[_-]?secret|credential|credentials|private[_-]?key|connection[_-]?string)\b["'']?\s*[:=]\s*)(?:Bearer\s+)?(?:"[^"\r\n]*"|''[^''\r\n]*''|[^\r\n;,}]+)'
    $text = [regex]::Replace($text,$secretAssignment,[Text.RegularExpressions.MatchEvaluator]{
        param([Text.RegularExpressions.Match]$Match)
        return $Match.Groups[1].Value + '[REDACTED]'
    })
    $text = $text -replace '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+','Bearer [REDACTED]'
    $text = $text -replace '(?i)([A-Z0-9._%+-]+)@([A-Z0-9.-]+\.[A-Z]{2,})','[EMAIL REDACTED]'
    return $text
}

function ConvertTo-NyxPrivateValue {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Value,
        [switch]$IncludeUserName,
        [switch]$IncludeIpAddresses,
        [int]$Depth=0
    )
    if ($Depth -gt 20) { return '[REDACTED: DEPTH LIMIT]' }
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) {
        return Protect-NyxText -InputObject $Value -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses
    }
    if ($Value -is [char] -or $Value -is [bool] -or $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64] -or $Value -is [single] -or $Value -is [double] -or
        $Value -is [decimal] -or $Value -is [datetime] -or $Value -is [guid] -or $Value -is [timespan]) {
        return $Value
    }
    if ($Value -is [Collections.IDictionary]) {
        $dictionary = [ordered]@{}
        foreach ($key in @($Value.Keys)) {
            $name = [string]$key
            if (Test-NyxSensitivePropertyName -Name $name) {
                $dictionary[$name] = '[REDACTED]'
            } else {
                $dictionary[$name] = ConvertTo-NyxPrivateValue -Value $Value[$key] -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses -Depth ($Depth+1)
            }
        }
        return [pscustomobject]$dictionary
    }
    if ($Value -is [Collections.IEnumerable]) {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $items.Add((ConvertTo-NyxPrivateValue -Value $item -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses -Depth ($Depth+1)))
        }
        return @($items.ToArray())
    }

    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty','Property','AliasProperty','ScriptProperty') })
    if ($properties.Count -gt 0) {
        $object = [ordered]@{}
        foreach ($property in $properties) {
            $name = [string]$property.Name
            if (Test-NyxSensitivePropertyName -Name $name) {
                $object[$name] = '[REDACTED]'
            } else {
                try {
                    $object[$name] = ConvertTo-NyxPrivateValue -Value $property.Value -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses -Depth ($Depth+1)
                } catch {
                    $object[$name] = '[UNAVAILABLE]'
                }
            }
        }
        return [pscustomobject]$object
    }
    return Protect-NyxText -InputObject ([string]$Value) -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses
}

function Protect-NyxObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$InputObject,
        [switch]$IncludeUserName,
        [switch]$IncludeIpAddresses
    )
    return ConvertTo-NyxPrivateValue -Value $InputObject -IncludeUserName:$IncludeUserName -IncludeIpAddresses:$IncludeIpAddresses -Depth 0
}

function Get-NyxPrivacyStatement {
    return 'Privacy: Everything analyzed by PC Checkup stays on this computer unless you explicitly export it.'
}

Export-ModuleMember -Function Test-NyxSensitivePropertyName,Remove-NyxIpAddresses,Protect-NyxText,Protect-NyxObject,Get-NyxPrivacyStatement

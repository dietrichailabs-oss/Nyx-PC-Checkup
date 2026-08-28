Set-StrictMode -Version 2.0

function ConvertTo-NyxPdfSafeText {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $ascii = -join ($Text.ToCharArray() | ForEach-Object { if ([int]$_ -ge 32 -and [int]$_ -le 126) { $_ } else { ' ' } })
    return $ascii.Replace('\','\\').Replace('(','\(').Replace(')','\)')
}

function Split-NyxReportLines {
    param([string[]]$Lines,[int]$Width=92)
    $out = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $Lines) {
        $remaining = [string]$line
        if ($remaining.Length -eq 0) { $out.Add(''); continue }
        while ($remaining.Length -gt $Width) {
            $take = $Width
            $space = $remaining.LastIndexOf(' ',$Width)
            if ($space -gt 20) { $take=$space }
            $out.Add($remaining.Substring(0,$take).TrimEnd())
            $remaining=$remaining.Substring($take).TrimStart()
        }
        $out.Add($remaining)
    }
    return @($out.ToArray())
}

function Write-NyxSimplePdf {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string[]]$Lines)
    $wrapped = @(Split-NyxReportLines -Lines $Lines)
    $pages = [System.Collections.Generic.List[object]]::new()
    for ($i=0; $i -lt $wrapped.Count; $i+=52) {
        $last=[math]::Min($i+51,$wrapped.Count-1)
        $pages.Add(@($wrapped[$i..$last]))
    }
    if ($pages.Count -eq 0) { $pages.Add(@('Nyx PC Checkup report')) }
    $objects = [System.Collections.Generic.List[string]]::new()
    $objects.Add('<< /Type /Catalog /Pages 2 0 R >>')
    $objects.Add('PAGES_PLACEHOLDER')
    $objects.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
    $pageRefs = [System.Collections.Generic.List[string]]::new()
    for ($p=0; $p -lt $pages.Count; $p++) {
        $pageObject=4+($p*2); $contentObject=$pageObject+1
        $pageRefs.Add("$pageObject 0 R")
        $objects.Add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 3 0 R >> >> /Contents $contentObject 0 R >>")
        $commands=[System.Collections.Generic.List[string]]::new()
        $commands.Add('BT /F1 10 Tf 48 756 Td 13 TL')
        foreach ($line in $pages[$p]) { $commands.Add(('('+(ConvertTo-NyxPdfSafeText $line)+') Tj T*')) }
        $commands.Add('ET')
        $stream=($commands -join "`n")+"`n"
        $length=[Text.Encoding]::ASCII.GetByteCount($stream)
        $objects.Add("<< /Length $length >>`nstream`n$stream"+'endstream')
    }
    $objects[1]="<< /Type /Pages /Kids [ $($pageRefs -join ' ') ] /Count $($pages.Count) >>"
    $ms=New-Object IO.MemoryStream
    $encoding=[Text.Encoding]::ASCII
    function Write-Ascii([IO.MemoryStream]$Stream,[string]$Value,[Text.Encoding]$Encoding) { $b=$Encoding.GetBytes($Value); $Stream.Write($b,0,$b.Length) }
    Write-Ascii $ms "%PDF-1.4`n%NYX`n" $encoding
    $offsets=[System.Collections.Generic.List[int64]]::new()
    for ($i=0; $i -lt $objects.Count; $i++) {
        $offsets.Add($ms.Position)
        Write-Ascii $ms ("{0} 0 obj`n{1}`nendobj`n" -f ($i+1),$objects[$i]) $encoding
    }
    $xref=$ms.Position
    Write-Ascii $ms ("xref`n0 {0}`n" -f ($objects.Count+1)) $encoding
    Write-Ascii $ms "0000000000 65535 f `n" $encoding
    foreach ($offset in $offsets) { Write-Ascii $ms ("{0:0000000000} 00000 n `n" -f $offset) $encoding }
    Write-Ascii $ms ("trailer`n<< /Size {0} /Root 1 0 R >>`nstartxref`n{1}`n%%EOF`n" -f ($objects.Count+1),$xref) $encoding
    [IO.File]::WriteAllBytes($Path,$ms.ToArray())
    $ms.Dispose()
}

Export-ModuleMember -Function Write-NyxSimplePdf,Split-NyxReportLines

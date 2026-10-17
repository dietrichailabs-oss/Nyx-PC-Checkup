param(
 [Parameter(Mandatory=$true)][string]$Source,
 [Parameter(Mandatory=$true)][string]$Destination,
 [Parameter(Mandatory=$true)][string]$SignerThumbprint
)
$ErrorActionPreference='Stop'
$sourcePath=(Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
$destinationPath=[IO.Path]::GetFullPath($Destination).TrimEnd('\')
if(Test-Path -LiteralPath $destinationPath){throw 'Destination must be new; no overwrites.'}
if($destinationPath -eq $sourcePath -or $destinationPath.StartsWith($sourcePath+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Copy destination cannot be inside the frozen source.'}
$cert=Get-Item -LiteralPath ('Cert:\CurrentUser\My\'+$SignerThumbprint)
if(-not $cert.HasPrivateKey){throw 'Signer private key unavailable.'}
$files=@(Get-ChildItem -LiteralPath $sourcePath -File -Recurse)
$before=@($files | ForEach-Object {
 [pscustomobject]@{RelativePath=$_.FullName.Substring($sourcePath.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash;Length=$_.Length}
})
New-Item -ItemType Directory -Path $destinationPath | Out-Null
Get-ChildItem -LiteralPath $sourcePath -Force | Copy-Item -Destination $destinationPath -Recurse
$copyHashes=@($before | ForEach-Object {
 $target=Join-Path $destinationPath $_.RelativePath
 if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $_.SHA256){throw ('Copy mismatch: '+$_.RelativePath)}
})
$signed=@(Get-ChildItem -LiteralPath $destinationPath -File -Recurse | Where-Object {$_.Extension -in '.ps1','.psm1','.psd1','.ps1xml'} | ForEach-Object {
 $signature=Set-AuthenticodeSignature -LiteralPath $_.FullName -Certificate $cert -HashAlgorithm SHA256
 if($signature.Status -ne 'Valid'){throw ('Signature rejected: '+$_.FullName+' '+$signature.Status)}
 [pscustomobject]@{RelativePath=$_.FullName.Substring($destinationPath.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash;SignatureStatus=[string]$signature.Status}
})
foreach($entry in $before){if((Get-FileHash -LiteralPath (Join-Path $sourcePath $entry.RelativePath) -Algorithm SHA256).Hash -ne $entry.SHA256){throw ('Frozen source changed: '+$entry.RelativePath)}}
[pscustomobject]@{Status='SIGNED_COPY_PREPARED';FrozenSource=$sourcePath;SignedCopy=$destinationPath;Signer=$SignerThumbprint;OriginalFiles=$before;SignedFiles=$signed;TestsExecuted=$false;FrozenCandidateAcceptance=$false} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ($destinationPath+'.signed-copy-provenance.json') -Encoding UTF8


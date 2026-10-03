"""Read-only identity reconciliation. No build or native acceptance execution."""
import hashlib
import json
import sys
import zipfile
from pathlib import Path

workspace = Path(sys.argv[1])
out = Path(sys.argv[2])
dist = workspace / 'qa25_clean_source_2f9fdb11950c4e8f98fd8e075d471696/dist'
guest = workspace / 'qa25_guest_evidence_20261002_221505'
expected = {
    'Nyx_PC_Checkup_1.0.0_Setup.exe': (559104, '5F5C1C294F23487DE1B4325173DC72C89950A2AAA96EBB1AC3F80B6CDE788112'),
    'Nyx_PC_Checkup_1.0.0_Portable.zip': (220566, 'B38A40D40CFFE86E30F1EA8E88D21295D14B1DD792D60A27962A22783E63D19C'),
    'Nyx_PC_Checkup_1.0.0_Source.zip': (794752, 'A4ED460A880BA04A289F504312BF7A1B8D0F3C1A5956DE46E19AFC837CF7049C'),
}
artifacts = []
for name, (size, digest) in expected.items():
    data = (dist / name).read_bytes()
    actual = hashlib.sha256(data).hexdigest().upper()
    assert len(data) == size and actual == digest, name
    artifacts.append(dict(name=name, bytes=len(data), sha256=actual, match=True))

with zipfile.ZipFile(dist / 'Nyx_PC_Checkup_1.0.0_Source.zip') as z:
    manifest_names = [n for n in z.namelist() if n.endswith('/SOURCE_TREE_IDENTITY.json')]
    assert len(manifest_names) == 1
    manifest_name = manifest_names[0]
    prefix = manifest_name[:-len('SOURCE_TREE_IDENTITY.json')]
    manifest = json.loads(z.read(manifest_name))
    records = []
    tree = hashlib.sha256()
    for name in sorted((n for n in z.namelist() if not n.endswith('/') and n != manifest_name), key=str.casefold):
        assert name.startswith(prefix)
        rel = name[len(prefix):]
        data = z.read(name)
        digest = hashlib.sha256(data).hexdigest().upper()
        records.append(dict(path=rel, size=len(data), sha256=digest))
        tree.update(rel.encode() + b'\0' + str(len(data)).encode() + b'\0' + digest.encode() + b'\n')
    assert records == manifest['files'] and len(records) == manifest['fileCount']
    actual_tree = tree.hexdigest().upper()
    assert actual_tree == '25D71479533E639EFC8A82ED2B93FDE3A6D47B632BB8EFBBEDAE819F9C3B0A60'

installed_records = json.loads((guest / 'INSTALLED_OFFLINE_HASHES.json').read_text(encoding='utf-8-sig'))
installed = {r['Path'].replace('\\', '/'): r for r in installed_records}
with zipfile.ZipFile(dist / 'Nyx_PC_Checkup_1.0.0_Portable.zip') as z:
    root = next(n for n in z.namelist() if n.endswith('/app/NyxPCCheckup.ps1'))[:-len('app/NyxPCCheckup.ps1')]
    portable = {n[len(root):]: dict(bytes=len(z.read(n)), sha256=hashlib.sha256(z.read(n)).hexdigest().upper())
                for n in z.namelist() if n.startswith(root) and not n.endswith('/')}
    matched = []
    mismatches = []
    for rel in sorted(set(portable) & set(installed)):
        p, i = portable[rel], installed[rel]
        if p['sha256'] == i['SHA256'] and p['bytes'] == i['Bytes']:
            matched.append(rel)
        else:
            mismatches.append(dict(path=rel, portable=p, installed=i))
    absent = sorted(set(portable) - set(installed))
    extras = sorted(set(installed) - set(portable))
    runtime_required = {p for p in portable if p.startswith('app/') or p == 'Nyx PC Checkup.exe'}
    runtime_missing = sorted(runtime_required - set(installed))
    assert not runtime_missing and not mismatches, (runtime_missing, mismatches)

summary = dict(
    artifacts=artifacts,
    canonicalSourceTree=dict(sha256=actual_tree, fileCount=len(records), recordsMatch=True),
    installedReconciliation=dict(
        portableFiles=len(portable), installedFiles=len(installed), exactMatchedFiles=len(matched),
        matchedPaths=matched, runtimeRequiredFiles=len(runtime_required), runtimeMissing=runtime_missing,
        hashMismatches=mismatches, portableOnly=absent, installedOnly=extras,
        caveat='Installed-only entries require documented installer provenance; file totals alone are not acceptance.'),
    productRebuilt=False, productModified=False,
)
out.mkdir(parents=True, exist_ok=True)
(out / 'IDENTITY_RECONCILIATION.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
print(json.dumps(summary, indent=2))

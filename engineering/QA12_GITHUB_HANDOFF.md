# Nyx PC Checkup 1.0.0 — QA12 GitHub Handoff

**Product:** Nyx PC Checkup  
**Version:** `1.0.0`  
**Build:** `2026.08.28-eng-qa12`  
**Harness:** `QA12-PS51-9`  
**Routing:** Engineering → Independent QA only  
**Release authorization:** `FALSE`

## Why this lightweight handoff exists

The original QA12 Engineering master ZIP is valid but is too large for reliable chat transport because it recursively carries historical QA evidence.

GitHub is now the working source/evidence backbone. The exact immutable candidate artifacts are delivered separately as a small candidate pack, while this branch carries the QA11→QA12 source delta, correction record, hashes, and QA instructions.

## QA12 immutable identities

```text
Original Engineering master ZIP
Size:    406,561,403 bytes
SHA-256: A59B53516C723C351B464BABB11FB134F88D43BCA3B2C7E9B5B4CBE4BE987FD5

Setup EXE
Size:    525,824 bytes
SHA-256: A48D2C5FE7FBF06FF02F62AD16B5CF1823E9572A5927232DEB1F579BF15EE455

Portable ZIP
Size:    212,186 bytes
SHA-256: DD8EABF82D0CF6BF765AEA070672D3267D8880469A001BCEC8CC2C24F19A1AC5

Source ZIP
Size:    742,170 bytes
SHA-256: 9461FF362AC5D0E2AE649CA193BFEFD0D0715E9569EE41806E28B1858F82675F

Source-tree identity
SHA-256: C92E6566825285718099C164EDBDCCB42AA4E72CB606F45D2F23DECECD6DEB2A

Independent QA11 FAIL master
SHA-256: E962569A552847A4FF9F6D08A165E4E1144B13ECB80A5D530AEE612BD0A4F820
```

## QA11-F-010 correction

QA12 fixes persisted cancelled-scan recovery at the contract boundary:

- validates each raw check result before it enters `Scan.Results`;
- validates the complete scan before worker output or persistence;
- validates and normalizes `last-scan.json` before UI/report use;
- accepts only `Good`, `NeedsAttention`, `Optional`, or `Unknown` statuses;
- rejects malformed/unsupported history safely instead of crashing or reporting Good;
- leaves rejected history untouched for support/recovery review;
- logs only a generic privacy-safe rejection warning;
- recomputes summary status from validated results;
- adds a native Windows F-010 cancellation/relaunch regression covering six timing points and two relaunches per case.

Issue of record: **#1 — QA11-F-010**.

## Engineering verification

- PowerShell application lint: PASS
- Windows harness lint: PASS
- Generated-artifact suite: **183/183 PASS**
- Setup clean-source reproduction: EXACT
- Portable clean-source reproduction: EXACT
- Source ZIP clean-source reproduction: EXACT
- Source-tree identity reproduction: EXACT
- manifest/SHA/ZIP/path-safety/source-cleanliness audits: PASS

## QA11 native regression floor

```text
Smoke                         107/107 PASS
Standard privilege/rollback   12/12 PASS
QA2 migration                244/244 PASS
Standard installer lifecycle  44/44 PASS
Elevated privilege/rollback   14/14 PASS
Elevated installer lifecycle  50/50 PASS
```

QA12 still requires native Windows execution of the F-010 Standard gate and completion of the remaining F-008 DPI/UI/accessibility matrix.

## Source delta

`engineering/qa12/QA11_to_QA12_source_delta.patch.gz.b64` contains a gzip-compressed, base64-encoded Git patch from the exact QA11 `product/` baseline to the exact QA12 source tree.

Reconstruct it on a normal Git checkout:

```bash
base64 -d engineering/qa12/QA11_to_QA12_source_delta.patch.gz.b64 | gzip -d > /tmp/QA11_to_QA12.patch
git apply --check /tmp/QA11_to_QA12.patch
git apply /tmp/QA11_to_QA12.patch
```

PowerShell equivalent:

```powershell
$b64 = Get-Content .\engineering\qa12\QA11_to_QA12_source_delta.patch.gz.b64 -Raw
[IO.File]::WriteAllBytes("$env:TEMP\QA12.patch.gz", [Convert]::FromBase64String($b64))
# Expand with a gzip-capable tool, then run: git apply --check <patch>; git apply <patch>
```

The small immutable QA12 candidate-artifact ZIP is the transport artifact; GitHub carries the source/evidence backbone so historical QA bundles are no longer nested into every handoff.

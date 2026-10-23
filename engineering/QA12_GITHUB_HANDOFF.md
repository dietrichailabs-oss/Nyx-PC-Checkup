# Nyx PC Checkup 1.0.0 — QA12 GitHub Handoff

**Product:** Nyx PC Checkup  
**Version:** `1.0.0`  
**Build:** `2026.08.28-eng-qa12`  
**Harness:** `QA12-PS51-9`  
**Routing:** Engineering → Independent QA only  
**Release authorization:** `FALSE`

## Lightweight transport model

The original QA12 Engineering master ZIP remains a valid immutable record, but at 406 MB it is too large for reliable chat transport because historical QA bundles were recursively carried forward.

For QA12 and later work, GitHub is the source-control / issue / evidence-index backbone. Candidate bytes are transported separately in a small immutable pack. Historical QA evidence is referenced by issue, artifact identity, and SHA-256 rather than nested into every new master ZIP.

The authoritative source baseline on `main` is the exact QA11 source. The exact corrected QA12 Source ZIP is included in the lightweight candidate pack so QA and Engineering can reproduce/import the QA12 tree without the historical evidence payload.

## QA12 immutable identities

```text
Original Engineering master ZIP
Size:    406,561,403 bytes
SHA-256: A59B53516C723C351B464BABB11FB134F88D43BCA3B2C7E9B5B4CBE4BE987FD5

Lightweight QA12 candidate pack
Size:    1,149,263 bytes
SHA-256: A17C469B6CD0ED6A8C6FF0EDE62831254BFC4C0FB4499CDC63A73C19B49169E2

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

## QA receives

Use `Nyx_PC_Checkup_1.0.0_QA12_Candidate_Artifacts.zip` as the transport artifact. It contains only:

- exact QA12 Setup EXE;
- exact QA12 Portable ZIP;
- exact QA12 Source ZIP;
- candidate manifest;
- SHA256SUMS;
- README.

The huge recursive master ZIP does not need to move between Engineering and QA again. GitHub issue #1 and this branch carry the correction/evidence index, while the immutable hashes preserve candidate identity.

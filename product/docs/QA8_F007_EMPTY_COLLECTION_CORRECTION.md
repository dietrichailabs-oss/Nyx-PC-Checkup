# QA8-F-007 Empty-Collection Aggregation Correction — QA9

Independent QA8 reproduced a native Windows PowerShell 5.1 `PropertyNotFoundException` when a valid cleanup candidate collection was empty. The same unguarded `Measure-Object -Sum` / `.Sum` form also existed in Downloads analysis.

## QA9 correction

QA9 changes shipped product bytes.

- `CleanupScan.psm1` now totals candidate bytes with explicit checked Int64 accumulation and returns `0` for an empty collection.
- `DownloadsAnalysis.psm1` uses the same zero-safe strategy and routes normal result construction through a single private result builder.
- No shipped runtime PowerShell file retains `Measure-Object ... -Sum` aggregation.
- Negative sizes and Int64 overflow fail closed rather than silently wrapping.

## Native Windows regression

`Run-WindowsSmokeTests.ps1` revision `QA9-PS51-6` now forces a legitimate zero-candidate bounded cleanup scan using a fresh temporary file and a one-file traversal bound. It also exercises the private Downloads result path with an empty collection and a collection containing only a harmless non-cleanup document. The same run verifies a confirmed nonexistent cleanup ID remains fail-closed after safety revalidation.

Engineering cannot execute Windows PowerShell 5.1 on the Linux build host; Independent QA must execute these exact QA9 assertions on Windows 10/11 x64.

## Historical preservation

QA8's native installer lifecycle **44/44 PASS** is a required regression boundary. QA9 must preserve normal and `/purgedata` install-root removal, exit 6/7 ordering, safe external cleanup working directory, and explicit purge boundaries.

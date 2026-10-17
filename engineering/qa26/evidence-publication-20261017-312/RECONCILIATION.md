# QA26 preserved Engineering evidence publication

Evidence-only reconciliation for Oct 13-17, 2026. No tests, rebuilds, product changes, or new test assignments.

## Authoritative saved counts

- 312 Engineering assertions PASS, 0 FAIL. This includes 149 signed-copy-scope assertions; it is not 312 frozen-candidate acceptances.
- 83/132 cells recorded complete: 56/99 strict plus 27/33 best effort at 200%.
- The former repository scoreboard contained 56 strict cells and no later best-effort cells. The 27 later cells are Dark 10, Light 7, Follow Windows 10.
- Count chain: 196 + 2 + 4 + 100 + 3 + 1 + 6 = 312. Each step is linked in RECONCILIATION.json.

## What is preserved

Current STATE.json, SCOREBOARD_CURRENT.json, HUMAN_ACTION_QUEUE.json; original Oct13-17 screenshots, page batches, native raw DPI, copied frozen installed identity evidence, collection receipts, raw manifests, qualification records, helper-validation outputs and unfinished/blocked records. Earlier supporting artifacts are retained where needed. Original evidence bytes and embedded timestamps are unchanged. PRESERVED_FILE_MANIFEST.json records SHA-256, Git blob identity and source filesystem timestamps.

## Remaining discrepancies and limits

- Five already-credited Light125 cells (Startup, Updates, Backup, System, Settings) cite the absent historical file collected-contracts-20261005-200141/INSTALLED_IDENTITY_COMPARISON.json. Existing INSTALLED_HASHES_RAW.json is preserved, not substituted. The historical ledger is not silently rewritten; Independent QA owns the disposition.
- Seven stale-capture auxiliary cases and 23 older Light125 cases remain uncredited. No missing result has been regenerated or inferred.
- Settings readability and installation-metadata reviews remain separate and unresolved.
- InstallerLifecycle and QA2Migration remain BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE.
- QA26-SEC-EXECUTIONPOLICY (Issue16) remains OPEN / security approval NOT ISSUED. F011 functional evidence does not approve launcher security design.
- Original historical nextAction fields are evidence, not assignments from this publication.

## Authority

Engineering evidence only. Campaign incomplete. No release or security approval. Independent QA retains PASS/HOLD/FAIL.

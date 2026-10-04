# QA26 unattended acceptance checkpoint

Frozen source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc
Build: 2026.10.02-eng-qa26
Harness: QA26-F023-PS51-26
Candidate: qa26-f023-candidate-20261002

Product source and candidate bytes were not modified or rebuilt. No QA27.

## Scoreboard

F-023 PASS. F-015 PASS_RECONCILED. F-020 and F-022 INCOMPLETE. F-010 and F-016 INCOMPLETE.
Strict: 20/99 PASS, 0 FAIL, 79 NOT_RUN.
Best-effort: 0/33 PASS, 0 FAIL, 33 NOT_RUN.
All downstream suites remain NOT_RUN in this continuation.

FollowWindows/100: 11/11 cells complete, published at 7cc9ae9189cc5d1a29aad321438cb913315d3e6a.
Dark/100: 9/11 cells complete: Storage, Startup, Security, Updates, Backup, System, Apps, Cleanup, Settings.
Dark Home and Checkup have positive native UI evidence but remain uncredited pending authoritative scan-result collection/validation.
Light/100 and other scale/theme batches are not credited.

## Evidence and limitations

STATE.json is the durable resume record; MATRIX.json records credited cells. Screenshots preserve actual native actions, keyboard focus/navigation, result detail, filters, tooltips, scrolling, contained maximize/restore, and cleanup Yes/No cancellation. Cleanup selection was restored to zero; no file deletion was approved. Current-user OneDrive remains Enabled; no all-users entry was modified.

Native 96 DPI was reconciled against the running app. Windows configured custom125% was not assumed to be applied125%.

Quick authoritative JSON was preserved using Explorer copy into the guest reports/last-scan.json before further scanning. The latest Full result remains scans/last-scan.json. Those copies still need byte/schema validation. An earlier Full completed visibly but its authoritative file was subsequently superseded by the Cleanup Refresh Full action; it is not counted as an authoritative validated run.

The small-preview QA25 build reading was an observer false alarm. Enlarged direct-native report header and installed VERSION.json show QA26. Original observation and resolution are both retained.

## Human action boundary

The normal host read-only collection launch awaits secure UAC; normal VM input failed to activate its captured window. HUMAN_ACTION_QUEUE.json records the exact UAC/guest-login/DPI-login tasks. No UAC, credentials, or security controls were bypassed. Independent local evidence processing continued.

The collector performs normal guest shutdown, mounts only the identified Nyx disk read-only without assigning a drive letter, copies logs/scans/reports/geometry/installed hashes, dismounts and restarts. Offline inventory is explicitly NOT live pre-shutdown cleanup proof.

After collection: validate every preserved scan contract, compare installed immutable hashes, reconcile actual guest DPI after login, credit only fully satisfied missing cells, and resume the next incomplete owner-ordered batch. Do not rebuild.

Engineering status: HOLD / INCOMPLETE ACCEPTANCE. No new genuine product defect established. Independent QA owns final PASS/HOLD/FAIL.

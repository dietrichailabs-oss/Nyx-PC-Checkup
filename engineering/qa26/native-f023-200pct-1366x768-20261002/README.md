# QA26 installed keyboard checkpoint

Engineering continuation only. Independent QA approval is not claimed.

Frozen source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc
Build: 2026.10.02-eng-qa26
Harness: QA26-F023-PS51-26

Native PS5.1, non-admin Nyx, Windows 11, confirmed 192 DPI (200%), 1366x768 physical screen, 1366x672 working area. Per-monitor-v2-aware collector. All 60 installed payload records matched expected exact file size/hash before launch.

Raw observation groups: initial installed checks 7/7; Storage navigation keys 8/8; recreated common-grid navigation keys 8/8; recreated/refresh/modal controls 5/5. These are 28 bounded observations, not 28 complete acceptance matrix cells. Alt+F4 close was human-operated and confirmed against the visible app. Automated injection of that shortcut was not a reliable VM control.

Full scan: 1 completed native run, 21 persisted results, authoritative validation 10/10; ReadOnly=true; Cancelled=false; performance.snapshot and apps.inventory both Good/Complete. Exact scan timestamps are in interactive/AUTHORITATIVE_FULL_SCAN_VALIDATION.json.

Earlier source gate: Python 224/224; structural lint 2/2; registered-handler/modal integration 116/116. These do not replace installed desktop acceptance.

F-023 remains focused acceptance INCOMPLETE pending full case/scale coverage. F-022/F-020/F-015 and 132-cell F-008 remain incomplete. Accepted complete F-008 cells: 0/132. Standard/Elevated and remaining lifecycle/privacy/safety suites are not yet run on QA26. Live pre-shutdown worker/artifact cleanup is not claimed from disk collection. Window/process records and app-close evidence are included.

Candidate product files were not modified or rebuilt. The evidence collector's PS5.1 top-level JSON array handling was corrected without changing product bytes. CANDIDATE.json in guest-session is the frozen baseline record and its NOT_RUN fields are not the current continuation result. App-data logs contain inherited historical entries; only the current session timestamps establish QA26 observations.

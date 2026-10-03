# QA26 installed 150% checkpoint

Frozen source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc
Build: 2026.10.02-eng-qa26
Harness: QA26-F023-PS51-26

Native non-admin Nyx, inbox PS5.1 x64, Windows 11. Guest evidence confirms SystemDpi=144 and sampled WindowDpi=144, physical resolution 1366x768, work area 1366x696, per-monitor-v2-aware observer.

13 bounded positive observations: five common-grid activation/navigation/focus/repeat controls and eight Apps search/column/keyboard/recreation/maximize/restore/folder-action controls. Exact cases and screenshots are in interactive/OBSERVATIONS.json. The requested-scaling field in that raw record was written before collection; APPLIED_DPI_CONFIRMATION.json and raw guest records provide the later confirmation.

All 60 installed payload records were verified by the guest before app launch. Product archives/source were not modified or rebuilt. App exit was observed in three consecutive empty-process samples. No live scan-worker/temp cleanup proof is claimed from subsequent disk collection.

F-023, F-022, F-020, F-015 and full F-008 remain INCOMPLETE. Accepted complete F-008 cells remain 0/132. Do not convert these observations into full page/cell acceptance. No Standard/Elevated results are claimed for QA26 here.

A02 geometry caveat: raw GetWindowRect records include an empty-titled transient window and maximized rectangles beyond the work-area coordinates. Visible-frame/clipping-ancestor and actual cell/font measurement oracle remains uncompleted; these raw samples alone establish neither a product containment failure nor a complete geometry PASS.

The frozen CANDIDATE.json baseline retains original NOT_RUN fields. Raw app logs include inherited history; current-session timestamps bound QA26 observations. Exact committed bytes are preserved by .gitattributes and SHA256SUMS.

Engineering HOLD / INCOMPLETE ACCEPTANCE. Independent QA owns final disposition.

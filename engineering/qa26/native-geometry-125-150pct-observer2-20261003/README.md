# QA26 installed geometry evidence: 125% and 150%

Engineering HOLD / INCOMPLETE. Independent QA owns the decision.
Frozen product source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc.
Build: 2026.10.02-eng-qa26. Candidate harness: QA26-F023-PS51-26.
Evidence observer: QA26-GEOMETRY-READONLY-2, around the exact installed script; this is not a native-EXE launch acceptance run.

125%: 12 samples, native 120 DPI, 1366x768, work area 1366x708, all PMv2, 9 Apps grid snapshots, no font fallback. Recorded filtering/restoration, Tab focus, Ctrl+End, maximize/restore, away/back recreation and normal close. The transient maximize screenshot is retained alongside the settled screenshot and is not counted as a settled PASS.
150%: 15 samples, native 144 DPI, 1366x768, work area 1366x696, all PMv2, 12 Apps grid snapshots, no font fallback. Recorded keyboard grid focus, Ctrl+End, Shift+Tab within cells, manual upward scrolling to actions/filter, filtering/restoration, maximize/restore, away/back recreation and normal close.

Measured header text fit its recorded column width at both scales. Sampled keyboard-reached cells were visible. At 150%, sequence 8 records a zero visible-height focused cell after intentional manual upward scrolling to reach the action/filter controls. Preserve this observation; it is not automatically a product failure or proof of complete focus accessibility.
No observer error file was observed in either collection. END records show normal observer return.
Installed hashes are retained raw; this checkpoint does not claim a new independent payload-hash reconciliation.

Full F-022 acceptance remains incomplete: body text/tooltips, all scrolling/action behaviors and containment still require complete acceptance. F-008 remains 0/132 fully accepted cells; no page-open-only observations are promoted to PASS. Required downstream suites remain pending. No product rebuild or source modification.

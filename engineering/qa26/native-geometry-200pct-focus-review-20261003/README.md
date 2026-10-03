# QA26 stopped 200% Apps focus evidence

Engineering stopped acceptance and requests Independent QA classification. No final QA PASS/FAIL is issued by Engineering.
The same frozen QA26 candidate was used; no rebuild, successor, or product source modification.

Observed keyboard-focus scrolling failure: after the exact sequence in ENGINEERING_STOPPED_RESULT.json, Tab focuses Version while its leading value remains clipped. Native sequence 17 records 231 pixels displayed for a 300-pixel Version column, 64-pixel row height. Screenshot 08 records the result and screenshot 09 confirms it after a two-second settle.

Observer caveat: FullyWithinClientAncestors=true applies to the recorded display rectangle, not complete nominal column width. It must not be treated as proof that all required cell text is visible. Independent QA should review the raw record, settled screenshot, and reproduction together. No further product changes are made here.

This observer run confirmed native 192 DPI, 1366x768/work area 1366x672, PMv2 throughout, 17 samples/14 Apps grid snapshots, zero font fallback. Earlier filtered Application and Reported size cells were visible. Manual horizontal page scrolling exposed Open selected folder, which opened the installed Nyx folder in Explorer. Normal app close and observer END are retained. These bounded positive observations do not override the later focus finding.

Acceptance stopped before maximize/restore and away/back at this scale, the complete shared-grid/F-015/F-008 matrix, or downstream Windows suites. F-008 remains 0/132 fully accepted cells. Frozen candidate artifacts are referenced by SHA-256, not nested into this evidence-only return. Installed hash inventory is retained raw; no new independent payload reconciliation is claimed by this checkpoint.

Earlier 125%/150% evidence: commit c650498b5e243e064d3703c9ff6ffa0f53ec7911, engineering/qa26/native-geometry-125-150pct-observer2-20261003/. No historical recursive evidence bundles are included.

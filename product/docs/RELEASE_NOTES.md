# Nyx PC Checkup 1.0.0 — QA11 Engineering Release Notes

**Build:** `2026.08.29-eng-qa11-f010`  
**Harness:** `QA11-F010-PS51-9`  
**Status:** Corrected Engineering candidate for Independent QA; not approved for public release.

## QA11 correction

QA11 corrects **QA10-F-009**, the native Windows UI-close lifecycle blocker. Optional scan/update/action temporary paths are now filtered and exact-boundary validated before any deletion call. Empty path fields can no longer reach `Remove-Item -LiteralPath`, and cleanup refuses files outside the exact Nyx temp root.

The same bounded cleanup contract is applied to FormClosing, scan completion, update completion/failure, action request/result cleanup, and the application acceptance probe.

The Windows Smoke harness adds real WinForms close probes with automatic updates disabled and enabled/due, plus zero-safe/outside-root cleanup assertions. Independent QA must still execute the broader manual close/cancel/update matrix on native Windows.

## QA9-F-008 preservation

QA11 preserves the responsive/DPI/accessibility correction introduced in QA10. The complete native final UI matrix remains required because QA10 failed before visual acceptance could run.

## Update availability

The existing Dietrich AI Labs weekly update checker remains notification-only. It does not silently download or execute an installer and does not publish this QA candidate to the website update manifest.

# QA9-WH-006 — Migration Harness Disposable-State Reset Correction

## Classification

**HARNESS ONLY — QA9 PRODUCT BYTES FROZEN**

Independent QA HOLD 3 established that WH-005 successfully reached QA9 migration code on native Windows PowerShell 5.1 and passed Scenarios 1–3. The remaining failure occurred before Scenario 4 because the harness reset was incomplete after a deliberately malformed rollback record caused QA9 uninstall to fail closed with exit 6.

## Native evidence established before this correction

- Smoke: 97/97 PASS
- Privilege / rollback: 12/12 PASS
- Installer lifecycle: 44/44 PASS
- Migration: 132/134, harness blocked
- CorrectedSetupRuns: 3
- Exact QA2 registry rollback migration: PASS
- Exact QA2 Startup-file rollback migration: PASS
- Tampered legacy journal fail-closed behavior: PASS

## Root cause

QA9 correctly preserves application integration when current-user rollback inventory is incomplete. The old reset then manually deleted InstallRoot/DataRoot but left exact HKCU uninstall registration and shortcuts. The next immutable QA2 install therefore encountered stale integration and entered a historical QA2 registry-snapshot path that is known to fail under Windows PowerShell 5.1.

The correction is scenario isolation. Immutable QA2 and QA9 product bytes are unchanged.

## Corrected reset contract

`Reset-DisposableState` now records its uninstaller attempt and exit code. Exit 0 must result in InstallRoot becoming absent. Exit 6 may trigger exact disposable cleanup because Scenarios 3/4 intentionally manufacture invalid rollback state. Any other nonzero exit produces `HARNESS_RESET_BLOCKED` and preserves state.

Forced cleanup is restricted to exact Nyx PC Checkup roots, the exact HKCU uninstall key, exact Start/desktop shortcuts, and harness-prefixed Run/RunOnce/Startup fixtures. Reparse-backed roots, shortcuts, or descendants block cleanup.

Before every immutable QA2 reinstall, the harness asserts:

- InstallRoot absent
- DataRoot absent
- uninstall registration absent
- Start shortcut absent
- desktop shortcut absent
- no harness fixture Run/RunOnce values
- no harness fixture Startup files
- installation parent ordinary/non-reparse
- installation parent writable
- prior reset recorded as successful

The report exposes all reset records as `ResetRuns`.

## Frozen identities

- QA9 Setup: `AB09FCA0574AC6D84A7289B271892EBE4DAF1AD1E0AA4ECBF0670012F070B5EA`
- QA9 Portable: `8EE1142084C121B9106EED9387C70DC3D06BADCE737F38A8B2847671AEC7FA7C`
- QA9 Source: `97EBF6A219CC2DEDC9BE975C58C96E5988241D98F5692130BCDE543229F11C82`
- QA2 Setup: `FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5`
- QA2 Source: `22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36`

## QA requirement

Rerun the complete Standard phase on native Windows PowerShell 5.1. PASS requires all five migration scenarios, no unhandled harness reset error, and `HarnessCorrectionRevision=QA9-WH006-1`. Elevated remains pending until Standard is clean.

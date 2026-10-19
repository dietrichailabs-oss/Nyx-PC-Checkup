# Who Gets What Next — Nyx PC Checkup 1.0.0 QA13

The active review loop contains only **Engineering and Independent QA**. Codex/Windows VM execution is part of Engineering pre-QA, not an additional reviewer or approval authority.

## Engineering / Codex Windows VM pre-QA

**Receives:** the exact immutable QA14 Setup, Portable, Source, manifests, hashes, root `RUN_QA14_WINDOWS_GATE.ps1`, five Windows PowerShell 5.1 suites, exact QA2 fixtures, and F-011 correction record.

**Purpose:** execute the exact candidate on clean interactive Windows 10/11 x64 snapshots; prove actual installed shortcut/direct-EXE visibility and singleton/close/relaunch behavior; rerun historical gates; and complete the F-008 visual/accessibility matrix.

**Authority:** may return Engineering `READY FOR INDEPENDENT QA` or `BLOCKED`. It may not issue Independent QA PASS.

## Independent QA

**Blocked until:** Engineering returns the exact unchanged QA14 bytes with complete native Windows functional, F-010, F-011, and F-008 evidence.

**Then receives:** the same exact candidate, current relevant evidence, manifest, hashes, and routing record.

**Authority:** `PASS`, `CONDITIONAL PASS`, `HOLD`, or `FAIL`.

## Correction route

Any genuine product defect returns to Engineering and creates a new immutable identity. A harness-only defect may be corrected separately without changing product bytes, with explicit evidence.

No additional reviewer, gate, recipient, or blocker is designated in this cycle. No additional approval authority is designated.

# Nyx PC Checkup 1.0.0 — QA15 Engineering Notes

**Build:** `2026.09.28-eng-qa25`  
**Harness:** `QA25-F022-PS51-25`  
**Status:** New immutable F-011 correction candidate; native Windows VM pre-QA required; not approved for release.

## Candidate-lineage clarification

GitHub previously recorded an unpublished QA13 R2 Engineering identity (`6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523`) without committing its complete exact product source to the branch. QA14 supersedes that pre-QA record so only one available, reproducible successor is routed forward. QA14 also keeps hidden installer/uninstaller workers separate from the visible GUI-child contract.

## F-011 installed-launch correction

QA12 proved that the installed shortcut could start a live singleton application with no usable main window. QA13 corrects the launch contract rather than weakening singleton protection:

- the application launcher now uses explicit PowerShell `-STA`;
- it no longer passes `-WindowStyle Hidden`;
- console suppression uses `CREATE_NO_WINDOW` without `STARTF_USESHOWWINDOW` / `SW_HIDE` for the GUI child;
- installer/uninstaller workers retain a separately named hidden-worker contract; and
- the WinForms main form explicitly remains normal and taskbar-visible.

A new manifest-bound Windows regression installs the exact candidate, launches the actual desktop shortcut and direct EXE, verifies a visible taskbar-eligible main window, verifies second-launch singleton behavior, closes cleanly, and opens visibly again.

## Preserved corrections

All F-001 through F-010 boundaries remain mandatory, including PowerShell 5.1 parser/list safety, runtime composition, rollback migration, uninstall cleanup, empty collections, responsive UI, close cleanup, and persisted cancelled-scan validation.

## Remaining native gate

Engineering/Codex must execute the full Standard/Elevated/F-010/F-011 Windows matrix and complete the open F-008 theme/DPI/accessibility matrix before this exact candidate is routed to Independent QA.

## Update availability

The Dietrich AI Labs weekly checker remains notification-only. It does not silently download or execute an installer and does not publish QA13 through the website manifest.

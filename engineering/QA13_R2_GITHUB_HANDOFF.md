# QA13 R2 GitHub Handoff — F-011 Installed Launch Visibility

## Status

**READY FOR CODEX WINDOWS PRE-QA — NOT YET READY FOR INDEPENDENT QA**

Build: `2026.08.30-eng-qa13-r2`  
Harness: `QA13-R2-PS51-14`

QA13 R2 is the authoritative successor candidate. It supersedes the earlier unexecuted QA13 transport identity after the local downloadable-copy operation was interrupted. No Windows result or approval is carried across candidate identities.

## Correction

- UI PowerShell launch explicitly uses `-STA`.
- The supported UI command no longer uses `-WindowStyle Hidden`.
- `CREATE_NO_WINDOW` suppresses only the console.
- The process launcher no longer sets `STARTF_USESHOWWINDOW` / `SW_HIDE` for the UI child.
- The main WinForms window is explicitly normal and taskbar-visible.
- The per-user singleton remains enforced.
- Standard VM execution includes a real installed desktop-shortcut/direct-EXE visibility regression.

## Frozen identities

```text
Setup:       60850A9E949E4B9AD50639E8250C8C132AFB9B027CF87FDC95F3091F835A065E
Portable:    4B289846756CA26EBCC2E0CD2E658B8A90F0F0509627F2329B913C506B375229
Source:      B7512BACBA50D33A6FB87A3B0617E2967049AE3ABC196DFFDDA1823833A88389
Source tree: 22D2D530C88FEB89F9D49617C24F283A730AB957AB096E3C15900D5C72A17F39
Handoff:     6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523
Launcher:    F3D39845D2C5E9C2056F8E660403A40662C133F210C38520FECEF34876A63558
App script:  888C7635B03CC951B413AEACBCC663C3E62F2229F2838D3D8F8809591D561648
```

## Engineering verification

- Application PowerShell lint: PASS
- Windows-harness PowerShell lint: PASS
- Generated-artifact suite: 193/193 PASS
- Clean-source Setup reproduction: exact
- Clean-source Portable reproduction: exact
- Clean-source Source reproduction: exact
- Lightweight archive CRC, manifest, and SHA256SUMS: PASS

## GitHub representation

GitHub stores the correction record, focused source patch, hashes, VM instructions, and issue coordination. The exact complete source is the 741,117-byte Source ZIP inside the 1,630,271-byte lightweight handoff. Recursive historical QA ZIPs are not embedded.

## Next gate

Codex runs the exact candidate on disposable Windows 10/11 x64 VMs using inbox Windows PowerShell 5.1. Independent QA remains blocked pending the F-011 installed-launch regression, retained functional regressions, and complete F-008 theme/DPI/accessibility matrix.

Routing remains Engineering -> Independent QA only. Codex is Engineering tooling, not an approval role. No additional reviewer is part of this cycle.

# Engineering Handoff — QA13 R2 F-011 Correction

## Status

**READY FOR CODEX WINDOWS PRE-QA — NOT YET READY FOR INDEPENDENT QA**

Build: `2026.08.30-eng-qa13-r2`  
Harness: `QA13-R2-PS51-14`

QA13 R2 supersedes the earlier QA13 transport identity before native VM execution. The first QA13 candidate was not routed to QA after its local user-facing copy was interrupted; no Windows evidence or approval is being transferred between identities.

## Finding corrected

`QA12-F-011` reproduced an installed singleton-owning process with no usable main window. The UI launcher combined PowerShell `-WindowStyle Hidden`, `STARTF_USESHOWWINDOW` / `SW_HIDE`, and `CREATE_NO_WINDOW`.

## Product correction

- launch the UI process explicitly with `-STA`;
- remove `-WindowStyle Hidden` from the UI command;
- use `CREATE_NO_WINDOW` only for console suppression;
- remove `STARTF_USESHOWWINDOW` / `SW_HIDE` from the shared process-launch path;
- explicitly keep the WinForms main form taskbar-visible and normal;
- preserve the per-user singleton; and
- add a real installed desktop-shortcut/direct-EXE native regression.

## Frozen candidate

```text
Setup SHA-256: 60850A9E949E4B9AD50639E8250C8C132AFB9B027CF87FDC95F3091F835A065E
Portable SHA-256: 4B289846756CA26EBCC2E0CD2E658B8A90F0F0509627F2329B913C506B375229
Source SHA-256: B7512BACBA50D33A6FB87A3B0617E2967049AE3ABC196DFFDDA1823833A88389
Source tree SHA-256: 22D2D530C88FEB89F9D49617C24F283A730AB957AB096E3C15900D5C72A17F39
Lightweight handoff SHA-256: 6860DA74C06B9A19C94AA7351533CC6B47559900E0F037A7DA31EAB57DA08523
```

Installed payload identities:

```text
Launcher SHA-256: F3D39845D2C5E9C2056F8E660403A40662C133F210C38520FECEF34876A63558
Application script SHA-256: 888C7635B03CC951B413AEACBCC663C3E62F2229F2838D3D8F8809591D561648
```

## Engineering verification

- PowerShell app lint: PASS
- PowerShell Windows-harness lint: PASS
- Generated-artifact suite: 193/193 PASS
- Fresh-source Setup reproduction: exact
- Fresh-source Portable reproduction: exact
- Fresh-source Source reproduction: exact
- Lightweight archive manifest and SHA256SUMS: PASS

## Native boundary

The Linux Engineering host cannot claim the visible main window, taskbar, singleton dialog, clean-close, DPI, or accessibility gates. Codex must execute the manifest-bound QA13 R2 Windows pre-QA matrix on disposable Windows 10/11 x64 VMs. The exact candidate goes to Independent QA only after the F-011 installed-launch gate and complete F-008 visual/accessibility matrix pass.

## Routing

Engineering -> Codex Windows pre-QA -> Independent QA. Codex is Engineering tooling, not another approval role. No additional reviewer, gate, recipient, or blocker is designated in this cycle.

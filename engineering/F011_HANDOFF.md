# Engineering Handoff — QA13 F-011 Correction

## Status

**READY FOR CODEX WINDOWS PRE-QA — NOT YET READY FOR INDEPENDENT QA**

Build: `2026.08.30-eng-qa13`  
Harness: `QA13-PS51-13`

## Finding corrected

`QA12-F-011` reproduced an installed singleton-owning process with no usable main window. The UI launcher combined PowerShell `-WindowStyle Hidden`, `STARTF_USESHOWWINDOW` / `SW_HIDE`, and `CREATE_NO_WINDOW`.

## Product correction

- launch the UI process explicitly with `-STA`;
- remove `-WindowStyle Hidden` from the UI command;
- use `CREATE_NO_WINDOW` only for console suppression;
- remove `STARTF_USESHOWWINDOW` / `SW_HIDE` from the shared process launcher;
- explicitly keep the WinForms main form taskbar-visible and normal;
- preserve the per-user singleton; and
- add a real installed desktop-shortcut/direct-EXE native regression.

## Frozen candidate

```text
Setup SHA-256: 447483FFED71E7622BBBBB18678670DF61D15AE18794F9BFAC8695BBF33115D2
Portable SHA-256: 03781C0DE2891735A3F8F131363811E176BC1A5EBA73F7DBDD715E2F43BBD413
Source SHA-256: A255864D23F49184908DF293D61034D09A83F853DBA831B7F08E482D2CCDC69A
Source tree SHA-256: C32856DB6CEA481B4864C65520D255FDF237986D1BB4953C81095CFAD4894BBC
Lightweight handoff SHA-256: B54283301E60182E545CC8718C85E56D6F439FC6D2F191DF808C65A4342E3FC5
```

Installed payload identities:

```text
Launcher SHA-256: F3D39845D2C5E9C2056F8E660403A40662C133F210C38520FECEF34876A63558
Application script SHA-256: 0FD7B75C1C450EF59B61BA11803D154638149C486C11D732B944B2FAE6CC9624
```

## Engineering verification

- PowerShell app lint: PASS
- PowerShell Windows-harness lint: PASS
- Generated-artifact suite: 195/195 PASS
- Fresh-source Setup reproduction: exact
- Fresh-source Portable reproduction: exact
- Fresh-source Source reproduction: exact
- Lightweight archive manifest and SHA256SUMS: PASS

## Native boundary

The Linux Engineering host cannot claim the visible main window, taskbar, singleton dialog, clean-close, DPI, or accessibility gates. Codex must execute the manifest-bound QA13 Windows pre-QA matrix on disposable Windows 10/11 x64 VMs. The exact candidate goes to Independent QA only after the F-011 installed-launch gate and complete F-008 visual/accessibility matrix pass.

## Routing

Engineering -> Codex Windows pre-QA -> Independent QA. Codex is Engineering tooling, not another approval role. No other reviewer is part of this cycle.

# Current QA27 scope takes precedence

Read QA27_F024_PDF_EXPORT.md and README_FIRST.md first. Native F-024 first;
no DPI/scaling work. Historical83/132 remains archived;49 cells are
WAIVED_BY_OWNER_DPI_SCOPE_20261019. No QA26 credit is copied into QA27.
Historical instructions below do not override the owner policy.

---

# Known Limitations â€” Corrected Engineering QA7 Candidate

1. **Native Windows acceptance remains pending.** Engineeringâ€™s Linux environment cannot execute Windows PowerShell 5.1, WinForms, registry, DPAPI, UAC, Windows Security/Update APIs, or the native installer lifecycle. Independent QA must execute the exact QA7 bytes on clean disposable Windows 10/11 x64 snapshots.
2. **QA6-F-005 is corrected but not claimed native-PASS by Engineering.** QA7 replaces nested forced module imports with one verified composition root and adds two real application Quick Check probes. Independent QA must confirm the full graph under Windows PowerShell 5.1.
3. **QA6 exit-11 installer evidence remains historically inconclusive.** QA7 adds branch-specific native setup diagnostics plus path/ACL/reparse/write preflight so the next result is attributable. The old QA2 fixture cannot emit new diagnostics and is explicitly handled as an inference-only case.
4. **The elevated phase remains open.** QA must run the Elevated phase from an elevated Windows PowerShell 5.1 session on a separate clean snapshot.
5. **The candidate is unsigned.** No code-signing certificate was supplied. It is an Engineering QA artifact, not a public release.
6. **Some Windows health signals may be Unknown.** Hardware, WMI/CIM providers, Windows services, permissions, and OEM support vary. Nyx reports Unknown rather than fabricating certainty.
7. **Update checking is notification-only.** The application never downloads or launches an installer. The official website manifest is not published by this Engineering build.

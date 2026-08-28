# Nyx PC Checkup 1.0.0 — QA3 Correction Matrix

## Exact failed intake

- Reviewed Engineering build: `2026.08.23-eng-qa3`
- Reviewed Engineering handoff: `Nyx_PC_Checkup_1.0.0_Engineering_QA3_Corrected_Master_Handoff(1).zip`
- Reviewed handoff size: `729,698 bytes`
- Reviewed handoff SHA-256: `2B7530BA910B5E7997699A6B49483B9B56DBF12785D6D91E9CEA81BCA6F07DA0`
- QA3 FAIL handoff supplied to Engineering: `Nyx_PC_Checkup_1.0.0_Independent_QA3_FAIL_Master_Handoff(3).zip`
- QA3 FAIL handoff size: `740,177 bytes`
- QA3 FAIL handoff SHA-256: `B89BDF579BB7EFB7D7DB28A49971576FD8A8682C731BAC5FE965362B6BAAFD4D`
- QA verdict: **FAIL — RELEASE BLOCKED**
- Corrected Engineering build: `2026.08.23-eng-qa4`

This matrix records Engineering’s response to the exact F-004 finding. It does not convert the QA3 failure into a pass. Independent QA must test the new immutable QA4 bytes.

## F-004 — QA2 current-user rollback migration

### Failure

The exact QA2 startup-disable implementation wrote a DPAPI CurrentUser-protected user journal that:

- omitted `JournalVersion`; and
- stored `OwnerSid=''` for non-elevated current-user actions.

QA3 hardened the current schema to require `JournalVersion=1` and the current Windows SID, but it had no compatibility path for those surviving QA2 user journals. Because application upgrades replace the install root while preserving the separate current-user data root, an active QA2 rollback could remain after upgrade and become un-restorable.

### Correction

`src/app/core/ActionHistory.psm1` now includes a narrow compatibility boundary:

1. `rollback.dpapi` must be an ordinary, bounded file in the exact current-user rollback root.
2. DPAPI `CurrentUser` decryption must succeed before legacy compatibility is considered.
3. The decrypted object must have the exact QA2 user property set—no missing or unknown fields.
4. `JournalScope` must be the exact string `User`.
5. `RequiresElevation` must be the actual Boolean `false`.
6. The QA2 `OwnerSid` field must be the exact expected empty string.
7. `ActionId` must match the 32-character rollback folder name.
8. Registry state is restricted to current-user Run/RunOnce and string/expand-string values.
9. Startup-file state is restricted to the current user’s Startup folder and exact rollback payload path.
10. File length, SHA-256, ordinary-file, directory-layout, and reparse-point boundaries are revalidated.
11. Valid QA2 user state is normalized in memory to `JournalVersion=1` and `OwnerSid=<current SID>`.
12. The normalized state is revalidated as current schema before it can be exposed to restore code.
13. Restore revalidates the normalized state and exact rollback folder immediately before any registry or file mutation.
14. The original journal is not silently rewritten during inventory. It remains preserved until a successful restore closes the rollback.

### Fail-closed behavior

The following do not enter the current-user restore path:

- a QA2 `JournalScope='Machine'` pointer;
- elevated legacy state;
- wrong/ambiguous schema;
- extra or missing properties;
- wrong ActionId;
- foreign registry locations;
- files outside the current Startup folder;
- unexpected rollback-folder contents;
- reparse-backed directories/files;
- invalid backup paths, lengths, or SHA-256 values;
- tampered DPAPI payloads;
- DPAPI payloads belonging to another Windows profile.

Invalid state is preserved and inventory becomes incomplete so enable/uninstall fail before mutation or removal.

## Exact prior-version fixtures

The source and handoff include test-only copies of the exact QA2 bytes:

| Fixture | Size | SHA-256 |
|---|---:|---|
| `tests/fixtures/qa2/Nyx_PC_Checkup_1.0.0_QA2_Setup.exe` | 417,280 | `FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5` |
| `tests/fixtures/qa2/Nyx_PC_Checkup_1.0.0_QA2_Source.zip` | 209,483 | `22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36` |

These fixtures are for disposable-Windows migration regression only. They are not candidate or release artifacts.

## Added regression coverage

### Local/static

`tests/test_qa2_migration_reference.py` verifies:

- exact fixture hashes and safe ZIP structure;
- exact QA2 legacy schema in the prior source;
- valid registry and Startup-folder normalization;
- multi-digit/current schema identity;
- exact-field enforcement;
- current-user source allowlists;
- backup path/hash/length checks;
- tampering, Machine-scope, wrong scope, wrong types, extra/missing properties, and foreign paths;
- DPAPI-before-migration order in production source;
- in-memory normalization; and
- restore revalidation before mutation.

### Disposable Windows

`tests/powershell/Run-WindowsQA2MigrationRegression.ps1` requires `-DestructiveCleanVmAcknowledged` and covers:

- exact QA2 setup hash verification;
- QA2 HKCU Run journal creation → QA4 upgrade → exact restore;
- QA2 current Startup-folder journal creation → QA4 upgrade → exact-byte restore;
- successfully decrypted but tampered QA2 state failing closed;
- QA2 Machine pointer rejection from the current-user path;
- QA4 uninstall restoring an active QA2 current-user rollback before code/data removal.

## Historical regression preserved

QA3’s static corrections remain in QA4:

- **F-001:** all-users startup entries remain read-only; no supported runtime/native elevation path exists.
- **F-002:** legacy ProgramData machine rollback is independently discovered; uninstall fails closed on `Present` or `Unknown`.
- **F-003:** reports apply structured minimization before serialization, including secret-bearing property roles and IPv4/IPv6 redaction.

## Engineering boundary

Engineering can run the source/reference, packaging, reproducibility, PE, manifest, and archive gates on the local Linux build host. Windows PowerShell 5.1, DPAPI, registry, WinForms, UAC observation, installer upgrade/uninstall, and exact QA2 migration execution remain for Independent QA on disposable Windows 10/11 x64 snapshots.

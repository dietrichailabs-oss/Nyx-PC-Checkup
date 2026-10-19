# QA7 Windows Harness Corrected Reissue

This reissue preserves the exact QA7 product bytes and changes only Engineering acceptance-harness, evidence, documentation, and handoff metadata.

## QA7-WH-002
`Run-WindowsElevatedStartupRollback.ps1` and `Run-WindowsInstallerLifecycle.ps1` now load current QA7 application modules only through `core\RuntimeComposition.psm1` with the `Actions` profile. Each path asserts that `Get-NyxStableId` plus required startup/action commands are available before testing behavior.

## QA7-WH-003
`Run-WindowsQA2MigrationRegression.ps1` now records the exact current-user `Startup` and `CommonStartup` shell-folder strings, blank state, existence, read access, and current-user Startup write capability before exercising immutable QA2. An unsuitable disposable profile is reported as `PRECONDITION_BLOCKED` before QA2 runtime enumeration rather than surfacing an opaque empty-`LiteralPath` exception. The immutable QA2 setup/source fixtures are unchanged.

## Frozen product identity
- Setup SHA-256: `4EA98094F61A4ACA3299A84F6E15E24644EAAEE2DE2ADE2DBC8950CD2E18DE6D`
- Portable SHA-256: `23BF85ACE6B539A8D2E66F1FB96413AA14E433FEF1655C174F5AFA3E3153D4A8`
- Source SHA-256: `F54061A47A30DF09FE707F95F42D00B1EBAC229D7DF2D0EC39B9548CD6E42A9A`

Harness revision: `QA9-PS51-6`. Independent QA must rerun Smoke, Standard, QA2 migration, installer lifecycle, then Elevated.

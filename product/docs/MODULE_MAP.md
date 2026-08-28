# Module Map — Nyx PC Checkup 1.0.0

## Application shell

- `src/app/NyxPCCheckup.ps1` — bootstrap, single-instance boundary, top-level error handling, UI entry.
- `src/app/ui/MainWindow.psm1` — navigation, responsive scan/update worker coordination, user-confirmed actions, settings.
- `src/app/ui/Controls.psm1` — reusable WinForms controls.
- `src/app/ui/Dialogs.psm1` — result detail, export preview, and update-available dialogs.
- `src/app/ui/Theme.psm1` — Dark, Light, and Follow Windows palettes.

## Core

- `core/RuntimeComposition.psm1` — sole ordered module-composition root, exact export inventory, profile loading, conflict rejection, and cumulative command-surface validation.
- `core/Models.psm1` — structured check-result contract and stable IDs.
- `core/CheckupEngine.psm1` — check registration, isolation, aggregation, cancellation, persistence.
- `core/Paths.psm1` — fixed local-data map and ordinary-directory enforcement.
- `core/Configuration.psm1` — bounded defaults, repair, atomic save, weekly-update preferences.
- `core/Diagnostics.psm1` — rotating privacy-minimized local logs.
- `core/Privacy.psm1` — recursive role-based minimization and text/address redaction.
- `core/ActionHistory.psm1` — bounded action history, DPAPI state, strict current schema, exact QA2-user normalization, and fail-closed rollback inventory.

## Deterministic rules

- `health_rules/HealthRules.psm1` — storage, battery, uptime, aggregation, and state rules.
- `health_rules/rules.json` — documented conservative thresholds.

## Read-only checks

- `checks/SystemInfo.psm1`
- `checks/StorageHealth.psm1`
- `checks/StorageScan.psm1`
- `checks/DownloadsAnalysis.psm1`
- `checks/CleanupScan.psm1`
- `checks/StartupApps.psm1`
- `checks/WindowsUpdates.psm1`
- `checks/SecurityStatus.psm1`
- `checks/BackupStatus.psm1`
- `checks/BatteryHealth.psm1`
- `checks/DriveHealth.psm1`
- `checks/PerformanceSnapshot.psm1`
- `checks/InstalledApps.psm1`
- `checks/Uptime.psm1`
- `checks/NetworkBasics.psm1`

## Confirmed actions

- `actions/StartupActions.psm1` — current-user-only reversible startup changes, normalized-state revalidation, and independent legacy machine-rollback discovery.
- `actions/CleanupActions.psm1` — selected, revalidated Recycle Bin cleanup.

## Update availability

- `updates/Versioning.psm1` — SemVer parsing/comparison, including beta and RC identifiers.
- `updates/Manifest.psm1` — product configuration, schema/content validation, exact HTTPS destination allowlist.
- `updates/Preferences.psm1` — seven-day scheduling and UTC attempt persistence in existing config.
- `updates/UpdateChecker.psm1` — bounded public JSON fetch and result-state production.
- `workers/UpdateCheckWorker.ps1` — isolated non-elevated update-check process and atomic result IPC.

## Reports

- `reports/ReportExport.psm1` — privacy-safe report model, preview text, TXT/JSON/PDF export.
- `reports/PdfWriter.psm1` — small local PDF summary writer.

## Workers

- `workers/ScanWorker.ps1` — read-only Quick/Full scan.
- `workers/ActionWorker.ps1` — fixed non-elevated action allowlist and request-hash binding.
- `workers/InstallWorker.ps1` — fixed-root payload finalization, shortcuts, and uninstall registration.
- `workers/UninstallWorker.ps1` — legacy-machine check, current-user rollback restoration, fail-closed removal.

## Platform boundary

- `platform/windows/WindowsHelpers.psm1` — Windows-specific helper queries and redirects.
- `platform/linux/CONTRACT.md` — future Linux adapter contract only; excluded from the Windows runtime payload.

## Native packaging

- `native/launcher.cpp` — Windows GUI launcher.
- `native/uninstaller.cpp` — fixed-root uninstaller launcher.
- `native/installer.cpp` — embedded clean-payload setup.
- `native/app.manifest` — `asInvoker`, Windows compatibility, DPI metadata.
- `tools/build_release.py` — complete local build, tests, evidence, manifests, and handoff assembly.
- `tools/build_and_verify_reproduction.py` — two-pass local reproducibility verification.
- `tools/ps_lint.py` — network-free PowerShell structural lint.

## Test suites

- `tests/test_engineering_contracts.py` — source, safety, PE, package, manifest, documentation, and archive contracts.
- `tests/test_update_reference.py` — scheduling, semantic version, manifest, URL, and downgrade reference matrix.
- `tests/test_privacy_reference.py` — nested secret-role and IP-address minimization reference matrix.
- `tests/test_qa2_migration_reference.py` — exact QA2 fixture/schema and fail-closed normalization reference matrix.
- `tests/fixtures/qa2/` — byte-pinned QA2 setup/source fixtures for migration regression only; excluded from runtime.
- `tests/powershell/Run-WindowsSmokeTests.ps1` — normal-user smoke and privacy/update runtime suite.
- `tests/powershell/Run-WindowsElevatedStartupRollback.ps1` — privilege-boundary and legacy rollback suite; filename retained for QA continuity.
- `tests/powershell/Run-WindowsQA2MigrationRegression.ps1` — exact QA2 HKCU/Startup migration, tampering, Machine-pointer rejection, and uninstall restoration.
- `tests/powershell/Run-WindowsInstallerLifecycle.ps1` — fresh install, repair, rollback blocks, uninstall, reinstall, purge, and leftovers.

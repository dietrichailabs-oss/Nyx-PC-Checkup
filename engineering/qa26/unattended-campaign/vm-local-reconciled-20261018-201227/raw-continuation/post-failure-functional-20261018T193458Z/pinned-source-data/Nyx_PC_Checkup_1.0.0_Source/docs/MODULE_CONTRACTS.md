# Module Contracts — Nyx PC Checkup 1.0.0

## Global rule

A module may perform only the responsibility documented here. Read-only checks cannot call modification modules. UI code cannot parse remote update metadata or own health thresholds. A failed module must return an explicit failure/Unknown result or a bounded action response; it must not silently continue after an uncertain mutation.

## Application shell contract

The shell owns startup, shutdown, single-instance behavior, navigation, DPI/theme initialization, worker lifecycle, and the top-level error boundary. It must not implement storage thresholds, registry mutation, file deletion, manifest parsing, or network transport.

## Runtime-composition contract

`core/RuntimeComposition.psm1` is the only owner of application-module loading. Runtime `.psm1` files must not import or force-reload one another. The composition root owns the ordered dependency profiles used by the application and workers, resolves every module to an ordinary file inside the exact application root, rejects same-name modules loaded from another path, imports a module to global caller scope at most once, and verifies the cumulative expected command surface after every dependency layer.

A module that is already loaded from the exact application path but has lost an expected public command is an error. Composition must fail closed rather than implicitly reload it. Repeating the same composition profile must be idempotent and preserve command identity and availability.

Every runtime module and every exported function must be registered in the composition inventory. The Windows smoke gate must load the complete real graph, verify the five shared result-model commands after full composition, repeat composition, and launch the guarded real application Quick Check path twice.

## Check contract

A check may query supported local operating-system and file metadata, run bounded local analysis, and perform the documented DNS-resolution diagnostic. It must not:

- delete or move files;
- modify startup configuration;
- change Windows Update, Windows Security, firewall, DNS, proxy, or service state;
- uninstall software;
- request elevation;
- upload system information.

Each returned result contains check ID, category, name, status, severity, finding, reason, evidence, recommendation, action safety level, timestamp, data source, completeness, and error reason where applicable.

## Checkup-engine contract

The engine owns registration, bounded execution, progress, cancellation, check-level exception isolation, status aggregation, and latest-scan persistence. One failed check cannot cancel unrelated checks. Cancellation preserves completed partial results. Scans are explicitly marked read-only.

## Health-rule contract

Rules are deterministic and centralized. Boundary values are tested. Unknown data produces **Unknown**, not an invented healthy or critical state. There is no opaque 0–100 score.

## Configuration contract

Configuration uses the existing per-user `config.json`. Load and save reject directories, reparse-backed destinations, oversized files, malformed JSON, unsupported enums, and out-of-range numeric values. Invalid values are repaired conservatively and persisted atomically.

The update preference contract is:

- `updates.enabled` — Boolean, default `true`;
- `updates.lastCheckUtc` — empty or normalized UTC timestamp.

No second settings database is permitted for update checks.

## Privacy contract

`Protect-NyxObject` recursively minimizes a structured object before serialization. Exact secret-bearing role names after punctuation/case normalization are redacted. Strings redact profile paths, usernames, valid IPv4/IPv6 tokens, bearer values, assignment-style secrets, and email addresses according to report options. Traversal depth is bounded.

Report export, action history, and diagnostic logging must invoke privacy minimization before persistence. Raw passwords, tokens, authorization values, hardware serials, product keys, browser data, document contents, and private keys are never intentional report fields.

## Startup-enumeration contract

The startup check reads five supported Run/RunOnce locations plus current/common Startup folders. It does not label unfamiliar software malicious and does not claim impact without evidence.

Current-user entries are marked modifiable. `HKLM` and Common Startup entries are marked all-users/read-only with `RequiresElevation=true` only as descriptive source metadata; no action may use that flag to elevate.

## Current-user startup-action contract

Writable sources are limited to current-user Run, RunOnce, and Startup folder entries. The action must:

- require explicit confirmation;
- reject all-users, machine-scope, wrong-user, stale, malformed, unsupported-value, and out-of-boundary states;
- revalidate current state;
- write a DPAPI CurrentUser journal before mutation;
- preserve a journal after a partial mutation failure;
- refuse conflicting restore;
- close the journal only after exact restore.

The action worker is non-elevated. Runtime source must contain no `RunAs` or machine-startup mutation path.

## QA2 current-user migration contract

A legacy current-user journal may be accepted only after DPAPI `CurrentUser` unprotect succeeds. The decrypted object must match the exact QA2 user schema, have a matching 32-character ActionId, `JournalScope='User'`, actual Boolean `RequiresElevation=false`, and the exact expected empty legacy owner field.

Registry sources are limited to HKCU Run/RunOnce with String or ExpandString values and no file-backup metadata. Startup-file sources are limited to the current user’s Startup folder with an exact backup path under the matching rollback action, exact length/SHA-256, ordinary-file checks, and no unexpected/reparse-backed data.

A valid object is normalized in memory to `JournalVersion=1` and the current Windows SID, then validated under the current schema. Restore must perform current-schema and rollback-folder validation again before any registry/file mutation. Inventory does not overwrite the original QA2 journal. Invalid or ambiguous state is preserved, inventory is incomplete, and enable/uninstall fail closed. A Machine-scope pointer never enters this contract.

## Legacy machine-rollback contract

QA7 may only discover legacy QA2 state under `%ProgramData%\DietrichAI.NyxPCCheckup\startup-rollback`. Discovery must begin from ProgramData itself and cannot depend on a per-user pointer.

The result is:

- `Clear` — root absent or contains no obligations/errors;
- `Present` — one or more valid machine journals exist;
- `Unknown` — storage is inaccessible, malformed, unexpected, oversized, or reparse-backed.

`Present` and `Unknown` block uninstall before removal. QA7 never creates, restores from, or uses a legacy machine journal to authorize a write.

## Cleanup-preview contract

Preview scans only approved roots, does not select candidates by default, stops at documented file/time/count bounds, exposes completeness and stop reason, and does not delete anything.

## Cleanup-action contract

The action accepts only stable IDs from a fresh approved candidate set. It revalidates ordinary-file status, parent chain, reparse status, category, size, and timestamp immediately before action. Supported files go to the Recycle Bin. Partial failures preserve unprocessed files and report exact results.

## Update-version contract

Version parsing follows the project’s SemVer-compatible formats, including `1.8.0-beta`, `1.8.0-beta.2`, and `1.0.0-rc.8`. Numeric components are compared numerically, prerelease precedence is respected, malformed values fail safely, and an older manifest version never produces an update offer.

## Update-manifest contract

Only schema version 1 and product ID `nyx-pc-checkup` are accepted. Required fields are validated; unknown fields are ignored. Display text is bounded and control-character checked. SHA-256, when present, must be exactly 64 hexadecimal characters.

Permitted destinations are HTTPS on `www.dietrichailabs.com`, port 443/default, with no user info, fragment, or query:

- exact manifest: `/updates/nyx-pc-checkup.json`;
- exact release page: `/apps/nyx-pc-checkup/`;
- download destination beneath `/downloads/`.

## Update-network contract

The checker performs one GET only when due or manually requested. It keeps normal TLS verification enabled, rejects redirects, uses a five-second timeout, accepts only JSON content type, requires strict UTF-8, and caps the body at 64 KiB. Failure returns `CHECK_FAILED` and never prevents application launch or normal use.

The optional test transport provider in `Invoke-NyxUpdateCheck` is used only by the Windows QA harness to inject deterministic errors. Production UI and worker code never supply it; the compiled endpoint and all validation remain unchanged.

## Update-UI contract

The UI owns scheduling invocation, user setting, manual command, same-session notification suppression, and native-themed messages. It consumes only the worker result envelope. It must not fetch, parse, or compare remote manifest content itself.

**View Update** may open only a previously validated official release URL. **Remind Me Later** dismisses the prompt without disabling update checks or changing the installed version.

## Report contract

TXT, JSON, and PDF exports use the same privacy-minimized model. The user sees a preview before choosing the output path. Export failure does not alter scan data.

## Installer-diagnostics contract

The QA-only `/diagnostics:"<path>"` argument may create one new UTF-16 JSON evidence file only when the parent is an existing ordinary directory, the filename contains `Nyx_PC_Checkup_Setup_Diagnostics_`, the extension is `.json`, and the destination does not already exist. It never overwrites a file.

Success and every setup exit branch record a stable branch ID, process exit code, native error, child-finalizer exit code, `%LOCALAPPDATA%`, intended/resolved parent and target, attributes, reparse state, bounded parent write-probe result, and payload/detail location where relevant. Diagnostics do not weaken any installation boundary or change the selected branch.

## Installer contract

Setup installs per user to the fixed LocalAppData Programs path. It validates ordinary directories, rejects reparse/collision boundaries, extracts only the embedded allowlisted payload, verifies size/hash identity, finalizes shortcuts/registration transactionally, and rejects a running application mutex. It installs no service, driver, scheduled task, firewall rule, or updater.

## Uninstaller contract

Uninstall validates the exact install root and application directory. Before any removal it:

1. independently evaluates legacy machine rollback and exits 7 on `Present` or `Unknown`;
2. validates every current-user journal and exits 6 on incomplete inventory;
3. restores every active current-user startup change and exits 6 on any failure.

Only then may it remove registration, shortcuts, the application, and optionally local data. A quiet uninstall preserves local data unless `/purgedata` is explicitly supplied.

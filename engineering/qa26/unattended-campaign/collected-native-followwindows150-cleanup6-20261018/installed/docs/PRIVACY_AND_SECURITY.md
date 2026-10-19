# Nyx PC Checkup 1.0.0 — Privacy and Security Notes

## Privacy defaults

Nyx PC Checkup has no telemetry, analytics, advertising, tracking, account, cloud synchronization, automatic report upload, remote inventory, or persistent device identifier. It does not inspect browser history, cookies, passwords, authentication tokens, document contents, product keys, or hardware serial numbers.

**Privacy: Everything analyzed by PC Checkup stays on this computer unless you explicitly export it.**

## Deliberate network operations

Version 1 has two narrow outbound-capable operations:

1. Network Basics may perform one bounded DNS resolution of Microsoft’s Windows connectivity-check hostname and records only success/failure.
2. The weekly update checker may fetch public JSON metadata from `https://www.dietrichailabs.com/updates/nyx-pc-checkup.json` at most once per seven days, unless the user starts a manual check.

The update request intentionally sends no username, machine name, hardware identity, document data, local paths, application inventory, scan results, usage history, email address, or telemetry. It uses a minimal product/version User-Agent. It does not upload application or user data. Normal network metadata inherent to HTTPS may still be processed by network and hosting infrastructure.

Neither operation changes DNS, proxy, firewall, routing, adapter, browser, Windows Update, or security configuration.

## Report and log minimization

Report objects are recursively minimized before TXT, JSON, or PDF serialization. Secret-bearing property roles—such as passwords, tokens, authorization values, cookies, API/access keys, client secrets, credentials, private keys, connection strings, and protected rollback state—are replaced with `[REDACTED]`.

Text fields additionally redact profile paths, usernames by default, email addresses, Bearer values, IPv4, compressed/expanded IPv6 such as `::1` and `2001:db8::1`, and IPv4-mapped IPv6. The user previews a report before export.

Logs are local, rotating, size-capped, redacted, and user-deletable. Production logging does not intentionally capture file contents or credentials.

## Local data and rollback

Per-user settings, logs, scan history, temporary worker envelopes, and current-user startup rollback data are stored beneath `%LOCALAPPDATA%\Dietrich AI Labs\Nyx PC Checkup`.

Current-user startup rollback is encrypted with Windows DPAPI `CurrentUser`, bound to the current Windows SID, constrained to supported `HKCU` Run/RunOnce locations or the current user’s Startup folder, and inventoried fail-closed. Unexpected files, malformed folders, invalid/oversized journals, reparse points, wrong-user state, or inaccessible storage prevent uninstall from deleting recovery code/data.

QA7 creates no machine-level rollback journals. For compatibility with the failed QA2 design, uninstall independently inspects `%ProgramData%\DietrichAI.NyxPCCheckup\startup-rollback`. A present, malformed, reparse-backed, unexpected, or inaccessible legacy obligation blocks uninstall before removal. QA7 does not elevate LocalAppData code to repair it.

## Privilege model

The application, workers, setup, and uninstaller run as the invoking user. Native manifests request `asInvoker`. Runtime and native source contain no `RunAs` path.

Nyx can modify only current-user startup entries. All-users `HKLM` and Common Startup entries are visible but read-only. Selecting one causes no UAC prompt and no change.

## File-system and registry safety

Storage and Downloads checks skip directory reparse points and apply file/time bounds. Cleanup does not accept arbitrary UI paths; it works from bounded allowlisted scans, stable candidate IDs, current metadata, and repeated parent-chain/reparse validation immediately before Recycle Bin use.

The only application-directed operating-state modification is an explicitly confirmed current-user startup disable/restore, plus per-user installer registration/shortcuts and explicitly selected cleanup. Nyx does not run a registry cleaner or modify Windows Update, Defender, firewall, services, drivers, networking, browsers, or policy.

## Update manifest security

The update checker uses HTTPS with normal platform certificate validation. Redirects are disabled. Timeout and response size are bounded. JSON is treated as untrusted data and validated for schema, exact product ID, required fields, SemVer, lengths, optional SHA-256 shape, and allowlisted Dietrich AI Labs destinations. Server content is never evaluated or executed.

The feature is notification-only. It does not download executables, launch installers, add an updater service/task, or replace the application.

## Package safety and signing

The runtime payload is built from an allowlist. Setup rejects unsafe staging/target boundaries and verifies exact path, size, SHA-256, file count, and absence of reparse points before registration. Source, tests, QA evidence, logs, caches, credentials, user data, Git metadata, and superseded builds are excluded from the installed runtime.

This Engineering QA candidate is unsigned. Code signing belongs to release management after exact-artifact QA and required security/compliance approvals. Signing changes bytes and requires final identity validation.
## QA2 user-journal compatibility security boundary

Compatibility does not relax DPAPI ownership or source boundaries. DPAPI CurrentUser decryption must succeed first. Only the exact QA2 non-elevated user schema is normalized, and the normalized state is validated under the current schema before restore. Machine scope, foreign paths, wrong types, extra/missing fields, reparse points, unexpected files, and mismatched file identities fail closed. The legacy protected journal is not rewritten during inventory.


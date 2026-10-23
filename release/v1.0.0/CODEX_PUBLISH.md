# Codex: Finish and Publish Nyx PC Checkup 1.0.0

## Authoritative mandate

The owner authorized public release of the **working QA27 application** on **October 22, 2026**, and ordered GitHub/documentation to match. Do not delay only to rerun historical DPI matrix or to ask for an execution-policy-compatible baseline the audit could not identify. Keep unfinished test/security verdicts accurate; do not claim a PASS where one doesn't exist.

Repository: `dietrichailabs-oss/Nyx-PC-Checkup`  
Release prep branch: `release/v1.0.0-owner-authorized-20261022`  
QA27 frozen application source: `ee357ca33dbb87653924c6def90ff29a38898fdb`  
Build: `2026.10.19-eng-qa27`  
Product: **1.0.0**

## Final release artifacts

Use this branch's:
- `release/v1.0.0/README.md`: real quick-start with installation, use, troubleshooting.
- `release/v1.0.0/USER_GUIDE.md`: full page-by-page documentation.
- `release/v1.0.0/LICENSE.txt`: public freeware, not engineering-only terms.
- `release/v1.0.0/RELEASE_NOTES.md`: accurate changes/known limitations.
- `release/v1.0.0/OWNER_RELEASE_AUTHORIZATION.md`: owner decision and separate technical verdicts.

Publish installer, portable ZIP, public documentation and computed SHA256SUMS (byte sizes + actual SHA-256).

Known prior identities:
- Unsigned frozen QA27 setup: 553,984 B, `8251F288E069F9B94DC98FF6B87E2C70326EAE8888FFA41B64E90C4527165EE8`.
- Portable QA27 ZIP: 218,651 B, `C59D1726E43C3EDE8E0AAC6014B067207102CBB51F9E2308265E597FCA6AB610`.
- Owner self-signed setup (same underlying executable, Authenticode addition): 555,984 B, `59A30F5194AB638DB3CBD162D6E89D1127360465D7EAFF6FCA3FC8CDCEB7D6AE`.

Signing may change container bytes. Do NOT call changed files hash-identical. Do NOT expose private keys, cert passwords, private evidence/scan data or QA archives in public downloads. Preserve third-party notices.

**The original embedded candidate license and some old user docs are stale.** Replace/supersede them for actual shipped public packages, but if it requires rebuilding/repackaging, assign **new exact artifact identities and smoke-test those release bytes**. Don't silently mutate frozen QA27 product artifacts.

## Bounded release smoke — no new QA marathon

Use actual release binaries: verify install/launch (non-admin), visible single instance and close/reopen, Quick check readable results, TXT and PDF exports, normal action navigation, source/payload hashes, uninstall/repair only on a safe isolated disposable test environment, no unexpected permission/security changes, and packaged documents/third-party notices. No DPI changes or F-008 matrix.

Owner PDF manual integration: legitimate same-code PASS_OBSERVED; it does not prove all boundary tests. Native direct-module suites/lifecycle/migration remain BLOCKED or NOT_RUN until separate compliant route; do not fabricate completion.

## GitHub promotion and publication

1. Create an ordinary PR from this release prep branch to `main`; remove obsolete QA11-era current-state text. No force-push or destruction of historical Engineering branches/reviews.
2. Merge using repository rules and record final source commit. If there is a mandatory approval gate, report it honestly rather than bypassing protections.
3. Tag final approved publication commit as `v1.0.0` **once**; do not move tag later.
4. Create proper release notes and upload **exact final signed setup**, portable ZIP, end-user README/guide, license, release notes and SHA256SUMS.
5. This repo is private; a GitHub release alone cannot be considered a **public download**.
6. Use actual authorized Dietrich AI Labs website/deployment workflow for public binaries. Verify downloaded hashes via public links.
7. Update `/updates/nyx-pc-checkup.json` **last**, to advertise v1.0.0 using real verified URLs and the existing accepted schema; do not invent links. Retain rollback manifest.
8. Update site product page to say FREEWARE, Windows 10/11 x64, with accurate privacy/limitations. It checks update availability, not “updated weekly” and not automatic installation.
9. Report final Git tag, release URL, public site URLs, uploaded byte lengths/hashes, website/feed verification and any blocked actions.

Do not close Issue #16 as security-approved. Issue #18 may document observed PDF functional resolution, but do not convert absent native scripts into passed tests.

## Final rule

**Ship on the owner's authority, with honest technical limitations.** Do not keep the owner babysitting routine Git, hashing, tagging, publishing or QA evidence. Stop only for a NEW material security/safety/data-loss defect or a truly impossible deployment credential/action, and report that precisely.

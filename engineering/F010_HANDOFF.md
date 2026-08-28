# Engineering Handoff — F-010 Persisted Scan Validation

## Git target

Repository:

`dietrichailabs-oss/Nyx-PC-Checkup`

Branch:

`eng/f010-persisted-scan-validation`

Tracking issue:

`#1 — QA11-F-010 — validate persisted cancelled-scan state before relaunch`

## Frozen failed baseline

Build: `2026.08.27-eng-qa11`

```text
Source ZIP SHA-256:  19AAE16749580CA8023711E081B1DCFDC0728CA5C6301DD55716E385CA775470
Source tree SHA-256: C4273FA058A9151EF7E51EDE2EC264892CA707FF5957B7F5C39EA0DB7D599EAA
```

The exact QA11 product source is already imported under `product/`. Do not re-import, regenerate, or silently rewrite the baseline before beginning the correction.

## Problem

Native QA sequence:

1. Start Full Check.
2. Cancel while `Cancel scan` is enabled.
3. Close Nyx; exit 0; no resident process.
4. Relaunch immediately.
5. Relaunch exits 1 with `PropertyNotFoundException: Status`.

Likely boundary:

```text
ScanWorker partial result production
  -> Save-NyxScanResults
  -> scans/last-scan.json
  -> Get-NyxLastScan
  -> MainWindow/Home rendering under StrictMode
```

## Required correction

Do **not** merely catch `PropertyNotFoundException`.

Create one authoritative persisted-scan validation/normalization contract.

Every persisted result accepted by the current UI/reporting layer must have valid required fields including:

- CheckId
- Category
- Name
- Status
- Severity
- Finding
- Reason
- Recommendation
- Complete

Supported Status values:

- Good
- NeedsAttention
- Optional
- Unknown

Malformed/unsupported historical state must:

- never crash the UI;
- never be silently treated as Good;
- never trigger a mutation;
- degrade to a safe no-usable-previous-scan / Unknown-type state;
- produce only privacy-safe diagnostics.

Audit the cancelled/partial scan producer so every object persisted in `Scan.Results` satisfies the current result model before `Save-NyxScanResults` commits it.

## Mandatory regressions

Add source and native-Windows regression coverage for:

- cancel immediately after Full Check begins;
- cancel during early checks;
- cancel during update/security checks;
- cancel during storage/profile enumeration;
- cancel during Downloads analysis;
- cancel during Cleanup preview;
- immediate relaunch after each cancellation;
- invalid JSON;
- wrong schema;
- missing/null/empty Results;
- one result missing Status;
- unsupported Status;
- result missing Category/CheckId/Finding;
- cancelled scan with zero valid results;
- valid partial scan;
- older supported scan shape if backward compatibility is intentionally preserved.

None may crash the UI.

## Do not regress

Carry forward F-001 through F-009.

Minimum native baseline already passed by QA11:

```text
Smoke                         107/107 PASS
Standard privilege/rollback   12/12 PASS
QA2 migration                244/244 PASS
Standard lifecycle            44/44 PASS
Elevated privilege/rollback   14/14 PASS
Elevated lifecycle            50/50 PASS
```

Preserve the F-008 responsive UI correction and F-009 bounded temporary-file cleanup.

## Packaging and return

After source correction/tests:

1. build from clean allowlisted staging;
2. reproduce source/package manifests;
3. produce a new immutable Setup / Portable / Source candidate;
4. record sizes, SHA-256 values, and source-tree identity;
5. open a PR to `main` referencing #1;
6. include exact test counts and changed-file scope;
7. route the exact immutable candidate to Independent QA.

Engineering does not self-approve QA PASS.

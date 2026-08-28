# Engineering Handoff — F-010 Persisted Scan Validation

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

Create one authoritative persisted-scan validation/normalization contract.

Every accepted result must have valid fields including:

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

Malformed/unsupported historical state must never crash, must never silently become Good, and must degrade to a safe unavailable/Unknown prior-scan state.

## Mandatory regressions

Test cancellation at multiple timing points plus malformed persisted-state cases, including invalid JSON, wrong schema, missing/null/empty Results, missing Status, unknown Status, and valid partial scans.

Preserve the already-green QA11 Windows baseline and F-001 through F-009.

# QA22 F-019 collection-cardinality correction

QA21 remains frozen. Successor build: `2026.09.27-eng-qa22`.
Harness: `QA22-F019-PS51-22`. Authority: Issue #11.

## Audited category callers

- Generic category page: confirmed unsafe direct function output followed by `.Count`; normalized at caller.
- Home group cards: downstream status helper already accepts object[] and filtered count already uses @(...); normalized caller for a consistent collection contract.
- Storage: downstream grid accepts object[]; normalized caller for the same contract.

## Nearby UI audit

- Home findings and status filters already use array subexpressions before Count.
- Storage folder result, Apps inventory result and Cleanup preview result use @(... | Select-Object -First 1), with Count guards before [0].
- Apps Details are normalized with @(...); Startup inventory reload uses @(Get-NyxStartupApplications).
- Progress lines use @(Read-NyxCompleteProgressLines) before Count/index access.
- SelectedRows/Controls/Columns are WinForms collections, with selection guards before index access.
- Cleanup IDs and device geometry nodes are explicit generic lists, not enumerated function output.
- Dialog and theme helpers consume scalar contracts; no additional pipeline Count/Length hazard identified there.

No exception suppression or StrictMode relaxation. No change to prior F-010 through F-018 corrections or update wording. Deferred callback lifetime concerns outside the F-019 cardinality class are not silently changed in this patch.

## Evidence boundaries

The deterministic harness executes unchanged extracted product page functions with real WinForms grids under PowerShell 5.1. Presentation-only status/privacy dependencies are test doubles. It is not installed interactive acceptance.

QA21 supplemental current guest logs/persisted state have not yet been collected. The original exception screenshots remain frozen and sufficient for Issue #11 classification. No QA22 installed or full-matrix acceptance is claimed by this document.

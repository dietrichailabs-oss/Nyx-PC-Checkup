# QA26 Engineering evidence handoff, October 19, 2026

EVIDENCE ONLY. Campaign incomplete. Independent QA retains final PASS / HOLD / FAIL. No release or security approval.

## Start here

- Authoritative Engineering scoreboard: **328 PASS / 1 FAIL**; matrix **83/132 ledger-complete** (strict 56/99, best-effort 27/33).
- This publication runs no tests and adds no acceptance credit. It publishes existing Oct 13-18 evidence and current ledgers, with earlier dependencies retained.
- Current STATE, HUMAN_ACTION_QUEUE and SCOREBOARD_CURRENT are under ../../unattended-campaign/.
- Read ../../unattended-campaign/vm-local-reconciled-20261018-201227/RECONCILIATION.md and HOST_RECONCILIATION.json for predicate-level qualification and raw references.
- The archive contains the complete preserved campaign, including Git-ignored logs/native outputs. FILE_INVENTORY.json records SHA-256, bytes, original creation and modification times for every included source file.
- Archive download and independent Git commit references are supplied on the evidence prerelease: https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/releases/tag/qa26-engineering-evidence-20261019_212515-r1

## Reconciliation, not reruns

The prior published branch supported 312 Engineering PASS / 0 FAIL and 83 matrix cells. The intervening preserved host batch established 318 / 0. Recovered VM-local evidence then qualified ten previously executed assertions and one PDF failure, yielding 328 / 1. No additional matrix cells or host-resumption tests were credited. The 149 historical signed-copy-scope assertions remain explicitly scoped and are not exact-frozen acceptance results. Five historical Light125 completed-cell identity dependencies remain reserved for review; 83 is the ledger count, not an Independent QA acceptance decision.

## Preserved PDF failure

Native PDF Save reported: Cannot bind argument to parameter 'Lines' because it is an empty string. No PDF was produced. See PDF_EXPORT_FAILURE_QUALIFICATION.json under raw-continuation/functional-exports-20261018T192122Z in the reconciled package. Error screenshot SHA-256: 1C86BEA7B76DD9BA1344CE804684F03679A450D374A5442CE38A586F3CD8FD0F. Frozen bytes are unchanged; failure was not rerun or fixed. Independent QA classification is pending. The full F-010 suite is not declared complete.

## Remaining limits and decisions

- Lifecycle/migration remain BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE. No approved untouched compatible native Windows PowerShell 5.1 baseline is qualified; do not change policy or use a QA-created Bypass, alternate engine or launcher trampoline.
- Future DPI/layout testing is owner-excluded, not completed. Existing DPI records are preserved as historical evidence only.
- Retain unqualified/stale-image attempts and do not repeat them. An earlier unintended TXT repeat during overwrite setup is disclosed and uncredited; overwrite-decline was not exercised.
- Seventeen original capture JSON files contain unquoted Infinity geometry. Preserve those bytes. Inspection-only views did not use invalid geometry to qualify outcomes. See NONSTANDARD_CAPTURE_AUDIT.json.
- Disputed metadata, historical missing identity dependencies and Settings readability remain for Independent QA. No missing result is inferred.
- Original authoritative Full raw is recovered with contract-only, zero additional credit; worker cleanup and retrospective DPI are not established.
- Launcher security is separate: https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/16 remains OPEN / NOT APPROVED. F-011 39/39 functional evidence is eligible for review, not security approval.

## Immutable identity

Frozen source: 0303a78a06f67252c86634cd73f1e4bda32dd3cc. Build: 2026.10.02-eng-qa26. Harness: QA26-F023-PS51-26.

Setup SHA-256: A2D3571A1C96FCD39A95E40376FE0861AAC27C58545C3842DE75EB19B2E9331C.

PAYLOAD_MANIFEST SHA-256: B1A6490BAB92A7DEABC38A3A5B3748926BE3F6B3ADB1404912313450C45EC56B.

F-011 raw report SHA-256: A5539F18E62F9F3B980F37F889D1AFA2B1BDCD7A1F19C4356653AF2D3688492B.

The archive is preserved evidence, not a new installer, release candidate, or product distribution. Installed module copies are historical identity evidence only. Unrelated ChatGPT-installer records, VM disks, Git internals and recursive archives are excluded.
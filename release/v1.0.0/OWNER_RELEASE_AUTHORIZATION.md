# Owner-Authorized Release — Audit Record

**Decision:** OWNER_AUTHORIZED_PUBLIC_FREEWARE_RELEASE  
**Date:** 2026-10-22  
**Product:** Nyx PC Checkup 1.0.0  
**Source:** ee357ca33dbb87653924c6def90ff29a38898fdb  
**QA27 build:** 2026.10.19-eng-qa27

The product owner directed public release after installing the QA27 F-024-corrected application on a physical Windows PC and successfully using it, including TXT and PDF export. A supplied 3-page PDF parsed/rendered successfully. The owner-signed installer was independently confirmed to contain the frozen QA27 unsigned executable image plus a 2,000-byte Authenticode signature addition.

This is a distribution/business authorization, **not an Independent QA PASS or security review approval**. QA27 native PowerShell focused runner was denied by Restricted execution policy; some lifecycle/migration suites are not completed; QA26 prior results do not automatically transfer to QA27; launcher security Issue #16 remains open. Historical F-008 matrix: 83/132 recorded, 49 waived by owner (not PASS). Preserve these statuses and the historical evidence.

Release operator may finalize end-user documentation, freeware license, final package signing/packaging, GitHub project status, binaries and official website/update feed. Every changed binary/ZIP needs a fresh actual SHA-256 and validation; never falsely claim byte identity to earlier candidates. Stop for any NEW material security, privacy or data-loss discovery. Do not invent public download URLs or Independent QA/security approval.

The owner wants completion without repeating the waived DPI matrix or demanding an unavailable PS5.1 executor. The official public-upload status is separately verifiable and must be reported truthfully.
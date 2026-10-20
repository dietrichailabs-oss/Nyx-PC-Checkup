# QA27 QEMU control recovery and Windows setup evidence

Snapshot UTC: 2026-10-20T00:30:44Z. This is a progress evidence snapshot. Engineering is continuing the normal Windows recovery path in a disposable QEMU overlay.

F-024 installed-GUI integration: NOT_EXECUTED_WINDOWS_PROVISIONING_RECOVERY_IN_PROGRESS. QA27 has not been installed, launched, or exported. Save count is 0. QA27 runtime results remain 0 PASS / 0 FAIL. No PDF success, native regression completion, or candidate acceptance is claimed.

## Frozen candidate

- Branch: eng/f024-pdf-export-empty-lines.
- Frozen source: ee357ca33dbb87653924c6def90ff29a38898fdb; source Git tree: 1a54ac83a5ab808cd80866b8fdb2b337c14dd2c3.
- QA26 base: 0303a78a06f67252c86634cd73f1e4bda32dd3cc.
- Build: 2026.10.19-eng-qa27; harness: QA27-F024-PS51-27.
- Source-tree SHA256: 103D15B084ED4CE02D314D89C7B2D92599122D0C2936113A1EF585355EC240D6.

| Artifact | Bytes | SHA256 |
|---|---:|---|
| Setup | 553984 | 8251F288E069F9B94DC98FF6B87E2C70326EAE8888FFA41B64E90C4527165EE8 |
| Portable | 218651 | C59D1726E43C3EDE8E0AAC6014B067207102CBB51F9E2308265E597FCA6AB610 |
| Source ZIP | 806768 | B0F7B77140E6B578738E17DE69836E100A18E0201040B53906D2A1EF10E393A5 |

[Immutable candidate and artifacts](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/blob/c8b9df9da754bd5c8ad00e5169b4d9fadd55104b/engineering/qa27/candidate-qa27-f024-20261019/README.md).

## Observations and limits

Computer Use was reconnected to a fresh returned QEMU window. Guest actions advanced Windows Setup through edition/license selection and installation to a new empty 48 GB virtual disk. Fresh captures and action outcomes are preserved. The full guest screen is now visible using QEMU's console-only Zoom To Fit; Windows display scale and resolution were not changed by QA. These wrapper captures provide no DPI/layout acceptance credit.

Transient QEMU menu actions require their popup-specific screenshot. A root-frame action intended for Zoom To Fit instead toggled Grab On Hover. Its state was restored off, and the popup-specific action then enabled console fit. See CONTROL_RECOVERY_NOTES.jsonl and 21_CONSOLE_VIEW_RECOVERY.json.

Correction: the earlier root-frame action intended for Machine > Power Down may have selected Quit. Process exit and clean QCOW2 container closure were verified; Windows ACPI shutdown is UNPROVEN. The original raw checkpoint receipt is preserved, with this qualification and the append-only correction ledger superseding its ACPI assertion.

Windows 10 Enterprise LTSC Evaluation installed its files and performed two automatic restarts, but welcome setup reached 'Why did my PC restart?' and requested an online update. This is an environment provisioning failure before QA27 execution. The screen, small Windows-created recovery logs, and immutable failed-disk hash are preserved. No specific root cause has been established.

Failed setup disk SHA256: BDAFD07D5018507F1BA598EF6E70ECF53C373A09109A8FC43B09348CBBAE0799. The recovery attempt uses a new QCOW2 overlay with that disk as read-only backing and a new copy of the dedicated FAT transfer volume. Local image paths and hashes are in 20_RECOVERY_CHECKPOINT.json.

Recovery configuration adds QEMU's built-in non-privileged user-mode NAT with an e1000 adapter. No host driver, shared folder, inbound port forwarding, firewall exception, VPN change, or security-policy change was introduced. [QEMU network documentation](https://www.qemu.org/docs/master/system/devices/net.html). The first normal recovery Next action was accepted and outbound connections were observed; its outcome is pending.

The copied Setup, preserved Full report, and both native read-only inspection helpers match their pinned hashes. Both inspected export directories were empty. No PowerShell QA harness is carried on the transfer volume, and the helpers do not launch the product or execute PowerShell modules.

## Remaining scope and blockers

The first eligible product case remains the exact installed shipped QA27 GUI path approved by [Issue #18](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/18#issuecomment-6278528488). Its bounded plan is in 15_GUI_EXECUTION_PLAN.json: verify installed payload and copied report, normal shipped launch, Export report -> Continue to save -> PDF summary -> fresh destination -> Save once, then inspect the actual file and preserve logs/captures/hashes. A successful outcome can qualify only PASS_OBSERVED/PENDING_INDEPENDENT_REVIEW for this integration component.

The already-denied native PS5.1 -File attempt was not repeated. Null/invalid/empty/consecutive-blank/page-boundary/TXT/JSON direct-module cases remain BLOCKED_ENVIRONMENT. This newly provisioned QEMU guest is not an approved untouched legacy native baseline. Lifecycle/migration remain blocked separately, and Issue #16 security review remains OPEN/NOT APPROVED.

QA26 remains 328 Engineering PASS / 1 FAIL, including its preserved PDF failure, with no added credit. All 59 installed QA26 payload files, its manifest, and preserved scan/config/history matched their pinned hashes during this session. Original Nyx VM operations: 0; its host-side Saved state was not independently rechecked.

[Issue #15 owner scope](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/15#issuecomment-6277826979) remains unchanged: historical matrix 83/132; remaining 49 are WAIVED_BY_OWNER_DPI_SCOPE_20261019. No new DPI tests, scaling transitions, matrix runs, or missing-DPI recovery were performed. No completed or executed-unqualified product case was repeated.

Independent QA owns final PASS/HOLD/FAIL. This snapshot grants no release or security approval.

## Evidence

Files are byte-preserving copies of the separate live continuation folder gui-disposable-20261019T223924Z as of the snapshot time. MANIFEST.json and SHA256SUMS.txt bind the copied records, helper sources, captures and logs. Windows media and virtual disks are located by their recorded local paths/hashes. Later execution evidence will be a separate append-only supplement.

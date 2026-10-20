# QA27 disposable guest recovery progress

This is an immutable progress snapshot, not a completed test run or candidate acceptance. F-024 installed-GUI integration remains NOT_EXECUTED because Windows out-of-box setup has not completed. QA27 installs, launches, exports and Save actions are all zero. Runtime remains 0 PASS / 0 FAIL. No product failure is inferred from Windows provisioning failures.

The prior snapshot is [31d32e279f5d769a0691ccb3a2210a8b862b507f](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/blob/31d32e279f5d769a0691ccb3a2210a8b862b507f/engineering/qa27/gui-control-recovery-20261020T003044Z/README.md). This delta adds new or changed live records in a fresh folder; unchanged evidence is referenced by hash in MANIFEST.json. Earlier files and append-only versions remain preserved.

QEMU controls are targetable and operable. The viewer is maximized with console-only Zoom To Fit and input grab off. Windows resolution, scaling, execution policy, UAC, trust, VPN and security settings were not changed. [QEMU documents these viewer controls separately from guest display settings](https://www.qemu.org/docs/master/system/qemu-manpage.html). No DPI testing or credit is claimed.

VM06 normal network recovery returned the same restart error. VM07 used four emulated CPUs and 3 GB RAM and reached region selection, then OOBEKEYBOARD and OOBELOCAL. The ordinary visible keyboard Skip advanced; a single ordinary OOBELOCAL Try again did not resolve the error. Its QEMU process exited following the correctly targeted ACPI Power Down request. The stopped QCOW2 dirty/corrupt flags were false; guest shutdown logs were not independently checked. Its preserved disk is 2,567,634,944 bytes, SHA-256 F834BC63F0771FDFB24FEE944C2CD8E1AEEFC8FA35FC0F81BDA1CAC8C1BC6494.

Read-only diagnosis used a separate flattened copy, never a mounted writable source disk. qemu-img compare returned exit 0 and Images are identical. The 10,903,814,144-byte flattened copy has SHA-256 830F896A12A523AA6D125238E9C5DF1A2D9A580A81FBD9C4B4BA5D8FC7CB5595. Selected original Windows logs and Application.evtx are preserved with hashes. They show LocalUser Plugin HRESULT 0x80070490, a 240-second update scan timeout, and a 19-second disk write. Root cause is unproven. Raw guest times are retained; setup changed its time zone normally, so outer time-zone conversion is not used to correlate events. No account, privacy, authentication, registry or policy workaround was attempted.

VM08 was mistakenly launched with its window hidden. Only the identity-checked owned emulator was stopped; its disk remains separate and guest clean shutdown is NOT claimed. No Nyx product case ran. VM09 uses a fresh child overlay of the preserved flattened VM07 disk and exact transfer-volume copy, with a visible normal launch, 4 GB RAM, four cores in one socket and 512 MiB TCG cache. The CPU model remains qemu64. Keyboard setup still failed, so the resource change has not resolved that error. VM09 is at the normal network setup transition after visible keyboard Skip; the outcome is pending at this snapshot. Current VM logs are not misrepresented as final closed logs.

Frozen QA27 source: ee357ca33dbb87653924c6def90ff29a38898fdb; Git tree: 1a54ac83a5ab808cd80866b8fdb2b337c14dd2c3. Build: 2026.10.19-eng-qa27. Harness: QA27-F024-PS51-27. Canonical source-tree SHA-256: 103D15B084ED4CE02D314D89C7B2D92599122D0C2936113A1EF585355EC240D6.

Pinned artifact SHA-256 values, already qualified in the prior preflight (not new runtime test credit):

- Setup: 8251F288E069F9B94DC98FF6B87E2C70326EAE8888FFA41B64E90C4527165EE8
- Portable: C59D1726E43C3EDE8E0AAC6014B067207102CBB51F9E2308265E597FCA6AB610
- Source ZIP: B0F7B77140E6B578738E17DE69836E100A18E0201040B53906D2A1EF10E393A5

[Issue 18 clarification](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/18#issuecomment-6278528488) remains the approved GUI route. The first product case must install and verify the exact frozen payload, safely stage the copied preserved Full report, launch the shipped EXE and export PDF to a fresh path with Save once. No scan or product launch has occurred. The read-only PDF inspection helper is prepared but unexecuted; it neither creates a substitute PDF nor grants direct-module coverage.

Native PowerShell boundary tests remain BLOCKED_ENVIRONMENT; the initial denied -File attempt was not repeated. Lifecycle/migration remain BLOCKED_ENVIRONMENT_LEGACY_PS51_IMPORT_BASELINE. This disposable guest is not that legacy baseline. Issue 16 is separate and OPEN / NOT APPROVED.

QA26 installation, evidence, old branch and PDF failure remain preserved. Original Nyx Saved VM was not accessed or operated. QA26 score stays 328 Engineering PASS / 1 FAIL, archived matrix 83/132, and remaining 49 are WAIVED_BY_OWNER_DPI_SCOPE_20261019. No QA26 credit is carried into QA27. No scoreboard was edited. Independent QA retains final PASS / HOLD / FAIL.

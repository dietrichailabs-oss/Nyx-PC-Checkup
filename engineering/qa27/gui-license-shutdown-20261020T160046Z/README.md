# QA27 Windows shutdown cause and post-account continuation

The owner completed normal Windows Account setup and reported that the window disappeared again. Read-only inspection confirmed QEMU was no longer running. The closed VM10 disk and transfer volume were preserved. The exact QA27 Setup/fixture/read-only helper file hashes still match and the EXPORT directory remains empty. No product case was executed.

## Confirmed disappearance cause

The original guest System.evtx contains User32 event 1074 for both latest shutdowns. Windows process C:\Windows\system32\wlms\wlms.exe initiated a planned shutdown with the message: The license period for this installation of Windows has expired. The operating system is shutting down. This establishes expired Windows evaluation licensing as the cause of the VM09/10 disappearances; it does not establish the cause of earlier OOBE errors. The original System.evtx is preserved here, SHA-256 0ACF980F75D8432C791DCB25FFDAF5BA6C2C2436351241735C8320A0FE15406B. Derived selected events retain their raw XML and messages. Guest times are retained without normalization against outer time-zone assumptions.

Source VM10 disk: 369,295,360 bytes, SHA-256 2EC6DC613054DD26D993CDA4D4D2305D95755693EBA585841FF2ED97ACADC236. A separate flattened diagnostic copy was made while stopped, and qemu-img compare returned exit 0, Images are identical. No original disk was mounted writable or repaired. VM11 is a fresh child overlay of that equivalent copy, preserving the owner account work. Transfer media is a fresh exact copy. No trial reset, rearm, clock rollback, license-service disabling, activation bypass, security-policy change or product change was used.

## Current exact prerequisite

VM11 / PID14116 was launched visibly at 2026-10-20T15:58:14Z with the same four-core / 4 GB configuration and QEMU viewer-only fit. It reached the Windows lock screen. Account setup has therefore progressed beyond the previous wizard. The owner has been asked only to unlock Windows inside QEMU and report the desktop ready, without sending a password. Computer Use guidance requires stopping at a locked desktop. No unlock input or further credential-screen capture was performed. Normal Windows activation has not yet been inspected because the desktop is locked. Broad approvals are already recorded; no routine approval is requested.

## QA disposition

F-024 exact installed-GUI remains NOT_EXECUTED_WINDOWS_DESKTOP_UNLOCK_PREREQUISITE. QA27 installs, launches, scans, exports and Save actions by the agent remain 0; runtime 0 PASS / 0 FAIL. The first product case remains the exact shipped Setup/payload verification/fixture/shipped EXE/PDF summary/fresh destination/Save once route approved in Issue18. The expired evaluation shutdown is an environment limitation, not a Nyx failure or GUI integration PASS. Do not reset licensing or misclassify environment interruptions as product failures. Stop on a genuine product failure, and preserve unknown/executed-unqualified outcomes without repeats.

Frozen source ee357ca33dbb87653924c6def90ff29a38898fdb; build 2026.10.19-eng-qa27; harness QA27-F024-PS51-27; canonical source-tree SHA-256 103D15B084ED4CE02D314D89C7B2D92599122D0C2936113A1EF585355EC240D6. Pinned Setup SHA-256 8251F288E069F9B94DC98FF6B87E2C70326EAE8888FFA41B64E90C4527165EE8, Portable C59D1726E43C3EDE8E0AAC6014B067207102CBB51F9E2308265E597FCA6AB610, Source ZIP B0F7B77140E6B578738E17DE69836E100A18E0201040B53906D2A1EF10E393A5. Product/source bytes are unchanged.

The denied native -File attempt was not repeated. Direct module coverage remains BLOCKED_ENVIRONMENT, lifecycle/migration still require the separately approved untouched compatible baseline, and Issue16 security review remains separate. This new disposable VM is not the legacy baseline. QA26 installation, evidence, old branch and PDF failure are preserved; score remains328 Engineering PASS /1 FAIL, archived matrix83/132 and49 WAIVED_BY_OWNER_DPI_SCOPE_20261019. No QA26 credit is carried into QA27. Original Nyx Saved VM was not operated. Independent QA retains final PASS / HOLD / FAIL.

Earlier Account/error progress and the cancelled, unexecuted fresh-install plan are preserved locally in gui-resume-20261020T105153Z and gui-clean-reprovision-20261020T111522Z. Their raw files are not claimed published by this snapshot. Previous published handoff remains https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/blob/3bf17b006144df367b285d05a83f4bf7bb18170f/engineering/qa27/gui-account-prerequisite-20261020T012759Z/README.md.

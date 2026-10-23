# Public release installer compatibility correction

Owner authorized fixing the publishing blocker on 2026-10-23.

The preserved documentation-updated installer returned exit 15. A separate private diagnostic build captured `CommandNotFoundException: Get-FileHash` in InstallWorker before integration changes. The same native PS5.1 process could resolve the hash function after explicitly importing its own Windows Utility module.

The correction imports `$PSHOME/Modules/Microsoft.PowerShell.Utility/Microsoft.PowerShell.Utility.psd1` with terminating errors and qualifies both existing Get-FileHash calls. No hash/size/path checks, rollback, or security boundary was removed. No execution policy, certificate trust, UAC, scaling, or machine protection was changed. This is not a QA bypass or a launcher trampoline.

The corrected signed final Setup returned 0 as a non-admin in isolated AppData. All 62 manifest files matched; existing current-user integration was restored after the check. The actual application launched with a native window. Owner then reported the requested Quick Check, result detail, TXT/PDF export, navigation, and close/relaunch worked. That is owner-observed functional evidence, not an independently automated GUI verdict. Public signing is self-signed, not a publicly trusted chain.

Application base remains QA27 source ee357ca33dbb87653924c6def90ff29a38898fdb. Only InstallWorker runtime bytes changed for this authorized correction; public documentation and packaging have new exact artifact hashes. Immutable QA26/QA27 engineering artifacts and failed packaging attempts remain preserved separately.

Historical DPI: 83/132 completed, 49 owner-waived, no new DPI work. Lifecycle/migration remain blocked and receive no credit. Issue #16 remains open; owner-authorized release is not independent security certification. No private scan/logs, signing keys, or internal evidence bundles are included in public downloads.

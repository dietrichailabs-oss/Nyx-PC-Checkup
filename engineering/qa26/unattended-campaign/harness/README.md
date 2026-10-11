# QA26 native evidence helper

Harness-only source; frozen product and build unchanged. No PowerShell execution-policy changes.

Status: NOT QUALIFIED FOR LIVE COLLECTION. Native inventory and checkpoint attempts returned Access is denied. Fixture runner fails because its comparator includes newly generated HELPER_PROVENANCE.json. Separate SHA-256 comparison matched 104 copied artifact files only; this is not full-helper or product acceptance. No live collection or clean snapshot was created.

CLI: inventory|checkpoint|collect|fixture OUTPUT [KNOWN_FIXTURE]. Outputs must be new directories. Full preservation checkpoints are not clean destructive fixtures. Collection intends graceful shutdown, read-only VHD attachment without drive letters, preserved exact records, detach and normal restart; these paths remain unverified.

Primary references:
- https://learn.microsoft.com/en-us/windows/win32/hyperv_v2/createsnapshot-msvm-virtualsystemsnapshotservice
- https://learn.microsoft.com/en-us/windows/win32/hyperv_v2/msvm-shutdowncomponent-initiateshutdown
- https://learn.microsoft.com/en-us/windows/win32/api/virtdisk/nf-virtdisk-attachvirtualdisk

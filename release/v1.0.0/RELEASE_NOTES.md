# Nyx PC Checkup 1.0.0 — Public Release Notes

**Publisher:** Dietrich AI Labs  
**OS:** Windows 10/11 x64  
**Price:** Freeware  
**Owner release authorization:** October 22, 2026

## First release

Local Quick/Full PC diagnostics with plain-language results, health views for storage, Windows updates, security, backup, startup, system and installed applications. Explicit current-user startup management, opt-in Cleanup, and TXT/JSON/PDF exports. Update checks are notification-only; no automatic software installation or diagnostic upload.

**PDF correction:** QA27 fixes the F-024 blank-separator binding failure. The owner installed a self-signed instance of the same executable code on a physical Windows PC and exported a valid readable PDF with three pages.

## Known limitations and disclosure

Firmware, TPM, Secure Boot, BitLocker, drive-health, backup and other Windows APIs may be unavailable and result in **Unknown**. Third-party backup providers may not be detected. Windows Update observations may reflect local cached data. Unusual display scale/viewport combinations may require scrolling; only 83/132 historical scale/theme matrix cells were completed and 49 remaining cells were owner-waived from release acceptance after VM scaling instability.

The owner authorized distribution despite outstanding complete Independent QA and security review; the product launcher security question remains open. This is **OWNER_AUTHORIZED_RELEASE**, not a claim of Independent QA PASS or third-party security certification. A self-signed installer is not publicly CA-trusted.

See [Quick Start](README.md), [User Guide](USER_GUIDE.md) and [Freeware License](LICENSE.txt).
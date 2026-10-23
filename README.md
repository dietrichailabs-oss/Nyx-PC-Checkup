# Nyx PC Checkup

**Nyx PC Checkup 1.0.0** is free, local-first Windows diagnostics and maintenance software from **Dietrich AI Labs**.

**Released:** October 23, 2026 · **Platform:** Windows 10/11 x64 · **License:** Proprietary freeware · **Account:** Not required.

## Download — official public website

- **[Product page, features and help](https://www.dietrichailabs.com/apps/nyx-pc-checkup/)**
- **[Windows installer — Setup.exe](https://www.dietrichailabs.com/downloads/nyx-pc-checkup/1.0.0/Nyx_PC_Checkup_1.0.0_Setup.exe)**
- **[Portable ZIP](https://www.dietrichailabs.com/downloads/nyx-pc-checkup/1.0.0/Nyx_PC_Checkup_1.0.0_Portable.zip)**
- [README and quick start](https://www.dietrichailabs.com/docs/nyx-pc-checkup/README) · [Full user guide](https://www.dietrichailabs.com/docs/nyx-pc-checkup/USER_GUIDE) · [Release notes](https://www.dietrichailabs.com/docs/nyx-pc-checkup/RELEASE_NOTES) · [Freeware license](https://www.dietrichailabs.com/docs/nyx-pc-checkup/LICENSE.txt)
- [SHA-256 checksum file](https://www.dietrichailabs.com/downloads/nyx-pc-checkup/1.0.0/SHA256SUMS.txt) · [Release availability manifest](https://www.dietrichailabs.com/updates/nyx-pc-checkup.json)

### Official v1.0.0 SHA-256

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `Nyx_PC_Checkup_1.0.0_Setup.exe` | 570,832 | `3AEE748C54267F7DDBAC9C3A36FA725BA3F14EFE63F4AEA905AD4615A3BDE972` |
| `Nyx_PC_Checkup_1.0.0_Portable.zip` | 226,589 | `FC9367AE8B9AD5CDCC01DDF356C3D24523AC370F7E8EF7D4021A79FDE2F5A66D` |

**[GitHub release v1.0.0](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/releases/tag/v1.0.0)** is the exact release record, but this source repository remains private. Use the **public official website** for downloads.

## What it does

Quick and Full PC checkups, plain-language **Good / Needs Attention / Optional / Unknown** statuses, and pages for Storage, Startup, Security, Updates, Backup, System, Apps and Cleanup.

- Scans are read-only. Supported current-user startup changes and Cleanup require explicit user confirmation.
- Export diagnostic reports to TXT, JSON or PDF.
- Local reports are not automatically uploaded.
- Nyx update checks only notify about availability; they do not automatically install software.

## Documentation and artwork

- [Quick start](release/v1.0.0/README.md) · [Full guide](release/v1.0.0/USER_GUIDE.md)
- [Release notes](release/v1.0.0/RELEASE_NOTES.md) · [Freeware license](release/v1.0.0/LICENSE.txt)
- [Responsive website-banner integration](release/v1.0.0/website/BANNER_INTEGRATION.md) · [Desktop hero](release/v1.0.0/website/hero-desktop.svg) · [Mobile hero](release/v1.0.0/website/hero-mobile.svg)

## Development and review

Final public release commit: `596c9e5257ab87ea3991efe7c025bd5a7861b9b9`. Corrected QA27 lineage began at `ee357ca33dbb87653924c6def90ff29a38898fdb`, build `2026.10.19-eng-qa27`.

Distribution is **owner-authorized**, not a claim that every independent QA/security gate passed. Launcher-security review [Issue #16](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/16) remains open. The historic 132-cell display-scaling matrix had 83 completed cells and 49 owner-waived (not marked PASS). This is not an antivirus program or automatic PC repair tool.

Authoritative source: `product/`. Historical testing evidence: `engineering/`, `qa/`. Workflow: [docs/WORKFLOW.md](docs/WORKFLOW.md).

Copyright © 2026 Dietrich AI Labs.
# Nyx PC Checkup

**Nyx PC Checkup** is a free, local-first Windows PC diagnostic and maintenance utility from **Dietrich AI Labs**.

**Version:** 1.0.0 • **Windows:** 10/11 x64 • **License:** Proprietary freeware • **Account:** Not required.

## What it does

Quick and Full PC checkups, clear **Good / Needs Attention / Optional / Unknown** findings, and views for Storage, Startup, Security, Updates, Backup, System, Apps and Cleanup. Ordinary scans do not change the system. Supported current-user startup changes and selected cleanup require explicit user action. Reports can be exported as TXT, JSON or PDF. Local diagnostic reports are not automatically uploaded.

## Download and instructions

Distribution is authorized by the product owner as of **October 22, 2026**. The actual public download channel must be verified by the Release operator. **This private GitHub repository is the source project, not a public download site.** Do not infer that downloads are live merely because release documentation exists.

- [Quick-start and program usage](release/v1.0.0/README.md)
- [Full user guide](release/v1.0.0/USER_GUIDE.md)
- [Release notes](release/v1.0.0/RELEASE_NOTES.md)
- [Freeware license](release/v1.0.0/LICENSE.txt)
- [Owner release decision](release/v1.0.0/OWNER_RELEASE_AUTHORIZATION.md)
- [Codex publishing instructions](release/v1.0.0/CODEX_PUBLISH.md)

## Engineering and provenance

Authoritative QA27 corrected application source commit: `ee357ca33dbb87653924c6def90ff29a38898fdb`. Build: `2026.10.19-eng-qa27`. The owner installed an Authenticode self-signed copy of the same executable on real hardware, used the application, and exported a valid readable PDF.

**OWNER_AUTHORIZED_RELEASE is not INDEPENDENT_QA_PASS.** Some test routes were unavailable; the separate shipped-launcher security review remains open ([Issue #16](https://github.com/dietrichailabs-oss/Nyx-PC-Checkup/issues/16)). The historical DPI matrix completed 83/132 cells; the owner waived the remaining 49 as a release gate without marking them PASS. Do not invent completed tests or security certification.

Source: `product/`. Historical QA evidence: `engineering/`, `qa/`. Process: [docs/WORKFLOW.md](docs/WORKFLOW.md).

Copyright © 2026 Dietrich AI Labs.
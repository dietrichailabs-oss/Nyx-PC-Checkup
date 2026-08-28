# Nyx PC Checkup 1.0.0 — User Guide

## Install

Open `Nyx_PC_Checkup_1.0.0_Setup.exe`. Setup installs for the current Windows user under `%LOCALAPPDATA%\Programs\Dietrich AI Labs\Nyx PC Checkup`, creates a Start-menu shortcut, and optionally creates a desktop shortcut. Installation and normal use should not request administrator access.

This Engineering QA candidate is unsigned, so Windows may display a reputation warning. Do not treat this package as publicly approved until the release gates are complete.

## Check the PC

Select **Check My PC** for the fast check or **Run Full Check** for additional folder analysis, Downloads, cleanup preview, battery/drive information, performance, and installed applications. Progress remains visible. You may cancel; completed partial results remain visible. A scan itself makes no repair or cleanup change.

Status language:

- **Good — No action needed:** available evidence did not show a meaningful problem.
- **Needs Attention — Recommended action:** evidence indicates a genuine reliability, storage, backup, update, security, or connectivity concern.
- **Optional — Your choice:** the PC can operate normally; the suggestion may improve convenience or reclaim space.
- **Unknown — Could not determine:** Windows did not provide enough reliable information. Unknown does not mean the PC is broken.

A healthy result can say: **Your PC looks good. Nothing needs fixing.**

## Review startup apps

The Startup page shows current-user and all-users entries.

Nyx can disable and restore only entries owned by the current Windows user: supported `HKCU` Run/RunOnce values and files in the current user’s Startup folder. A change requires confirmation. Nyx records a DPAPI-protected rollback journal before changing Windows state, and **Re-enable** restores the exact supported prior state when no conflict exists.

All-users `HKLM` and Common Startup entries are displayed **read-only** in Version 1. Selecting one does not request elevation and does not change the machine.

Do not disable security software, touchpad/audio utilities, backup tools, cloud-sync clients, or hardware support utilities unless you understand the consequence.

## Use cleanup safely

Run a Full Check, open **Cleanup**, review every candidate, select only desired items, read the exact total and consequence, and confirm. Nothing is preselected. Supported files are revalidated immediately before action and sent to the Windows Recycle Bin where practical. A failure leaves the file in place and is reported.

Nyx does not automatically delete Documents, photos, videos, general Downloads content, browser profiles, Windows Update files, restore points, Windows installer caches, app databases, cloud-sync data, saved games, or development files.

## Open official Windows settings

Nyx can open Windows Update, Windows Security, Backup, Storage, Installed Apps, and System settings. It does not reimplement Windows Update, replace antivirus, alter firewall rules, uninstall applications automatically, install drivers, or change DNS/proxy settings.

## Check for Nyx PC Checkup updates

Settings provides:

- **Automatically check for updates once a week** — enabled by default.
- **Check for Updates Now** — available at any time and bypasses the weekly timer.

Nyx fetches public metadata from `https://www.dietrichailabs.com/updates/nyx-pc-checkup.json`. A newer version prompt offers **View Update** and **Remind Me Later**. **View Update** opens the allowlisted official Dietrich AI Labs release page in the default browser.

Nyx does not download or install the update. Automatic failures are unobtrusive and offline use remains available.

## Export a report

After a scan, choose **Export report**, review the preview, select TXT, JSON, or PDF, and choose a destination. Reports are structurally minimized and redacted before serialization. By default they exclude secret-bearing properties, usernames, profile paths, IP addresses including compressed IPv6, email addresses, serial numbers, product keys, browser data, and document contents.

The report remains local unless you explicitly send it somewhere.

## Settings and local data

Choose Dark, Light, or Follow Windows theme. In-app health notifications are conservative and can be disabled. The Settings page also provides the weekly-update preference, manual update action, local data location, and log deletion.

Nyx has no required resident background process. Closing the application stops active scan/update workers.

## Uninstall

Use Windows Installed Apps or run `Uninstall Nyx PC Checkup.exe`. The uninstaller first validates legacy machine rollback storage and current-user rollback journals. It restores supported current-user startup changes before removal.

If recovery state is malformed, inaccessible, conflicting, or includes a legacy QA2 machine-level obligation, uninstall stops before removing the application, shortcuts, registration, or recovery data. This is intentional fail-closed behavior.

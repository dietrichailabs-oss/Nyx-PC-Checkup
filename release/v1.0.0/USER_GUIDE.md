# Nyx PC Checkup 1.0.0 — Complete User Guide

## Installation

Windows 10/11 x64. Run the official Setup as the Windows user who will use Nyx, or extract the complete portable ZIP and launch the included executable. Default installed path:

`%LOCALAPPDATA%\Programs\Dietrich AI Labs\Nyx PC Checkup`

Default per-user data path:

`%LOCALAPPDATA%\Dietrich AI Labs\Nyx PC Checkup`

No account or product key is required. A self-signed installer is not equivalent to a publicly trusted publisher signature. Download from an official channel and match the final SHA-256.

## Quick and Full checks

From Home/Checkup choose **Check My PC** for Quick, or **Run Full Check** for deeper folder, Downloads, installed-app, storage and performance measurements where supported. Wait for the results; Full may take longer. **Cancel scan** stops an active check but may preserve completed partial findings. A new scan refreshes older results.

Results mean: **Good** (no important concern observed), **Needs Attention** (action may help), **Optional** (choice rather than urgency), or **Unknown** (unavailable/unreliable Windows signal). Unknown does not mean the computer is broken. Open a result to see the finding, reason, evidence source and recommendation.

Keyboard: Tab/Shift+Tab move between controls; arrow keys, PageUp/PageDown and Home/End navigate supported grids; Enter opens supported result details or actions. Use scrollbars where a table doesn't fit the window.

## Storage, System, Security, Updates and Backup

**Storage** shows disk capacity, available space and supported folder/Downloads/large-file information. Opening a folder is not deletion. A large or old file is not automatically junk.

**System** displays available Windows, uptime, network, drive and performance observations. Device-specific firmware/SMART information may be unavailable.

**Security** reads supported Windows status and can open the official Windows Security app; Nyx cannot replace antivirus or disable protections automatically.

**Updates** shows Windows Update/restart indicators and opens Windows Update; cached results may require Windows to refresh. Nyx's own update-check feature is availability-only; it cannot automatically download/install a new Nyx version.

**Backup** reports supported Windows backup traces, not necessarily third-party cloud/offsite tools. Undetected Windows backup does not prove no backup exists. Keep verified backups of important files.

## Startup changes — reversible current-user entries only

Open **Startup**, select the intended application, check its name/location/state, and (for supported current-user entries only) choose **Disable** and confirm. Select a supported disabled entry and choose **Re-enable** to restore. Use **Refresh** to verify each step. All-users entries are displayed read-only and cannot be changed in version 1.

Nyx records protected rollback information before a supported change. If an entry was removed/changed, restoration may fail safely. Do not disable security, drivers, sync, backup, accessibility, sound or hardware utilities casually.

## Installed Apps and Cleanup

**Apps** lists installed applications and supports searching and opening valid folder/Windows Installed Apps destinations; Nyx does not silently uninstall software.

**Cleanup** requires a deliberate action. After a Full scan, review the supported candidate items, select the specific items, check the selected total and exact consequence, then confirm. Nothing is preselected. Supported removal attempts use the Recycle Bin where practical. Never assume all files are recoverable, or use cleanup as a substitute for backups.

## Export TXT, JSON and PDF

Once a scan exists, select **Export report**, review the preview, choose your file format in the Save dialog and save. **Text** saves .txt (often opens in Notepad), **JSON** saves structured .json, and **PDF summary** saves a readable .pdf for a PDF viewer. If the file opens in the wrong application, check the selected format and extension first. Exports are minimized/redacted by default; review before sharing.

## Settings and privacy

Select **Follow Windows**, **Light** or **Dark**. Settings also offers in-app notifications, update availability controls, **Check for Updates Now**, local data folder and local-log deletion options. An automatic update-*availability* check may run periodically when enabled, but the application does not update itself weekly or install anything.

Ordinary diagnostics and saved scans remain local. Narrow optional network/DNS and HTTPS update-manifest checks do not upload diagnostic results. Nyx is not an internet-required cloud service.

## Repair, uninstall, troubleshooting

Close Nyx before running a same/newer official installer for repair or upgrade. To remove it use **Windows Installed Apps** or the Nyx uninstaller. Startup changes are restored first where safe; an unresolved rollback conflict/legacy state can intentionally block uninstall without deleting needed recovery data.

If **Unknown**, inspect the detail and Windows tool, rather than assuming failure. If PDF doesn't open as PDF, ensure **PDF summary** was selected. If Windows says restart required, save work and restart when convenient. Some extreme Windows scaling/window configurations may need horizontal or vertical scrolling. Complete multi-DPI certification is not claimed.

Nyx cannot guarantee a machine has no malware, bad hardware, missing third-party backups or future faults. It doesn't act as a registry cleaner, RAM booster, antivirus replacement or unattended repair bot.

More details: [Quick Start](README.md), [Release Notes](RELEASE_NOTES.md), [License](LICENSE.txt).
# Nyx PC Checkup 1.0.0 — Start Here

**Free local PC health checks for Windows 10 and 11 (64-bit)**  
**Publisher:** Dietrich AI Labs

Nyx PC Checkup shows common computer-health information in everyday language, without fake error counts or automatic repairs. **Scanning is read-only.**

## Install

**Installer:** Open `Nyx_PC_Checkup_1.0.0_Setup.exe` from the verified official release. Follow the prompts; the installer normally installs for your Windows user, provides a Start-menu entry, and can offer a desktop shortcut.

**Portable ZIP:** Extract the entire `Nyx_PC_Checkup_1.0.0_Portable.zip` into a folder, then launch the Nyx PC Checkup executable inside that folder. Do not run it directly within the compressed archive. User settings/data may still be stored in Windows AppData.

**Signature warning:** Some builds are self-signed, not signed by a publicly trusted code-signing provider. Always obtain the software from an official Dietrich AI Labs channel and compare its SHA-256 with the published manifest. Do not disable Windows protections or import an unknown trust certificate.

## Run a check

1. Launch Nyx PC Checkup.
2. Select **Check My PC** for a quick scan, or **Run Full Check** for additional diagnostics.
3. Review each finding or open its details.
4. **Cancel scan** stops a running scan; completed partial results may remain visible.

**Good** = no meaningful concern detected by that check. **Needs Attention** = something worth reviewing. **Optional** = only if useful. **Unknown** = Windows did not provide sufficient information; not automatically a defect.

## Pages

| Page | Purpose |
|---|---|
| Home | Overall summary and recommendations |
| Checkup | Start scans, see progress and details |
| Storage | Disk space, folders, Downloads and related results |
| Startup | Review launch-at-sign-in entries; optionally disable/re-enable eligible current-user items |
| Security | Windows protection information; link to Windows Security |
| Updates | Update/restart indicators; link to Windows Update |
| Backup | Detectable Windows backup information |
| System | Windows, uptime, network and performance details |
| Apps | Search installed applications; folder and Windows settings links |
| Cleanup | Review and explicitly confirm selected cleanup items |
| Settings | Themes, update availability, local data and logs |

**Important:** All-users Startup entries are **read-only**. Scans never delete files. On Cleanup, no items are preselected; selected supported items may be sent to Recycle Bin after separate confirmation.

## Export reports

After scanning, select **Export report**, check the preview, select **Text (.txt)**, **JSON (.json)** or **PDF summary (.pdf)** in the save dialog, and save. Text often opens in Notepad; PDF opens in a PDF reader such as Microsoft Edge. Review reports before sharing.

## Privacy, updates and uninstall

Results/logs remain local unless you explicitly export/share a report. No account or telemetry upload is required. Optional update checks request public release information, but **do not download or install updates automatically**.

Uninstall with **Windows Settings → Apps → Installed apps** or the Nyx uninstaller. It first attempts safe restoration of supported startup changes and may halt if recovery data is inconsistent. See the [full guide](USER_GUIDE.md).

Nyx is not antivirus, an automatic registry cleaner, or a guarantee against PC failure.

[Full User Guide](USER_GUIDE.md) · [Release Notes](RELEASE_NOTES.md) · [Freeware License](LICENSE.txt)

© 2026 Dietrich AI Labs.
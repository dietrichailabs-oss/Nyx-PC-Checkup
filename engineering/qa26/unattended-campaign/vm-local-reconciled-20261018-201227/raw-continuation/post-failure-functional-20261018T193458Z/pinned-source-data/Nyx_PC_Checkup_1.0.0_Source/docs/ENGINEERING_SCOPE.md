# Nyx PC Checkup — Complete Engineering Scope

## Project Identity

**Product:** Nyx PC Checkup
**Publisher:** Dietrich AI Labs
**Product type:** Local-first Windows PC health and maintenance utility
**Primary audience:** Normal, nontechnical Windows users
**Initial platform:** Windows 10/11, 64-bit
**Future platform:** Linux / eventual Nyx OS integration
**Development model:** Modular, continuous self-testing, full Version 1 completion before independent QA

---

# 1. Mission

Build the complete, polished, release-ready **Nyx PC Checkup Version 1**.

Nyx PC Checkup should answer one simple question for an ordinary user:

> **“Is my computer okay, and is there anything I should actually do?”**

The application must inspect common PC-health areas and explain them in simple language without frightening users with meaningless warnings or pretending that harmless conditions are emergencies.

The interface should primarily classify findings as:

- **Good**
- **Needs Attention**
- **Optional**
- **Unknown / Could Not Check**

The application must explain:

- What was checked
- What was found
- Why it matters
- Whether action is actually necessary
- What safe action the user can take

The application must be:

- Local-first
- Privacy-respecting
- Lightweight
- Fast
- Understandable
- Conservative about changing the computer
- Transparent about anything it cannot determine

---

# 2. Product Philosophy

Nyx PC Checkup must explicitly reject the behavior common to low-quality “PC cleaner” applications.

## Never do the following

- Fake thousands of “errors”
- Mark harmless registry entries as dangerous
- Claim that a healthy computer is critically damaged
- Display fake virus findings
- Invent performance problems
- Exaggerate minor issues with flashing red warnings
- Claim a PC will become dramatically faster without evidence
- Sell “premium fixes”
- Use dark patterns
- Automatically install software
- Automatically install drivers
- Automatically disable Windows services
- Automatically change security settings
- Automatically delete user files
- Run a generic registry cleaner
- Run a “RAM booster”
- Purge caches merely to make a cleanup number look impressive
- Delete Windows Update files without clear justification and user approval
- Disable Windows Defender or other security software
- Change browser settings
- Modify network settings silently
- Change startup configuration without explicit user action
- Upload system information without permission
- Add telemetry by default

Nyx PC Checkup should sometimes tell the user:

> **“Your computer looks fine. Nothing needs fixing.”**

That is an acceptable and desirable result.

---

# 3. Engineering Execution Model

Engineering must build the **entire approved Version 1** before handing the project to independent QA.

Do not submit:

- An architecture skeleton
- A partial dashboard
- Placeholder buttons
- Incomplete modules
- Mock-only functionality
- A prototype presented as Version 1

Engineering must continuously:

> **BUILD → TEST → FIND DEFECTS → FIX → RETEST → REGRESSION TEST → CHECKPOINT → CONTINUE**

Do not knowingly carry broken modules forward.

Engineering is authorized to fix ordinary defects autonomously without requesting permission.

Every meaningful module must have:

- Narrow responsibility
- Documented contract
- Focused tests
- Defined error behavior
- Explicit dependencies
- Failure isolation
- Rollback boundary where practical

No monolithic application file.

---

# 4. High-Level User Experience

## Home Screen

The home screen should immediately show a simple summary similar to:

### Your PC

**Overall status: Good**

- Storage — Good
- Windows Updates — Good
- Security — Good
- Startup Apps — 3 worth reviewing
- Backup — Not configured
- Downloads — 11.4 GB, optional cleanup
- Temporary Files — 2.1 GB, optional cleanup

Then:

**3 things worth looking at**

1. Backup is not configured.
2. Five programs start automatically but have not been used recently.
3. Your Downloads folder contains 6.8 GB of old installers.

No alarmist language.

---

# 5. Status Model

Use only transparent deterministic health states.

## Required states

### Good

No meaningful problem detected.

### Needs Attention

There is a genuine issue that could affect security, reliability, storage, backup, updates, or normal operation.

### Optional

The computer is functioning normally, but the user may choose to improve convenience or reclaim space.

### Unknown

The application could not reliably determine the status.

Every status must include:

- Finding
- Reason
- Evidence
- Recommended action
- Whether the recommendation is optional or important

Do not use an arbitrary 0–100 “PC health score” unless the calculation is fully explainable.

Prefer categorical health reporting.

---

# 6. Required Version 1 Modules

## Module 1 — Application Shell

Own:

- Startup
- Shutdown
- Navigation
- Module registration
- Global state
- Background-task coordination
- Error boundary
- Version/build identity

Must not contain health-check implementation logic.

---

# 7. System Overview Module

Display basic PC information in human-readable form.

Required information:

- Computer name
- Windows edition
- Windows version/build
- 64-bit status
- Processor
- Installed RAM
- Available RAM
- System drive
- System-drive capacity
- System-drive free space
- Device uptime
- Laptop/Desktop classification where reliably available

Optional:

- GPU
- Manufacturer
- Model
- Battery presence

Do not expose hardware serial numbers unnecessarily.

Do not display unique identifiers unless needed for a specific local function.

---

# 8. Storage Health Module

Analyze storage without immediately deleting anything.

Required checks:

- Total system-drive capacity
- Free space
- Percentage free
- User-profile storage consumption
- Downloads-folder size
- Desktop-folder size
- Documents-folder size
- Pictures-folder size
- Videos-folder size
- Temporary-file size
- Recycle Bin size where safely obtainable
- Largest user-accessible folders
- Largest files
- Old installers
- Old archives
- Duplicate candidates where practical

Suggested health rules:

**Good**

- Reasonable free space

**Needs Attention**

- Critically low free space
- Windows system drive approaching a level likely to impair updates or operation

**Optional**

- Large Downloads directory
- Large temporary directory
- Large unused installers
- Old archives

Thresholds must be documented and conservative.

Do not call 30 GB of free space “critical” merely because another app might.

---

# 9. Safe Cleanup Module

Cleanup must always be user-directed.

Before deleting anything:

1. Scan
2. Categorize
3. Display files/categories
4. Display total reclaimable size
5. Explain consequences
6. Let the user select what to remove
7. Require confirmation
8. Perform deletion
9. Report exact result

Version 1 may safely support categories such as:

- User temporary files
- Application temporary files created by Nyx PC Checkup
- Old installer packages in Downloads
- Old ZIP/archive files selected by the user
- Recycle Bin
- Safe temporary directories where the operating-system contract allows it

Do not silently delete:

- Documents
- Photos
- Videos
- Downloads
- Installer caches required by Windows
- Windows Update components
- Restore points
- Browser profiles
- Application data
- User databases
- Saved games
- Development files
- Cloud synchronization data

If deletion fails, preserve the file and report the reason.

---

# 10. Downloads Checkup Module

Normal-user focused.

Scan Downloads and categorize:

- Installers
- ZIP archives
- Documents
- Images
- Videos
- Large files
- Old files
- Duplicate candidates

Useful groups:

- Older than 30 days
- Older than 90 days
- Older than 1 year
- Larger than 100 MB
- Larger than 1 GB
- Installers that may no longer be needed

Never assume old means unwanted.

Offer:

- Open folder
- Select files
- Move to Recycle Bin
- Keep
- Ignore

---

# 11. Startup Applications Module

Show applications configured to start with Windows.

Display:

- Application name
- Publisher where available
- Startup source
- Enabled/disabled state
- Impact estimate only when backed by real evidence
- Executable path
- Whether the file still exists

Use plain language:

> “This program starts automatically when Windows starts.”

Do not label unfamiliar software as malicious.

Allow:

- Open file location
- View details
- Disable startup entry
- Re-enable previously disabled entry

Every modification requires explicit user action.

Create rollback information before modification.

Do not delete startup entries simply because they are disabled.

---

# 12. Windows Update Status Module

Check Windows Update status through supported Windows interfaces.

Display:

- Whether important updates appear pending
- Whether restart is pending
- Last successful update date where reliably available
- Windows build
- End-of-support warning if determinable from maintained data

Primary actions should generally open the proper Windows Update interface rather than reimplement Windows Update.

Possible statuses:

**Good**

> “Windows appears up to date.”

**Needs Attention**

> “Windows reports that updates are waiting to install.”

**Needs Attention**

> “A restart is required to finish installing updates.”

**Unknown**

> “Windows Update status could not be determined.”

Never claim a machine is fully patched when only limited update information was available.

---

# 13. Security Status Module

Integrate with Windows security information where supported.

Check without disabling or modifying protections.

Possible information:

- Microsoft Defender status where available
- Registered antivirus status
- Real-time protection state where reliably available
- Firewall status
- Windows Security service availability
- Secure Boot status where available
- TPM availability where useful
- BitLocker/device encryption state where safely obtainable

Plain-English examples:

> “Windows reports that antivirus protection is active.”

> “Windows Firewall appears to be turned off.”

> “Drive encryption is not enabled. This is optional for many home PCs but can protect files if a laptop is lost.”

Do not:

- Call lack of BitLocker a critical failure on every machine
- Disable security software
- Attempt antivirus replacement
- Present Nyx PC Checkup as antivirus software

Provide an **Open Windows Security** action where appropriate.

---

# 14. Backup Checkup Module

Determine whether the user appears to have a backup strategy where possible.

Version 1 should primarily educate and link to available backup options.

Check where reliably obtainable:

- Windows backup configuration
- File History state
- Known local backup configuration
- Recent backup timestamp where supported

Status examples:

**Good**

> “A recent backup was detected.”

**Needs Attention**

> “No backup could be detected.”

But include:

> “You may already use another backup service that Nyx PC Checkup cannot detect.”

Provide:

- Learn why backups matter
- Open Windows Backup
- Open File History
- Future Nyx Backup integration point

Do not claim no backup exists unless that can actually be established.

---

# 15. Battery Health Module

Only show this module on devices with a battery.

Where Windows provides reliable information, display:

- Current charge
- Design capacity
- Current full-charge capacity
- Estimated battery health
- Cycle information where available
- Charging state

Explain:

> “Your battery currently holds approximately 81% of its original designed capacity.”

Avoid false precision.

If battery-health information cannot be obtained:

> “Battery health information is unavailable on this device.”

Do not treat ordinary battery aging as a critical PC failure.

---

# 16. Memory and Performance Snapshot

This is diagnostic information, not a fake optimizer.

Display:

- Current CPU usage
- Current memory usage
- Available memory
- Disk activity
- Basic current system load

Optional:

- Highest CPU-consuming processes
- Highest memory-consuming processes

Use language such as:

> “Memory use is currently high.”

Do not say:

> “You need more RAM.”

unless evidence supports a sustained problem.

No RAM-cleaning button.

No process-killing automation.

If process termination is eventually added, it must be explicit and treated as an advanced feature.

---

# 17. Drive Health

Where supported and reliable, collect basic drive-health information.

Potential sources:

- Windows storage APIs
- SMART status
- NVMe health data
- Manufacturer-independent supported APIs

Possible information:

- Drive type
- Capacity
- Health status
- Temperature where available
- Wear level where available
- SMART warning

Important:

A healthy result should say:

> “No drive-health warning was reported.”

Not:

> “Your drive cannot fail.”

If SMART reports a failure warning:

**Needs Attention**

Explain that backup should be prioritized.

---

# 18. Installed Applications Review

Display installed applications in a simple searchable list.

Information:

- Application
- Publisher
- Version
- Installation date where available
- Estimated size where available

Actions:

- Open uninstall settings
- Trigger supported uninstall workflow only with explicit confirmation
- Open application folder where appropriate

Optional categories:

- Recently installed
- Very large applications

Do not call applications “junk.”

Do not automatically uninstall anything.

---

# 19. PC Restart/Uptime Check

Very long uptime can occasionally explain pending updates or transient issues.

Display uptime.

Example:

> “Your PC has been running for 19 days. A restart may help complete updates and clear temporary problems.”

This should generally be **Optional**, not an emergency.

Never imply that PCs need daily restarts.

---

# 20. Network Basics Module

Keep Version 1 simple.

Display:

- Internet connection available/unavailable
- Active network type
- Basic adapter status
- Approximate connection state
- DNS configuration only in advanced details

Useful diagnostics:

- Internet unavailable
- Adapter disconnected
- DNS resolution test
- Gateway availability where appropriate

Do not:

- Scan other network devices automatically
- Collect browsing history
- Capture packets
- Change DNS
- Change proxy settings
- Change firewall configuration

---

# 21. Checkup Engine

Create a central rules engine.

Each check should return a structured object such as:

- Check ID
- Category
- Name
- Status
- Severity
- Evidence
- Explanation
- Recommended action
- Action safety level
- Timestamp
- Data source
- Whether elevated privileges were required
- Whether result is complete
- Error/unknown reason

Rules must be centralized and testable.

Do not bury thresholds throughout UI code.

---

# 22. Full Scan

Provide one large, obvious button:

# Check My PC

The scan should run supported checks in the background.

Requirements:

- UI remains responsive
- Progress is visible
- Checks may run concurrently where safe
- Failed check does not cancel unrelated checks
- User can cancel
- Partial results remain visible
- No modifications occur during scanning
- Scanning itself should normally require no administrator privileges

At completion show:

> **Your PC looks good.**

or:

> **2 things need attention and 4 optional items are available.**

Do not inflate totals.

---

# 23. Quick Scan and Detailed Scan

Version 1 may support:

### Quick Check

Fast checks:

- Storage
- Update status
- Security status
- Startup entries
- Backup
- Uptime

### Full Check

Adds:

- Folder-size analysis
- Large files
- Downloads analysis
- Battery
- Drive health
- Installed applications
- Performance snapshot

Quick Check should ideally finish within seconds on normal hardware.

Full Check should provide continuous progress.

---

# 24. Fix Actions

Every fix must be classified.

## Safe Redirect

Open official Windows settings.

Examples:

- Windows Update
- Windows Security
- Backup
- Storage settings
- Installed Apps

## Reversible Local Change

Examples:

- Disable startup app

Must record previous state and provide undo.

## Destructive Action

Examples:

- Delete temporary files
- Empty Recycle Bin
- Delete selected Downloads files

Must show:

- Exact item/category
- Exact size
- Consequence
- Confirmation

Never perform destructive fixes automatically.

---

# 25. Undo and Recovery

Where technically practical, reversible actions must support Undo.

Keep a local action history:

- Timestamp
- Action
- Previous state
- Result
- Undo availability

Do not store unnecessary personal file data indefinitely.

Cleanup actions sent to Recycle Bin should use the system Recycle Bin rather than permanent deletion where practical.

---

# 26. Privacy Requirements

Nyx PC Checkup is local-first.

Default behavior:

- No telemetry
- No analytics uploads
- No system inventory uploads
- No remote account
- No cloud storage
- No advertising
- No tracking
- No sale of data
- No background data collection unrelated to functionality

System reports remain local unless the user explicitly exports them.

Do not include:

- Full usernames in exported diagnostics unless explicitly requested
- Hardware serial numbers unnecessarily
- Product keys
- Browser history
- Passwords
- Cookies
- Authentication tokens
- Document contents

Provide:

**Privacy: Everything analyzed by PC Checkup stays on this computer unless you explicitly export it.**

---

# 27. Diagnostic Report Export

Allow the user to export a support-friendly report.

Formats:

- TXT
- JSON
- PDF summary if practical

Default report should include:

- App version
- Windows version
- General hardware class
- Check results
- Statuses
- Recommendations
- Scan timestamp

Default report must exclude:

- API keys
- Passwords
- Tokens
- Private documents
- Browser data
- Personal file contents
- Hardware serial numbers
- Unnecessary usernames
- IP addresses unless explicitly requested for network diagnosis

Provide a preview before export.

---

# 28. User Interface Design

Nyx PC Checkup should look premium but simple.

Suggested navigation:

- Home
- Checkup
- Storage
- Startup
- Security
- Updates
- Backup
- System
- Cleanup
- Settings

Home should remain the primary normal-person interface.

Advanced details should be expandable rather than dumped onto the screen.

Use recognizable language.

Prefer:

**Storage is getting low**

over:

**SYSTEM VOLUME THRESHOLD EXCEEDED**

Prefer:

**5 programs start with Windows**

over:

**Boot Autostart Enumeration Results**

---

# 29. Visual Status Language

Use consistent icons and text.

Do not depend on color alone.

Examples:

### Good

✓ No action needed

### Needs Attention

! Recommended action

### Optional

○ Your choice

### Unknown

? Could not determine

Accessibility must remain usable for color-blind users.

---

# 30. Themes and Display

Required:

- Dark theme
- Light theme
- Follow Windows theme
- 100% scaling
- 125%
- 150%
- 200%

No clipped text.

No overlapping controls.

No microscopic system information.

Support common laptop resolutions.

---

# 31. Notifications

Version 1 should be conservative about notifications.

Potential notifications:

- Critically low disk space
- Windows restart pending for update
- Drive-health warning
- Backup significantly overdue where reliably known

Do not nag about:

- Temporary files
- Downloads
- Startup applications
- Minor storage opportunities

Allow all notifications to be disabled.

---

# 32. Background Operation

PC Checkup should not need to run continuously for normal use.

Default:

- No forced background resident process

Optional future setting:

- Periodic lightweight health check

If background monitoring is added later:

- Opt-in
- Minimal CPU/RAM
- Clear tray icon
- Easy disable
- No telemetry

Version 1 should favor manual scans unless a background component is genuinely necessary.

---

# 33. Administrator Privileges

Normal application operation should run without elevation.

Request elevation only for an action that genuinely requires administrator rights.

Never launch the entire application permanently elevated merely for convenience.

Explain why elevation is requested.

If the user declines:

- Cancel that action
- Keep the rest of the application functional

---

# 34. Error Handling

Individual failures must not crash the application.

Examples:

- SMART unavailable
- Windows Update API unavailable
- Antivirus status inaccessible
- Registry key inaccessible
- Folder access denied
- Corrupt metadata
- Battery API unavailable

Show:

> “This check could not be completed.”

Provide technical details only under an expandable section.

Logs must redact:

- Usernames where practical
- Tokens
- Credentials
- Sensitive paths where unnecessary

---

# 35. Logging

Local diagnostic logging only.

Requirements:

- Rotating logs
- Small storage cap
- Secret redaction
- No upload
- User can delete logs
- Developer-level diagnostics can be enabled manually

Production logging should not capture user file contents.

---

# 36. Future Nyx OS Compatibility

Build Windows first.

Keep core modules platform-neutral.

Required platform separation:

nyx\_pc\_checkup/

- core/
- checks/
- health\_rules/
- storage/
- cleanup/
- reports/
- ui/
- platform/
  - windows/
  - linux/
- security/
- configuration/
- packaging/

Windows-specific modules own:

- Registry access
- Windows Update integration
- Windows Security integration
- Startup enumeration
- Windows notifications
- DPAPI if used
- Recycle Bin integration
- Installer
- Windows paths

Core checkup logic must not directly depend on Windows APIs.

This allows later:

> Windows utility → Linux port → native Nyx OS System Health component.

---

# 37. Recommended Engineering Modules

Target approximately 20–30 meaningful modules rather than one giant application or hundreds of meaningless fragments.

Suggested major modules:

1. app\_bootstrap
2. system\_info
3. checkup\_engine
4. health\_rules
5. storage\_scan
6. cleanup
7. downloads\_analysis
8. startup\_apps
9. windows\_updates
10. security\_status
11. backup\_status
12. battery\_health
13. drive\_health
14. performance\_snapshot
15. installed\_apps
16. uptime
17. network\_basics
18. action\_engine
19. undo\_history
20. report\_export
21. configuration
22. diagnostics
23. privacy
24. ui\_dashboard
25. ui\_details
26. windows\_adapter
27. linux\_adapter\_contract
28. packaging

Smaller focused files underneath these are expected.

---

# 38. Testing Policy

Engineering must test continuously as development proceeds.

Required test classes:

- Unit
- Contract
- Integration
- Regression
- Adversarial
- UI
- Packaging
- Installer

---

# 39. Required Unit Tests

Test health rules around:

- Free-space thresholds
- Downloads classification
- File ages
- File sizes
- Startup state
- Update states
- Backup states
- Battery calculations
- Drive-health states
- Uptime recommendations
- Unknown/unavailable states
- Security status
- Cleanup totals
- Report redaction
- Status aggregation

Boundary values must be tested.

---

# 40. Safety Tests

Verify PC Checkup never:

- Deletes files during a scan
- Disables startup applications without confirmation
- Modifies registry settings unexpectedly
- Changes Windows Update settings
- Disables security software
- Changes firewall settings
- Installs drivers
- Changes networking
- Removes programs automatically
- Permanently deletes personal files without explicit confirmation
- Uploads system data
- Creates telemetry
- Requires elevation for routine scanning

---

# 41. Adversarial Tests

Test:

- Access denied
- Corrupt registry entries
- Broken startup entries
- Extremely long paths
- Unicode filenames
- Invalid filenames
- Junctions
- Symbolic links
- Reparse points
- Network drives
- Offline drives
- Removable drives
- Millions of files
- Huge files
- Files disappearing during scan
- Directory changes during scan
- Read-only folders
- Locked files
- Low disk space
- User cancellation
- Shutdown during scan
- Corrupt configuration
- Invalid Windows API responses
- Missing Windows services
- Missing SMART data
- Unknown antivirus
- Multiple antivirus products
- Laptop without battery data
- Desktop with no battery
- Unsupported Windows build

The application must fail safely.

---

# 42. Performance Requirements

Target:

- Application launch: approximately 2 seconds or less on reasonable hardware where practical
- Quick Check: seconds, not minutes
- Full storage scan: progressive and cancellable
- UI never freezes
- Background workers bounded
- Low idle CPU
- Reasonable memory footprint
- Avoid rescanning unchanged data unnecessarily

Do not optimize prematurely at the expense of correctness.

---

# 43. Clean Packaging Requirement

Packaging must begin from a clean allowlisted staging directory.

Never copy the entire project tree.

Include only:

- Application executable/runtime
- Required libraries
- Required assets
- Icons/themes
- Licenses/notices
- Documentation
- Version metadata
- Installer/uninstaller

Exclude:

- Source unless intentionally distributed
- Tests
- QA evidence
- Screenshots
- Checkpoints
- Git
- Virtual environments
- Caches
- Logs
- Crash dumps
- User data
- Test data
- Test databases
- Developer settings
- Local paths
- Secrets
- Credentials
- Superseded builds

Packaging script must fail when unexpected files appear.

---

# 44. Installer Requirements

Windows installer must support:

- Fresh install
- Correct application identity
- Start-menu shortcut
- Optional desktop shortcut
- Correct icon
- Correct version
- Correct uninstall registration
- Normal-user runtime
- Upgrade
- Repair/reinstall if supported
- Clean uninstall

Before independent QA, Engineering must personally verify the generated installer through an automated/local clean-install test procedure.

Do not repeat prior portfolio installer failures caused by:

- Missing runtime files
- Development paths
- Incorrect working directories
- Packaging whole project trees
- Broken shortcuts
- Missing dependencies

---

# 45. Version 1 Exclusions

Do NOT add these to Version 1 unless explicitly approved:

- Registry cleaner
- Driver updater
- Antivirus engine
- Malware scanner replacement
- RAM optimizer
- CPU optimizer
- Automatic service disabling
- Automatic registry modification
- BIOS updater
- Firmware updater
- Overclocking
- Fan control
- Password manager
- VPN
- Network packet capture
- Device discovery
- Remote administration
- Cloud account
- Paid subscription
- Ads
- Telemetry
- AI diagnosis
- Automatic support chat
- Background always-on system agent

Keep Version 1 focused.

---

# 46. Future Modules

Architect for later optional modules:

- Nyx Backup
- Nyx Duplicate Finder
- Nyx Space
- Nyx Network Watch
- Nyx Secure File Scanner integration
- Browser security status
- Nyx Browser update status
- Nyx OS package updates
- Nyx OS system health
- Device-to-device backup
- Scheduled health checks

Do not implement them merely because extension points exist.

---

# 47. Internal Engineering Completion Gate

Engineering must not hand the application to QA until:

- Full Version 1 scope is implemented
- No placeholder buttons remain
- No fake health results exist
- Unit tests pass
- Integration tests pass
- Regression tests pass
- Adversarial safety tests pass
- UI tests pass
- Quick Check works
- Full Check works
- Cleanup preview works
- Cleanup confirmation works
- Startup actions are reversible
- Unknown states are handled
- Offline behavior works
- Non-admin scan works
- Elevated action behavior works
- Reports redact sensitive information
- Package secret scan passes
- Installer builds
- Installer installs
- Application launches from installed location
- Restart works
- Upgrade works
- Repair/reinstall works where supported
- Uninstall works
- No dev environment is required
- Manifest is complete
- SBOM is complete
- Licenses are included
- SHA-256 hashes are recorded
- Documentation matches actual behavior

---

# 48. Independent QA Gate

After Engineering freezes the complete candidate:

QA independently tests the exact immutable artifact.

QA must assume Engineering missed something.

QA scope includes:

- Functional testing
- Safety testing
- Destructive-action testing
- Permissions
- Registry boundaries
- Startup changes
- Cleanup correctness
- Storage calculations
- Windows Update states
- Security states
- Backup status
- Drive-health behavior
- Battery behavior
- User cancellation
- Error isolation
- Regression
- UI scaling
- Accessibility
- Packaging
- Clean installation
- Upgrade
- Repair
- Uninstall
- Leftovers
- Manifest
- Hashes

QA does not silently repair Engineering source.

Any correction creates a new artifact requiring applicable retesting.

---

# 49. Current Development-Cycle Governance Override

For the current Nyx PC Checkup development cycle, the only active roles are **Engineering and Independent QA**:

- **Engineering** — implements, tests, corrects, freezes, and packages a candidate.
- **Independent QA** — independently tests the exact immutable candidate and returns `PASS`, `CONDITIONAL PASS`, `HOLD`, or `FAIL`.

This latest governance instruction supersedes the earlier multi-role routing language that originally appeared in this scope. No additional reviewer, approval gate, recipient, release authority, or blocker is designated by the Engineering handoff. Routing beyond Independent QA must not be inferred.

# 50. Correction Loop

Required sequence for this cycle:

**Engineering complete/corrected build**

→ Engineering internal test and packaging gates

→ Immutable Engineering candidate and one master handoff ZIP

→ Independent QA

→ Engineering correction and new identity when QA returns findings

→ Independent QA regression of the newly frozen bytes

Engineering never approves its own candidate. QA never silently edits Engineering source.

# 51. Required Engineering Handoff Bundle

Produce one master ZIP whenever practical. Include the exact candidate, portable comparison package, exact source/build identity, version, manifests, sizes, SHA-256 hashes, SBOM, licenses/notices, architecture/module contracts, tests/results, known limitations, installer/upgrade/uninstall instructions, privacy/security notes, packaging/reproducibility evidence, rollback information, and explicit two-role routing.

# 52. Who Gets What Next

## Independent QA

Receives the exact immutable master handoff and all evidence. Purpose: independent adversarial validation. Authority: `PASS`, `CONDITIONAL PASS`, `HOLD`, or `FAIL`.

## Engineering

Receives QA’s exact verdict and findings. Purpose: preserve a passing artifact unchanged or produce a corrected build with a new identity. Authority: build and resubmit only.

# 53. Publication Boundary

An Engineering-to-QA handoff is not public-release authorization. This document does not designate a publication recipient or infer any post-QA release route.

# 54. Engineering Timing Records

For every substantial work session, record Eastern Time:

- Start
- Stop
- Elapsed active time
- Module
- Work performed
- Files changed
- Tests performed
- Result
- Checkpoint
- Remaining work

Do not include waiting, sleep, idle periods, or unrelated work as active Engineering time.

---

# 55. Definition of Done

Nyx PC Checkup Version 1 is complete when a normal Windows user can:

1. Install it.
2. Open it without administrator privileges.
3. Click **Check My PC**.
4. Understand the results without technical expertise.
5. See what is good.
6. See what genuinely needs attention.
7. See optional cleanup opportunities.
8. Understand why each item was flagged.
9. Safely take approved actions.
10. Undo reversible changes where supported.
11. Export a privacy-safe report.
12. Close the application without leaving unnecessary background services running.
13. Uninstall it cleanly.

And the application can truthfully tell a healthy user:

> **Your PC looks good. Nothing needs fixing.**

That sentence is an acceptance requirement.

---

# 56. Initial Engineering Command

Begin development of the complete **Nyx PC Checkup Version 1** now.

Build modularly from the first line.

Implement the entire approved Version 1 scope.

Test continuously.

Fix defects as they are discovered.

Do not knowingly advance through failing module gates.

Do not stop at a prototype.

Do not stop after the first working dashboard.

Do not hand partial functionality to independent QA.

Continue until:

- Version 1 is feature complete
- Internal testing passes
- Windows packaging passes
- The installer has been verified
- The immutable Engineering candidate is frozen
- The complete master QA handoff ZIP is ready

Keep the application lightweight, local-first, understandable to normal people, and aggressively honest about what is and is not wrong with their computer.

The product should help users—not frighten them into clicking buttons.
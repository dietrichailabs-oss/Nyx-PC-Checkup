from __future__ import annotations

import hashlib
import json
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path, PurePosixPath

import pytest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
DIST = ROOT / "dist"
STAGE = ROOT / "release_staging" / "Nyx_PC_Checkup_1.0.0_Portable"
BUILD_ID = "2026.09.27-eng-qa22"

EXPECTED_MODULES = {
    "core/Models.psm1",
    "core/Paths.psm1",
    "core/Configuration.psm1",
    "core/Diagnostics.psm1",
    "core/Privacy.psm1",
    "core/CheckupEngine.psm1",
    "core/ActionHistory.psm1",
    "health_rules/HealthRules.psm1",
    "checks/SystemInfo.psm1",
    "checks/StorageHealth.psm1",
    "checks/StorageScan.psm1",
    "checks/DownloadsAnalysis.psm1",
    "checks/StartupApps.psm1",
    "checks/WindowsUpdates.psm1",
    "checks/SecurityStatus.psm1",
    "checks/BackupStatus.psm1",
    "checks/BatteryHealth.psm1",
    "checks/PerformanceSnapshot.psm1",
    "checks/DriveHealth.psm1",
    "checks/InstalledApps.psm1",
    "checks/Uptime.psm1",
    "checks/NetworkBasics.psm1",
    "checks/CleanupScan.psm1",
    "actions/StartupActions.psm1",
    "actions/CleanupActions.psm1",
    "reports/ReportExport.psm1",
    "reports/PdfWriter.psm1",
    "ui/Theme.psm1",
    "ui/Controls.psm1",
    "ui/Dialogs.psm1",
    "ui/MainWindow.psm1",
    "updates/Versioning.psm1",
    "updates/Manifest.psm1",
    "updates/Preferences.psm1",
    "updates/UpdateChecker.psm1",
    "workers/ScanWorker.ps1",
    "workers/ActionWorker.ps1",
    "workers/UpdateCheckWorker.ps1",
    "workers/InstallWorker.ps1",
    "workers/UninstallWorker.ps1",
    "platform/windows/WindowsHelpers.psm1",
}


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def runtime_files() -> list[Path]:
    return sorted(p for p in APP.rglob("*") if p.is_file() and p.suffix.lower() in {".ps1", ".psm1"})


def all_runtime_source(*, exclude_updates: bool = False) -> str:
    files = runtime_files()
    if exclude_updates:
        files = [p for p in files if "updates" not in p.relative_to(APP).parts and p.name != "UpdateCheckWorker.ps1"]
    return "\n".join(text(p) for p in files)


def parse_pe(path: Path) -> dict[str, int]:
    data = path.read_bytes()
    assert data[:2] == b"MZ"
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe : pe + 4] == b"PE\0\0"
    machine, sections, timestamp = struct.unpack_from("<HHI", data, pe + 4)
    opt = pe + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    subsystem = struct.unpack_from("<H", data, opt + 68)[0]
    dll_characteristics = struct.unpack_from("<H", data, opt + 70)[0]
    resource_rva, resource_size = struct.unpack_from("<II", data, opt + 112 + 2 * 8)
    return {
        "machine": machine,
        "sections": sections,
        "timestamp": timestamp,
        "magic": magic,
        "subsystem": subsystem,
        "dll_characteristics": dll_characteristics,
        "resource_rva": resource_rva,
        "resource_size": resource_size,
    }


def validate_zip(path: Path) -> list[str]:
    problems: list[str] = []
    lower: set[str] = set()
    with zipfile.ZipFile(path) as zf:
        assert zf.testzip() is None
        for info in zf.infolist():
            name = info.filename
            pp = PurePosixPath(name)
            if name.startswith(("/", "\\")) or ".." in pp.parts or re.match(r"^[A-Za-z]:", name):
                problems.append(f"unsafe path: {name}")
            key = name.casefold()
            if key in lower:
                problems.append(f"duplicate/case collision: {name}")
            lower.add(key)
            if (info.external_attr >> 16) & 0o170000 == 0o120000:
                problems.append(f"symlink: {name}")
    return problems


def require_artifact(path: Path) -> None:
    if not path.exists():
        pytest.skip(f"build artifact not present before packaging run: {path}")


def test_version_and_product_identity() -> None:
    version = json.loads(text(ROOT / "VERSION.json"))
    assert version == {
        "product": "Nyx PC Checkup",
        "publisher": "Dietrich AI Labs",
        "version": "1.0.0",
        "build": BUILD_ID,
        "channel": "Engineering QA Candidate",
        "platform": "Windows 10/11 x64",
        "architecture": "PowerShell 5.1 modular application with native x64 launchers",
        "telemetry": False,
    }
    assert BUILD_ID in text(ROOT / "tools" / "build_release.py")
    assert BUILD_ID in text(APP / "workers" / "InstallWorker.ps1")


def test_expected_modular_structure_exists() -> None:
    actual = {p.relative_to(APP).as_posix() for p in APP.rglob("*") if p.is_file()}
    assert EXPECTED_MODULES <= actual
    assert len([p for p in actual if p.endswith((".ps1", ".psm1"))]) >= 39
    assert (APP / "platform" / "linux" / "CONTRACT.md").exists()


def test_powershell_structural_linter_passes_for_app_and_windows_suites() -> None:
    for target in [APP, ROOT / "tests" / "powershell"]:
        result = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "ps_lint.py"), str(target)],
            check=False,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stdout + result.stderr
        assert "PASS" in result.stdout


def test_no_placeholder_or_mock_runtime() -> None:
    bad = re.compile(r"\b(?:TODO|FIXME|PLACEHOLDER|coming soon|not implemented|mock result|fake result)\b", re.I)
    findings: list[str] = []
    for p in APP.rglob("*"):
        if p.is_file() and p.suffix.lower() in {".ps1", ".psm1", ".json"}:
            for n, line in enumerate(text(p).splitlines(), 1):
                if bad.search(line):
                    findings.append(f"{p.relative_to(ROOT)}:{n}:{line}")
    assert not findings


def test_network_surface_is_isolated_to_fixed_update_checker() -> None:
    non_update = all_runtime_source(exclude_updates=True)
    for pattern in [
        r"Invoke-WebRequest",
        r"Invoke-RestMethod",
        r"Start-BitsTransfer",
        r"System\.Net\.WebClient",
        r"Net\.Http\.HttpClient",
        r"HttpWebRequest",
        r"UploadFile",
        r"UploadString",
        r"TcpClient",
        r"UdpClient",
        r"HttpListener",
        r"New-PSSession",
        r"Invoke-Command\s+-ComputerName",
    ]:
        assert re.search(pattern, non_update, re.I) is None, pattern
    checker = text(APP / "updates" / "UpdateChecker.psm1")
    assert checker.count("[Net.HttpWebRequest]::Create") == 1
    assert "https://www.dietrichailabs.com/updates/nyx-pc-checkup.json" in text(APP / "updates" / "Manifest.psm1")
    assert "Upload" not in checker


def test_scan_worker_is_read_only_and_isolated() -> None:
    source = text(APP / "workers" / "ScanWorker.ps1")
    assert "ReadOnly=$true" in source
    assert "actions\\StartupActions" not in source
    assert "actions\\CleanupActions" not in source
    for forbidden in ["Set-ItemProperty", "New-ItemProperty", "Remove-ItemProperty", "Clear-RecycleBin", "-Verb RunAs"]:
        assert forbidden not in source
    check_source = "\n".join(text(p) for p in sorted((APP / "checks").glob("*.psm1")))
    for forbidden in ["Set-ItemProperty", "New-ItemProperty", "Remove-ItemProperty", "Clear-RecycleBin", "Stop-Process", "Disable-NetAdapter"]:
        assert forbidden not in check_source


def test_health_states_and_acceptance_sentence_are_fixed() -> None:
    source = text(APP / "core" / "Models.psm1")
    assert "[ValidateSet('Good','NeedsAttention','Optional','Unknown')]" in source
    assert "Your PC looks good. Nothing needs fixing." in source
    assert "0–100" not in all_runtime_source()
    rules = json.loads(text(APP / "health_rules" / "rules.json"))
    assert rules["storage"]["criticalFreeBytes"] == 10 * 1024**3
    assert rules["storage"]["attentionFreeBytes"] == 20 * 1024**3
    assert rules["uptime"]["optionalDays"] == 14
    assert rules["battery"]["attentionHealthPercent"] == 50


@pytest.mark.parametrize(
    ("free", "total", "expected"),
    [
        (30 * 1024**3, 500 * 1024**3, "Good"),
        (4 * 1024**3, 500 * 1024**3, "NeedsAttention"),
        (0, 0, "Unknown"),
        (10 * 1024**3, 100 * 1024**3, "Good"),
        (10 * 1024**3 - 1, 100 * 1024**3, "NeedsAttention"),
    ],
)
def test_storage_rule_reference_boundaries(free: int, total: int, expected: str) -> None:
    rules = json.loads(text(APP / "health_rules" / "rules.json"))["storage"]
    if total <= 0:
        result = "Unknown"
    else:
        percent = round((free / total) * 100, 1)
        hard_floor = rules["criticalFreeBytes"] // 2
        if free < hard_floor or (free < rules["criticalFreeBytes"] and percent < rules["criticalFreePercent"]):
            result = "NeedsAttention"
        elif free < rules["criticalFreeBytes"] or (free < rules["attentionFreeBytes"] and percent < rules["attentionFreePercent"]):
            result = "NeedsAttention"
        else:
            result = "Good"
    assert result == expected


def test_startup_write_ahead_rollback_precedes_current_user_change() -> None:
    source = text(APP / "actions" / "StartupActions.psm1")
    body = source[source.index("function Disable-NyxStartupApplication") : source.index("function Enable-NyxStartupApplication")]
    journal = body.index("$journal = New-NyxUserStartupRollbackJournal")
    registry_change = body.index("Remove-ItemProperty")
    file_change = body.index("Move-Item -LiteralPath $state.SourcePath")
    assert journal < registry_change
    assert journal < file_change
    history = text(APP / "core" / "ActionHistory.psm1")
    assert "ProtectedData]::Protect" in history
    assert "DataProtectionScope]::CurrentUser" in history
    assert "Test-NyxCurrentUserRollbackState" in history


def test_all_users_startup_entries_are_read_only_and_never_elevate() -> None:
    actions = text(APP / "actions" / "StartupActions.psm1")
    checks = text(APP / "checks" / "StartupApps.psm1")
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "ReadOnlyRegistry" in actions and "ReadOnlyFolder" in actions
    assert "Version 1 does not modify all-users startup entries" in actions
    assert "Status 'ReadOnly'" in actions
    assert "CanModify=$editable" in checks
    assert "All-users startup entries are displayed read-only in Version 1" in checks
    assert "$State.Disable.Enabled=([bool]$app.Enabled -and [bool]$app.CanModify)" in ui
    assert "$State.Enable.Enabled=(-not [bool]$app.Enabled -and [bool]$app.CanModify)" in ui
    assert "never trigger elevation" in ui


def test_no_runtime_or_native_component_requests_elevation() -> None:
    runtime = all_runtime_source()
    assert re.search(r"-Verb\s+RunAs", runtime, re.I) is None
    assert "Test-NyxAdministrator" not in runtime
    assert "NeedsElevation" not in runtime
    manifest = text(ROOT / "native" / "app.manifest")
    assert 'requestedExecutionLevel level="asInvoker"' in manifest
    assert "requireAdministrator" not in manifest
    for native_name in ["installer.cpp", "launcher.cpp", "uninstaller.cpp"]:
        native = text(ROOT / "native" / native_name)
        assert "runas" not in native.lower()
        assert "ShellExecute" not in native


def test_current_user_rollback_validates_sid_scope_and_allowlist() -> None:
    history = text(APP / "core" / "ActionHistory.psm1")
    for token in [
        "The rollback journal belongs to a different Windows user",
        "Only non-elevated current-user rollback journals are accepted",
        "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
        "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        "The rollback startup file is outside the current-user Startup folder",
    ]:
        assert token in history
    actions = text(APP / "actions" / "StartupActions.psm1")
    assert "Only current-user rollback journals are accepted" in actions
    assert "OwnerSid=(Get-NyxCurrentUserSid)" in actions


def test_legacy_machine_rollback_is_independently_discovered_and_fail_closed() -> None:
    actions = text(APP / "actions" / "StartupActions.psm1")
    body = actions[actions.index("function Get-NyxLegacyMachineRollbackObligations") : actions.index("function New-NyxUserStartupRollbackJournal")]
    assert "$env:ProgramData" in actions
    assert "DietrichAI.NyxPCCheckup\\startup-rollback" in actions
    assert "Get-ChildItem -LiteralPath $root.FullName" in body
    assert "rollback.json" in body
    assert "Status='Clear'" in body
    assert "'Unknown'" in body and "'Present'" in body
    assert "Get-NyxStartupRollbackInventory" not in body
    assert "Test-Path -LiteralPath $rootPath" not in body
    assert "ErrorCategory]::ObjectNotFound" in body
    assert "PermissionDenied" in body


def test_uninstall_checks_legacy_and_current_recovery_before_removal() -> None:
    source = text(APP / "workers" / "UninstallWorker.ps1")
    legacy = source.index("$legacy=Get-NyxLegacyMachineRollbackObligations")
    legacy_abort = source.index("exit 7", legacy)
    current = source.index("$currentUserInventory=Get-NyxStartupRollbackInventory", legacy_abort)
    current_abort = source.index("exit 6", current)
    restores = source.index("$restores=@(Restore-AllNyxStartupApplications", current_abort)
    removal = source.index("Remove-Item -LiteralPath 'HKCU:\\Software", restores)
    assert legacy < legacy_abort < current < current_abort < restores < removal
    assert "Independent repair of the legacy machine-level rollback is required" in source
    assert "Uninstall stopped before removing the application, shortcuts, registration, or local recovery data" in source


def test_action_worker_accepts_only_fixed_operations_and_uuid_ipc() -> None:
    source = text(APP / "workers" / "ActionWorker.ps1")
    operations = set(re.findall(r"^\s*'([A-Za-z]+)'\s*\{", source, re.M))
    assert operations == {"DisableStartup", "EnableStartup", "Cleanup"}
    assert r"^action-([a-f0-9]{32})-request\.json$" in source
    assert r"^action-([a-f0-9]{32})-result\.json$" in source
    assert "RequestSha256" in source
    assert "ReadAllBytes($files.Request)" in source
    assert "confirmed action request changed before execution" in source
    assert "ConfirmedByUser" in source
    assert "non-elevated worker" in source


def test_cleanup_is_unselected_revalidated_bounded_and_recycled() -> None:
    scan = text(APP / "checks" / "CleanupScan.psm1")
    action = text(APP / "actions" / "CleanupActions.psm1")
    assert "SelectedByDefault=$false" in scan
    assert "MaxVisitedFiles=100000" in scan and "MaxSeconds=30" in scan
    assert "Assert-NyxCleanupParentChain" in action
    assert action.count("Get-NyxValidatedCleanupFile -Candidate $item") >= 2
    assert "RecycleOption]::SendToRecycleBin" in action
    assert "Delete selected" not in action
    for category in ["User temporary files", "Old installer in Downloads", "Old archive in Downloads"]:
        assert category in action


def test_reports_use_structured_privacy_minimization_before_serialization() -> None:
    report = text(APP / "reports" / "ReportExport.psm1")
    privacy = text(APP / "core" / "Privacy.psm1")
    assert "Protect-NyxObject -InputObject $report" in report
    assert "function ConvertTo-NyxPrivateValue" in privacy
    assert "Test-NyxSensitivePropertyName" in privacy
    for role in ["password", "token", "authorization", "connectionstring", "protectedstate"]:
        assert role in privacy.lower()
    assert "[Net.IPAddress]::TryParse" in privacy
    assert "IPv4-mapped IPv6" in privacy
    assert "::1" in privacy and "2001:db8::1" in privacy



def test_uninstall_final_cleanup_uses_safe_external_cwd_and_fails_observably() -> None:
    native = text(ROOT / "native" / "uninstaller.cpp")
    worker = text(APP / "workers" / "UninstallWorker.ps1")
    assert 'nyx_wcopy(safeCwd,systemRoot,1024)' in native
    assert 'nyx_wcat(safeCwd,L"\\\\System32",1024)' in native
    assert "nyx_run_hidden_worker(ps,cmd,safeCwd)" in native
    assert "nyx_run(ps,cmd,root,TRUE)" not in native
    for token in [
        "$safeWorkingDirectory",
        "-WorkingDirectory $safeWorkingDirectory",
        "-PassThru -ErrorAction Stop",
        "cleanup could not be scheduled from a safe Windows directory",
        "final uninstall cleanup process could not be started",
        "exit 8",
        "$cleanupFailureMarker",
        "INSTALL_ROOT_REMOVE_FAILED",
        "$expectedDataRoot",
        "Unexpected Nyx data root",
    ]:
        assert token in worker
    schedule = worker.index("$cleanup=Start-Process")
    success = worker.rindex("exit 0")
    assert schedule < success
    assert worker.index("exit 6") < schedule
    assert worker.index("exit 7") < schedule


def test_installer_and_uninstaller_enforce_exact_per_user_root_and_manifest() -> None:
    install = text(APP / "workers" / "InstallWorker.ps1")
    uninstall = text(APP / "workers" / "UninstallWorker.ps1")
    expected = "Programs\\Dietrich AI Labs\\Nyx PC Checkup"
    assert expected in install and expected in uninstall
    assert "PAYLOAD_MANIFEST.json" in install
    assert "unexpected file appeared in the clean payload" in install.lower()
    assert "Get-FileHash" in install
    assert "reparse" in install.lower() and "reparse" in uninstall.lower()


def test_native_pe_candidates_are_hardened_x64_gui_with_manifest() -> None:
    candidates = [
        ROOT / "build" / "native" / "Nyx PC Checkup.exe",
        ROOT / "build" / "native" / "Uninstall Nyx PC Checkup.exe",
        DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe",
    ]
    for path in candidates:
        require_artifact(path)
        pe = parse_pe(path)
        assert pe["machine"] == 0x8664
        assert pe["magic"] == 0x20B
        assert pe["subsystem"] == 2
        assert pe["timestamp"] == 0
        assert pe["dll_characteristics"] & 0x40
        assert pe["dll_characteristics"] & 0x100
        assert pe["dll_characteristics"] & 0x20
        assert pe["resource_rva"] and pe["resource_size"]
        data = path.read_bytes()
        assert b"asInvoker" in data
        assert "Nyx PC Checkup".encode("utf-16le") in data


def test_stage_payload_manifest_is_exact_and_clean() -> None:
    manifest_path = STAGE / "PAYLOAD_MANIFEST.json"
    require_artifact(manifest_path)
    manifest = json.loads(text(manifest_path))
    assert manifest["build"] == BUILD_ID
    expected = {entry["path"]: entry for entry in manifest["files"]}
    actual = {
        p.relative_to(STAGE).as_posix(): p
        for p in STAGE.rglob("*")
        if p.is_file() and p != manifest_path
    }
    assert set(expected) == set(actual)
    for rel, p in actual.items():
        assert expected[rel]["size"] == p.stat().st_size
        assert expected[rel]["sha256"] == sha256(p)
    forbidden_parts = {"tests", "evidence", ".git", "__pycache__", ".pytest_cache", "source"}
    for rel in actual:
        assert forbidden_parts.isdisjoint(PurePosixPath(rel).parts)
        assert not rel.endswith((".pyc", ".log", ".dmp"))
    assert "app/platform/linux/CONTRACT.md" not in actual
    assert "app/updates/UpdateChecker.psm1" in actual
    assert "app/workers/UpdateCheckWorker.ps1" in actual


def test_release_archives_are_safe_and_have_expected_roots() -> None:
    for archive in [DIST / "Nyx_PC_Checkup_1.0.0_Portable.zip", DIST / "Nyx_PC_Checkup_1.0.0_Source.zip"]:
        require_artifact(archive)
        assert validate_zip(archive) == []
        with zipfile.ZipFile(archive) as zf:
            roots = {PurePosixPath(i.filename).parts[0] for i in zf.infolist() if i.filename}
            assert len(roots) == 1


def test_source_archive_identity_is_exact_and_self_excluding() -> None:
    source_zip = DIST / "Nyx_PC_Checkup_1.0.0_Source.zip"
    require_artifact(source_zip)
    with zipfile.ZipFile(source_zip) as zf:
        identity_name = next(name for name in zf.namelist() if name.endswith("/SOURCE_TREE_IDENTITY.json"))
        archive_root = identity_name.rsplit("/", 1)[0] + "/"
        identity = json.loads(zf.read(identity_name))
        assert identity["build"] == BUILD_ID
        assert identity["identityExcludes"] == ["SOURCE_TREE_IDENTITY.json"]
        records = []
        aggregate = hashlib.sha256()
        for name in sorted((n for n in zf.namelist() if not n.endswith("/") and n != identity_name), key=str.casefold):
            rel = name[len(archive_root) :]
            data = zf.read(name)
            digest = hashlib.sha256(data).hexdigest().upper()
            records.append({"path": rel, "size": len(data), "sha256": digest})
            aggregate.update(rel.encode() + b"\0" + str(len(data)).encode("ascii") + b"\0" + digest.encode("ascii") + b"\n")
        assert identity["files"] == records
        assert identity["fileCount"] == len(records)
        assert identity["treeSha256"] == aggregate.hexdigest().upper()


def test_runtime_does_not_contain_excluded_pc_cleaner_features() -> None:
    source = all_runtime_source().lower()
    for token in [
        "pnputil",
        "disable-windowsoptionalfeature",
        "set-service -startuptype disabled",
        "netsh interface ip set dns",
        "set-dnsclientserveraddress",
        "set-netfirewallprofile",
        "set-mppreference -disablerealtimemonitoring",
    ]:
        assert token not in source
    assert "no ram-cleaning button" not in source


def test_documentation_and_handoff_inputs_are_complete() -> None:
    required_docs = {
        "ARCHITECTURE.md",
        "MODULE_MAP.md",
        "MODULE_CONTRACTS.md",
        "USER_GUIDE.md",
        "PRIVACY_AND_SECURITY.md",
        "INSTALL_UPGRADE_UNINSTALL.md",
        "KNOWN_LIMITATIONS.md",
        "BUILD_AND_REPRODUCE.md",
        "QA_TEST_PLAN.md",
        "WHO_GETS_WHAT_NEXT.md",
        "RELEASE_NOTES.md",
        "QA2_CORRECTION_MATRIX.md",
        "QA3_CORRECTION_MATRIX.md",
        "UPDATE_CHECK_IMPLEMENTATION.md",
    }
    assert required_docs <= {p.name for p in (ROOT / "docs").glob("*.md")}
    for name in ["Run-WindowsSmokeTests.ps1", "Run-WindowsElevatedStartupRollback.ps1", "Run-WindowsQA2MigrationRegression.ps1", "Run-WindowsInstallerLifecycle.ps1"]:
        assert (ROOT / "tests" / "powershell" / name).exists()
    sbom = json.loads(text(ROOT / "SBOM.json"))
    assert sbom["bomFormat"] == "CycloneDX"
    assert sbom["metadata"]["component"]["version"] == "1.0.0"


def test_configuration_and_rollback_inputs_are_bounded() -> None:
    configuration = text(APP / "core" / "Configuration.psm1")
    history = text(APP / "core" / "ActionHistory.psm1")
    for token in [
        "function Repair-NyxConfiguration",
        "FollowWindows",
        "-Minimum 65536 -Maximum 10485760",
        "-Minimum 1000 -Maximum 2000000",
        "The configuration file is not an ordinary bounded file",
        "The configuration destination is not an ordinary file",
        "ConvertTo-NyxUtcTimestampText",
    ]:
        assert token in configuration
    assert "$journal.Length -gt 2097152" in history
    assert "rollback.dpapi" in history
    assert "FileAttributes]::ReparsePoint" in history
    assert "Get-ChildItem -LiteralPath $root.FullName -File -Force" in history
    assert "Unexpected file exists in the current-user rollback root" in history
    assert "Get-ChildItem -LiteralPath $root.FullName -Directory -Force" in history


def test_update_preferences_are_in_existing_configuration_system() -> None:
    defaults = json.loads(text(APP / "config" / "defaults.json"))
    assert defaults["updates"] == {"enabled": True, "lastCheckUtc": ""}
    configuration = text(APP / "core" / "Configuration.psm1")
    assert "updates=[pscustomobject][ordered]" in configuration
    assert "lastCheckUtc=(ConvertTo-NyxUtcTimestampText" in configuration
    assert "another settings database" not in all_runtime_source().lower()


def test_update_ui_has_setting_without_weekly_promise_and_nonblocking_worker() -> None:
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "Automatically check for updates once a week" not in ui
    assert "optional weekly update check" not in ui
    assert "Check for Updates Now" in ui
    assert "Start-NyxUpdateCheck -Manual" in ui
    assert "$form.Add_Shown({" in ui
    assert "Start-NyxUpdateCheck" in ui
    assert "UpdateCheckWorker.ps1" in ui
    assert "UpdateTimer" in ui
    assert "Start-Process" in ui
    assert "Checking the official Dietrich AI Labs update manifest" in ui


def test_update_ui_suppresses_same_version_per_session_and_only_opens_allowlisted_release_url() -> None:
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "ShownUpdateVersion" in ui
    assert "Update $version was already shown during this session" in ui
    assert "Show-NyxUpdateAvailableDialog" in ui
    assert "Test-NyxUpdateDestinationUri -Value ([string]$result.Manifest.ReleaseUrl) -Purpose 'Release'" in ui
    assert "Invoke-NyxOpen ([string]$result.Manifest.ReleaseUrl)" in ui
    assert "DownloadFile" not in ui and "Start-BitsTransfer" not in ui


def test_update_checker_keeps_tls_validation_and_rejects_redirects_and_oversize() -> None:
    checker = text(APP / "updates" / "UpdateChecker.psm1")
    manifest = text(APP / "updates" / "Manifest.psm1")
    assert "$request.AllowAutoRedirect=$false" in checker
    assert "$request.Timeout=[int]$config.TimeoutMilliseconds" in checker
    assert "$request.ReadWriteTimeout=[int]$config.TimeoutMilliseconds" in checker
    assert "MaximumResponseBytes=65536" in manifest
    assert "The update manifest response is oversized" in checker
    assert r"[\x00-\x1F\x7F]" in manifest
    assert "ServerCertificateValidationCallback" not in all_runtime_source()
    assert "CertificatePolicy" not in all_runtime_source()
    assert "ServicePointManager" not in all_runtime_source()


def test_update_checker_is_notification_only_not_an_automatic_updater() -> None:
    update_source = "\n".join(text(p) for p in sorted((APP / "updates").glob("*.psm1"))) + text(APP / "workers" / "UpdateCheckWorker.ps1")
    for forbidden in [
        "DownloadFile",
        "DownloadString",
        "Start-BitsTransfer",
        "WebClient",
        "Process.Start",
        "Start-Process",
        "msiexec",
        "ShellExecute",
    ]:
        assert forbidden not in update_source
    assert "View Update" in text(APP / "ui" / "Dialogs.psm1")
    assert "Remind Me Later" in text(APP / "ui" / "Dialogs.psm1")


def test_semantic_version_and_manifest_validation_are_isolated_from_ui() -> None:
    versioning = text(APP / "updates" / "Versioning.psm1")
    manifest = text(APP / "updates" / "Manifest.psm1")
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "function Compare-NyxSemanticVersion" in versioning
    assert "Numeric prerelease identifiers cannot contain leading zeroes" in versioning
    assert "[StringComparison]::Ordinal" in versioning
    assert "manifest belongs to a different product" in manifest
    assert "schema version is unsupported" in manifest
    assert "missing required field" in manifest
    assert "Test-NyxUpdateDestinationUri" in manifest
    # The UI may parse a bounded local worker-result envelope, but it must not
    # fetch, validate, or compare the remote manifest itself.
    update_ui = ui[ui.index("function Start-NyxUpdateCheck") : ui.index("function Show-NyxMainWindow")]
    assert "Get-NyxUpdateManifestText" not in update_ui
    assert "ConvertTo-NyxValidatedUpdateManifest" not in update_ui
    assert "Compare-NyxSemanticVersion" not in ui


def test_update_failure_is_noncritical_and_automatic_success_is_silent() -> None:
    checker = text(APP / "updates" / "UpdateChecker.psm1")
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "CHECK_FAILED" in checker
    assert "NETWORK_OR_TLS_FAILURE" in checker
    assert "INVALID_RESPONSE_OR_METADATA" in checker
    assert "if($manual)" in ui
    up_to_date_case = ui[ui.index("'UP_TO_DATE'") : ui.index("'CHECK_FAILED'")]
    assert "if($manual)" in up_to_date_case
    assert "Unable to check for updates" in ui


def test_qa2_correction_matrix_covers_exact_findings_and_prior_identity() -> None:
    matrix = text(ROOT / "docs" / "QA2_CORRECTION_MATRIX.md")
    for token in [
        "F-001",
        "F-002",
        "F-003",
        "61B870429BDB22A3F7106A8720A9EE9845D9C2D8B499336E5E1EF9EFBC4D81AF",
        "5DE23C322DD48C69FCEC47331217962603CDE8011CDE9A90083371D3FDDFF6E5",
        "667,197 bytes",
        "2026.08.23-eng-qa2",
        BUILD_ID,
        "all-users entries are read-only",
        "legacy machine rollback",
        "compressed IPv6",
    ]:
        assert token.lower() in matrix.lower()


def test_unknown_state_conservatism_and_security_coverage() -> None:
    network = text(APP / "checks" / "NetworkBasics.psm1")
    security = text(APP / "checks" / "SecurityStatus.psm1")
    apps = text(APP / "checks" / "InstalledApps.psm1")
    assert "Nyx will not call the connection broken" in network
    assert "-Status 'Unknown'" in network
    assert "security.windows-security-service" in security
    assert "SecurityHealthService" in security and "wscsvc" in security
    assert "security.tpm" in security and "Get-Tpm" in security
    assert "Windows returned no firewall-profile records" in security
    assert "Windows returned no supported installed-application records" in apps
    assert "-Complete $false" in apps


def test_battery_profile_and_local_data_hardening_contracts() -> None:
    battery = text(APP / "checks" / "BatteryHealth.psm1")
    storage = text(APP / "checks" / "StorageScan.psm1")
    paths = text(APP / "core" / "Paths.psm1")
    assert "[math]::Min(100" in battery
    assert "ChargingState" in battery and "Get-NyxBatteryChargingState" in battery
    assert "Name='User profile'" in storage
    assert "UserProfile=$profileResult" in storage
    assert "Assert-NyxOrdinaryDataDirectory" in paths
    assert "FileAttributes]::ReparsePoint" in paths
    assert "cannot be a junction or symbolic link" in paths


def test_ui_cancel_cleanup_refresh_and_notification_contracts() -> None:
    ui = text(APP / "ui" / "MainWindow.psm1")
    assert "Check cancelled. Partial results were preserved." in ui
    assert "Cleanup finished. Refreshing the read-only cleanup preview." in ui
    assert "Start-NyxScan -Mode 'Full';return" in ui
    assert "Show-NyxConservativeNotification -Scan $script:NyxUi.Scan" in ui
    assert "Show-NyxCompletionNotification" not in ui
    assert "Save settings" in ui
    assert "$script:NyxUi.ScanProcess.Kill()" in ui
    assert "$script:NyxUi.UpdateProcess.Kill()" in ui


def test_native_launchers_do_not_disable_stack_argument_probing() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    assert "-mno-stack-arg-probe" not in builder
    for name in ["launcher.cpp", "uninstaller.cpp", "installer.cpp"]:
        native = text(ROOT / "native" / name)
        assert "static WCHAR" in native
    assert "WCHAR exe[1024]={0}" not in text(ROOT / "native" / "launcher.cpp")
    assert "WCHAR cmd[4096]={0}" not in text(ROOT / "native" / "installer.cpp")


def test_windows_suites_cover_privilege_privacy_update_migration_and_uninstall_boundaries() -> None:
    smoke = text(ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1")
    privilege = text(ROOT / "tests" / "powershell" / "Run-WindowsElevatedStartupRollback.ps1")
    migration = text(ROOT / "tests" / "powershell" / "Run-WindowsQA2MigrationRegression.ps1")
    lifecycle = text(ROOT / "tests" / "powershell" / "Run-WindowsInstallerLifecycle.ps1")
    for token in ["Current-user startup disable completes", "2001:db8::1", "Password", "Manual update"]:
        assert token in smoke
    for token in ["All-users entry is read-only", "No UAC", "legacy machine rollback", "alternate administrator"]:
        assert token.lower() in privilege.lower()
    for token in ["Exact QA2 setup fixture hash matches", "Corrected build identifies QA2 user schema", "Tampered QA2 journal fails closed", "Uninstall restores QA2 current-user rollback before removal"]:
        assert token in migration
    for token in ["Fresh install", "Repair", "Uninstall", "legacy machine rollback", "docs\\USER_GUIDE.md"]:
        assert token.lower() in lifecycle.lower()


def test_local_reproducibility_wrapper_is_present_and_network_free() -> None:
    wrapper_path = ROOT / "tools" / "build_and_verify_reproduction.py"
    assert wrapper_path.exists()
    wrapper = text(wrapper_path)
    assert "REPRODUCIBILITY_CHECK.json" in wrapper
    assert '"networkUsed": False' in wrapper
    assert '"githubUsed": False' in wrapper
    assert "sourceExactMatch" in wrapper
    for token in ["urllib", "requests", "http://", "https://"]:
        assert token not in wrapper


def test_builder_resolves_local_toolchain_and_copies_all_tests() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    assert 'shutil.which("clang++")' in builder
    assert 'shutil.which("lld-link")' in builder
    assert "NYX_CLANG" in builder and "NYX_LLD_LINK" in builder
    assert "/usr/local/swift/usr/bin" not in builder
    assert "for path in iter_files(ROOT / \"tests\")" in builder
    assert "Nyx_PC_Checkup_1.0.0_Engineering_QA15_F012_Corrected_Master_Handoff.zip" in builder
    assert '"automaticUpdaterImplemented": False' in builder
    assert '"websiteManifestDeployedByEngineering": False' in builder


def test_installer_finalization_is_quiet_aware_and_transactional() -> None:
    worker = text(APP / "workers" / "InstallWorker.ps1")
    native = text(ROOT / "native" / "installer.cpp")
    for token in [
        "[int]$Quiet=0",
        "function Get-NyxFileSnapshot",
        "function Restore-NyxFileSnapshot",
        "function Get-NyxRegistrySnapshot",
        "function Restore-NyxRegistrySnapshot",
        "$snapshotsCaptured=$true",
        "Restore-NyxFileSnapshot -Snapshot $startSnapshot",
        "Restore-NyxRegistrySnapshot -Snapshot $uninstallSnapshot",
        "if($Quiet -ne 1)",
    ]:
        assert token in worker
    install_state = worker.index("install-state.json")
    shortcut = worker.index("$shortcut=$shell.CreateShortcut", install_state)
    registry = worker.index("New-Item -Path $uninstallKey", shortcut)
    assert install_state < shortcut < registry
    assert "nyx_finalize(const WCHAR* target,BOOL desktop,BOOL quiet)" in native
    assert 'nyx_wcat(cmd,L" -Quiet ",4096)' in native
    assert "nyx_finalize(g_install_target,desktop,quiet)" in native


def test_installer_and_uninstaller_reject_reparse_backed_boundaries() -> None:
    native = text(ROOT / "native" / "installer.cpp")
    uninstaller = text(APP / "workers" / "UninstallWorker.ps1")
    for token in [
        "FILE_ATTRIBUTE_REPARSE_POINT",
        "nyx_ordinary_dir",
        "CREATE_NEW",
        "colliding temporary installation path",
        "reparse-backed existing installation directory",
        "reparse-backed installation parent directory",
    ]:
        assert token in native
    assert "The uninstall location is missing, invalid, or reparse-backed" in uninstaller
    assert "The application directory failed its safety boundary check" in uninstaller
    assert uninstaller.count("FileAttributes]::ReparsePoint") >= 2


def test_engineering_evidence_boundary_names_all_windows_suites() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    readme = text(ROOT / "README_FIRST.md")
    for token in ["normal-user smoke and privacy/update", "privilege-boundary and legacy rollback", "exact QA2-to-QA9 user rollback migration", "installer lifecycle"]:
        assert token in builder
        assert token in readme

def test_update_schema_requires_exact_integer_type() -> None:
    manifest = text(APP / "updates" / "Manifest.psm1")
    assert "@('System.Int32','System.Int64') -notcontains $schemaType" in manifest
    assert "[int64]$schemaValue -ne 1" in manifest


def test_builder_purges_python_caches_before_clean_inventory_and_handoff_copy() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    assert "def remove_python_caches(root: Path)" in builder
    assert builder.count("remove_python_caches(ROOT)") >= 3
    assert 'if any(part in {"__pycache__", ".pytest_cache"} for part in rel.parts):' in builder
    assert 'if path.suffix.lower() in {".pyc", ".pyo"}:' in builder


def test_gate_records_exact_qa4_windows_harness_hold_and_reviewed_candidate_identity() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    for token in [
        "Nyx_PC_Checkup_1.0.0_QA4_Windows_Harness_HOLD_Master_Handoff(1).zip",
        "Nyx_PC_Checkup_1.0.0_Engineering_QA4_Corrected_Master_Handoff(1).zip",
        "1547058",
        "D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1",
        "1548197",
        "22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7",
        "FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5",
        "22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36",
    ]:
        assert token in builder


def test_qa4_windows_harness_correction_is_documented_and_build_gated() -> None:
    matrix = text(ROOT / "docs" / "QA4_WINDOWS_HARNESS_CORRECTION.md")
    builder = text(ROOT / "tools" / "build_release.py")
    readme = text(ROOT / "README_FIRST.md")
    for token in [
        "D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1",
        "22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7",
        "Argument types do not match",
        "QA22-F019-PS51-22",
        "ToArray()",
        "new product candidate",
    ]:
        assert token.lower() in matrix.lower()
        assert token.lower() in readme.lower()
    for token in [
        "write_qa4_windows_harness_correction_evidence",
        "QA4_WINDOWS_HARNESS_CORRECTION.json",
        "legacyGenericListConstructorsRemaining",
        "unsafeDirectGenericListArrayConversionsRemaining",
        '"runtimeSweepExpanded": True',
        '"windowsPowerShell51ExecutedByEngineering": False',
    ]:
        assert token in builder



def test_qa5_native_windows_failures_are_documented_and_build_gated() -> None:
    matrix = text(ROOT / "docs" / "QA5_WINDOWS_EXECUTION_CORRECTION.md")
    builder = text(ROOT / "tools" / "build_release.py")
    readme = text(ROOT / "README_FIRST.md")
    for token in [
        "B72A0BAD2094F37EAE1E853794A72763A9ACF76D3B27E776AC5FB8647F19B349",
        "5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298",
        "QA5-WIN-001",
        "QA5-WIN-002",
        "QA5-ORCH-001",
        "QA5-ENC-001",
        "automatic-variable collision",
        "QA22-F019-PS51-22",
        "RUN_QA15_WINDOWS_GATE.ps1",
    ]:
        assert token.lower() in matrix.lower()
        assert token.lower() in readme.lower()
    for token in [
        "write_qa5_windows_execution_correction_evidence",
        "QA5_WINDOWS_EXECUTION_CORRECTION.json",
        "ambiguousUnqualifiedVariableColonPatternsRemaining",
        "protectedErrorVariableBindingsRemaining",
        "unsafeBomlessNonAsciiFilesRemaining",
        "nativeParserPreflightInRunner",
        "runnerValidatesHarnessReports",
        '"windowsPowerShell51ExecutedByEngineering": False',
        "PRIOR_QA_EVIDENCE",
    ]:
        assert token in builder


def test_qa6_native_module_composition_failure_is_documented_and_build_gated() -> None:
    matrix = text(ROOT / "docs" / "QA6_MODULE_COMPOSITION_CORRECTION.md")
    builder = text(ROOT / "tools" / "build_release.py")
    readme = text(ROOT / "README_FIRST.md")
    routing = text(ROOT / "docs" / "WHO_GETS_WHAT_NEXT.md")
    for token in [
        "E81C56200A409B83E3A1B04A045D4726BE41C24494ED459FB9B91EAB4CACE324",
        "38B28BB535067EB0B8508A364F6D9EE1DB6FC068D72608F83CFD34F8D28D41C7",
        "QA6-F-005",
        "New-NyxCheckResult",
        "RuntimeComposition.psm1",
        "QA22-F019-PS51-22",
        "HarnessInferenceFromImmutableQA2Source",
    ]:
        assert token.lower() in matrix.lower()
        assert token.lower() in readme.lower()
    for token in [
        "QA6_FAIL_EVIDENCE",
        "write_qa6_module_composition_correction_evidence",
        "QA6_MODULE_COMPOSITION_CORRECTION.json",
        "nestedRuntimeImportStatementsRemaining",
        "realApplicationQuickCheckLaunchesRequired",
        "nativeInstallerBranchIds",
        '"exactQa6FailIncluded": True',
    ]:
        assert token in builder
    assert "Engineering and Independent QA" in routing
    assert "No additional reviewer" in routing


def test_qa3_correction_matrix_covers_f004_and_exact_intake() -> None:
    matrix = text(ROOT / "docs" / "QA3_CORRECTION_MATRIX.md")
    for token in [
        "F-004",
        "2B7530BA910B5E7997699A6B49483B9B56DBF12785D6D91E9CEA81BCA6F07DA0",
        "B89BDF579BB7EFB7D7DB28A49971576FD8A8682C731BAC5FE965362B6BAAFD4D",
        "FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5",
        "DPAPI CurrentUser",
        "normalized in memory",
        "Machine-scope",
        "2026.08.23-eng-qa4",
    ]:
        assert token.lower() in matrix.lower()


def test_qa2_user_migration_is_narrow_dpapi_first_and_fail_closed() -> None:
    history = text(APP / "core" / "ActionHistory.psm1")
    inventory = history[history.index("function Get-NyxStartupRollbackInventory") : history.index("function Get-NyxActiveStartupDisables")]
    assert inventory.index("Unprotect-NyxState") < inventory.index("Resolve-NyxCurrentUserRollbackState")
    converter = history[history.index("function ConvertFrom-NyxQA2CurrentUserRollbackState") : history.index("function Resolve-NyxCurrentUserRollbackState")]
    for token in [
        "Test-NyxRollbackExactProperties",
        "JournalScope",
        "RequiresElevation",
        "OwnerSid",
        "JournalVersion=1",
        "OwnerSid=(Get-NyxRollbackCurrentUserSid)",
        "A legacy machine rollback pointer cannot enter the current-user restore path",
        "Test-NyxCurrentUserRollbackState",
    ]:
        assert token in converter
    assert "QA2-User" in history
    assert "NormalizedInMemory" in inventory


def test_current_cycle_routing_is_engineering_and_independent_qa_only() -> None:
    routing = text(ROOT / "docs" / "WHO_GETS_WHAT_NEXT.md")
    scope = text(ROOT / "docs" / "ENGINEERING_SCOPE.md")
    assert "Engineering and Independent QA" in routing
    assert "No additional reviewer" in routing
    assert "Engineering and Independent QA" in scope
    assert routing.count("## Independent QA") == 1
    assert routing.count("## Engineering") == 1
    assert "No additional reviewer, gate, recipient, or blocker is designated" in routing
    assert "No additional reviewer, approval gate, recipient, release authority, or blocker is designated" in scope
    builder = text(ROOT / "tools" / "build_release.py")
    assert '"nextAuthority": "Independent QA: PASS / CONDITIONAL PASS / HOLD / FAIL"' in builder


def test_exact_qa2_fixture_files_are_copied_as_tests_not_runtime_payload() -> None:
    fixture_dir = ROOT / "tests" / "fixtures" / "qa2"
    assert (fixture_dir / "Nyx_PC_Checkup_1.0.0_QA2_Setup.exe").exists()
    assert (fixture_dir / "Nyx_PC_Checkup_1.0.0_QA2_Source.zip").exists()
    builder = text(ROOT / "tools" / "build_release.py")
    assert 'for path in iter_files(ROOT / "tests")' in builder
    assert "for path in iter_files(APP)" in builder
    assert "tests" in builder and "forbidden" in builder


def test_qa7_handoff_exposes_manifest_bound_root_windows_runner() -> None:
    builder = text(ROOT / "tools" / "build_release.py")
    runner = text(ROOT / "tests" / "powershell" / "RUN_QA15_WINDOWS_GATE.ps1")
    readme = text(ROOT / "README_FIRST.md")
    assert 'HANDOFF / "RUN_QA15_WINDOWS_GATE.ps1"' in builder
    assert 'root + "RUN_QA15_WINDOWS_GATE.ps1"' in builder
    assert "QA15_WINDOWS_PARSE_PREFLIGHT.json" in runner
    assert "ExpectedReportPath" in runner
    assert "ReportValidationError" in runner
    assert "Harness report verdict is FAIL" in runner
    assert '-File ".\\RUN_QA15_WINDOWS_GATE.ps1"' in readme

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / "native" / "installer.cpp"
HELPER = ROOT / "tests" / "powershell" / "InstallerDiagnosticsHelpers.ps1"
LIFECYCLE = ROOT / "tests" / "powershell" / "Run-WindowsInstallerLifecycle.ps1"
MIGRATION = ROOT / "tests" / "powershell" / "Run-WindowsQA2MigrationRegression.ps1"
RUNNER = ROOT / "tests" / "powershell" / "RUN_QA11_WINDOWS_GATE.ps1"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_native_installer_emits_machine_readable_diagnostics_for_every_exit_branch() -> None:
    source = read(INSTALLER)
    for token in (
        "/diagnostics:",
        "dietrich-ai-labs.nyx-pc-checkup.setup-diagnostics.v1",
        "2026.08.29-eng-qa11-f010-r3",
        "LOCALAPPDATA_MISSING",
        "INSTALL_PARENT_UNSAFE",
        "RUNNING_INSTANCE",
        "TEMP_PATH_COLLISION",
        "PAYLOAD_STAGE_WRITE_FAILED",
        "EXISTING_TARGET_REPARSE",
        "EXISTING_TARGET_INVALID",
        "ROLLBACK_BOUNDARY_FAILED",
        "ACTIVATION_FAILED",
        "FINALIZATION_FAILED",
        "USER_CANCELLED",
        "SUCCESS",
        "parentAttributes",
        "parentIsReparsePoint",
        "parentWriteProbeSucceeded",
        "resolvedInstallParent",
        "resolvedInstallTarget",
        "childExitCode",
    ):
        assert token in source
    assert "CREATE_NEW" in source
    assert "nyx_valid_diagnostics_destination" in source
    assert "Nyx_PC_Checkup_Setup_Diagnostics_" in source


def test_installer_preflight_records_environment_acl_reparse_resolution_and_write_probe() -> None:
    source = read(HELPER)
    for token in (
        "LocalAppDataEnvironment",
        "LocalAppDataSpecialFolder",
        "PathComponents",
        "ResolvedPath",
        "Attributes",
        "IsReparsePoint",
        "AclOwner",
        "AclSddl",
        "WriteCapability",
        "NearestExistingAncestor",
        "Invoke-NyxSetupWithDiagnostics",
        "Read-NyxSetupDiagnostic",
        "New-NyxQA2ExitInference",
        "HarnessInferenceFromImmutableQA2Source",
    ):
        assert token in source


def test_current_setup_harnesses_require_valid_branch_diagnostics() -> None:
    lifecycle = read(LIFECYCLE)
    migration = read(MIGRATION)
    assert lifecycle.count("Invoke-NyxSetupWithDiagnostics") >= 4
    assert lifecycle.count("DiagnosticValid") >= 4
    assert "RUNNING_INSTANCE" in lifecycle
    assert lifecycle.count("branchId -eq 'SUCCESS'") >= 3
    assert "InstallerEnvironmentPreflight" in lifecycle
    assert "SetupRuns=@($setupRuns.ToArray())" in lifecycle

    assert "Invoke-NyxSetupWithDiagnostics" in migration
    assert "New-NyxQA2ExitInference" in migration
    assert "QA2SetupInferences" in migration
    assert "CorrectedSetupRuns" in migration
    assert "InstallerEnvironmentPreflight" in migration
    assert "2026.08.29-eng-qa11-f010-r3" in migration


def test_qa7_runner_manifest_binds_helper_and_complete_evidence_tree() -> None:
    source = read(RUNNER)
    assert "InstallerDiagnosticsHelpers.ps1" in source
    assert "InstallerDiagnosticsHelperSha256" in source
    assert "QA11_WINDOWS_PARSE_PREFLIGHT.json" in source
    assert "QA11_WINDOWS_RUN_SUMMARY.json" in source
    assert 'Compress-Archive -LiteralPath $evidence' in source
    assert "$script:ExpectedHarnessRevision='QA11-F010-PS51-11'" in source
    assert "$script:ExpectedBuild='2026.08.29-eng-qa11-f010-r3'" in source

from __future__ import annotations

import copy
import hashlib
import json
import ntpath
import re
import zipfile
from pathlib import Path, PurePosixPath

import pytest

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
FIXTURES = ROOT / "tests" / "fixtures" / "qa2"
MANIFEST_PATH = FIXTURES / "QA2_FIXTURE_MANIFEST.json"
QA2_SETUP = FIXTURES / "Nyx_PC_Checkup_1.0.0_QA2_Setup.exe"
QA2_SOURCE = FIXTURES / "Nyx_PC_Checkup_1.0.0_QA2_Source.zip"
ACTION_ID = "0123456789abcdef0123456789abcdef"
CURRENT_SID = "S-1-5-21-1000-2000-3000-1001"
STARTUP = r"C:\Users\QA\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
ROLLBACK = rf"C:\Users\QA\AppData\Local\Dietrich AI Labs\Nyx PC Checkup\actions\disabled-startup\{ACTION_ID}"

QA2_FIELDS = {
    "JournalScope",
    "ActionId",
    "OwnerSid",
    "Id",
    "Name",
    "Publisher",
    "SourceType",
    "SourcePath",
    "SourceLabel",
    "ValueName",
    "ValueKind",
    "Command",
    "ExecutablePath",
    "RequiresElevation",
    "BackupPath",
    "SourceLength",
    "SourceHash",
}
V1_FIELDS = QA2_FIELDS | {"JournalVersion"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def win(path: str) -> str:
    return ntpath.normcase(ntpath.normpath(path))


def registry_state() -> dict[str, object]:
    return {
        "JournalScope": "User",
        "ActionId": ACTION_ID,
        "OwnerSid": "",
        "Id": "qa-registry",
        "Name": "QA2 registry fixture",
        "Publisher": "QA",
        "SourceType": "Registry",
        "SourcePath": r"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "SourceLabel": "Current user Run",
        "ValueName": "NyxPCCheckup_QA2_Migration",
        "ValueKind": "String",
        "Command": r'"C:\Windows\System32\notepad.exe" --nyx-qa2-migration',
        "ExecutablePath": r"C:\Windows\System32\notepad.exe",
        "RequiresElevation": False,
        "BackupPath": "",
        "SourceLength": None,
        "SourceHash": "",
    }


def startup_state(payload: bytes = b"QA2 startup payload\r\n") -> tuple[dict[str, object], bytes]:
    filename = "NyxPCCheckup_QA2_Migration.cmd"
    state = registry_state()
    state.update(
        {
            "Id": "qa-startup-file",
            "Name": "QA2 Startup-folder fixture",
            "SourceType": "StartupFile",
            "SourcePath": ntpath.join(STARTUP, filename),
            "SourceLabel": "Current user Startup folder",
            "ValueName": "",
            "ValueKind": "",
            "Command": ntpath.join(STARTUP, filename),
            "ExecutablePath": ntpath.join(STARTUP, filename),
            "BackupPath": ntpath.join(ROLLBACK, "payload", filename),
            "SourceLength": len(payload),
            "SourceHash": hashlib.sha256(payload).hexdigest().upper(),
        }
    )
    return state, payload


def require_exact_string(state: dict[str, object], name: str, *, allow_empty: bool = False) -> str:
    value = state.get(name)
    if not isinstance(value, str):
        raise ValueError(f"{name} must be a string")
    if not allow_empty and not value:
        raise ValueError(f"{name} is empty")
    if "\x00" in value or "\r" in value or "\n" in value:
        raise ValueError(f"{name} has an invalid character")
    return value


def normalize_qa2_reference(
    state: dict[str, object],
    *,
    action_id: str = ACTION_ID,
    current_sid: str = CURRENT_SID,
    startup_folder: str = STARTUP,
    rollback_folder: str = ROLLBACK,
    payload: bytes | None = None,
) -> dict[str, object]:
    """Independent executable specification for the narrow QA2-user migration.

    DPAPI itself is Windows-only and is covered by the supplied Windows suite.
    This reference begins *after* successful CurrentUser unprotect and validates
    every remaining legacy schema and source-boundary requirement.
    """

    if set(state) != QA2_FIELDS:
        raise ValueError("not the exact QA2 user schema")
    if not re.fullmatch(r"[a-f0-9]{32}", action_id) or state["ActionId"] != action_id:
        raise ValueError("invalid action identity")
    if state["JournalScope"] == "Machine":
        raise ValueError("machine pointer rejected")
    if state["JournalScope"] != "User":
        raise ValueError("not a user journal")
    if type(state["RequiresElevation"]) is not bool or state["RequiresElevation"] is not False:
        raise ValueError("elevation value invalid")
    if state["OwnerSid"] != "":
        raise ValueError("legacy owner must be exactly empty")

    for name in ("JournalScope", "ActionId", "OwnerSid", "Id", "Name", "Publisher", "SourceType", "SourcePath", "SourceLabel", "ValueName", "ValueKind", "Command", "ExecutablePath", "BackupPath", "SourceHash"):
        require_exact_string(state, name, allow_empty=name in {"OwnerSid", "Publisher", "SourceLabel", "ValueName", "ValueKind", "Command", "ExecutablePath", "BackupPath", "SourceHash"})

    source_type = state["SourceType"]
    source_path = state["SourcePath"]
    if source_type == "Registry":
        allowed = {
            win(r"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"),
            win(r"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"),
        }
        if win(source_path) not in allowed:
            raise ValueError("registry boundary rejected")
        if not state["ValueName"] or state["ValueKind"] not in {"String", "ExpandString"}:
            raise ValueError("registry metadata invalid")
        if state["BackupPath"] != "" or state["SourceHash"] != "" or state["SourceLength"] is not None:
            raise ValueError("registry file metadata invalid")
    elif source_type == "StartupFile":
        if win(ntpath.dirname(source_path)) != win(startup_folder):
            raise ValueError("startup boundary rejected")
        if state["ValueName"] != "" or state["ValueKind"] != "":
            raise ValueError("startup registry metadata invalid")
        expected_backup = ntpath.join(rollback_folder, "payload", ntpath.basename(source_path))
        if win(state["BackupPath"]) != win(expected_backup):
            raise ValueError("backup path rejected")
        if type(state["SourceLength"]) is not int or state["SourceLength"] < 0:
            raise ValueError("source length invalid")
        if not re.fullmatch(r"[A-Fa-f0-9]{64}", state["SourceHash"]):
            raise ValueError("source hash invalid")
        if payload is None:
            raise ValueError("payload identity unavailable")
        if len(payload) != state["SourceLength"] or hashlib.sha256(payload).hexdigest().upper() != state["SourceHash"].upper():
            raise ValueError("payload identity mismatch")
    else:
        raise ValueError("unsupported source type")

    normalized = dict(state)
    normalized["JournalVersion"] = 1
    normalized["OwnerSid"] = current_sid
    return normalized


def test_exact_qa2_fixture_manifest_and_bytes() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    assert manifest["build"] == "2026.08.23-eng-qa2"
    expected = {entry["path"]: entry for entry in manifest["fixtures"]}
    for path in (QA2_SETUP, QA2_SOURCE):
        entry = expected[path.name]
        assert path.stat().st_size == entry["size"]
        assert sha256(path) == entry["sha256"]
    assert manifest["engineeringHandoff"]["sha256"] == "61B870429BDB22A3F7106A8720A9EE9845D9C2D8B499336E5E1EF9EFBC4D81AF"
    assert manifest["qaFailureHandoff"]["sha256"] == "5DE23C322DD48C69FCEC47331217962603CDE8011CDE9A90083371D3FDDFF6E5"


def test_qa2_source_fixture_is_safe_and_contains_the_confirmed_legacy_schema() -> None:
    with zipfile.ZipFile(QA2_SOURCE) as zf:
        assert zf.testzip() is None
        names = zf.namelist()
        assert len(names) == len({name.casefold() for name in names})
        assert all(not name.startswith(("/", "\\")) and ".." not in PurePosixPath(name).parts for name in names)
        startup = zf.read("Nyx_PC_Checkup_1.0.0_Source/src/app/actions/StartupActions.psm1").decode("utf-8")
        action_history = zf.read("Nyx_PC_Checkup_1.0.0_Source/src/app/core/ActionHistory.psm1").decode("utf-8")
    qa2_state = startup[startup.index("$state = [pscustomobject][ordered]@{") : startup.index("try{[void](Test-NyxStartupStateBoundary", startup.index("$state = [pscustomobject][ordered]@{"))]
    assert "JournalVersion" not in qa2_state
    assert "OwnerSid=$(if($requiresElevation){Get-NyxCurrentUserSid}else{''})" in qa2_state
    assert "DataProtectionScope]::CurrentUser" in action_history


def test_valid_qa2_registry_state_normalizes_to_current_schema() -> None:
    normalized = normalize_qa2_reference(registry_state())
    assert set(normalized) == V1_FIELDS
    assert normalized["JournalVersion"] == 1
    assert normalized["OwnerSid"] == CURRENT_SID
    assert normalized["JournalScope"] == "User"
    assert normalized["RequiresElevation"] is False


def test_valid_qa2_startup_file_state_normalizes_after_exact_payload_validation() -> None:
    state, payload = startup_state()
    normalized = normalize_qa2_reference(state, payload=payload)
    assert normalized["JournalVersion"] == 1
    assert normalized["OwnerSid"] == CURRENT_SID
    assert normalized["SourceLength"] == len(payload)


@pytest.mark.parametrize(
    ("mutation", "error"),
    [
        (lambda s: s.update({"Unexpected": "x"}), "schema"),
        (lambda s: s.pop("OwnerSid"), "schema"),
        (lambda s: s.update({"JournalScope": "Machine"}), "machine"),
        (lambda s: s.update({"JournalScope": "Elsewhere"}), "user"),
        (lambda s: s.update({"RequiresElevation": "false"}), "elevation"),
        (lambda s: s.update({"RequiresElevation": True}), "elevation"),
        (lambda s: s.update({"OwnerSid": CURRENT_SID}), "owner"),
        (lambda s: s.update({"ActionId": "f" * 32}), "identity"),
        (lambda s: s.update({"SourcePath": r"HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"}), "boundary"),
        (lambda s: s.update({"SourcePath": r"HKCU:\Software\Other\Run"}), "boundary"),
        (lambda s: s.update({"ValueKind": "Binary"}), "metadata"),
        (lambda s: s.update({"BackupPath": r"C:\Temp\payload.bin"}), "metadata"),
        (lambda s: s.update({"SourceLength": 0}), "metadata"),
    ],
)
def test_malformed_or_ambiguous_qa2_registry_state_fails_closed(mutation, error: str) -> None:
    state = registry_state()
    mutation(state)
    with pytest.raises(ValueError, match=error):
        normalize_qa2_reference(state)


@pytest.mark.parametrize(
    ("mutation", "payload_mutation", "error"),
    [
        (lambda s: s.update({"SourcePath": r"C:\Users\QA\Desktop\bad.cmd"}), lambda b: b, "boundary"),
        (lambda s: s.update({"BackupPath": r"C:\Temp\stolen.cmd"}), lambda b: b, "backup"),
        (lambda s: s.update({"SourceLength": -1}), lambda b: b, "length"),
        (lambda s: s.update({"SourceLength": "20"}), lambda b: b, "length"),
        (lambda s: s.update({"SourceHash": "not-a-hash"}), lambda b: b, "hash"),
        (lambda s: None, lambda b: b + b"tampered", "identity"),
        (lambda s: s.update({"ValueName": "unexpected"}), lambda b: b, "metadata"),
    ],
)
def test_malformed_or_tampered_qa2_startup_state_fails_closed(mutation, payload_mutation, error: str) -> None:
    state, payload = startup_state()
    mutation(state)
    with pytest.raises(ValueError, match=error):
        normalize_qa2_reference(state, payload=payload_mutation(payload))


def test_production_compatibility_path_is_dpapi_first_narrow_and_revalidated_before_mutation() -> None:
    history = (APP / "core" / "ActionHistory.psm1").read_text(encoding="utf-8")
    startup = (APP / "actions" / "StartupActions.psm1").read_text(encoding="utf-8")
    assert "function ConvertFrom-NyxQA2CurrentUserRollbackState" in history
    assert "function Resolve-NyxCurrentUserRollbackState" in history
    assert "QA2-User" in history and "NormalizedInMemory=$true" in history
    assert "A legacy machine rollback pointer cannot enter the current-user restore path." in history
    assert "Successful DPAPI CurrentUser decryption happens before this" in history
    inventory = history[history.index("function Get-NyxStartupRollbackInventory") : history.index("function Get-NyxActiveStartupDisables")]
    assert inventory.index("$rawState = Unprotect-NyxState") < inventory.index("Resolve-NyxCurrentUserRollbackState")
    assert "if ([bool]$resolved.NormalizedInMemory) { Protect-NyxState -State $state } else { $protected }" in inventory
    converter = history[history.index("function ConvertFrom-NyxQA2CurrentUserRollbackState") : history.index("function Resolve-NyxCurrentUserRollbackState")]
    assert "JournalVersion=1" in converter
    assert "OwnerSid=(Get-NyxRollbackCurrentUserSid)" in converter
    assert "Test-NyxRollbackExactProperties" in converter
    assert "Test-NyxRollbackSourceState" in history
    enable = startup[startup.index("function Enable-NyxStartupApplication") : startup.index("function Restore-AllNyxStartupApplications")]
    assert enable.index("Test-NyxCurrentUserRollbackState") < min(
        enable.index("New-ItemProperty"),
        enable.index("Move-Item -LiteralPath $backup.FullName"),
    )


def test_runtime_regression_harness_names_all_required_qa2_to_corrected_scenarios() -> None:
    harness = (ROOT / "tests" / "powershell" / "Run-WindowsQA2MigrationRegression.ps1").read_text(encoding="utf-8")
    for token in [
        "FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5",
        "QA2 registry journal has no JournalVersion",
        "QA2 registry journal has empty OwnerSid",
        "Corrected build identifies QA2 user schema",
        "QA2 Startup-folder payload restores exact bytes",
        "Tampered QA2 journal fails closed",
        "QA2 machine pointer is rejected",
        "Uninstall restores QA2 current-user rollback before removal",
        "DestructiveCleanVmAcknowledged",
    ]:
        assert token in harness

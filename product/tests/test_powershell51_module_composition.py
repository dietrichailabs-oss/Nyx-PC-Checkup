from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
COMPOSITION = APP / "core" / "RuntimeComposition.psm1"
SMOKE = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def exported_functions(path: Path) -> list[str]:
    text = read(path)
    match = re.search(r"(?im)^Export-ModuleMember\s+-Function\s+([^\r\n]+)", text)
    assert match, f"No function export declaration in {path.relative_to(ROOT)}"
    return [part.strip(" '\"\t") for part in match.group(1).split(",") if part.strip()]


def registered_modules() -> dict[str, set[str]]:
    text = read(COMPOSITION)
    pattern = re.compile(
        r"Name='(?P<name>[^']+)';RelativePath='(?P<path>[^']+)';Exports=@\((?P<exports>[^)]*)\)"
    )
    result: dict[str, set[str]] = {}
    for match in pattern.finditer(text):
        rel = match.group("path").replace("\\", "/")
        exports = set(re.findall(r"'([^']+)'", match.group("exports")))
        assert rel not in result, f"Duplicate runtime module registration: {rel}"
        result[rel] = exports
    return result


def test_runtime_composition_is_the_only_runtime_module_loader() -> None:
    assert COMPOSITION.is_file()
    for module in APP.rglob("*.psm1"):
        text = read(module)
        if module == COMPOSITION:
            assert "Import-Module -Name $full -Global" in text
            assert "Import-NyxRuntimeGraph" in text
            assert not re.search(r"(?im)^\s*Import-Module\b[^\r\n]*\s-Force(?:\s|$)", text)
        else:
            assert not re.search(r"(?im)^\s*Import-Module\b", text), (
                f"Nested module ownership returned in {module.relative_to(ROOT)}"
            )


def test_every_runtime_module_and_export_is_registered_exactly() -> None:
    registered = registered_modules()
    expected: dict[str, set[str]] = {}
    for module in APP.rglob("*.psm1"):
        if module == COMPOSITION:
            continue
        rel = module.relative_to(APP).as_posix()
        expected[rel] = set(exported_functions(module))
    assert registered == expected


def test_composition_validates_cumulative_surface_after_each_layer() -> None:
    text = read(COMPOSITION)
    assert "for($i=0;$i -lt $plan.Count;$i++)" in text
    assert "Test-NyxRuntimeCommandSurface -AppRoot $rootFull -Plan $plan -ThroughIndex $i" in text
    assert "Runtime command surface failed after loading" in text
    assert "Get-Module -All" in text
    assert "A conflicting module named" in text
    assert "ImportedToGlobalScope" in text
    assert "refusing an implicit reload" in text
    assert "Import-Module -ModuleInfo" not in text


def test_all_entrypoints_use_the_composition_root() -> None:
    entrypoints = [APP / "NyxPCCheckup.ps1", *[APP / "workers" / name for name in ("ActionWorker.ps1", "ScanWorker.ps1", "UpdateCheckWorker.ps1", "UninstallWorker.ps1")]]
    for entrypoint in entrypoints:
        text = read(entrypoint)
        assert "RuntimeComposition.psm1" in text, entrypoint
        assert "Import-NyxRuntimeGraph" in text, entrypoint
    assert "-Profile UI" in read(APP / "NyxPCCheckup.ps1")
    assert "-Profile Scan" in read(APP / "workers" / "ScanWorker.ps1")
    assert "-Profile Actions" in read(APP / "workers" / "ActionWorker.ps1")
    assert "-Profile Update" in read(APP / "workers" / "UpdateCheckWorker.ps1")
    assert "-Profile Uninstall" in read(APP / "workers" / "UninstallWorker.ps1")


def test_windows_smoke_exercises_full_graph_and_two_real_quick_checks() -> None:
    text = read(SMOKE)
    assert "Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Full" in text
    for command in (
        "New-NyxCheckResult",
        "New-NyxUnknownResult",
        "Get-NyxStatusLabel",
        "Get-NyxStatusSymbol",
        "Get-NyxResultSummary",
    ):
        assert command in text
    assert "Repeated composition is idempotent and preserves command availability" in text
    assert "foreach($probeNumber in @(1,2))" in text
    assert "Real application acceptance launch {0} exits successfully" in text
    assert "The real Quick Check worker exited" in read(APP / "NyxPCCheckup.ps1")


def test_app_acceptance_probe_is_guarded_and_uses_real_scan_worker() -> None:
    text = read(APP / "NyxPCCheckup.ps1")
    assert "NYX_PC_CHECKUP_ACCEPTANCE" in text
    assert "application acceptance probe is available only to the explicit QA harness" in text
    assert "ScanWorker.ps1" in text
    assert "-Mode Quick" in text
    assert "RuntimeComposition" in text
    assert "2026.09.26-eng-qa17" in text

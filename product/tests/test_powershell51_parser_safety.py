from __future__ import annotations

import importlib.util
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
WINDOWS_HARNESSES = ROOT / "tests" / "powershell"
SCOPE_QUALIFIERS = {
    "env",
    "script",
    "global",
    "local",
    "private",
    "using",
    "variable",
    "function",
}


def powershell_files() -> list[Path]:
    return sorted([*APP.rglob("*.ps1"), *APP.rglob("*.psm1"), *WINDOWS_HARNESSES.rglob("*.ps1")])


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def test_no_unqualified_variable_is_immediately_followed_by_colon() -> None:
    """Prevent the exact `$ActionId:` Windows PowerShell parser regression."""
    pattern = re.compile(r"(?<!`)\$([A-Za-z_][A-Za-z0-9_]*):")
    findings: list[str] = []
    for path in powershell_files():
        source = read(path)
        for match in pattern.finditer(source):
            if match.group(1).casefold() in SCOPE_QUALIFIERS:
                continue
            line = source.count("\n", 0, match.start()) + 1
            findings.append(f"{path.relative_to(ROOT)}:{line}:{match.group(0)}")
    assert not findings, "\n".join(findings)


def test_protected_error_automatic_variable_is_not_bound_or_overwritten() -> None:
    """Prevent the exact `foreach($error ...)` Windows PowerShell 5.1 failure."""
    patterns = [
        re.compile(r"(?i)\bforeach\s*\(\s*\$error\b"),
        re.compile(r"(?im)(?<![A-Za-z0-9_:])\$error\s*="),
        re.compile(r"(?is)\bparam\s*\([^)]*\$error(?:\s*[,)=]|\b)"),
        re.compile(r"(?i)\bSet-Variable\s+(?:-Name\s+)?(?:['\"])?Error\b"),
    ]
    findings: list[str] = []
    for path in powershell_files():
        source = read(path)
        for pattern in patterns:
            for match in pattern.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                findings.append(f"{path.relative_to(ROOT)}:{line}:{match.group(0)}")
    assert not findings, "\n".join(findings)


def test_exact_qa5_native_windows_failures_are_corrected() -> None:
    history = read(APP / "core" / "ActionHistory.psm1")
    smoke = read(WINDOWS_HARNESSES / "Run-WindowsSmokeTests.ps1")
    assert "$ActionId:" not in history
    assert '"Unexpected data exists in rollback {0}: {1}" -f $ActionId,$child.Name' in history
    assert "foreach($parseError in @($parserErrors))" in smoke
    assert "foreach($error in" not in smoke.casefold()
    assert "[ref]$parserTokens" in smoke and "[ref]$parserErrors" in smoke


def test_structural_linter_has_regression_rules_for_both_qa5_failures(tmp_path: Path) -> None:
    spec = importlib.util.spec_from_file_location("nyx_ps_lint", ROOT / "tools" / "ps_lint.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    bad = tmp_path / "Bad.ps1"
    bad.write_text(
        'foreach($error in @()){}\nthrow "Unexpected data exists in rollback $ActionId: child"\n',
        encoding="utf-8",
    )
    errors = module.lint_ps51_hazards(bad, bad.read_text(encoding="utf-8"))
    joined = "\n".join(errors)
    assert "protected $Error" in joined
    assert "ambiguous variable interpolation" in joined

    good = tmp_path / "Good.ps1"
    good.write_text(
        'foreach($parseError in @()){}\nthrow ("Unexpected data exists in rollback {0}: {1}" -f $ActionId,$child.Name)\n',
        encoding="utf-8",
    )
    assert module.lint_ps51_hazards(good, good.read_text(encoding="utf-8")) == []


def test_windows_powershell51_encoding_gate_rejects_utf8_without_bom(tmp_path: Path) -> None:
    spec = importlib.util.spec_from_file_location("nyx_ps_lint_encoding", ROOT / "tools" / "ps_lint.py")
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    ascii_source = b"Write-Host 'plain ASCII'\n"
    assert module.lint_ps51_encoding(tmp_path / "Ascii.ps1", ascii_source) == []

    unsafe_utf8 = "Write-Host 'caf\u00e9'\n".encode("utf-8")
    unsafe_errors = module.lint_ps51_encoding(tmp_path / "Unsafe.ps1", unsafe_utf8)
    assert any("UTF-8 BOM" in item for item in unsafe_errors)

    safe_utf8 = b"\xef\xbb\xbf" + unsafe_utf8
    assert module.lint_ps51_encoding(tmp_path / "Safe.ps1", safe_utf8) == []


def test_all_shipped_powershell_is_ascii_or_utf8_bom() -> None:
    findings: list[str] = []
    for path in powershell_files():
        data = path.read_bytes()
        if any(byte >= 0x80 for byte in data) and not data.startswith(b"\xef\xbb\xbf"):
            findings.append(str(path.relative_to(ROOT)))
    assert not findings, "\n".join(findings)

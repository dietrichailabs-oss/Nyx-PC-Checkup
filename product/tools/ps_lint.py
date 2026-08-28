#!/usr/bin/env python3
"""Small dependency-free structural linter for Windows PowerShell source.

It is not a replacement for the PowerShell parser.  It deliberately checks the
failure modes that can be verified in a non-Windows build environment: balanced
syntax delimiters outside strings/comments, valid here-string boundaries,
backtick continuation placement, Windows PowerShell 5.1-safe text encoding,
import targets, declared exports, and native-QA-proven parser hazards.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

OPEN = {"(": ")", "[": "]", "{": "}"}
CLOSE = set(OPEN.values())


PS_SCOPE_QUALIFIERS = {"env", "script", "global", "local", "private", "using", "variable", "function"}


def lint_ps51_hazards(path: Path, text: str) -> list[str]:
    """Catch target-interpreter hazards proven by native Windows QA.

    This remains deliberately narrow: it detects ambiguous unbraced variable
    interpolation immediately followed by a colon inside expandable strings,
    and writes/loop bindings to PowerShell's protected $Error automatic
    variable. It does not claim to replace the Windows PowerShell parser.
    """
    errors: list[str] = []
    state = "normal"
    block_comment = False
    here_quote = ""
    line = 1
    col = 0
    i = 0
    line_start = True
    normal_chars = list(text)

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        col += 1

        if ch == "\n":
            line += 1
            col = 0
            line_start = True
            if state == "comment":
                state = "normal"
            i += 1
            continue

        if state == "here":
            if line_start:
                terminator = f"{here_quote}@"
                end = text.find("\n", i)
                if end < 0:
                    end = len(text)
                physical = text[i:end].rstrip("\r\t ")
                if physical == terminator:
                    for j in range(i, end):
                        normal_chars[j] = " "
                    state = "normal"
                    here_quote = ""
                    i = end
                    line_start = False
                    continue
            if here_quote == '"' and ch == "$":
                match = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*):", text[i:])
                if match and match.group(1).casefold() not in PS_SCOPE_QUALIFIERS:
                    errors.append(
                        f"{path}:{line}:{col}: ambiguous variable interpolation {match.group(0)!r}; use ${{name}} or the format operator"
                    )
            normal_chars[i] = " " if ch != "\n" else ch
            line_start = False
            i += 1
            continue

        if block_comment:
            normal_chars[i] = " "
            if ch == "#" and nxt == ">":
                normal_chars[i + 1] = " "
                block_comment = False
                i += 2
                col += 1
            else:
                i += 1
            line_start = False
            continue

        if state == "comment":
            normal_chars[i] = " "
            i += 1
            line_start = False
            continue

        if state == "single":
            normal_chars[i] = " "
            if ch == "'":
                if nxt == "'":
                    normal_chars[i + 1] = " "
                    i += 2
                    col += 1
                    continue
                state = "normal"
            i += 1
            line_start = False
            continue

        if state == "double":
            normal_chars[i] = " "
            if ch == "`" and nxt:
                normal_chars[i + 1] = " "
                i += 2
                col += 1
                line_start = False
                continue
            if ch == "$":
                match = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*):", text[i:])
                if match and match.group(1).casefold() not in PS_SCOPE_QUALIFIERS:
                    errors.append(
                        f"{path}:{line}:{col}: ambiguous variable interpolation {match.group(0)!r}; use ${{name}} or the format operator"
                    )
            if ch == '"':
                state = "normal"
            i += 1
            line_start = False
            continue

        # normal code
        if ch == "<" and nxt == "#":
            normal_chars[i] = normal_chars[i + 1] = " "
            block_comment = True
            i += 2
            col += 1
            line_start = False
            continue
        if ch == "#":
            normal_chars[i] = " "
            state = "comment"
            i += 1
            line_start = False
            continue
        if ch == "@" and nxt in ("'", '"'):
            end = text.find("\n", i + 2)
            if end < 0:
                end = len(text)
            if text[i + 2:end].strip("\r\t ") == "":
                for j in range(i, end):
                    normal_chars[j] = " "
                state = "here"
                here_quote = nxt
                i = end
                line_start = False
                continue
        if ch == "'":
            normal_chars[i] = " "
            state = "single"
            i += 1
            line_start = False
            continue
        if ch == '"':
            normal_chars[i] = " "
            state = "double"
            i += 1
            line_start = False
            continue
        if not ch.isspace():
            line_start = False
        i += 1

    normal = "".join(normal_chars)
    protected_patterns = [
        (re.compile(r"(?i)\bforeach\s*\(\s*\$error\b"), "foreach binding shadows protected $Error"),
        (re.compile(r"(?im)(?<![A-Za-z0-9_:])\$error\s*="), "assignment overwrites protected $Error"),
        (re.compile(r"(?is)\bparam\s*\([^)]*\$error(?:\s*[,)=]|\b)"), "parameter shadows protected $Error"),
        (re.compile(r"(?i)\bSet-Variable\s+(?:-Name\s+)?(?:['\"])?Error\b"), "Set-Variable overwrites protected $Error"),
    ]
    for pattern, message in protected_patterns:
        for match in pattern.finditer(normal):
            line_number = normal.count("\n", 0, match.start()) + 1
            errors.append(f"{path}:{line_number}: {message}")
    return errors


def lint_text(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    stack: list[tuple[str, int, int]] = []
    state = "normal"
    block_comment = False
    here_quote = ""
    line = 1
    col = 0
    i = 0
    line_start = True

    # Backtick continuation is legal only when it is the final character.
    for n, raw in enumerate(text.splitlines(), 1):
        if re.search(r"`[ \t]+$", raw):
            errors.append(f"{path}:{n}: backtick continuation has trailing whitespace")

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""
        col += 1

        if ch == "\n":
            line += 1
            col = 0
            line_start = True
            if state == "comment":
                state = "normal"
            i += 1
            continue

        if state == "here":
            # A here-string terminator must begin a physical line and be exactly
            # quote+@ except for trailing whitespace.
            if line_start:
                terminator = f"{here_quote}@"
                end = text.find("\n", i)
                if end < 0:
                    end = len(text)
                physical = text[i:end].rstrip("\r\t ")
                if physical == terminator:
                    state = "normal"
                    here_quote = ""
                    i = end
                    line_start = False
                    continue
            line_start = False
            i += 1
            continue

        if block_comment:
            if ch == "#" and nxt == ">":
                block_comment = False
                i += 2
                col += 1
            else:
                i += 1
            line_start = False
            continue

        if state == "comment":
            i += 1
            line_start = False
            continue

        if state == "single":
            if ch == "'":
                if nxt == "'":
                    i += 2
                    col += 1
                    continue
                state = "normal"
            i += 1
            line_start = False
            continue

        if state == "double":
            if ch == "`" and nxt:
                i += 2
                col += 1
                line_start = False
                continue
            if ch == '"':
                state = "normal"
            i += 1
            line_start = False
            continue

        # normal
        if ch == "<" and nxt == "#":
            block_comment = True
            i += 2
            col += 1
            line_start = False
            continue
        if ch == "#":
            state = "comment"
            i += 1
            line_start = False
            continue
        # Here-string opener may be preceded by whitespace or expression text;
        # PowerShell requires newline immediately after @' / @".
        if ch == "@" and nxt in ("'", '"'):
            after = text[i + 2 : text.find("\n", i + 2) if "\n" in text[i + 2 :] else len(text)]
            if after.strip("\r\t ") == "":
                state = "here"
                here_quote = nxt
                i += 2
                col += 1
                line_start = False
                continue
        if ch == "'":
            state = "single"
            i += 1
            line_start = False
            continue
        if ch == '"':
            state = "double"
            i += 1
            line_start = False
            continue
        if ch in OPEN:
            stack.append((ch, line, col))
        elif ch in CLOSE:
            if not stack:
                errors.append(f"{path}:{line}:{col}: unmatched closing {ch}")
            else:
                opening, oline, ocol = stack.pop()
                if OPEN[opening] != ch:
                    errors.append(
                        f"{path}:{line}:{col}: closing {ch} does not match {opening} at {oline}:{ocol}"
                    )
        if not ch.isspace():
            line_start = False
        i += 1

    if state in {"single", "double"}:
        errors.append(f"{path}:{line}:{col}: unterminated {state}-quoted string")
    if state == "here":
        errors.append(f"{path}:{line}:{col}: unterminated here-string")
    if block_comment:
        errors.append(f"{path}:{line}:{col}: unterminated block comment")
    for opening, oline, ocol in reversed(stack):
        errors.append(f"{path}:{oline}:{ocol}: unclosed {opening}")
    return errors


def lint_imports(path: Path, text: str, app_root: Path) -> list[str]:
    errors: list[str] = []
    # Handles this project's canonical Import-Module (Join-Path $PSScriptRoot '...') form.
    for match in re.finditer(
        r"Import-Module\s+\(Join-Path\s+\$PSScriptRoot\s+'([^']+)'\)", text, re.IGNORECASE
    ):
        rel = match.group(1).replace("\\", "/")
        target = (path.parent / rel).resolve()
        if not target.exists():
            errors.append(f"{path}: import target does not exist: {rel}")
    # AppRoot imports are checked from app root.
    for match in re.finditer(
        r"Import-Module\s+\(Join-Path\s+\$AppRoot\s+'([^']+)'\)", text, re.IGNORECASE
    ):
        rel = match.group(1).replace("\\", "/")
        target = (app_root / rel).resolve()
        if not target.exists():
            errors.append(f"{path}: AppRoot import target does not exist: {rel}")
    return errors


def lint_exports(path: Path, text: str) -> list[str]:
    errors: list[str] = []
    if path.suffix.lower() != ".psm1":
        return errors
    defined = set(re.findall(r"(?im)^\s*function\s+([A-Za-z0-9_-]+)\s*\{", text))
    export_matches = re.findall(r"(?im)^\s*Export-ModuleMember\s+-Function\s+([^\r\n]+)", text)
    if not export_matches:
        errors.append(f"{path}: module has no Export-ModuleMember declaration")
        return errors
    for declaration in export_matches:
        # Strip comments and split comma-separated names.
        for name in declaration.split("#", 1)[0].split(","):
            name = name.strip().strip("'\"")
            if name and name not in defined:
                errors.append(f"{path}: exports undefined function {name}")
    return errors


def resolve_app_root(scan_root: Path) -> Path:
    """Locate src/app whether scanning the project, app tree, or QA harness tree."""
    candidates = [scan_root / "src" / "app", scan_root]
    candidates.extend(parent / "src" / "app" for parent in scan_root.parents)
    for candidate in candidates:
        if (candidate / "NyxPCCheckup.ps1").is_file():
            return candidate.resolve()
    return (scan_root / "src" / "app").resolve()


def lint_ps51_encoding(path: Path, data: bytes) -> list[str]:
    """Require ASCII or UTF-8-with-BOM for deterministic Windows PS 5.1 decoding."""
    errors: list[str] = []
    if b"\x00" in data:
        errors.append(f"{path}: NUL/UTF-16-style encoding is not accepted by this build")
        return errors
    try:
        data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        errors.append(f"{path}: source is not valid UTF-8: {exc}")
        return errors
    if any(byte >= 0x80 for byte in data) and not data.startswith(b"\xef\xbb\xbf"):
        errors.append(
            f"{path}: non-ASCII PowerShell source must carry a UTF-8 BOM for Windows PowerShell 5.1"
        )
    return errors


def lint_tree(root: Path) -> list[str]:
    errors: list[str] = []
    root = root.resolve()
    app_root = resolve_app_root(root)
    scanned = 0
    for path in sorted(root.rglob("*")):
        if path.suffix.lower() not in {".ps1", ".psm1"} or not path.is_file():
            continue
        scanned += 1
        data = path.read_bytes()
        encoding_errors = lint_ps51_encoding(path, data)
        errors.extend(encoding_errors)
        if encoding_errors:
            continue
        text = data.decode("utf-8-sig")
        errors.extend(lint_text(path, text))
        errors.extend(lint_ps51_hazards(path, text))
        errors.extend(lint_imports(path, text, app_root))
        errors.extend(lint_exports(path, text))
    if scanned == 0:
        errors.append(f"{root}: no PowerShell files were scanned")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    errors = lint_tree(args.root.resolve())
    if errors:
        print("\n".join(errors))
        return 1
    print("PowerShell structural lint: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

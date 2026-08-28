#!/usr/bin/env python3
"""Build the complete local Nyx PC Checkup 1.0.0 Engineering QA handoff.

This builder intentionally uses only local source and the LLVM tools already
present in the engineering environment.  It creates native x64 Windows PE
launchers, a self-contained per-user setup executable, a clean portable ZIP,
a source ZIP, test evidence, manifests, and one immutable QA handoff ZIP.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import textwrap
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable, Sequence
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "src" / "app"
NATIVE = ROOT / "native"
BUILD = ROOT / "build"
BUILD_NATIVE = BUILD / "native"
STAGE_BASE = ROOT / "release_staging"
STAGE = STAGE_BASE / "Nyx_PC_Checkup_1.0.0_Portable"
DIST = ROOT / "dist"
EVIDENCE = ROOT / "evidence"
HANDOFF_BASE = ROOT / "handoff_staging"
HANDOFF = HANDOFF_BASE / "Nyx_PC_Checkup_1.0.0_Engineering_QA11_Corrected_Master_Handoff"
VERSION = "1.0.0"
BUILD_ID = "2026.08.27-eng-qa11"
HARNESS_REVISION = "QA11-PS51-8"
PRIOR_QA_EVIDENCE = ROOT / "prior_qa_evidence" / "QA5_MASTER_HANDOFF_20260824_184906.zip"
QA6_FAIL_EVIDENCE = ROOT / "prior_qa_evidence" / "Nyx_PC_Checkup_1.0.0_Independent_QA6_FAIL_Master_Handoff(1).zip"
QA6_FAIL_SIZE = 26479
QA6_FAIL_SHA256 = "E81C56200A409B83E3A1B04A045D4726BE41C24494ED459FB9B91EAB4CACE324"
QA6_WINDOWS_EVIDENCE_NAME = "QA6_MASTER_HANDOFF_20260824_193051.zip"
QA6_WINDOWS_EVIDENCE_SIZE = 17941
QA6_WINDOWS_EVIDENCE_SHA256 = "38B28BB535067EB0B8508A364F6D9EE1DB6FC068D72608F83CFD34F8D28D41C7"
QA7_FAIL_EVIDENCE = ROOT / "prior_qa_evidence" / "Nyx_PC_Checkup_1.0.0_Independent_QA7_FAIL_Master_Handoff(1).zip"
QA7_FAIL_SIZE = 3524834
QA7_FAIL_SHA256 = "7AA2AAD53BD10A2286E476619586CE790485A41361EA60AE427CB0A4CD5FBA57"
QA8_FAIL_EVIDENCE = ROOT / "prior_qa_evidence" / "Nyx_PC_Checkup_1.0.0_Independent_QA8_FAIL_Master_Handoff(1).zip"
QA8_FAIL_SIZE = 5235486
QA8_FAIL_SHA256 = "B181A0793FF4C085555D03C24140B91EFC26345F92AD1579CEBE62360B934466"
QA8_REVIEWED_HANDOFF_NAME = "Nyx_PC_Checkup_1.0.0_Engineering_QA8_Corrected_Master_Handoff(1).zip"
QA8_REVIEWED_HANDOFF_SIZE = 5209637
QA8_REVIEWED_HANDOFF_SHA256 = "F2D1F79D3C99B8BBE86E07C63A9B22E298EBACC1F6E85762AA27A1D3081C871A"
QA8_SETUP_SHA256 = "8DB485C619681C59A5D99956BDA2372372C3BABB7907477D8782A7AF6CE1521D"
QA8_PORTABLE_SHA256 = "A1F7A7CC7A31DE37122AC268DB830EC8A32EEE3FCED7BBFD4F8EDC3A652C6C8C"
QA8_SOURCE_SHA256 = "153CF7C3563118FFD9FA0295F0296B00F72C743BC1ED92083A26CE2EFCB45AEC"
QA9_FINAL_UI_FAIL_EVIDENCE = ROOT / "prior_qa_evidence" / "Nyx_PC_Checkup_1.0.0_Independent_QA9_FINAL_UI_FAIL_Master_Handoff(1).zip"
QA9_FINAL_UI_FAIL_SIZE = 85017549
QA9_FINAL_UI_FAIL_SHA256 = "33B355C6F426321D3B5AAE764EFD8E3DC09006E2643E751E8DAD7FEB3993BA38"
QA9_REVIEWED_HANDOFF_NAME = "Nyx_PC_Checkup_1.0.0_Engineering_QA9_Migration_Harness_WH006_Corrected_Master_Handoff(1).zip"
QA9_REVIEWED_HANDOFF_SIZE = 84115464
QA9_REVIEWED_HANDOFF_SHA256 = "5EFFAF04D5C7041E37176D0887A64567570E5B45FE33D15474778C452214E31E"
QA9_SETUP_SHA256 = "AB09FCA0574AC6D84A7289B271892EBE4DAF1AD1E0AA4ECBF0670012F070B5EA"
QA9_PORTABLE_SHA256 = "8EE1142084C121B9106EED9387C70DC3D06BADCE737F38A8B2847671AEC7FA7C"
QA9_SOURCE_SHA256 = "97EBF6A219CC2DEDC9BE975C58C96E5988241D98F5692130BCDE543229F11C82"
QA10_FAIL_EVIDENCE = ROOT / "prior_qa_evidence" / "Nyx_PC_Checkup_1.0.0_Independent_QA10_FAIL_Master_Handoff(1).zip"
QA10_FAIL_SIZE = 95573076
QA10_FAIL_SHA256 = "59D51387CFDF937807C36095716DF736C1972FC85FB46D2E268527851D0688F2"
QA10_REVIEWED_HANDOFF_NAME = "Nyx_PC_Checkup_1.0.0_Engineering_QA10_Corrected_Master_Handoff(1).zip"
QA10_REVIEWED_HANDOFF_SIZE = 95540672
QA10_REVIEWED_HANDOFF_SHA256 = "E058A08ED6BD37808B45C58A6284D7FF404AD48F68D24B0549953E90D1E7A844"
QA10_SETUP_SHA256 = "E8930C8D9442C1D6798BA7C2E8BF6B600B7C4959265E063747B58218802FD80C"
QA10_PORTABLE_SHA256 = "C6E6F7223D414A4A8B6644767692FAB004D1136515CF7F96612B2001D58467DB"
QA10_SOURCE_SHA256 = "DC1023E1EDF363250C3BFB8925C08685CA8AA00C872FA2D62117B94CBEDEA17B"
QA7_REVIEWED_HANDOFF_NAME = "Nyx_PC_Checkup_1.0.0_Engineering_QA7_Harness_Corrected_Master_Handoff(1).zip"
QA7_REVIEWED_HANDOFF_SIZE = 3504312
QA7_REVIEWED_HANDOFF_SHA256 = "E0EB875741EB87D9A0BF2979AAEFB5AF3C8BEFB0D2EBD9E400DD642399708DC0"
QA7_SETUP_SHA256 = "4EA98094F61A4ACA3299A84F6E15E24644EAAEE2DE2ADE2DBC8950CD2E18DE6D"
QA7_PORTABLE_SHA256 = "23BF85ACE6B539A8D2E66F1FB96413AA14E433FEF1655C174F5AFA3E3153D4A8"
QA7_SOURCE_SHA256 = "F54061A47A30DF09FE707F95F42D00B1EBAC229D7DF2D0EC39B9548CD6E42A9A"
FIXED_ZIP_DT = (2026, 8, 27, 0, 0, 0)

CLANG = Path(os.environ.get("NYX_CLANG") or shutil.which("clang++") or "clang++")
LLD_LINK = Path(os.environ.get("NYX_LLD_LINK") or shutil.which("lld-link") or "lld-link")


class BuildError(RuntimeError):
    pass


def run(args: Sequence[str | os.PathLike[str]], *, cwd: Path | None = None, capture: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = [str(x) for x in args]
    result = subprocess.run(cmd, cwd=cwd, text=True, capture_output=capture, check=False)
    if result.returncode != 0:
        raise BuildError(
            f"Command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"STDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return result


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    temp.replace(path)


def clean_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def remove_python_caches(root: Path) -> None:
    """Remove transient Python/pytest files before any clean-tree inventory."""
    cache_dirs = sorted(
        (
            path
            for path in root.rglob("*")
            if path.is_dir() and path.name in {"__pycache__", ".pytest_cache"}
        ),
        key=lambda path: len(path.parts),
        reverse=True,
    )
    for path in cache_dirs:
        if path.is_symlink():
            path.unlink(missing_ok=True)
        elif path.exists():
            shutil.rmtree(path)
    for suffix in ("*.pyc", "*.pyo"):
        for path in root.rglob(suffix):
            if path.is_file() or path.is_symlink():
                path.unlink(missing_ok=True)


def copy_file(src: Path, dst: Path) -> None:
    if not src.is_file():
        raise BuildError(f"Required file is missing: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def iter_files(root: Path) -> list[Path]:
    return sorted((p for p in root.rglob("*") if p.is_file()), key=lambda p: p.relative_to(root).as_posix().casefold())


def ensure_safe_tree(root: Path, *, forbidden_parts: set[str] | None = None) -> None:
    forbidden_parts = forbidden_parts or set()
    seen: set[str] = set()
    for path in iter_files(root):
        rel = path.relative_to(root).as_posix()
        pp = PurePosixPath(rel)
        if rel.startswith(("/", "\\")) or ".." in pp.parts:
            raise BuildError(f"Unsafe path in tree: {rel}")
        key = rel.casefold()
        if key in seen:
            raise BuildError(f"Case-colliding path in tree: {rel}")
        seen.add(key)
        if forbidden_parts.intersection(pp.parts):
            raise BuildError(f"Forbidden path in clean tree: {rel}")
        if path.is_symlink():
            raise BuildError(f"Symlink is not allowed in clean tree: {rel}")


def deterministic_zip(source_root: Path, output: Path, archive_root: str) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    temp = output.with_suffix(output.suffix + ".tmp")
    if temp.exists():
        temp.unlink()
    ensure_safe_tree(source_root)
    with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9, allowZip64=True) as zf:
        for path in iter_files(source_root):
            rel = path.relative_to(source_root).as_posix()
            arc = f"{archive_root}/{rel}"
            info = zipfile.ZipInfo(arc, FIXED_ZIP_DT)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            info.create_system = 3
            zf.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    temp.replace(output)
    validate_zip(output)


def validate_zip(path: Path) -> None:
    seen: set[str] = set()
    with zipfile.ZipFile(path) as zf:
        bad = zf.testzip()
        if bad:
            raise BuildError(f"ZIP CRC failure in {path}: {bad}")
        for info in zf.infolist():
            name = info.filename
            pp = PurePosixPath(name)
            if name.startswith(("/", "\\")) or ".." in pp.parts or (len(name) > 1 and name[1] == ":"):
                raise BuildError(f"Unsafe ZIP path in {path}: {name}")
            key = name.casefold()
            if key in seen:
                raise BuildError(f"Duplicate/case-colliding ZIP path in {path}: {name}")
            seen.add(key)
            if ((info.external_attr >> 16) & 0o170000) == 0o120000:
                raise BuildError(f"Symlink entry in {path}: {name}")


def res_identifier(number: int) -> bytes:
    return struct.pack("<HH", 0xFFFF, number)


def resource_header(data_size: int, resource_type: int, resource_name: int, *, language: int = 1033, flags: int = 0x1030) -> bytes:
    identifiers = res_identifier(resource_type) + res_identifier(resource_name)
    pad = b"\0" * (-(8 + len(identifiers)) % 4)
    fixed = struct.pack("<IHHII", 0, flags, language, 0, 0)
    header_size = 8 + len(identifiers) + len(pad) + len(fixed)
    return struct.pack("<II", data_size, header_size) + identifiers + pad + fixed


def align4(data: bytes) -> bytes:
    return data + b"\0" * (-len(data) % 4)


def utf16z(value: str) -> bytes:
    return value.encode("utf-16le") + b"\0\0"


def version_block(key: str, value: bytes = b"", *, value_length: int | None = None, value_type: int = 1, children: Iterable[bytes] = ()) -> bytes:
    body = struct.pack("<HHH", 0, 0 if value_length is None else value_length, value_type) + utf16z(key)
    body = align4(body)
    body += value
    body = align4(body)
    for child in children:
        body += child
        body = align4(body)
    body = struct.pack("<H", len(body)) + body[2:]
    return body


def make_version_info(*, description: str, original_filename: str, internal_name: str) -> bytes:
    fixed = struct.pack(
        "<13I",
        0xFEEF04BD, 0x00010000,
        0x00010000, 0x00000000,
        0x00010000, 0x00000000,
        0x0000003F, 0,
        0x00040004, 1, 0, 0, 0,
    )
    strings = {
        "CompanyName": "Dietrich AI Labs",
        "FileDescription": description,
        "FileVersion": VERSION,
        "InternalName": internal_name,
        "LegalCopyright": "Copyright (c) 2026 Dietrich AI Labs",
        "OriginalFilename": original_filename,
        "ProductName": "Nyx PC Checkup",
        "ProductVersion": VERSION,
        "Comments": "Local-first Windows PC health and maintenance utility",
    }
    string_children = [
        version_block(k, utf16z(v), value_length=len(utf16z(v)) // 2, value_type=1)
        for k, v in strings.items()
    ]
    table = version_block("040904B0", b"", value_length=0, value_type=1, children=string_children)
    string_file_info = version_block("StringFileInfo", b"", value_length=0, value_type=1, children=[table])
    translation = version_block("Translation", struct.pack("<HH", 0x0409, 1200), value_length=4, value_type=0)
    var_file_info = version_block("VarFileInfo", b"", value_length=0, value_type=1, children=[translation])
    return version_block("VS_VERSION_INFO", fixed, value_length=len(fixed), value_type=0, children=[string_file_info, var_file_info])


def icon_resources(icon_path: Path) -> tuple[list[tuple[int, int, bytes]], bytes]:
    raw = icon_path.read_bytes()
    if len(raw) < 6:
        raise BuildError("Icon file is truncated")
    reserved, icon_type, count = struct.unpack_from("<HHH", raw, 0)
    if reserved != 0 or icon_type != 1 or count <= 0:
        raise BuildError("Icon file has an invalid header")
    icons: list[tuple[int, int, bytes]] = []
    group_entries = bytearray()
    for index in range(count):
        offset = 6 + index * 16
        width, height, colors, reserved_entry, planes, bits, size, image_offset = struct.unpack_from("<BBBBHHII", raw, offset)
        image = raw[image_offset:image_offset + size]
        if len(image) != size:
            raise BuildError("Icon image is truncated")
        resource_id = 101 + index
        icons.append((3, resource_id, image))
        group_entries += struct.pack("<BBBBHHIH", width, height, colors, reserved_entry, planes, bits, size, resource_id)
    group = struct.pack("<HHH", 0, 1, count) + bytes(group_entries)
    return icons, group


def write_resource_file(path: Path, *, description: str, original_filename: str, internal_name: str) -> None:
    manifest = (NATIVE / "app.manifest").read_bytes()
    icons, group = icon_resources(APP / "assets" / "nyx_pc_checkup.ico")
    entries: list[tuple[int, int, bytes]] = []
    entries.extend(icons)
    entries.append((14, 1, group))
    entries.append((16, 1, make_version_info(description=description, original_filename=original_filename, internal_name=internal_name)))
    entries.append((24, 1, manifest))
    output = bytearray(resource_header(0, 0, 0, language=0, flags=0))
    for typ, name, data in entries:
        output += resource_header(len(data), typ, name)
        output += align4(data)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(output))


def require_tools() -> None:
    for tool in [CLANG, LLD_LINK]:
        if not tool.is_file():
            raise BuildError(f"Required local build tool is missing: {tool}")


def make_import_library(definition: Path, output: Path) -> None:
    run([LLD_LINK, "/lib", "/machine:x64", f"/def:{definition}", f"/out:{output}"])


def compile_object(source: Path, output: Path, *, include_dirs: Sequence[Path] = ()) -> None:
    args: list[str | os.PathLike[str]] = [
        CLANG, "--target=x86_64-pc-windows-msvc", "-std=c++17", "-O2", "-ffreestanding",
        "-fno-exceptions", "-fno-rtti", "-fno-stack-protector", "-fno-ident", "-c", source, "-o", output,
    ]
    for include in include_dirs:
        args.extend(["-I", include])
    run(args)


def link_pe(output: Path, objects: Sequence[Path], resource: Path, libraries: Sequence[Path]) -> None:
    args: list[str | os.PathLike[str]] = [
        LLD_LINK, "/subsystem:windows,6.0", "/entry:wWinMainCRTStartup", "/nodefaultlib", "/machine:x64",
        "/dynamicbase", "/nxcompat", "/highentropyva", "/manifest:no", "/timestamp:0", "/opt:ref", "/opt:icf",
        f"/out:{output}",
    ]
    args.extend(objects)
    args.extend(libraries)
    args.append(resource)
    run(args)


def parse_pe(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    if data[:2] != b"MZ":
        raise BuildError(f"Not a PE file: {path}")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe_offset:pe_offset + 4] != b"PE\0\0":
        raise BuildError(f"Invalid PE signature: {path}")
    machine, sections, timestamp = struct.unpack_from("<HHI", data, pe_offset + 4)
    opt = pe_offset + 24
    magic = struct.unpack_from("<H", data, opt)[0]
    subsystem = struct.unpack_from("<H", data, opt + 68)[0]
    dll_characteristics = struct.unpack_from("<H", data, opt + 70)[0]
    resource_rva, resource_size = struct.unpack_from("<II", data, opt + 112 + 2 * 8)
    import_rva, import_size = struct.unpack_from("<II", data, opt + 112 + 1 * 8)
    result = {
        "path": path.name,
        "size": path.stat().st_size,
        "sha256": sha256(path),
        "machine": f"0x{machine:04X}",
        "sections": sections,
        "timestamp": timestamp,
        "optionalHeaderMagic": f"0x{magic:04X}",
        "subsystem": subsystem,
        "dllCharacteristics": f"0x{dll_characteristics:04X}",
        "dynamicBase": bool(dll_characteristics & 0x40),
        "nxCompat": bool(dll_characteristics & 0x100),
        "highEntropyVa": bool(dll_characteristics & 0x20),
        "resourceRva": resource_rva,
        "resourceSize": resource_size,
        "importRva": import_rva,
        "importSize": import_size,
        "containsAsInvokerManifest": b"asInvoker" in data,
        "containsProductName": "Nyx PC Checkup".encode("utf-16le") in data,
    }
    if machine != 0x8664 or magic != 0x20B or subsystem != 2:
        raise BuildError(f"PE identity gate failed: {path}")
    if not (dll_characteristics & 0x40 and dll_characteristics & 0x100 and dll_characteristics & 0x20):
        raise BuildError(f"PE hardening flags missing: {path}")
    if not resource_rva or not resource_size or b"asInvoker" not in data:
        raise BuildError(f"PE resource/manifest gate failed: {path}")
    return result


def build_launchers() -> list[dict[str, object]]:
    require_tools()
    clean_dir(BUILD_NATIVE)
    for name in ["kernel32", "user32", "shell32"]:
        copy_file(NATIVE / "imports" / f"{name}.def", BUILD_NATIVE / f"{name}.def")
        make_import_library(BUILD_NATIVE / f"{name}.def", BUILD_NATIVE / f"{name}.lib")
    libraries = [BUILD_NATIVE / "kernel32.lib", BUILD_NATIVE / "user32.lib", BUILD_NATIVE / "shell32.lib"]
    specs = [
        ("launcher.cpp", "launcher.obj", "Nyx PC Checkup.exe", "Nyx PC Checkup", "Nyx PC Checkup.exe", "NyxPCCheckup"),
        ("uninstaller.cpp", "uninstaller.obj", "Uninstall Nyx PC Checkup.exe", "Nyx PC Checkup Uninstaller", "Uninstall Nyx PC Checkup.exe", "NyxPCCheckupUninstaller"),
    ]
    reports: list[dict[str, object]] = []
    for source_name, object_name, exe_name, description, original, internal in specs:
        obj = BUILD_NATIVE / object_name
        res = BUILD_NATIVE / (Path(object_name).stem + ".res")
        exe = BUILD_NATIVE / exe_name
        compile_object(NATIVE / source_name, obj, include_dirs=[NATIVE])
        write_resource_file(res, description=description, original_filename=original, internal_name=internal)
        link_pe(exe, [obj], res, libraries)
        reports.append(parse_pe(exe))
    return reports


def stage_portable() -> dict[str, object]:
    clean_dir(STAGE)
    copy_file(BUILD_NATIVE / "Nyx PC Checkup.exe", STAGE / "Nyx PC Checkup.exe")
    copy_file(BUILD_NATIVE / "Uninstall Nyx PC Checkup.exe", STAGE / "Uninstall Nyx PC Checkup.exe")

    for path in iter_files(APP):
        rel = path.relative_to(APP)
        if rel.as_posix() == "platform/linux/CONTRACT.md":
            continue
        if any(part in {"__pycache__", ".pytest_cache"} for part in rel.parts):
            continue
        copy_file(path, STAGE / "app" / rel)

    for name in ["README_FIRST.md", "LICENSE.txt", "THIRD_PARTY_NOTICES.txt", "VERSION.json", "SBOM.json"]:
        copy_file(ROOT / name, STAGE / name)
    copy_file(ROOT / "docs" / "USER_GUIDE.md", STAGE / "docs" / "USER_GUIDE.md")
    copy_file(ROOT / "docs" / "PRIVACY_AND_SECURITY.md", STAGE / "docs" / "PRIVACY_AND_SECURITY.md")
    copy_file(ROOT / "docs" / "INSTALL_UPGRADE_UNINSTALL.md", STAGE / "docs" / "INSTALL_UPGRADE_UNINSTALL.md")
    copy_file(ROOT / "docs" / "KNOWN_LIMITATIONS.md", STAGE / "docs" / "KNOWN_LIMITATIONS.md")

    forbidden = {"tests", "evidence", ".git", "__pycache__", ".pytest_cache", "source"}
    ensure_safe_tree(STAGE, forbidden_parts=forbidden)
    files = []
    for path in iter_files(STAGE):
        rel = path.relative_to(STAGE).as_posix()
        if rel == "PAYLOAD_MANIFEST.json":
            continue
        files.append({"path": rel, "size": path.stat().st_size, "sha256": sha256(path)})
    manifest = {
        "schema": "dietrich-ai-labs.nyx-pc-checkup.payload.v1",
        "product": "Nyx PC Checkup",
        "publisher": "Dietrich AI Labs",
        "version": VERSION,
        "build": BUILD_ID,
        "platform": "Windows 10/11 x64",
        "fileCount": len(files),
        "files": files,
    }
    atomic_json(STAGE / "PAYLOAD_MANIFEST.json", manifest)
    return manifest


def cpp_wide_literal(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'L"{escaped}"'


def generate_payload_header() -> Path:
    generated = NATIVE / "generated"
    clean_dir(generated)
    header = generated / "payload.h"
    files = iter_files(STAGE)
    lines = [
        "#pragma once",
        "#include \"win_types.hpp\"",
        "struct NyxPayloadEntry { const WCHAR* path; const BYTE* data; unsigned long long size; };",
        "",
    ]
    entries = []
    for index, path in enumerate(files):
        rel = path.relative_to(STAGE).as_posix().replace("/", "\\")
        data = path.read_bytes()
        symbol = f"NYX_PAYLOAD_DATA_{index}"
        lines.append(f"static const BYTE {symbol}[] = {{")
        for start in range(0, len(data), 24):
            chunk = data[start:start + 24]
            lines.append("    " + ",".join(f"0x{byte:02X}" for byte in chunk) + ",")
        if not data:
            lines.append("    0x00,")
        lines.append("};")
        entries.append((rel, symbol, len(data)))
    lines.append("")
    lines.append("static const NyxPayloadEntry NYX_PAYLOAD[] = {")
    for rel, symbol, size in entries:
        lines.append(f"    {{{cpp_wide_literal(rel)}, {symbol}, {size}ULL}},")
    lines.append("};")
    lines.append("static const unsigned long NYX_PAYLOAD_COUNT = (unsigned long)(sizeof(NYX_PAYLOAD)/sizeof(NYX_PAYLOAD[0]));")
    lines.append("")
    header.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return header


def build_setup() -> dict[str, object]:
    payload_header = generate_payload_header()
    obj = BUILD_NATIVE / "installer.obj"
    res = BUILD_NATIVE / "installer.res"
    setup = DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe"
    DIST.mkdir(parents=True, exist_ok=True)
    compile_object(NATIVE / "installer.cpp", obj, include_dirs=[NATIVE, payload_header.parent])
    write_resource_file(
        res,
        description="Nyx PC Checkup Setup",
        original_filename="Nyx_PC_Checkup_1.0.0_Setup.exe",
        internal_name="NyxPCCheckupSetup",
    )
    libraries = [BUILD_NATIVE / "kernel32.lib", BUILD_NATIVE / "user32.lib", BUILD_NATIVE / "shell32.lib"]
    link_pe(setup, [obj], res, libraries)
    return parse_pe(setup)


def source_file_allowed(rel: PurePosixPath) -> bool:
    if len(rel.parts) == 1 and rel.name == "SOURCE_TREE_IDENTITY.json":
        return False
    if any(part in {".git", ".pytest_cache", "__pycache__", "dist", "release_staging", "handoff_staging", "evidence", "prior_qa_evidence", "qa_inputs"} for part in rel.parts):
        return False
    if rel.parts[:2] == ("build", "native"):
        return False
    if rel.parts[:2] == ("native", "generated"):
        return False
    if rel.suffix.lower() in {".pyc", ".pyo", ".log", ".dmp"}:
        return False
    return True


def make_source_tree(temp_root: Path) -> Path:
    source_tree = temp_root / "Nyx_PC_Checkup_1.0.0_Source"
    source_tree.mkdir(parents=True)
    for path in iter_files(ROOT):
        rel = PurePosixPath(path.relative_to(ROOT).as_posix())
        if not source_file_allowed(rel):
            continue
        copy_file(path, source_tree / Path(*rel.parts))
    ensure_safe_tree(source_tree)
    return source_tree


def write_source_identity(source_tree: Path) -> dict[str, object]:
    records = []
    aggregate = hashlib.sha256()
    for path in iter_files(source_tree):
        rel = path.relative_to(source_tree).as_posix()
        digest = sha256(path)
        records.append({"path": rel, "size": path.stat().st_size, "sha256": digest})
        aggregate.update(rel.encode("utf-8") + b"\0" + str(path.stat().st_size).encode("ascii") + b"\0" + digest.encode("ascii") + b"\n")
    return {
        "schema": "dietrich-ai-labs.source-tree-identity.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "fileCount": len(records),
        "identityExcludes": ["SOURCE_TREE_IDENTITY.json"],
        "treeSha256": aggregate.hexdigest().upper(),
        "files": records,
    }


def build_archives() -> tuple[Path, Path, dict[str, object]]:
    clean_dir(DIST)
    portable = DIST / "Nyx_PC_Checkup_1.0.0_Portable.zip"
    deterministic_zip(STAGE, portable, "Nyx_PC_Checkup_1.0.0_Portable")
    with tempfile.TemporaryDirectory(prefix="nyx-source-") as tmp:
        temp = Path(tmp)
        source_tree = make_source_tree(temp)
        source_identity = write_source_identity(source_tree)
        atomic_json(source_tree / "SOURCE_TREE_IDENTITY.json", source_identity)
        source_zip = DIST / "Nyx_PC_Checkup_1.0.0_Source.zip"
        deterministic_zip(source_tree, source_zip, "Nyx_PC_Checkup_1.0.0_Source")
    return portable, source_zip, source_identity


def execute_tests() -> dict[str, object]:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    lint_app = run([sys.executable, ROOT / "tools" / "ps_lint.py", APP])
    lint_windows = run([sys.executable, ROOT / "tools" / "ps_lint.py", ROOT / "tests" / "powershell"])
    pytest_result = run([sys.executable, "-m", "pytest", "-q"], cwd=ROOT)
    report = {
        "schema": "dietrich-ai-labs.engineering-test-report.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "environment": {
            "os": platform.platform(),
            "python": sys.version,
            "clang": run([CLANG, "--version"]).stdout.splitlines()[0],
            "lldLink": run([LLD_LINK, "--version"]).stdout.strip(),
            "windowsRuntimeExecuted": False,
        },
        "suites": [
            {"name": "PowerShell structural lint — app", "status": "PASS", "output": lint_app.stdout.strip()},
            {"name": "PowerShell structural lint — Windows tests", "status": "PASS", "output": lint_windows.stdout.strip()},
            {"name": "Python engineering contract, safety, PE, manifest, and archive suite", "status": "PASS", "output": pytest_result.stdout.strip()},
        ],
        "boundary": (
            "This Linux engineering environment validated source contracts, safety invariants, clean staging, archive safety, "
            "native x64 PE structure, embedded manifests/resources, and package identities. The four supplied PowerShell Windows "
            "suites (normal-user smoke and privacy/update, privilege-boundary and legacy rollback, exact QA2-to-QA11 user rollback migration (historical suite label: exact QA2-to-QA9 user rollback migration), and installer lifecycle) require independent execution on Windows 10/11 x64."
        ),
        "verdict": "PASS WITH WINDOWS EXECUTION DEFERRED TO INDEPENDENT QA",
    }
    atomic_json(EVIDENCE / "ENGINEERING_TEST_REPORT.json", report)
    (EVIDENCE / "ENGINEERING_TEST_OUTPUT.txt").write_text(
        "PowerShell app lint\n====================\n" + lint_app.stdout +
        "\nPowerShell Windows-test lint\n==============================\n" + lint_windows.stdout +
        "\nPytest\n======\n" + pytest_result.stdout,
        encoding="utf-8",
    )
    return report


def packaging_report(payload: dict[str, object], source_identity: dict[str, object], pe_reports: list[dict[str, object]]) -> dict[str, object]:
    files = []
    for path in iter_files(DIST):
        files.append({"path": path.name, "size": path.stat().st_size, "sha256": sha256(path)})
    return {
        "schema": "dietrich-ai-labs.packaging-evidence.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "cleanStaging": {
            "path": "release_staging/Nyx_PC_Checkup_1.0.0_Portable",
            "payloadFileCount": payload["fileCount"],
            "payloadManifestSha256": sha256(STAGE / "PAYLOAD_MANIFEST.json"),
            "unexpectedFiles": 0,
            "symlinks": 0,
            "reparsePoints": "not applicable in Linux staging; Windows installer rejects reparse points during finalization",
        },
        "source": {"treeSha256": source_identity["treeSha256"], "fileCount": source_identity["fileCount"]},
        "nativePe": pe_reports,
        "artifacts": files,
        "authenticode": "Unsigned Engineering QA candidate; no code-signing certificate was supplied.",
    }


def write_environment_evidence(start_et: dt.datetime, stop_et: dt.datetime) -> None:
    elapsed = stop_et - start_et
    env = {
        "schema": "dietrich-ai-labs.engineering-environment.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "startEastern": start_et.isoformat(),
        "stopEastern": stop_et.isoformat(),
        "elapsedActiveBuildSessionSeconds": round(elapsed.total_seconds(), 3),
        "host": platform.platform(),
        "python": sys.version,
        "buildTools": {
            "clang": run([CLANG, "--version"]).stdout.splitlines()[0],
            "lldLink": run([LLD_LINK, "--version"]).stdout.strip(),
        },
        "networkBuildDependency": False,
        "githubUsed": False,
        "windowsRuntimeAvailable": False,
    }
    atomic_json(EVIDENCE / "BUILD_ENVIRONMENT_AND_TIMING.json", env)


def write_qa4_windows_harness_correction_evidence() -> dict[str, object]:
    harness_dir = ROOT / "tests" / "powershell"
    harness_names = [
        "Run-WindowsSmokeTests.ps1",
        "Run-WindowsElevatedStartupRollback.ps1",
        "Run-WindowsQA2MigrationRegression.ps1",
        "Run-WindowsInstallerLifecycle.ps1",
    ]
    powershell_files = sorted(
        [*APP.rglob("*.ps1"), *APP.rglob("*.psm1"), *harness_dir.rglob("*.ps1")],
        key=lambda path: path.relative_to(ROOT).as_posix().casefold(),
    )
    legacy_constructor = "New-Object System.Collections.Generic.List["
    unsafe_report_tokens = [
        "Results=@($script:Results)",
        "Results=@($results)",
        "return @($fail)",
    ]
    legacy_hits: list[str] = []
    unsafe_hits: list[str] = []
    for path in powershell_files:
        source = path.read_text(encoding="utf-8")
        if legacy_constructor.casefold() in source.casefold():
            legacy_hits.append(path.relative_to(ROOT).as_posix())
        for token in unsafe_report_tokens:
            if token.casefold() in source.casefold():
                unsafe_hits.append(f"{path.relative_to(ROOT).as_posix()}::{token}")
    if legacy_hits or unsafe_hits:
        raise BuildError(
            "Windows PowerShell 5.1 generic-list correction scan failed: "
            f"constructors={legacy_hits}, unsafe={unsafe_hits}"
        )
    evidence = {
        "schema": "dietrich-ai-labs.qa4-windows-harness-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "qaHoldInput": {
            "name": "Nyx_PC_Checkup_1.0.0_QA4_Windows_Harness_HOLD_Master_Handoff(1).zip",
            "size": 1547058,
            "sha256": "D34BA21D369B72CD03A7EE7105C7CB5838D5650456D19616C507590877C371F1",
            "verdict": "HOLD — ENGINEERING ACTION REQUIRED FOR WINDOWS QA HARNESS",
        },
        "reviewedQa4Candidate": {
            "name": "Nyx_PC_Checkup_1.0.0_Engineering_QA4_Corrected_Master_Handoff(1).zip",
            "size": 1548197,
            "sha256": "22CB1C4A81BB24B532B90918F14CB268C58586A96AF9FAAB8652820F64D520C7",
        },
        "correction": {
            "legacyGenericListConstructorsRemaining": len(legacy_hits),
            "unsafeDirectGenericListArrayConversionsRemaining": len(unsafe_hits),
            "constructorPattern": "[System.Collections.Generic.List[T]]::new()",
            "materializationPattern": "@($list.ToArray())",
            "introducedBuild": "2026.08.24-eng-qa5",
            "introducedHarnessRevision": "QA5-PS51-1",
            "currentBuild": BUILD_ID,
            "currentHarnessRevision": HARNESS_REVISION,
            "runtimeSweepExpanded": True,
            "reasonForNewCandidateIdentity": "The same Windows PowerShell 5.1-incompatible construct was present in shipped runtime modules, so QA5 changed Setup/Portable/runtime bytes rather than issuing a harness-only rewrap. QA7 preserves that correction.",
        },
        "correctedHarnesses": [
            {
                "path": f"tests/powershell/{name}",
                "size": (harness_dir / name).stat().st_size,
                "sha256": sha256(harness_dir / name),
            }
            for name in harness_names
        ],
        "staticCoverage": {
            "powershellFilesScanned": len(powershell_files),
            "allLegacyConstructorsRemoved": True,
            "allKnownUnsafeReportConversionsRemoved": True,
            "targetInterpreterGuardPresent": all(
                "Windows PowerShell 5.1 (Desktop edition)" in (harness_dir / name).read_text(encoding="utf-8")
                for name in harness_names
            ),
        },
        "windowsPowerShell51ExecutedByEngineering": False,
        "boundary": "This Linux engineering host has no Windows PowerShell 5.1, WinForms, registry, DPAPI, UAC, or Windows installer runtime. Corrected target-Windows execution remains mandatory for Independent QA; Engineering does not claim that gate passed.",
        "result": "STATIC CORRECTION PASS — NATIVE WINDOWS EXECUTION PENDING INDEPENDENT QA",
    }
    atomic_json(EVIDENCE / "QA4_WINDOWS_HARNESS_CORRECTION.json", evidence)
    return evidence


def write_qa5_windows_execution_correction_evidence() -> dict[str, object]:
    harness_dir = ROOT / "tests" / "powershell"
    powershell_files = sorted(
        [*APP.rglob("*.ps1"), *APP.rglob("*.psm1"), *harness_dir.rglob("*.ps1")],
        key=lambda path: path.relative_to(ROOT).as_posix().casefold(),
    )
    scope_qualifiers = {"env", "script", "global", "local", "private", "using", "variable", "function"}
    ambiguous_pattern = re.compile(r"(?<!`)\$([A-Za-z_][A-Za-z0-9_]*):")
    protected_patterns = [
        re.compile(r"(?i)\bforeach\s*\(\s*\$error\b"),
        re.compile(r"(?im)(?<![A-Za-z0-9_:])\$error\s*="),
        re.compile(r"(?is)\bparam\s*\([^)]*\$error(?:\s*[,)=]|\b)"),
        re.compile(r"(?i)\bSet-Variable\s+(?:-Name\s+)?(?:['\"])?Error\b"),
    ]
    ambiguous_hits: list[str] = []
    protected_hits: list[str] = []
    unsafe_encoding_hits: list[str] = []
    invalid_utf8_hits: list[str] = []
    for path in powershell_files:
        data = path.read_bytes()
        try:
            source = data.decode("utf-8-sig")
        except UnicodeDecodeError as exc:
            invalid_utf8_hits.append(f"{path.relative_to(ROOT).as_posix()}::{exc}")
            continue
        if any(byte >= 0x80 for byte in data) and not data.startswith(b"\xef\xbb\xbf"):
            unsafe_encoding_hits.append(path.relative_to(ROOT).as_posix())
        for match in ambiguous_pattern.finditer(source):
            if match.group(1).casefold() in scope_qualifiers:
                continue
            line = source.count("\n", 0, match.start()) + 1
            ambiguous_hits.append(f"{path.relative_to(ROOT).as_posix()}:{line}:{match.group(0)}")
        for pattern in protected_patterns:
            for match in pattern.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                protected_hits.append(f"{path.relative_to(ROOT).as_posix()}:{line}:{match.group(0)}")
    if ambiguous_hits or protected_hits or unsafe_encoding_hits or invalid_utf8_hits:
        raise BuildError(
            "QA5 Windows execution correction scan failed: "
            f"ambiguous={ambiguous_hits}, protectedErrorBindings={protected_hits}, "
            f"unsafeEncoding={unsafe_encoding_hits}, invalidUtf8={invalid_utf8_hits}"
        )

    prior_present = PRIOR_QA_EVIDENCE.is_file()
    if prior_present:
        if PRIOR_QA_EVIDENCE.stat().st_size != 7842 or sha256(PRIOR_QA_EVIDENCE) != "5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298":
            raise BuildError("The optional QA5 native-Windows evidence archive does not match its recorded identity")

    corrected_paths = [
        ROOT / "src" / "app" / "core" / "ActionHistory.psm1",
        ROOT / "src" / "app" / "ui" / "Controls.psm1",
        ROOT / "src" / "app" / "ui" / "MainWindow.psm1",
        harness_dir / "Run-WindowsSmokeTests.ps1",
        harness_dir / "Run-WindowsQA2MigrationRegression.ps1",
        harness_dir / "RUN_QA11_WINDOWS_GATE.ps1",
        ROOT / "tools" / "ps_lint.py",
        ROOT / "tests" / "test_powershell51_parser_safety.py",
    ]
    evidence = {
        "schema": "dietrich-ai-labs.qa5-windows-execution-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "qa5FailEvidenceInput": {
            "name": "QA5_MASTER_HANDOFF_20260824_184906.zip",
            "size": 7842,
            "sha256": "5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298",
            "presentInPrimaryBuildWorkspace": prior_present,
            "verdict": "QA5 FAIL — reproducible Windows PowerShell 5.1 defects; route to Engineering",
            "intakeCaveat": "The supplied seven-file evidence archive omitted the Standard QA5_WINDOWS_RUN_SUMMARY.json even though its text report listed that file. The preserved smoke and privilege JSON reports still establish both defects.",
        },
        "reviewedQa5Candidate": {
            "name": "Nyx_PC_Checkup_1.0.0_Engineering_QA5_Corrected_Master_Handoff.zip",
            "size": 1564979,
            "sha256": "B72A0BAD2094F37EAE1E853794A72763A9ACF76D3B27E776AC5FB8647F19B349",
            "setupSha256": "A3753F22AAFF3C46B51731A1D61E5CD75CF9FB4C1FCD504373B33F6C1538A883",
            "portableSha256": "3F75BD8F3622DE227DC858112B69DC4501341D7892FA7041038D2D8C21A40A38",
            "sourceSha256": "2CDF6C78C39E555FAC2D10AACA244AA274E43A20BD6C83FB65628DBC4FC24240",
        },
        "nativeWindowsObservation": {
            "windowsVersion": "Microsoft Windows NT 10.0.26200.0",
            "powerShellVersion": "5.1.26100.9168",
            "psEdition": "Desktop",
            "standardUserExecution": True,
        },
        "findings": [
            {
                "trackingId": "QA5-WIN-001",
                "severity": "BLOCKER",
                "location": "src/app/core/ActionHistory.psm1:202 in QA5",
                "failure": "Windows PowerShell 5.1 rejected an expandable string containing unbraced $ActionId immediately followed by a colon.",
                "correction": "The message now uses the format operator, eliminating ambiguous variable interpolation grammar.",
            },
            {
                "trackingId": "QA5-WIN-002",
                "severity": "BLOCKER",
                "location": "tests/powershell/Run-WindowsSmokeTests.ps1:54 in QA5",
                "failure": "The smoke parser loop bound foreach($error ...), colliding case-insensitively with PowerShell's protected $Error automatic variable.",
                "correction": "Parser outputs now use parserTokens/parserErrors and the loop variable parseError; the source path is captured before the nested loop.",
            },
            {
                "trackingId": "QA5-ORCH-001",
                "severity": "QA-EVIDENCE ROBUSTNESS",
                "location": "QA5 Windows gate orchestrator",
                "failure": "The runner's ErrorActionPreference Stop could abort orchestration on child PowerShell error records before writing the Standard summary.",
                "correction": "The supplied QA6 runner invokes each child under a temporary Continue preference, captures output and exit code, validates the exact JSON report and harness revision, continues remaining harnesses, and always writes its run summary after successful initialization.",
            },
            {
                "trackingId": "QA5-ENC-001",
                "severity": "PREVENTIVE WINDOWS POWERSHELL 5.1 COMPATIBILITY",
                "location": "PowerShell source text encoding",
                "failure": "Windows PowerShell 5.1 may decode BOM-less non-ASCII UTF-8 source using the active ANSI code page, making otherwise valid source non-deterministic across systems.",
                "correction": "All shipped and QA PowerShell files are ASCII-clean or must carry a UTF-8 BOM; the structural linter and regression suite enforce that rule. Existing UI glyphs and the Unicode filename fixture are constructed from explicit character code points.",
            },
        ],
        "staticRegression": {
            "powershellFilesScanned": len(powershell_files),
            "ambiguousUnqualifiedVariableColonPatternsRemaining": len(ambiguous_hits),
            "protectedErrorVariableBindingsRemaining": len(protected_hits),
            "unsafeBomlessNonAsciiFilesRemaining": len(unsafe_encoding_hits),
            "invalidUtf8FilesRemaining": len(invalid_utf8_hits),
            "harnessRevision": HARNESS_REVISION,
            "nativeParserPreflightInRunner": True,
            "runnerValidatesHarnessJsonAndRevision": True,
            "linterRulesAdded": True,
            "dedicatedPythonRegressionTestsAdded": True,
        },
        "correctedFiles": [
            {
                "path": path.relative_to(ROOT).as_posix(),
                "size": path.stat().st_size,
                "sha256": sha256(path),
            }
            for path in corrected_paths
        ],
        "windowsPowerShell51ExecutedByEngineering": False,
        "boundary": "Engineering reproduced and corrected the exact source patterns from native Windows evidence, but this Linux host cannot execute Windows PowerShell 5.1, WinForms, registry/DPAPI/UAC, or the installer lifecycle. Independent QA must execute the immutable QA7 bytes.",
        "result": "STATIC CORRECTION PASS — PRESERVED IN QA7 — NATIVE WINDOWS REGRESSION STILL REQUIRED",
    }
    atomic_json(EVIDENCE / "QA5_WINDOWS_EXECUTION_CORRECTION.json", evidence)
    return evidence


def write_qa6_module_composition_correction_evidence() -> dict[str, object]:
    if not QA6_FAIL_EVIDENCE.is_file():
        raise BuildError(f"Required Independent QA6 FAIL handoff is missing: {QA6_FAIL_EVIDENCE}")
    if QA6_FAIL_EVIDENCE.stat().st_size != QA6_FAIL_SIZE or sha256(QA6_FAIL_EVIDENCE) != QA6_FAIL_SHA256:
        raise BuildError("Independent QA6 FAIL handoff identity mismatch")

    with zipfile.ZipFile(QA6_FAIL_EVIDENCE) as zf:
        nested_name = "evidence_input/" + QA6_WINDOWS_EVIDENCE_NAME
        try:
            nested = zf.read(nested_name)
            findings = zf.read("FINDINGS.md").decode("utf-8")
            requirements = zf.read("ENGINEERING_FIX_REQUIREMENTS.md").decode("utf-8")
        except KeyError as exc:
            raise BuildError(f"Independent QA6 FAIL handoff is missing required evidence: {exc}") from exc
    if len(nested) != QA6_WINDOWS_EVIDENCE_SIZE or hash_bytes(nested) != QA6_WINDOWS_EVIDENCE_SHA256:
        raise BuildError("Nested QA6 native-Windows evidence identity mismatch")
    for token in ["QA6-F-005", "New-NyxCheckResult", "FAIL — RETURN TO ENGINEERING"]:
        if token not in findings:
            raise BuildError(f"QA6 findings do not contain required intake token: {token}")
    for token in ["import full real runtime dependency graph", "launch the real application", "real Quick Check", "branch identifier"]:
        if token.casefold() not in requirements.casefold():
            raise BuildError(f"QA6 Engineering requirements do not contain required token: {token}")

    composition = APP / "core" / "RuntimeComposition.psm1"
    composition_text = composition.read_text(encoding="utf-8-sig")
    runtime_modules = sorted(
        (path for path in APP.rglob("*.psm1") if path != composition),
        key=lambda path: path.relative_to(APP).as_posix().casefold(),
    )
    nested_imports: list[str] = []
    export_inventory: dict[str, set[str]] = {}
    for path in runtime_modules:
        source = path.read_text(encoding="utf-8-sig")
        for match in re.finditer(r"(?im)^\s*Import-Module\b[^\r\n]*", source):
            line = source.count("\n", 0, match.start()) + 1
            nested_imports.append(f"{path.relative_to(ROOT).as_posix()}:{line}:{match.group(0).strip()}")
        export_match = re.search(r"(?im)^Export-ModuleMember\s+-Function\s+([^\r\n]+)", source)
        if export_match is None:
            raise BuildError(f"Runtime module has no explicit function export declaration: {path.relative_to(ROOT)}")
        exports = {
            part.strip(" '\"\t")
            for part in export_match.group(1).split(",")
            if part.strip(" '\"\t")
        }
        export_inventory[path.relative_to(APP).as_posix()] = exports
    if nested_imports:
        raise BuildError(f"Nested runtime module imports remain: {nested_imports}")
    if re.search(r"(?im)^\s*Import-Module\b[^\r\n]*\s-Force(?:\s|$)", composition_text):
        raise BuildError("Runtime composition root still force-reloads a module")
    if "Import-Module -ModuleInfo" in composition_text or "refusing an implicit reload" not in composition_text:
        raise BuildError("Runtime composition root does not fail closed on a missing already-loaded command surface")

    registration_pattern = re.compile(
        r"Name='(?P<name>[^']+)';RelativePath='(?P<path>[^']+)';Exports=@\((?P<exports>[^)]*)\)"
    )
    registered: dict[str, set[str]] = {}
    registered_names: set[str] = set()
    for match in registration_pattern.finditer(composition_text):
        rel = match.group("path").replace("\\", "/")
        if rel in registered or match.group("name") in registered_names:
            raise BuildError(f"Duplicate runtime composition registration: {rel}")
        registered_names.add(match.group("name"))
        registered[rel] = set(re.findall(r"'([^']+)'", match.group("exports")))
    if registered != export_inventory:
        missing = sorted(set(export_inventory) - set(registered))
        extra = sorted(set(registered) - set(export_inventory))
        mismatched = sorted(rel for rel in set(registered) & set(export_inventory) if registered[rel] != export_inventory[rel])
        raise BuildError(f"Runtime composition inventory mismatch: missing={missing}, extra={extra}, exports={mismatched}")

    entrypoint_profiles = {
        APP / "NyxPCCheckup.ps1": "-Profile UI",
        APP / "workers" / "ScanWorker.ps1": "-Profile Scan",
        APP / "workers" / "ActionWorker.ps1": "-Profile Actions",
        APP / "workers" / "UpdateCheckWorker.ps1": "-Profile Update",
        APP / "workers" / "UninstallWorker.ps1": "-Profile Uninstall",
    }
    for path, profile_token in entrypoint_profiles.items():
        source = path.read_text(encoding="utf-8-sig")
        for token in ["RuntimeComposition.psm1", "Import-NyxRuntimeGraph", profile_token]:
            if token not in source:
                raise BuildError(f"Composition-root entrypoint contract missing {token}: {path.relative_to(ROOT)}")

    smoke = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"
    smoke_text = smoke.read_text(encoding="utf-8-sig")
    for token in [
        "Import-NyxRuntimeGraph -AppRoot $AppRoot -Profile Full",
        "New-NyxCheckResult",
        "New-NyxUnknownResult",
        "Get-NyxStatusLabel",
        "Get-NyxStatusSymbol",
        "Get-NyxResultSummary",
        "Repeated composition is idempotent and preserves command availability",
        "foreach($probeNumber in @(1,2))",
        "Real application acceptance launch {0} completes a real Quick Check",
        "HarnessRevision='QA11-PS51-8'",
    ]:
        if token not in smoke_text:
            raise BuildError(f"QA7 smoke graph/real-application regression is missing: {token}")

    installer = NATIVE / "installer.cpp"
    installer_text = installer.read_text(encoding="utf-8")
    branch_ids = [
        "RUNNING_INSTANCE", "LOCALAPPDATA_MISSING", "INSTALL_PARENT_UNSAFE", "TEMP_PATH_COLLISION",
        "PAYLOAD_STAGE_WRITE_FAILED", "EXISTING_TARGET_REPARSE", "EXISTING_TARGET_INVALID",
        "ROLLBACK_BOUNDARY_FAILED", "ACTIVATION_FAILED", "FINALIZATION_FAILED", "USER_CANCELLED", "SUCCESS",
    ]
    for token in ["/diagnostics:", "dietrich-ai-labs.nyx-pc-checkup.setup-diagnostics.v1", *branch_ids]:
        if token not in installer_text:
            raise BuildError(f"QA7 native setup diagnostics are missing: {token}")

    helper = ROOT / "tests" / "powershell" / "InstallerDiagnosticsHelpers.ps1"
    helper_text = helper.read_text(encoding="utf-8-sig")
    for token in [
        "LocalAppDataEnvironment", "LocalAppDataSpecialFolder", "PathComponents", "ResolvedPath",
        "Attributes", "IsReparsePoint", "AclOwner", "AclSddl", "WriteCapability",
        "Invoke-NyxSetupWithDiagnostics", "HarnessInferenceFromImmutableQA2Source",
    ]:
        if token not in helper_text:
            raise BuildError(f"QA7 installer preflight helper is missing: {token}")

    runner = ROOT / "tests" / "powershell" / "RUN_QA11_WINDOWS_GATE.ps1"
    runner_text = runner.read_text(encoding="utf-8-sig")
    for token in [
        "$script:ExpectedBuild='2026.08.27-eng-qa11'",
        "$script:ExpectedHarnessRevision='QA11-PS51-8'",
        "InstallerDiagnosticsHelpers.ps1",
        "QA11_WINDOWS_PARSE_PREFLIGHT.json",
        "QA11_WINDOWS_RUN_SUMMARY.json",
    ]:
        if token not in runner_text:
            raise BuildError(f"QA7 Windows runner contract is missing: {token}")

    corrected_paths = [
        composition,
        APP / "NyxPCCheckup.ps1",
        APP / "workers" / "ActionWorker.ps1",
        APP / "workers" / "ScanWorker.ps1",
        APP / "workers" / "UpdateCheckWorker.ps1",
        APP / "workers" / "UninstallWorker.ps1",
        smoke,
        installer,
        NATIVE / "win_types.hpp",
        NATIVE / "imports" / "kernel32.def",
        helper,
        ROOT / "tests" / "powershell" / "Run-WindowsQA2MigrationRegression.ps1",
        ROOT / "tests" / "powershell" / "Run-WindowsInstallerLifecycle.ps1",
        runner,
        ROOT / "tests" / "test_powershell51_module_composition.py",
        ROOT / "tests" / "test_installer_branch_diagnostics.py",
    ]
    evidence = {
        "schema": "dietrich-ai-labs.qa6-module-composition-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "qa6FailInput": {
            "name": QA6_FAIL_EVIDENCE.name,
            "size": QA6_FAIL_SIZE,
            "sha256": QA6_FAIL_SHA256,
            "verdict": "FAIL — RETURN TO ENGINEERING",
            "trackingId": "QA6-F-005",
        },
        "reviewedQa6Candidate": {
            "name": "Nyx_PC_Checkup_1.0.0_Engineering_QA6_Corrected_Master_Handoff.zip",
            "size": 1606742,
            "sha256": "5516DF2357C9426681FDAFA09F67B786D4CD5FF8FDEA07F0777915B0AF01E515",
            "setupSha256": "57A15ADCE82776D719983FDA2842BFB03458F2C728A2F3C02A582AA6DE70E383",
            "portableSha256": "61E06E625EB255CCB0C2145278509E62BEA5CD499C03694B5FA19E05A512032D",
            "sourceSha256": "C0A3CB784DC980FECA854E71FCB090865305F23C8CA707F37C2D09AE99790D65",
        },
        "nativeWindowsEvidence": {
            "name": QA6_WINDOWS_EVIDENCE_NAME,
            "size": QA6_WINDOWS_EVIDENCE_SIZE,
            "sha256": QA6_WINDOWS_EVIDENCE_SHA256,
            "windowsVersion": "Microsoft Windows NT 10.0.26200.0",
            "powerShellVersion": "5.1.26100.9168",
            "psEdition": "Desktop",
            "smoke": "FAIL — 1/2",
            "privilegeStandard": "PASS — 11/11",
            "qa2Migration": "INCONCLUSIVE / BLOCKED AFTER QA2 SETUP EXIT 11 — 2/4",
            "installerLifecycleStandard": "INCONCLUSIVE / BLOCKED AFTER QA6 SETUP EXIT 11 — 0/7",
        },
        "findings": [
            {
                "trackingId": "QA6-F-005",
                "severity": "HIGH / RELEASE BLOCKER",
                "failure": "Windows PowerShell 5.1 lost New-NyxCheckResult after the full QA6 nested/forced module import graph loaded.",
                "rootCauseArea": "Shared modules repeatedly imported Models.psm1 with -Force, allowing child module-scope reload ownership to remove the public caller command surface.",
                "correction": "QA7 introduces one ordered composition root, removes nested runtime imports, imports each exact module path to global caller scope at most once, rejects conflicting module paths, verifies cumulative exports after every layer, and fails closed rather than implicitly reloading an already-loaded module with missing exports.",
            },
            {
                "trackingId": "QA6-INST-EVIDENCE-001",
                "severity": "ACCEPTANCE-EVIDENCE HARDENING",
                "failure": "QA2 and QA6 setup both exited 11 on the same non-clean host without enough branch evidence to attribute the result.",
                "correction": "QA7 preserves fail-closed installer behavior and adds bounded native branch diagnostics plus independent LOCALAPPDATA/path/ACL/reparse/write-capability preflight evidence. Immutable QA2 branch interpretations are explicitly labeled as harness inference.",
            },
        ],
        "staticRegression": {
            "runtimeModulesRegistered": len(registered),
            "runtimeExportsRegistered": sum(len(exports) for exports in registered.values()),
            "nestedRuntimeImportStatementsRemaining": len(nested_imports),
            "forceReloadsInCompositionRootRemaining": 0,
            "implicitReloadOnMissingSurfaceRemaining": 0,
            "entrypointsUsingCompositionRoot": len(entrypoint_profiles),
            "fullGraphModelCommandsAsserted": 5,
            "realApplicationQuickCheckLaunchesRequired": 2,
            "nativeInstallerBranchIds": len(branch_ids),
            "harnessRevision": HARNESS_REVISION,
        },
        "correctedFiles": [
            {
                "path": path.relative_to(ROOT).as_posix(),
                "size": path.stat().st_size,
                "sha256": sha256(path),
            }
            for path in corrected_paths
        ],
        "windowsPowerShell51ExecutedByEngineering": False,
        "boundary": "Engineering validated the composition architecture, exact command/export inventory, entrypoint ownership, real-application smoke design, native setup diagnostic branches, and package contracts locally. This Linux host cannot execute Windows PowerShell 5.1, WinForms, registry/DPAPI/UAC, or the native installer lifecycle. Independent QA must execute the immutable QA7 bytes on clean Windows snapshots.",
        "result": "STATIC CORRECTION PASS — NEW QA7 CANDIDATE REQUIRED FOR NATIVE WINDOWS REGRESSION",
    }
    atomic_json(EVIDENCE / "QA6_MODULE_COMPOSITION_CORRECTION.json", evidence)
    return evidence



def write_qa7_f006_uninstall_correction_evidence() -> dict[str, object]:
    native_path = ROOT / "native" / "uninstaller.cpp"
    worker_path = APP / "workers" / "UninstallWorker.ps1"
    native = native_path.read_text(encoding="utf-8")
    worker = worker_path.read_text(encoding="utf-8")
    required_native = [
        "nyx_wcopy(safeCwd,systemRoot,1024)",
        'nyx_wcat(safeCwd,L"\\\\System32",1024)',
        "nyx_run(ps,cmd,safeCwd,TRUE)",
    ]
    required_worker = [
        "$safeWorkingDirectory",
        "-WorkingDirectory $safeWorkingDirectory",
        "-PassThru -ErrorAction Stop",
        "$cleanupFailureMarker",
        "INSTALL_ROOT_REMOVE_FAILED",
        "$expectedDataRoot",
        "Unexpected Nyx data root",
        "exit 8",
    ]
    missing = [token for token in required_native if token not in native]
    missing += [token for token in required_worker if token not in worker]
    if "nyx_run(ps,cmd,root,TRUE)" in native:
        missing.append("legacy install-root native cwd still present")
    if missing:
        raise BuildError(f"QA7-F-006 uninstall correction regression failed: {missing}")
    if not QA7_FAIL_EVIDENCE.is_file() or QA7_FAIL_EVIDENCE.stat().st_size != QA7_FAIL_SIZE or sha256(QA7_FAIL_EVIDENCE) != QA7_FAIL_SHA256:
        raise BuildError("Required Independent QA7 FAIL evidence identity mismatch")
    evidence = {
        "schema": "dietrich-ai-labs.qa7-f006-uninstall-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "finding": "QA7-F-006",
        "severity": "HIGH / RELEASE BLOCKER",
        "qa7FailInput": {
            "name": QA7_FAIL_EVIDENCE.name,
            "size": QA7_FAIL_SIZE,
            "sha256": QA7_FAIL_SHA256,
            "reviewedEngineeringHandoff": {
                "name": QA7_REVIEWED_HANDOFF_NAME,
                "size": QA7_REVIEWED_HANDOFF_SIZE,
                "sha256": QA7_REVIEWED_HANDOFF_SHA256,
            },
            "frozenProduct": {
                "setupSha256": QA7_SETUP_SHA256,
                "portableSha256": QA7_PORTABLE_SHA256,
                "sourceSha256": QA7_SOURCE_SHA256,
            },
            "nativeResult": {
                "smoke": "88/88 PASS",
                "privilegeRollback": "12/12 PASS",
                "installerLifecycle": "42/44 FAIL",
                "normalUninstallExit0RootRemoved": False,
                "purgeUninstallExit0RootRemoved": False,
                "qa2Migration": "PRECONDITION_BLOCKED",
            },
        },
        "correction": {
            "nativeWorkerCurrentDirectory": "SystemRoot\\\\System32, never InstallRoot",
            "detachedCleanupWorkingDirectory": "explicit SystemRoot\\\\System32",
            "cleanupLaunchValidated": True,
            "cleanupLaunchFailureExitCode": 8,
            "cleanupFailureMarkerOnResidualInstallRoot": True,
            "purgeDataRootExactBoundaryValidation": True,
            "purgeDataRootReparseRejected": True,
            "rollbackExit6Preserved": True,
            "legacyMachineRollbackExit7Preserved": True,
            "defaultLocalDataRetentionPreserved": True,
            "explicitPurgeSemanticsPreserved": True,
        },
        "correctedFiles": [
            {"path": native_path.relative_to(ROOT).as_posix(), "size": native_path.stat().st_size, "sha256": sha256(native_path)},
            {"path": worker_path.relative_to(ROOT).as_posix(), "size": worker_path.stat().st_size, "sha256": sha256(worker_path)},
            {"path": "tests/test_engineering_contracts.py", "size": (ROOT / "tests" / "test_engineering_contracts.py").stat().st_size, "sha256": sha256(ROOT / "tests" / "test_engineering_contracts.py")},
        ],
        "windowsPowerShell51ExecutedByEngineering": False,
        "boundary": "Engineering can compile and structurally validate the corrected Windows x64 candidate locally, but this host cannot execute the native Windows uninstall lifecycle. Independent QA must verify exact QA11 bytes on disposable Windows 10/11 x64.",
        "result": "STATIC/BUILD REGRESSION PASS — NATIVE WINDOWS UNINSTALL REGRESSION REQUIRED",
    }
    atomic_json(EVIDENCE / "QA7_F006_UNINSTALL_CORRECTION.json", evidence)
    return evidence



def write_qa8_f007_empty_collection_correction_evidence() -> dict[str, object]:
    cleanup = ROOT / "src" / "app" / "checks" / "CleanupScan.psm1"
    downloads = ROOT / "src" / "app" / "checks" / "DownloadsAnalysis.psm1"
    smoke = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"
    pattern = re.compile(r"Measure-Object[^\r\n]*-Sum", re.IGNORECASE)
    runtime_hits = []
    for path in sorted([*APP.rglob("*.ps1"), *APP.rglob("*.psm1")]):
        source = path.read_text(encoding="utf-8-sig")
        if pattern.search(source):
            runtime_hits.append(path.relative_to(ROOT).as_posix())
    if runtime_hits:
        raise BuildError(f"QA8-F-007 unsafe runtime aggregation patterns remain: {runtime_hits}")
    smoke_source = smoke.read_text(encoding="utf-8-sig")
    required_markers = [
        "F-007 zero cleanup candidate set returns a valid result",
        "F-007 zero cleanup candidate set reports TotalBytes zero",
        "F-007 empty Downloads returns a valid Good result",
        "F-007 empty Downloads reports TotalBytes zero",
        "F-007 non-candidate-only Downloads remains Good",
        "F-007 cleanup action safety revalidation remains fail-closed",
    ]
    missing = [marker for marker in required_markers if marker not in smoke_source]
    if missing:
        raise BuildError(f"QA8-F-007 Windows regression markers missing: {missing}")
    if not QA8_FAIL_EVIDENCE.is_file() or QA8_FAIL_EVIDENCE.stat().st_size != QA8_FAIL_SIZE or sha256(QA8_FAIL_EVIDENCE) != QA8_FAIL_SHA256:
        raise BuildError("Required Independent QA8 FAIL evidence identity mismatch")
    evidence = {
        "schema": "dietrich-ai-labs.qa8-f007-empty-collection-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "harnessRevision": HARNESS_REVISION,
        "finding": "QA8-F-007",
        "severity": "HIGH functional compatibility / release blocker",
        "qa8FailInput": {
            "name": QA8_FAIL_EVIDENCE.name,
            "size": QA8_FAIL_SIZE,
            "sha256": QA8_FAIL_SHA256,
            "reviewedEngineeringHandoff": {
                "name": QA8_REVIEWED_HANDOFF_NAME,
                "size": QA8_REVIEWED_HANDOFF_SIZE,
                "sha256": QA8_REVIEWED_HANDOFF_SHA256,
                "setupSha256": QA8_SETUP_SHA256,
                "portableSha256": QA8_PORTABLE_SHA256,
                "sourceSha256": QA8_SOURCE_SHA256,
            },
            "nativeWindowsRegressionAlreadyClosed": {
                "qa7F006": "PASS in QA8",
                "privilegeRollback": "12/12 PASS",
                "installerLifecycle": "44/44 PASS",
            },
        },
        "correction": {
            "cleanupAggregation": "explicit Int64 accumulation; empty set returns zero",
            "downloadsAggregation": "explicit Int64 accumulation; empty set returns zero",
            "runtimeMeasureObjectSumPatternsRemaining": len(runtime_hits),
            "negativeSizeRejected": True,
            "int64OverflowRejected": True,
            "windowsRegressions": required_markers,
        },
        "correctedFiles": [
            {"path": cleanup.relative_to(ROOT).as_posix(), "size": cleanup.stat().st_size, "sha256": sha256(cleanup)},
            {"path": downloads.relative_to(ROOT).as_posix(), "size": downloads.stat().st_size, "sha256": sha256(downloads)},
            {"path": smoke.relative_to(ROOT).as_posix(), "size": smoke.stat().st_size, "sha256": sha256(smoke)},
            {"path": "tests/test_qa8_f007_empty_collection.py", "size": (ROOT / "tests" / "test_qa8_f007_empty_collection.py").stat().st_size, "sha256": sha256(ROOT / "tests" / "test_qa8_f007_empty_collection.py")},
        ],
        "windowsPowerShell51ExecutedByEngineering": False,
        "boundary": "Engineering can statically and structurally validate the corrected runtime, but Independent QA must execute the QA11-PS51-8 empty-state regressions under Windows PowerShell 5.1.",
        "result": "STATIC/BUILD REGRESSION PASS — NATIVE WINDOWS F-007 REGRESSION REQUIRED",
    }
    atomic_json(EVIDENCE / "QA8_F007_EMPTY_COLLECTION_CORRECTION.json", evidence)
    return evidence



def write_qa9_f008_ui_correction_evidence() -> dict[str, object]:
    main_ui = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"
    controls = ROOT / "src" / "app" / "ui" / "Controls.psm1"
    ui_test = ROOT / "tests" / "test_qa9_f008_ui_responsiveness.py"
    plan = ROOT / "docs" / "QA_TEST_PLAN.md"
    required = [main_ui, controls, ui_test, plan, QA9_FINAL_UI_FAIL_EVIDENCE]
    missing = [str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path) for path in required if not path.is_file()]
    if missing:
        raise BuildError(f"QA9-F-008 correction inputs missing: {missing}")
    if QA9_FINAL_UI_FAIL_EVIDENCE.stat().st_size != QA9_FINAL_UI_FAIL_SIZE or sha256(QA9_FINAL_UI_FAIL_EVIDENCE) != QA9_FINAL_UI_FAIL_SHA256:
        raise BuildError("Required Independent QA9 FINAL UI FAIL evidence identity mismatch")

    main_source = main_ui.read_text(encoding="utf-8-sig")
    control_source = controls.read_text(encoding="utf-8-sig")
    plan_source = plan.read_text(encoding="utf-8-sig")
    required_main_markers = [
        "Get-NyxResponsiveWindowSize -Form $form",
        "$headerActions.Dock='Right'",
        "$footerActions.Dock='Right'",
        "$version.Dock='Bottom'",
        "Register-NyxFocusScrollTree -Root $script:NyxUi.Content",
        "ScrollControlIntoView($target)",
        "$grid.ScrollBars='Both'",
        "Check for Updates Now",
        "Open local data folder",
        "Delete local logs",
    ]
    missing_main = [marker for marker in required_main_markers if marker not in main_source]
    if missing_main:
        raise BuildError(f"QA9-F-008 responsive UI markers missing: {missing_main}")
    required_control_markers = ["$label.AutoEllipsis=$false", "$label.UseCompatibleTextRendering=$true", "$grid.ShowCellToolTips=$true"]
    missing_controls = [marker for marker in required_control_markers if marker not in control_source]
    if missing_controls:
        raise BuildError(f"QA9-F-008 control markers missing: {missing_controls}")
    matrix_markers = ["100%", "125%", "150%", "200%", "1366", "768", "Follow Windows", "Dark", "Light", "Tab", "Shift+Tab", "Export report", "Cancel scan"]
    missing_matrix = [marker for marker in matrix_markers if marker.lower() not in plan_source.lower()]
    if missing_matrix:
        raise BuildError(f"QA9-F-008 final UI matrix is incomplete: {missing_matrix}")

    evidence = {
        "schema": "dietrich-ai-labs.qa9-f008-final-ui-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "harnessRevision": HARNESS_REVISION,
        "finding": "QA9-F-008",
        "severity": "HIGH / RELEASE BLOCKER",
        "qa9FinalUiFailInput": {
            "name": QA9_FINAL_UI_FAIL_EVIDENCE.name,
            "size": QA9_FINAL_UI_FAIL_SIZE,
            "sha256": QA9_FINAL_UI_FAIL_SHA256,
            "reviewedEngineeringHandoff": {
                "name": QA9_REVIEWED_HANDOFF_NAME,
                "size": QA9_REVIEWED_HANDOFF_SIZE,
                "sha256": QA9_REVIEWED_HANDOFF_SHA256,
                "setupSha256": QA9_SETUP_SHA256,
                "portableSha256": QA9_PORTABLE_SHA256,
                "sourceSha256": QA9_SOURCE_SHA256,
            },
            "nativeBaselineBeforeUiFail": {
                "smoke": "97/97 PASS",
                "standardPrivilegeRollback": "12/12 PASS",
                "qa2Migration": "244/244 PASS",
                "standardInstallerLifecycle": "44/44 PASS",
                "elevatedPrivilegeRollback": "14/14 PASS",
                "elevatedInstallerLifecycle": "50/50 PASS",
            },
            "failedVisualClass": "150% DPI on 1366x768-class constrained viewport",
        },
        "correction": {
            "dpiAwareInitialSizing": True,
            "workingAreaBoundedSizing": True,
            "globalActionsDocked": True,
            "longLabelsWrap": True,
            "focusScrollIntoView": True,
            "startupPrimaryActionsBeforeGrid": True,
            "appsPrimaryActionsBeforeGrid": True,
            "startupGridHorizontalScrolling": True,
            "gridCellTooltips": True,
            "cleanupLayoutCompacted": True,
            "settingsControlsWidenedAndScrollable": True,
            "requiredNativeFinalMatrix": ["Follow Windows", "Dark", "Light", "100%", "125%", "150%", "200%", "1366x768", "Tab/Shift+Tab"],
        },
        "correctedFiles": [
            {"path": main_ui.relative_to(ROOT).as_posix(), "size": main_ui.stat().st_size, "sha256": sha256(main_ui)},
            {"path": controls.relative_to(ROOT).as_posix(), "size": controls.stat().st_size, "sha256": sha256(controls)},
            {"path": ui_test.relative_to(ROOT).as_posix(), "size": ui_test.stat().st_size, "sha256": sha256(ui_test)},
            {"path": plan.relative_to(ROOT).as_posix(), "size": plan.stat().st_size, "sha256": sha256(plan)},
        ],
        "windowsWinFormsVisualMatrixExecutedByEngineering": False,
        "boundary": "Engineering cannot execute native WinForms/DPI visual acceptance on this Linux host. Independent QA must run the full QA11 final UI matrix on exact frozen QA11 bytes.",
        "result": "STATIC/STRUCTURAL UI CORRECTION PASS — NATIVE WINDOWS VISUAL ACCEPTANCE REQUIRED",
    }
    atomic_json(EVIDENCE / "QA9_F008_UI_CORRECTION.json", evidence)
    return evidence


def write_qa10_f009_ui_close_correction_evidence() -> dict[str, object]:
    paths_module = ROOT / "src" / "app" / "core" / "Paths.psm1"
    composition = ROOT / "src" / "app" / "core" / "RuntimeComposition.psm1"
    main_ui = ROOT / "src" / "app" / "ui" / "MainWindow.psm1"
    app_entry = ROOT / "src" / "app" / "NyxPCCheckup.ps1"
    smoke = ROOT / "tests" / "powershell" / "Run-WindowsSmokeTests.ps1"
    regression = ROOT / "tests" / "test_qa10_f009_ui_close_cleanup.py"
    plan = ROOT / "docs" / "QA_TEST_PLAN.md"
    correction_doc = ROOT / "docs" / "QA10_F009_UI_CLOSE_CORRECTION.md"
    required = [paths_module, composition, main_ui, app_entry, smoke, regression, plan, correction_doc, QA10_FAIL_EVIDENCE]
    missing = [str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path) for path in required if not path.is_file()]
    if missing:
        raise BuildError(f"QA10-F-009 correction inputs missing: {missing}")
    if QA10_FAIL_EVIDENCE.stat().st_size != QA10_FAIL_SIZE or sha256(QA10_FAIL_EVIDENCE) != QA10_FAIL_SHA256:
        raise BuildError("Required Independent QA10 FAIL evidence identity mismatch")

    paths_source = paths_module.read_text(encoding="utf-8-sig")
    main_source = main_ui.read_text(encoding="utf-8-sig")
    app_source = app_entry.read_text(encoding="utf-8-sig")
    smoke_source = smoke.read_text(encoding="utf-8-sig")
    plan_source = plan.read_text(encoding="utf-8-sig")
    required_paths = [
        "function Remove-NyxTemporaryArtifacts",
        "[string]::IsNullOrWhiteSpace([string]$candidate)",
        "[string]::Equals($parent,$tempFull,[StringComparison]::OrdinalIgnoreCase)",
        "[IO.FileAttributes]::ReparsePoint",
        "Remove-Item -LiteralPath $full -Force -ErrorAction Stop",
    ]
    missing_paths = [marker for marker in required_paths if marker not in paths_source]
    if missing_paths:
        raise BuildError(f"QA10-F-009 bounded temp cleanup markers missing: {missing_paths}")

    unsafe_ui_patterns = [
        "Remove-Item -LiteralPath $script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath",
        "Remove-Item -LiteralPath $script:NyxUi.UpdateOutput",
        "Remove-Item -LiteralPath $req,$out",
    ]
    remaining = [pattern for pattern in unsafe_ui_patterns if pattern in main_source]
    if remaining:
        raise BuildError(f"QA10-F-009 unsafe optional UI cleanup remains: {remaining}")
    required_main = [
        "Remove-NyxTemporaryArtifacts -Path @($req,$out)",
        "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.UpdateOutput)",
        "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath)",
        "Remove-NyxTemporaryArtifacts -Path @($script:NyxUi.ScanOutput,$script:NyxUi.ProgressPath,$script:NyxUi.CancelPath,$script:NyxUi.UpdateOutput)",
        "AcceptanceCloseProbe",
    ]
    missing_main = [marker for marker in required_main if marker not in main_source]
    if missing_main:
        raise BuildError(f"QA10-F-009 UI correction markers missing: {missing_main}")
    if "Remove-NyxTemporaryArtifacts -Path @($out,$progress,$cancel)" not in app_source:
        raise BuildError("QA10-F-009 application acceptance cleanup is not using the bounded helper")

    smoke_markers = [
        "F-009 optional temp cleanup accepts empty path fields without throwing",
        "F-009 optional temp cleanup rejects a lookalike path outside Nyx temp",
        "F-009 real UI close probe ({0}) exits cleanly",
        "updates disabled",
        "updates enabled before output exists",
        "-AcceptanceUiCloseProbe",
    ]
    missing_smoke = [marker for marker in smoke_markers if marker not in smoke_source]
    if missing_smoke:
        raise BuildError(f"QA10-F-009 Windows close regression markers missing: {missing_smoke}")
    plan_markers = [
        "close immediately",
        "automatic update disabled",
        "before update output exists",
        "Quick Check",
        "Cancel scan",
        "update-check",
        "close/relaunch",
        "unhandled .NET",
        "terminal error",
        "background process",
        "outside the exact Nyx temp root",
        "F-001 through F-009",
    ]
    missing_plan = [marker for marker in plan_markers if marker.lower() not in plan_source.lower()]
    if missing_plan:
        raise BuildError(f"QA10-F-009 native close matrix is incomplete: {missing_plan}")

    evidence = {
        "schema": "dietrich-ai-labs.qa10-f009-ui-close-correction.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "harnessRevision": HARNESS_REVISION,
        "finding": "QA10-F-009",
        "severity": "HIGH / RELEASE-BLOCKING FUNCTIONAL STABILITY",
        "qa10FailInput": {
            "name": QA10_FAIL_EVIDENCE.name,
            "size": QA10_FAIL_SIZE,
            "sha256": QA10_FAIL_SHA256,
            "reviewedEngineeringHandoff": {
                "name": QA10_REVIEWED_HANDOFF_NAME,
                "size": QA10_REVIEWED_HANDOFF_SIZE,
                "sha256": QA10_REVIEWED_HANDOFF_SHA256,
                "setupSha256": QA10_SETUP_SHA256,
                "portableSha256": QA10_PORTABLE_SHA256,
                "sourceSha256": QA10_SOURCE_SHA256,
            },
            "nativeFailure": "FormClosing passed empty optional path strings to Remove-Item -LiteralPath, surfacing through Application.Run",
            "standardTerminalSummaryProduced": False,
            "finalUiMatrixReached": False,
        },
        "correction": {
            "centralBoundedTempCleanup": True,
            "emptyNullWhitespaceFiltered": True,
            "exactNyxTempParentRequired": True,
            "knownTempFilenameAllowlistRequired": True,
            "reparseRootAndFileRejected": True,
            "uiActionCleanupUsesHelper": True,
            "uiUpdateCleanupUsesHelper": True,
            "uiScanCleanupUsesHelper": True,
            "formClosingCleanupUsesHelper": True,
            "applicationAcceptanceCleanupUsesHelper": True,
            "topLevelFatalErrorBoundaryPreserved": True,
            "realWinFormsCloseProbesInSmoke": 2,
            "nativeCloseMatrixRequired": True,
        },
        "correctedFiles": [
            {"path": paths_module.relative_to(ROOT).as_posix(), "size": paths_module.stat().st_size, "sha256": sha256(paths_module)},
            {"path": composition.relative_to(ROOT).as_posix(), "size": composition.stat().st_size, "sha256": sha256(composition)},
            {"path": main_ui.relative_to(ROOT).as_posix(), "size": main_ui.stat().st_size, "sha256": sha256(main_ui)},
            {"path": app_entry.relative_to(ROOT).as_posix(), "size": app_entry.stat().st_size, "sha256": sha256(app_entry)},
            {"path": smoke.relative_to(ROOT).as_posix(), "size": smoke.stat().st_size, "sha256": sha256(smoke)},
            {"path": regression.relative_to(ROOT).as_posix(), "size": regression.stat().st_size, "sha256": sha256(regression)},
            {"path": plan.relative_to(ROOT).as_posix(), "size": plan.stat().st_size, "sha256": sha256(plan)},
            {"path": correction_doc.relative_to(ROOT).as_posix(), "size": correction_doc.stat().st_size, "sha256": sha256(correction_doc)},
        ],
        "windowsPowerShell51ExecutedByEngineering": False,
        "windowsWinFormsCloseLifecycleExecutedByEngineering": False,
        "boundary": "Engineering can statically validate and package the corrected close lifecycle, but Independent QA must execute exact QA11 bytes under native Windows PowerShell 5.1/WinForms and complete the final UI matrix.",
        "result": "STATIC/BUILD REGRESSION PASS — NATIVE WINDOWS CLOSE/UI ACCEPTANCE REQUIRED",
    }
    atomic_json(EVIDENCE / "QA10_F009_UI_CLOSE_CORRECTION.json", evidence)
    return evidence

def create_handoff(payload: dict[str, object], source_identity: dict[str, object], test_report: dict[str, object], packaging: dict[str, object]) -> Path:
    clean_dir(HANDOFF)
    copy_file(ROOT / "README_FIRST.md", HANDOFF / "README_FIRST.md")
    copy_file(ROOT / "tests" / "powershell" / "RUN_QA11_WINDOWS_GATE.ps1", HANDOFF / "RUN_QA11_WINDOWS_GATE.ps1")

    for name in ["Nyx_PC_Checkup_1.0.0_Setup.exe", "Nyx_PC_Checkup_1.0.0_Portable.zip"]:
        copy_file(DIST / name, HANDOFF / "candidate" / name)
    copy_file(DIST / "Nyx_PC_Checkup_1.0.0_Source.zip", HANDOFF / "source" / "Nyx_PC_Checkup_1.0.0_Source.zip")
    if PRIOR_QA_EVIDENCE.is_file():
        if PRIOR_QA_EVIDENCE.stat().st_size != 7842 or sha256(PRIOR_QA_EVIDENCE) != "5E6DC04424216650720A408BF8E99AAF52FD6EF20DE35489F76D0740ADE36298":
            raise BuildError("Prior QA5 Windows evidence identity mismatch")
        copy_file(PRIOR_QA_EVIDENCE, HANDOFF / "prior_qa" / PRIOR_QA_EVIDENCE.name)
    if not QA6_FAIL_EVIDENCE.is_file() or QA6_FAIL_EVIDENCE.stat().st_size != QA6_FAIL_SIZE or sha256(QA6_FAIL_EVIDENCE) != QA6_FAIL_SHA256:
        raise BuildError("Required Independent QA6 FAIL evidence identity mismatch")
    copy_file(QA6_FAIL_EVIDENCE, HANDOFF / "prior_qa" / QA6_FAIL_EVIDENCE.name)

    if not QA7_FAIL_EVIDENCE.is_file() or QA7_FAIL_EVIDENCE.stat().st_size != QA7_FAIL_SIZE or sha256(QA7_FAIL_EVIDENCE) != QA7_FAIL_SHA256:
        raise BuildError("Required Independent QA7 FAIL evidence identity mismatch")
    copy_file(QA7_FAIL_EVIDENCE, HANDOFF / "prior_qa" / QA7_FAIL_EVIDENCE.name)

    if not QA8_FAIL_EVIDENCE.is_file() or QA8_FAIL_EVIDENCE.stat().st_size != QA8_FAIL_SIZE or sha256(QA8_FAIL_EVIDENCE) != QA8_FAIL_SHA256:
        raise BuildError("Required Independent QA8 FAIL evidence identity mismatch")
    copy_file(QA8_FAIL_EVIDENCE, HANDOFF / "prior_qa" / QA8_FAIL_EVIDENCE.name)

    if not QA9_FINAL_UI_FAIL_EVIDENCE.is_file() or QA9_FINAL_UI_FAIL_EVIDENCE.stat().st_size != QA9_FINAL_UI_FAIL_SIZE or sha256(QA9_FINAL_UI_FAIL_EVIDENCE) != QA9_FINAL_UI_FAIL_SHA256:
        raise BuildError("Required Independent QA9 FINAL UI FAIL evidence identity mismatch")
    copy_file(QA9_FINAL_UI_FAIL_EVIDENCE, HANDOFF / "prior_qa" / QA9_FINAL_UI_FAIL_EVIDENCE.name)

    if not QA10_FAIL_EVIDENCE.is_file() or QA10_FAIL_EVIDENCE.stat().st_size != QA10_FAIL_SIZE or sha256(QA10_FAIL_EVIDENCE) != QA10_FAIL_SHA256:
        raise BuildError("Required Independent QA10 FAIL evidence identity mismatch")
    copy_file(QA10_FAIL_EVIDENCE, HANDOFF / "prior_qa" / QA10_FAIL_EVIDENCE.name)

    for path in iter_files(ROOT / "docs"):
        copy_file(path, HANDOFF / "docs" / path.name)
    for path in iter_files(ROOT / "tests"):
        rel = path.relative_to(ROOT / "tests")
        if any(part in {"__pycache__", ".pytest_cache"} for part in rel.parts):
            continue
        if path.suffix.lower() in {".pyc", ".pyo"}:
            continue
        copy_file(path, HANDOFF / "tests" / rel)
    copy_file(ROOT / "tools" / "ps_lint.py", HANDOFF / "tests" / "tools" / "ps_lint.py")

    for path in iter_files(EVIDENCE):
        copy_file(path, HANDOFF / "evidence" / path.name)
    for name in ["VERSION.json", "SBOM.json", "LICENSE.txt", "THIRD_PARTY_NOTICES.txt"]:
        copy_file(ROOT / name, HANDOFF / "metadata" / name)
    copy_file(STAGE / "PAYLOAD_MANIFEST.json", HANDOFF / "metadata" / "PAYLOAD_MANIFEST.json")
    atomic_json(HANDOFF / "metadata" / "SOURCE_TREE_IDENTITY.json", source_identity)

    gate = {
        "schema": "dietrich-ai-labs.engineering-gate.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "engineeringVerdict": "READY FOR INDEPENDENT WINDOWS QA",
        "sourceAndPackagingTests": test_report["verdict"],
        "windowsRuntimeAndInstallerLifecycle": "NOT EXECUTED IN LINUX ENGINEERING ENVIRONMENT — REQUIRED FROM QA",
        "supersedes": {
            "build": "2026.08.27-eng-qa10",
            "reviewedEngineeringHandoffName": QA10_REVIEWED_HANDOFF_NAME,
            "reviewedEngineeringHandoffSize": QA10_REVIEWED_HANDOFF_SIZE,
            "reviewedEngineeringHandoffSha256": QA10_REVIEWED_HANDOFF_SHA256,
            "qa10FailHandoffName": QA10_FAIL_EVIDENCE.name,
            "qa10FailHandoffSize": QA10_FAIL_SIZE,
            "qa10FailHandoffSha256": QA10_FAIL_SHA256,
            "qaVerdict": "FAIL — QA10-F-009 real UI close lifecycle passed empty optional temp paths to Remove-Item -LiteralPath under Windows PowerShell 5.1",
        },
        "historicalCorrectionsPreserved": {
            "F-001": "All-users startup entries remain read-only; runtime/native elevation paths remain removed.",
            "F-002": "Legacy ProgramData rollback remains independently discovered and uninstall remains fail-closed on Present or Unknown.",
            "F-003": "Reports retain structured minimization before serialization with compressed IPv6 and secret-role coverage.",
            "F-004": "Exact DPAPI CurrentUser QA2 user journals remain strictly validated and normalized in memory before any restore; invalid state fails closed.",
        },
        "qa4WindowsHarnessCorrection": {
            "trackingId": "QA4-WH-001",
            "introducedHarnessRevision": "QA5-PS51-1",
            "currentHarnessRevision": HARNESS_REVISION,
            "fourMandatoryHarnessesCorrected": True,
            "runtimeHomologueSweepCompleted": True,
            "legacyNewObjectGenericListPatternRemaining": 0,
            "directGenericListArrayWrapperPatternRemaining": 0,
            "evidence": "evidence/QA4_WINDOWS_HARNESS_CORRECTION.json",
        },
        "qa5WindowsExecutionCorrection": {
            "trackingIds": ["QA5-WIN-001", "QA5-WIN-002", "QA5-ORCH-001", "QA5-ENC-001"],
            "harnessRevision": HARNESS_REVISION,
            "ambiguousVariableColonPatternRemaining": 0,
            "protectedErrorVariableBindingsRemaining": 0,
            "unsafeBomlessNonAsciiFilesRemaining": 0,
            "nativeParserPreflightInRunner": True,
            "runnerValidatesHarnessReports": True,
            "evidence": "evidence/QA5_WINDOWS_EXECUTION_CORRECTION.json",
            "rawQaEvidenceIncludedWhenAvailable": PRIOR_QA_EVIDENCE.is_file(),
        },
        "qa6ModuleCompositionCorrection": {
            "trackingIds": ["QA6-F-005", "QA6-INST-EVIDENCE-001"],
            "harnessRevision": HARNESS_REVISION,
            "singleCompositionRoot": True,
            "nestedRuntimeImportsRemaining": 0,
            "forceReloadsRemaining": 0,
            "cumulativeCommandSurfaceValidation": True,
            "realApplicationQuickCheckLaunchesRequired": 2,
            "nativeInstallerBranchDiagnostics": True,
            "installerEnvironmentPreflight": True,
            "evidence": "evidence/QA6_MODULE_COMPOSITION_CORRECTION.json",
            "exactQa6FailIncluded": True,
        },
        "qa7UninstallCorrection": {
            "trackingId": "QA7-F-006",
            "harnessRevision": HARNESS_REVISION,
            "nativeWorkerUsesSafeExternalCwd": True,
            "detachedCleanupUsesExplicitSafeWorkingDirectory": True,
            "cleanupSchedulingFailureObservable": True,
            "cleanupSchedulingFailureExitCode": 8,
            "purgeDataBoundaryRevalidated": True,
            "evidence": "evidence/QA7_F006_UNINSTALL_CORRECTION.json",
            "exactQa7FailIncluded": True,
        },
        "qa8EmptyCollectionCorrection": {
            "trackingId": "QA8-F-007",
            "harnessRevision": HARNESS_REVISION,
            "measureObjectSumPatternsRemaining": 0,
            "zeroCleanupCandidateRegression": True,
            "emptyDownloadsRegression": True,
            "nonCandidateOnlyDownloadsRegression": True,
            "cleanupSafetyRevalidationRegression": True,
            "qa8NativeF006LifecyclePassPreserved": True,
            "evidence": "evidence/QA8_F007_EMPTY_COLLECTION_CORRECTION.json",
            "exactQa8FailIncluded": True,
        },
        "qa9FinalUiCorrection": {
            "trackingId": "QA9-F-008",
            "harnessRevision": HARNESS_REVISION,
            "responsiveDpiLayout": True,
            "globalActionsDocked": True,
            "focusScrollIntoView": True,
            "wrappedLabels": True,
            "gridHorizontalScrollingAndTooltips": True,
            "fullNativeUiMatrixRequired": True,
            "windowsWinFormsVisualMatrixExecutedByEngineering": False,
            "evidence": "evidence/QA9_F008_UI_CORRECTION.json",
            "exactQa9FinalUiFailIncluded": True,
        },
        "qa10UiCloseCorrection": {
            "trackingId": "QA10-F-009",
            "harnessRevision": HARNESS_REVISION,
            "centralBoundedTempCleanup": True,
            "emptyNullWhitespaceFiltered": True,
            "exactNyxTempBoundaryRequired": True,
            "reparseBackedCleanupRejected": True,
            "realWinFormsCloseProbesInSmoke": 2,
            "fullNativeCloseLifecycleMatrixRequired": True,
            "windowsWinFormsCloseLifecycleExecutedByEngineering": False,
            "evidence": "evidence/QA10_F009_UI_CLOSE_CORRECTION.json",
            "exactQa10FailIncluded": True,
        },
        "qa2MigrationFixtures": {
            "setupName": "Nyx_PC_Checkup_1.0.0_QA2_Setup.exe",
            "setupSize": 417280,
            "setupSha256": "FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5",
            "sourceName": "Nyx_PC_Checkup_1.0.0_QA2_Source.zip",
            "sourceSize": 209483,
            "sourceSha256": "22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36",
            "runtimeSuite": "tests/powershell/Run-WindowsQA2MigrationRegression.ps1",
        },
        "updateAvailabilityCheck": {
            "implemented": True,
            "manifestUrl": "https://www.dietrichailabs.com/updates/nyx-pc-checkup.json",
            "automaticMaximumFrequencyDays": 7,
            "manualBypassesSchedule": True,
            "notificationOnly": True,
            "automaticUpdaterImplemented": False,
            "websiteManifestDeployedByEngineering": False,
        },
        "githubUsed": False,
        "releaseAuthorization": False,
        "nextAuthority": "Independent QA: PASS / CONDITIONAL PASS / HOLD / FAIL",
        "candidateSetupSha256": sha256(HANDOFF / "candidate" / "Nyx_PC_Checkup_1.0.0_Setup.exe"),
        "candidatePortableSha256": sha256(HANDOFF / "candidate" / "Nyx_PC_Checkup_1.0.0_Portable.zip"),
    }
    atomic_json(HANDOFF / "ENGINEERING_GATE.json", gate)

    # Master manifest intentionally excludes itself and SHA256SUMS to avoid circular identities.
    manifest_files = []
    for path in iter_files(HANDOFF):
        rel = path.relative_to(HANDOFF).as_posix()
        if rel in {"MASTER_MANIFEST.json", "SHA256SUMS.txt"}:
            continue
        manifest_files.append({"path": rel, "size": path.stat().st_size, "sha256": sha256(path)})
    master = {
        "schema": "dietrich-ai-labs.master-handoff-manifest.v1",
        "product": "Nyx PC Checkup",
        "version": VERSION,
        "build": BUILD_ID,
        "candidateStatus": "Corrected Engineering QA11 candidate — release blocked pending independent Windows QA",
        "fileCount": len(manifest_files),
        "files": manifest_files,
        "payloadManifestSha256": sha256(STAGE / "PAYLOAD_MANIFEST.json"),
        "sourceTreeSha256": source_identity["treeSha256"],
        "packagingEvidenceSha256": sha256(EVIDENCE / "PACKAGING_EVIDENCE.json"),
    }
    atomic_json(HANDOFF / "MASTER_MANIFEST.json", master)

    sums = []
    for path in iter_files(HANDOFF):
        rel = path.relative_to(HANDOFF).as_posix()
        if rel == "SHA256SUMS.txt":
            continue
        sums.append(f"{sha256(path)}  {rel}")
    (HANDOFF / "SHA256SUMS.txt").write_text("\n".join(sums) + "\n", encoding="utf-8")

    ensure_safe_tree(HANDOFF, forbidden_parts={".git", "__pycache__", ".pytest_cache"})
    final_zip = DIST / "Nyx_PC_Checkup_1.0.0_Engineering_QA11_Corrected_Master_Handoff.zip"
    deterministic_zip(HANDOFF, final_zip, HANDOFF.name)
    return final_zip


def validate_handoff_archive(path: Path) -> None:
    """Verify the final immutable handoff from inside the ZIP itself."""
    validate_zip(path)
    root = HANDOFF.name + "/"
    with zipfile.ZipFile(path) as zf:
        names = {info.filename for info in zf.infolist() if not info.is_dir()}
        required = {
            root + "MASTER_MANIFEST.json",
            root + "SHA256SUMS.txt",
            root + "ENGINEERING_GATE.json",
            root + "RUN_QA11_WINDOWS_GATE.ps1",
            root + "evidence/QA5_WINDOWS_EXECUTION_CORRECTION.json",
            root + "docs/QA5_WINDOWS_EXECUTION_CORRECTION.md",
            root + "evidence/QA6_MODULE_COMPOSITION_CORRECTION.json",
            root + "docs/QA6_MODULE_COMPOSITION_CORRECTION.md",
            root + "prior_qa/" + QA6_FAIL_EVIDENCE.name,
            root + "prior_qa/" + QA7_FAIL_EVIDENCE.name,
            root + "prior_qa/" + QA8_FAIL_EVIDENCE.name,
            root + "prior_qa/" + QA9_FINAL_UI_FAIL_EVIDENCE.name,
            root + "prior_qa/" + QA10_FAIL_EVIDENCE.name,
            root + "evidence/QA7_F006_UNINSTALL_CORRECTION.json",
            root + "evidence/QA8_F007_EMPTY_COLLECTION_CORRECTION.json",
            root + "docs/QA8_F007_EMPTY_COLLECTION_CORRECTION.md",
            root + "docs/QA7_F006_UNINSTALL_CORRECTION.md",
            root + "evidence/QA9_F008_UI_CORRECTION.json",
            root + "docs/QA9_F008_UI_CORRECTION.md",
            root + "evidence/QA10_F009_UI_CLOSE_CORRECTION.json",
            root + "docs/QA10_F009_UI_CLOSE_CORRECTION.md",
            root + "candidate/Nyx_PC_Checkup_1.0.0_Setup.exe",
            root + "candidate/Nyx_PC_Checkup_1.0.0_Portable.zip",
            root + "source/Nyx_PC_Checkup_1.0.0_Source.zip",
        }
        if PRIOR_QA_EVIDENCE.is_file():
            required.add(root + "prior_qa/" + PRIOR_QA_EVIDENCE.name)
        if not required <= names:
            raise BuildError(f"Final handoff is missing required entries: {sorted(required - names)}")
        manifest = json.loads(zf.read(root + "MASTER_MANIFEST.json"))
        expected = {entry["path"]: entry for entry in manifest["files"]}
        actual_names = {
            name[len(root):]
            for name in names
            if name.startswith(root) and name[len(root):] not in {"MASTER_MANIFEST.json", "SHA256SUMS.txt"}
        }
        if set(expected) != actual_names:
            raise BuildError("Final handoff master-manifest inventory does not match the archive")
        for rel, entry in expected.items():
            data = zf.read(root + rel)
            if len(data) != int(entry["size"]) or hash_bytes(data) != entry["sha256"]:
                raise BuildError(f"Final handoff master-manifest identity mismatch: {rel}")
        sum_lines = zf.read(root + "SHA256SUMS.txt").decode("utf-8").splitlines()
        sums: dict[str, str] = {}
        for line in sum_lines:
            digest, sep, rel = line.partition("  ")
            if not sep or rel in sums:
                raise BuildError("Final handoff SHA256SUMS format or uniqueness check failed")
            sums[rel] = digest
        sum_actual = {
            name[len(root):]
            for name in names
            if name.startswith(root) and name[len(root):] != "SHA256SUMS.txt"
        }
        if set(sums) != sum_actual:
            raise BuildError("Final handoff SHA256SUMS inventory does not match the archive")
        for rel, digest in sums.items():
            if hash_bytes(zf.read(root + rel)) != digest:
                raise BuildError(f"Final handoff SHA256SUMS mismatch: {rel}")
        gate = json.loads(zf.read(root + "ENGINEERING_GATE.json"))
        if gate["candidateSetupSha256"] != hash_bytes(zf.read(root + "candidate/Nyx_PC_Checkup_1.0.0_Setup.exe")):
            raise BuildError("Final handoff setup identity does not match ENGINEERING_GATE.json")
        if gate["candidatePortableSha256"] != hash_bytes(zf.read(root + "candidate/Nyx_PC_Checkup_1.0.0_Portable.zip")):
            raise BuildError("Final handoff portable identity does not match ENGINEERING_GATE.json")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--keep-intermediates", action="store_true", help="Retain compiler objects and generated payload header")
    parser.add_argument(
        "--candidate-only",
        action="store_true",
        help="Build and test Setup, Portable, and Source without constructing the QA evidence handoff. Used for clean-source reproducibility.",
    )
    args = parser.parse_args()
    eastern = ZoneInfo("America/New_York")
    start_et = dt.datetime.now(tz=eastern)
    try:
        remove_python_caches(ROOT)
        for path in [STAGE_BASE, DIST, EVIDENCE, HANDOFF_BASE]:
            clean_dir(path)
        pe_reports = build_launchers()
        payload = stage_portable()
        portable, source_zip, source_identity = build_archives()
        setup_report = build_setup()
        pe_reports.append(setup_report)
        # build_archives cleaned DIST before setup, so portable/source remain and setup was added.
        test_report = execute_tests()
        if not args.candidate_only:
            write_qa4_windows_harness_correction_evidence()
            write_qa5_windows_execution_correction_evidence()
            write_qa6_module_composition_correction_evidence()
            write_qa7_f006_uninstall_correction_evidence()
            write_qa8_f007_empty_collection_correction_evidence()
            write_qa9_f008_ui_correction_evidence()
            write_qa10_f009_ui_close_correction_evidence()
        # pytest creates cache files; remove them before clean packaging/handoff inventory.
        remove_python_caches(ROOT)
        packaging = packaging_report(payload, source_identity, pe_reports)
        atomic_json(EVIDENCE / "PACKAGING_EVIDENCE.json", packaging)
        atomic_json(EVIDENCE / "PE_INSPECTION.json", {"schema": "dietrich-ai-labs.pe-inspection.v1", "files": pe_reports})
        stop_et = dt.datetime.now(tz=eastern)
        write_environment_evidence(start_et, stop_et)

        if args.candidate_only:
            summary = {
                "mode": "candidate-only",
                "handoff": None,
                "setup": {"path": str(DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe"), "size": (DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe").stat().st_size, "sha256": sha256(DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe")},
                "portable": {"path": str(portable), "size": portable.stat().st_size, "sha256": sha256(portable)},
                "source": {"path": str(source_zip), "size": source_zip.stat().st_size, "sha256": sha256(source_zip), "treeSha256": source_identity["treeSha256"]},
                "tests": test_report["suites"],
                "engineeringVerdict": "CANDIDATE ARTIFACTS REPRODUCED — QA HANDOFF NOT CONSTRUCTED IN THIS MODE",
                "releaseAuthorization": False,
                "githubUsed": False,
            }
            atomic_json(DIST / "BUILD_SUMMARY.json", summary)
            print(json.dumps(summary, indent=2))
            return 0

        final_zip = create_handoff(payload, source_identity, test_report, packaging)
        validate_handoff_archive(final_zip)
        summary = {
            "handoff": str(final_zip),
            "size": final_zip.stat().st_size,
            "sha256": sha256(final_zip),
            "setup": {"path": str(DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe"), "size": (DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe").stat().st_size, "sha256": sha256(DIST / "Nyx_PC_Checkup_1.0.0_Setup.exe")},
            "portable": {"path": str(portable), "size": portable.stat().st_size, "sha256": sha256(portable)},
            "source": {"path": str(source_zip), "size": source_zip.stat().st_size, "sha256": sha256(source_zip), "treeSha256": source_identity["treeSha256"]},
            "tests": test_report["suites"],
            "engineeringVerdict": "READY FOR INDEPENDENT WINDOWS QA",
            "historicalCorrections": {"F-001": "PRESERVED IN QA7", "F-002": "PRESERVED IN QA7", "F-003": "PRESERVED IN QA7", "F-004": "PRESERVED IN QA7", "QA4-WH-001": "PRESERVED IN QA7", "QA5-WIN-001": "PRESERVED FROM QA6", "QA5-WIN-002": "PRESERVED FROM QA6", "QA5-ORCH-001": "PRESERVED FROM QA6", "QA5-ENC-001": "PRESERVED FROM QA6", "QA6-F-005": "CORRECTED IN QA7", "QA6-INST-EVIDENCE-001": "PRESERVED IN QA8", "QA7-F-006": "NATIVE PASS PRESERVED FROM QA8", "QA8-F-007": "CORRECTED IN QA9", "QA9-F-008": "CORRECTED IN QA10 AND PRESERVED IN QA11 — NATIVE FINAL UI MATRIX REQUIRED", "QA10-F-009": "CORRECTED IN QA11 — NATIVE CLOSE LIFECYCLE MATRIX REQUIRED"},
            "qa4WindowsHarnessCorrection": {"introducedHarnessRevision": "QA5-PS51-1", "currentHarnessRevision": HARNESS_REVISION, "runtimeSweepExpanded": True, "windowsPowerShell51ExecutedByEngineering": False, "evidence": "evidence/QA4_WINDOWS_HARNESS_CORRECTION.json"},
            "qa5WindowsExecutionCorrection": {"harnessRevision": HARNESS_REVISION, "windowsPowerShell51ExecutedByEngineering": False, "evidence": "evidence/QA5_WINDOWS_EXECUTION_CORRECTION.json"},
            "qa6ModuleCompositionCorrection": {"harnessRevision": HARNESS_REVISION, "singleCompositionRoot": True, "realApplicationQuickCheckLaunchesRequired": 2, "nativeInstallerBranchDiagnostics": True, "windowsPowerShell51ExecutedByEngineering": False, "evidence": "evidence/QA6_MODULE_COMPOSITION_CORRECTION.json"},
            "qa9FinalUiCorrection": {"trackingId": "QA9-F-008", "harnessRevision": HARNESS_REVISION, "nativeWindowsUiMatrixRequired": True, "windowsWinFormsVisualMatrixExecutedByEngineering": False, "evidence": "evidence/QA9_F008_UI_CORRECTION.json"},
            "qa10UiCloseCorrection": {"trackingId": "QA10-F-009", "harnessRevision": HARNESS_REVISION, "boundedTempCleanup": True, "nativeWindowsCloseLifecycleRequired": True, "windowsWinFormsCloseLifecycleExecutedByEngineering": False, "evidence": "evidence/QA10_F009_UI_CLOSE_CORRECTION.json"},
            "qa2MigrationFixtures": {"setupSha256": "FF4C838A1DEF4ABDE39FE89F3A58D023AD25D8C61B99D1836FCB3270F8A301C5", "sourceSha256": "22FCFA7E3050CA854803DD0265109F92444E38E081483A7E2C73DFC0BC522B36"},
            "updateAvailabilityCheck": {
                "implemented": True,
                "manifestUrl": "https://www.dietrichailabs.com/updates/nyx-pc-checkup.json",
                "notificationOnly": True,
                "automaticUpdaterImplemented": False,
                "websiteManifestDeployedByEngineering": False,
            },
            "releaseAuthorization": False,
            "githubUsed": False,
            "finalHandoffInternalAudit": "PASS",
        }
        atomic_json(DIST / "BUILD_SUMMARY.json", summary)
        print(json.dumps(summary, indent=2))
        return 0
    except Exception as exc:
        print(f"BUILD FAILED: {exc}", file=sys.stderr)
        return 1
    finally:
        remove_python_caches(ROOT)


if __name__ == "__main__":
    raise SystemExit(main())

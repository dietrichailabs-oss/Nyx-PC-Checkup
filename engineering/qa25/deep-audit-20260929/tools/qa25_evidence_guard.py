#!/usr/bin/env python3
"""Read-only QA25 evidence/coverage guard. Never runs or certifies Nyx itself.

Python 3.10+, standard library only. All geometry must already have been
captured by an independent native observer in one physical-pixel coordinate
space. The tool checks supplied facts and files; it cannot authenticate that
keystrokes occurred or judge a screenshot. See MASTER_AUDIT.md.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any

CANDIDATE = {
    "build": "2026.09.28-eng-qa25",
    "product_harness": "QA25-F022-PS51-25",
    "source_commit": "f55c0d3bda6a99a20d218a2a390f217963a0d9be",
    "declared_source_tree_sha256": "25D71479533E639EFC8A82ED2B93FDE3A6D47B632BB8EFBBEDAE819F9C3B0A60",
}
ARTIFACTS = {
    "Nyx_PC_Checkup_1.0.0_Setup.exe": (559104, "5F5C1C294F23487DE1B4325173DC72C89950A2AAA96EBB1AC3F80B6CDE788112"),
    "Nyx_PC_Checkup_1.0.0_Portable.zip": (220566, "B38A40D40CFFE86E30F1EA8E88D21295D14B1DD792D60A27962A22783E63D19C"),
    "Nyx_PC_Checkup_1.0.0_Source.zip": (794752, "A4ED460A880BA04A289F504312BF7A1B8D0F3C1A5956DE46E19AFC837CF7049C"),
}
THEMES = ("FollowWindows", "Dark", "Light")
SCALES = (100, 125, 150, 200)
PAGES = ("Home", "Checkup", "Storage", "Startup", "Security", "Updates", "Backup", "System", "Apps", "Cleanup", "Settings")
CHECKS = ("native_identity_verified", "applied_dpi_verified", "theme_verified", "geometry_readable", "keyboard_operable", "navigation_and_actions_accessible", "state_behavior_correct", "work_area_contained", "no_unhandled_exception")
VERDICTS = {"NOT_RUN", "PARTIAL", "BLOCKED_HARNESS", "FAIL", "PASS"}
HEX64 = re.compile(r"^[a-fA-F0-9]{64}$")
SCHEMA = "nyx.qa25.f008.evidence.v1"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest().upper()


def load_json(path: Path) -> Any:
    # Reject duplicate object keys, which would otherwise silently overwrite.
    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result
    with path.open("r", encoding="utf-8-sig") as f:
        return json.load(f, object_pairs_hook=pairs,
                         parse_constant=lambda v: (_ for _ in ()).throw(ValueError(f"Non-finite JSON number: {v}")))


def cell_id(theme: str, scale: int, page: str) -> str:
    return f"F008/{theme}/{scale}/{page}"


def make_matrix() -> dict[str, Any]:
    return {
        "schema": SCHEMA, "candidate": dict(CANDIDATE),
        "protocol": "QA25-DEEP-AUDIT-20260929-v1",
        "notice": "Unexecuted template. No native QA25 PASS is asserted.",
        "cells": [{"id": cell_id(t, s, p), "theme": t, "scale_percent": s,
                   "page": p, "verdict": "NOT_RUN", "checks": dict.fromkeys(CHECKS),
                   "session": None, "evidence": [], "notes": ""}
                  for t, s, p in itertools.product(THEMES, SCALES, PAGES)],
    }


def safe_file(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative:
        raise ValueError("Evidence path must be a nonempty relative string")
    name = relative.replace("\\", "/")
    pp = PurePosixPath(name)
    if pp.is_absolute() or ":" in name or any(x in ("", ".", "..") for x in name.split("/")):
        raise ValueError(f"Unsafe evidence path: {relative}")
    root = root.resolve(strict=True)
    path = root
    for part in pp.parts:
        path = path / part
        if path.is_symlink():
            raise ValueError(f"Symlink evidence is not accepted: {relative}")
    resolved = path.resolve(strict=True)
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise ValueError(f"Evidence is not an ordinary file under root: {relative}")
    return resolved


def verify_artifacts(root: Path) -> list[str]:
    errors: list[str] = []
    for name, (size, sha) in ARTIFACTS.items():
        try:
            path = safe_file(root, name)
            if path.stat().st_size != size or digest(path) != sha:
                errors.append(f"Candidate artifact mismatch: {name}")
        except (OSError, ValueError) as e:
            errors.append(f"{name}: {e}")
    return errors


def number(v: Any, name: str, positive: bool = False) -> float:
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v):
        raise ValueError(f"{name} must be finite numeric data, not bool/null/string")
    if positive and v <= 0:
        raise ValueError(f"{name} must be positive")
    return float(v)


def rect(v: Any, name: str) -> tuple[float, float, float, float]:
    if not isinstance(v, list) or len(v) != 4:
        raise ValueError(f"{name} must be [left, top, width, height]")
    x, y, w, h = [number(a, name) for a in v]
    if w <= 0 or h <= 0:
        raise ValueError(f"{name} must have positive dimensions")
    return x, y, w, h


def intersection(a: tuple[float, ...], b: tuple[float, ...]) -> tuple[float, float, float, float]:
    x, y = max(a[0], b[0]), max(a[1], b[1])
    return x, y, max(0.0, min(a[0]+a[2], b[0]+b[2])-x), max(0.0, min(a[1]+a[3], b[1]+b[3])-y)


def evaluate_geometry(g: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(g, dict):
        raise ValueError("Geometry root must be an object")
    if g.get("coordinate_space") != "physical-screen-pixels":
        raise ValueError("Geometry needs one declared physical-screen-pixel coordinate space")
    if g.get("focused") is not True or g.get("layout_settled") is not True:
        raise ValueError("Focus and settled layout must be explicitly established")
    whole = rect(g.get("full_cell_rect"), "full_cell_rect")
    clips = g.get("clip_rectangles")
    if not isinstance(clips, list) or not clips:
        raise ValueError("Supply data viewport AND every clipping ancestor/work-area rectangle")
    visible = whole
    for i, r in enumerate(clips):
        visible = intersection(visible, rect(r, f"clip_rectangles[{i}]"))
    scale = number(g.get("scale_percent"), "scale_percent", True) / 100.0
    logical = number(g.get("policy_minimum_logical"), "policy_minimum_logical", True)
    width = number(g.get("column_width_px"), "column_width_px", True)
    minimum = number(g.get("column_minimum_px"), "column_minimum_px", True)
    text = number(g.get("essential_text_width_px"), "essential_text_width_px", True)
    padding = number(g.get("horizontal_padding_px"), "horizontal_padding_px")
    if padding < 0:
        raise ValueError("Padding cannot be negative")
    # Match the frozen source tests: nearest integer, midpoint-to-even.
    # Using ceil here would falsely reject e.g. 130 * 1.25 -> 162 pixels.
    required = int(round(logical * scale))
    checks = {
        "column_has_practical_width": width >= required,
        "minimum_width_enforces_policy": minimum >= required,
        "cell_matches_column_width": abs(whole[2] - width) <= 2,
        "full_cell_visible": visible[2] > 0 and visible[3] > 0 and visible[2] >= whole[2]-2 and visible[3] >= whole[3]-2,
        "essential_text_fits": visible[2] >= text + padding,
    }
    return {"passed": all(checks.values()), "checks": checks,
            "visible_rect": list(visible), "required_width_px": required,
            "scope": "Checks supplied geometry only; not independent proof of a native action."}


def validate_matrix(data: dict[str, Any], root: Path) -> dict[str, Any]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return {"valid": False, "complete": False, "errors": ["Matrix root must be an object"]}
    if data.get("schema") != SCHEMA:
        errors.append("Wrong matrix schema")
    if data.get("candidate") != CANDIDATE:
        errors.append("Wrong or incomplete frozen QA25 identity; no automatic carry-forward")
    cells = data.get("cells")
    if not isinstance(cells, list):
        return {"valid": False, "complete": False, "errors": errors+["cells must be a list"]}
    expected = {cell_id(t,s,p) for t,s,p in itertools.product(THEMES,SCALES,PAGES)}
    seen: set[str] = set()
    counts: Counter[str] = Counter()
    for c in cells:
        if not isinstance(c, dict):
            errors.append("Cell is not an object"); continue
        ident = c.get("id")
        if not isinstance(ident, str):
            errors.append("Cell ID is missing or not a string"); continue
        if ident in seen:
            errors.append(f"Duplicate cell: {ident}")
        seen.add(ident)
        if ident not in expected or ident != cell_id(c.get("theme"), c.get("scale_percent"), c.get("page")):
            errors.append(f"Unexpected cell coordinates: {ident}")
        verdict = c.get("verdict")
        if not isinstance(verdict, str) or verdict not in VERDICTS:
            errors.append(f"Invalid verdict: {ident}"); continue
        counts[verdict] += 1
        if verdict != "PASS":
            continue
        if not isinstance(c.get("checks"), dict) or any(c["checks"].get(k) is not True for k in CHECKS):
            errors.append(f"Incomplete PASS checklist: {ident}")
        session = c.get("session")
        if not isinstance(session, dict):
            errors.append(f"Missing native session: {ident}"); continue
        if session.get("source_commit") != CANDIDATE["source_commit"] or session.get("build") != CANDIDATE["build"]:
            errors.append(f"Wrong session candidate: {ident}")
        if not str(session.get("powershell_version", "")).startswith("5.1."):
            errors.append(f"Not a recorded PS5.1 session: {ident}")
        if session.get("measurement_mode") != "installed_native":
            errors.append(f"Synthetic/integration-only evidence cannot certify F008: {ident}")
        for key in ("session_id", "os_build", "dpi_method", "observer_awareness", "capture_basis"):
            if not isinstance(session.get(key), str) or not session[key].strip():
                errors.append(f"Missing session {key}: {ident}")
        awareness = str(session.get("observer_awareness", "")).lower()
        if "unaware" in awareness or awareness in ("", "unknown"):
            errors.append(f"Unproven/non-DPI-aware observer: {ident}")
        try:
            dpi = number(session.get("effective_dpi"), "effective_dpi", True)
            if abs(dpi - number(c.get("scale_percent"), "scale_percent", True)*0.96) > 1:
                errors.append(f"Requested scale does not match measured DPI: {ident}")
        except ValueError as e:
            errors.append(f"{ident}: {e}")
        if session.get("selected_theme") != c.get("theme") or session.get("resolved_theme") not in ("Dark", "Light"):
            errors.append(f"Unverified selected/resolved theme: {ident}")
        if c.get("theme") in ("Dark", "Light") and session.get("resolved_theme") != c["theme"]:
            errors.append(f"Resolved theme disagrees with explicit selection: {ident}")
        resolution = session.get("resolution")
        if not isinstance(resolution, list) or len(resolution) != 2 or any(isinstance(x,bool) or not isinstance(x,int) or x <= 0 for x in resolution):
            errors.append(f"Missing actual resolution: {ident}")
        elif c.get("scale_percent") in (150, 200) and resolution != [1366, 768]:
            errors.append(f"This protocol's constrained 1366x768 case is missing: {ident}")
        refs = c.get("evidence")
        kinds: set[str] = set()
        if not isinstance(refs, list):
            errors.append(f"Evidence must be a list: {ident}"); continue
        for ref in refs:
            try:
                if not isinstance(ref, dict):
                    raise ValueError("Evidence reference is not an object")
                sha = ref.get("sha256")
                if not isinstance(sha, str) or not HEX64.fullmatch(sha):
                    raise ValueError("Missing/invalid evidence SHA-256")
                path = safe_file(root, ref.get("path"))
                if digest(path) != sha.upper():
                    raise ValueError(f"Evidence hash mismatch: {ref.get('path')}")
                kind = ref.get("kind")
                if not isinstance(kind, str):
                    raise ValueError("Missing evidence kind")
                kinds.add(kind)
            except (OSError, ValueError, TypeError) as e:
                errors.append(f"{ident}: {e}")
        if not {"screenshot", "native_record", "installed_identity"}.issubset(kinds):
            errors.append(f"Missing screenshot/native record/installed identity: {ident}")
    if seen != expected or len(cells) != 132:
        errors.append("Matrix must contain exactly the 132 unique required cells")
    return {"valid": not errors, "complete": not errors and counts["PASS"] == 132,
            "counts": dict(counts), "errors": errors,
            "scope": "Coverage and evidence-integrity check only; independent review and other release gates still required."}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="command", required=True)
    q = sub.add_parser("init-matrix"); q.add_argument("output", type=Path)
    q = sub.add_parser("verify-artifacts"); q.add_argument("directory", type=Path)
    q = sub.add_parser("geometry"); q.add_argument("record", type=Path)
    q = sub.add_parser("matrix"); q.add_argument("record", type=Path); q.add_argument("--evidence-root", type=Path, required=True); q.add_argument("--require-complete", action="store_true")
    a = p.parse_args()
    try:
        if a.command == "init-matrix":
            # Exclusive create: never silently overwrite an execution journal.
            with a.output.open("x", encoding="utf-8") as f:
                json.dump(make_matrix(), f, indent=2); f.write("\n")
            print("Created 132 NOT_RUN cells. No QA result has been generated."); return 0
        if a.command == "verify-artifacts":
            errors = verify_artifacts(a.directory)
            print(json.dumps({"archive_hashes_match": not errors, "errors": errors,
                              "source_tree_recomputed": False}, indent=2)); return 2 if errors else 0
        if a.command == "geometry":
            result = evaluate_geometry(load_json(a.record))
            print(json.dumps(result, indent=2)); return 0 if result["passed"] else 2
        result = validate_matrix(load_json(a.record), a.evidence_root)
        print(json.dumps(result, indent=2))
        if not result["valid"]: return 2
        return 3 if a.require_complete and not result["complete"] else 0
    except (OSError, ValueError, TypeError, KeyError) as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr); return 2


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "product"
IDENTITY = ROOT / "SOURCE_TREE_IDENTITY.json"
EXPECTED_TREE = "C4273FA058A9151EF7E51EDE2EC264892CA707FF5957B7F5C39EA0DB7D599EAA"

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()

def main() -> int:
    data = json.loads(IDENTITY.read_text(encoding="utf-8"))
    failures = []
    if data.get("treeSha256") != EXPECTED_TREE:
        failures.append(f"identity treeSha256 != expected: {data.get('treeSha256')}")
    for rec in data.get("files", []):
        path = ROOT / rec["path"]
        if not path.is_file():
            failures.append(f"missing: {rec['path']}")
            continue
        if path.stat().st_size != rec["size"]:
            failures.append(f"size mismatch: {rec['path']}")
        if sha256(path) != rec["sha256"]:
            failures.append(f"hash mismatch: {rec['path']}")
    if failures:
        print("QA11 BASELINE VERIFY: FAIL")
        for failure in failures:
            print("-", failure)
        return 1
    print(f"QA11 BASELINE VERIFY: PASS ({len(data.get('files', []))} files; tree {EXPECTED_TREE})")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

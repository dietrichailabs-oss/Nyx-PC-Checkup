#!/usr/bin/env python3
"""Build Nyx PC Checkup locally, reproduce it from the source ZIP, and freeze QA handoff."""
from __future__ import annotations

import datetime as dt
import json
import platform
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from zoneinfo import ZoneInfo

import build_release as br


def run_builder(root: Path, *, candidate_only: bool = False) -> dict[str, object]:
    command = [sys.executable, str(root / "tools" / "build_release.py")]
    if candidate_only:
        command.append("--candidate-only")
    result = subprocess.run(
        command,
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise br.BuildError(
            f"Build failed in {root}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}"
        )
    return json.loads(result.stdout)


def main() -> int:
    eastern = ZoneInfo("America/New_York")
    started = dt.datetime.now(tz=eastern)
    try:
        primary = run_builder(br.ROOT)
        primary_files = {
            "setup": Path(primary["setup"]["path"]),
            "portable": Path(primary["portable"]["path"]),
            "source": Path(primary["source"]["path"]),
        }
        primary_hashes = {name: br.sha256(path) for name, path in primary_files.items()}

        with tempfile.TemporaryDirectory(prefix="nyx-pc-checkup-repro-") as temp_name:
            temp = Path(temp_name)
            with zipfile.ZipFile(primary_files["source"]) as zf:
                zf.extractall(temp)
            source_roots = [p for p in temp.iterdir() if p.is_dir()]
            if len(source_roots) != 1:
                raise br.BuildError("Source ZIP did not extract to one exact root")
            reproduced = run_builder(source_roots[0], candidate_only=True)
            reproduced_files = {
                "setup": Path(reproduced["setup"]["path"]),
                "portable": Path(reproduced["portable"]["path"]),
                "source": Path(reproduced["source"]["path"]),
            }
            reproduced_hashes = {name: br.sha256(path) for name, path in reproduced_files.items()}

        matches = {name: primary_hashes[name] == reproduced_hashes[name] for name in primary_hashes}
        if not all(matches.values()):
            raise br.BuildError(f"Clean-source reproducibility failed: {matches}")

        stopped = dt.datetime.now(tz=eastern)
        evidence = {
            "schema": "dietrich-ai-labs.reproducibility-check.v1",
            "product": "Nyx PC Checkup",
            "version": br.VERSION,
            "build": br.BUILD_ID,
            "startedEastern": started.isoformat(),
            "completedEastern": stopped.isoformat(),
            "elapsedSeconds": round((stopped - started).total_seconds(), 3),
            "host": platform.platform(),
            "method": "Built the project, extracted the generated source ZIP to a new temporary root, built that source independently, and compared exact SHA-256 identities.",
            "networkUsed": False,
            "githubUsed": False,
            "artifacts": {
                name: {
                    "primarySha256": primary_hashes[name],
                    "reproducedSha256": reproduced_hashes[name],
                    "exactMatch": matches[name],
                }
                for name in ["setup", "portable", "source"]
            },
            "result": "PASS",
            "note": "The master QA handoff ZIP contains session timing evidence and is therefore not expected to be byte-identical across separate build sessions. Its internal manifest and SHA256SUMS are audited each time.",
        }
        br.atomic_json(br.EVIDENCE / "REPRODUCIBILITY_CHECK.json", evidence)

        payload = json.loads((br.STAGE / "PAYLOAD_MANIFEST.json").read_text(encoding="utf-8"))
        source_identity = json.loads((br.HANDOFF / "metadata" / "SOURCE_TREE_IDENTITY.json").read_text(encoding="utf-8"))
        test_report = json.loads((br.EVIDENCE / "ENGINEERING_TEST_REPORT.json").read_text(encoding="utf-8"))
        packaging = json.loads((br.EVIDENCE / "PACKAGING_EVIDENCE.json").read_text(encoding="utf-8"))
        handoff = br.create_handoff(payload, source_identity, test_report, packaging)
        br.validate_handoff_archive(handoff)

        summary_path = br.DIST / "BUILD_SUMMARY.json"
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        summary["handoff"] = str(handoff)
        summary["size"] = handoff.stat().st_size
        summary["sha256"] = br.sha256(handoff)
        summary["reproducibility"] = {
            "result": "PASS",
            "setupExactMatch": True,
            "portableExactMatch": True,
            "sourceExactMatch": True,
            "evidence": "evidence/REPRODUCIBILITY_CHECK.json",
        }
        summary["finalHandoffInternalAudit"] = "PASS"
        br.atomic_json(summary_path, summary)
        print(json.dumps(summary, indent=2))
        return 0
    except Exception as exc:
        print(f"BUILD/REPRODUCTION FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

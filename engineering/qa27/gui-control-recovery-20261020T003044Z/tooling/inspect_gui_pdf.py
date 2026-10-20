"""Read-only inspection of the single actual QA27 GUI-exported PDF.

This does not execute product code, create a PDF, repair one, or substitute for
the blocked native PowerShell unit/module suite. All output files are new.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from pypdf import PdfReader


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pdf", type=Path)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    output = args.output_directory.resolve()
    output.mkdir(parents=False, exist_ok=False)
    result = {
        "StartedUtc": datetime.now(timezone.utc).isoformat(),
        "Scope": "F-024 installed-GUI integration output inspection only",
        "NativeModuleSuiteCredit": 0,
        "PdfModified": False,
        "Reader": "pypdf strict=True",
        "Passed": False,
    }
    try:
        pdf_path = args.pdf.resolve(strict=True)
        fixture_path = args.fixture.resolve(strict=True)
        payload = pdf_path.read_bytes()
        fixture_bytes = fixture_path.read_bytes()
        fixture_hash = hashlib.sha256(fixture_bytes).hexdigest().upper()
        assert fixture_hash == "9EBD0A3DD3933AB3161AE1629E9E010A0805C4A177CC440E560BB1B67A4295DE"
        fixture = json.loads(fixture_bytes.decode("utf-8-sig"))
        result.update({
            "PdfPath": str(pdf_path), "Bytes": len(payload),
            "SHA256": hashlib.sha256(payload).hexdigest().upper(),
            "FixtureSHA256": fixture_hash,
            "Header": payload[:16].decode("ascii", errors="replace"),
        })
        assert len(payload) > 0 and payload.startswith(b"%PDF-")
        assert payload.rstrip().endswith(b"%%EOF")
        reader = PdfReader(pdf_path, strict=True)
        assert not reader.is_encrypted and len(reader.pages) > 0
        texts = [page.extract_text() or "" for page in reader.pages]
        text = "\n".join(texts)
        required = [
            "NYX PC CHECKUP - LOCAL DIAGNOSTIC SUMMARY", "Dietrich AI Labs",
            "2026.10.19-eng-qa27", "Scan: Full", str(fixture["CompletedUtc"]),
            "Finding:", "Why:", "Recommendation:",
            str(fixture["Results"][0]["Name"]),
        ]
        result["RequiredContent"] = [{"Text": token, "Found": token in text} for token in required]
        assert all(item["Found"] for item in result["RequiredContent"]), "Expected report content missing"
        with (output / "EXTRACTED_TEXT.txt").open("x", encoding="utf-8") as stream:
            stream.write(text)

        # Inspect parsed text operators instead of trusting text extraction to
        # retain empty rows. The shipped writer uses Td, TL, Tj and T*.
        rows = []
        for page_index, page in enumerate(reader.pages):
            y, leading = 0.0, 0.0
            for operands, operator in page.get_contents().operations:
                if operator == b"BT":
                    y = 0.0
                elif operator == b"TL":
                    leading = float(operands[0])
                elif operator == b"Td":
                    y += float(operands[1])
                elif operator == b"T*":
                    y -= leading
                elif operator == b"Tj":
                    rows.append({"Page": page_index + 1, "Y": y, "Text": str(operands[0])})
        first_page = [row for row in rows if row["Page"] == 1]
        assert len(first_page) >= 8
        assert first_page[0]["Text"].startswith("NYX PC CHECKUP")
        step = first_page[0]["Y"] - first_page[1]["Y"]
        assert step > 0
        scan_index = next(i for i, row in enumerate(first_page) if row["Text"].startswith("Scan: "))
        overall_index = next(i for i, row in enumerate(first_page) if row["Text"].startswith("Overall: "))
        between = first_page[scan_index + 1:overall_index]
        assert len(between) == 1 and between[0]["Text"] == "", "Intentional first separator row missing"
        gap = first_page[scan_index]["Y"] - first_page[overall_index]["Y"]
        assert gap == step * 2, "Blank separator did not retain its vertical advance"
        result.update({
            "PageCount": len(reader.pages), "ReadableExpectedContent": True,
            "NormalLineAdvancePoints": step, "FirstSeparatorGapPoints": gap,
            "IntentionalFirstBlankSeparatorPreserved": True,
            "EmptyRowsInDocument": sum(row["Text"] == "" for row in rows),
            "TextRows": rows, "Passed": True,
        })
    except Exception as error:
        result["Error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        result["CompletedUtc"] = datetime.now(timezone.utc).isoformat()
        with (output / "GUI_PDF_INSPECTION.json").open("x", encoding="utf-8") as stream:
            json.dump(result, stream, indent=2)
            stream.write("\n")
        print(json.dumps({key: value for key, value in result.items() if key != "TextRows"}, indent=2))


if __name__ == "__main__":
    main()

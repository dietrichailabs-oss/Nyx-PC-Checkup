#!/usr/bin/env python3
"""Independent PDF-parser/readability stage of the focused native F-024 gate.

Run only after Test-QA27PdfExportBlankLines.ps1 completes on exact QA27 bytes.
Needs pypdf; never creates or repairs PDF files, scans the PC, or changes policy.
"""
import argparse
import hashlib
import json
from pathlib import Path

from pypdf import PdfReader


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence_directory', type=Path)
    args = parser.parse_args()
    root = args.evidence_directory.resolve()
    result = json.loads((root / 'F024_NATIVE_RESULT.json').read_text(encoding='utf-8-sig'))
    assert result['Passed'] is True, 'Native stage must pass first'
    assert result['PSEdition'] == 'Desktop' and result['PowerShellVersion'].startswith('5.1.')
    checks = []
    for output in result['Outputs']:
        path = Path(output['Path']).resolve()
        assert path.parent == root, 'Only this exact evidence directory is allowed'
        assert path.stat().st_size == output['Bytes'] > 0
        assert hashlib.sha256(path.read_bytes()).hexdigest().upper() == output['SHA256']
        reader = PdfReader(path, strict=True)
        assert len(reader.pages) > 0
        text = '\n'.join(page.extract_text() for page in reader.pages)
        wanted = {
            'normal.pdf': ('Ordinary first line', 'Ordinary second line'),
            'single-blank.pdf': ('Before', 'After'),
            'consecutive-blanks.pdf': ('Before', 'After'),
            'empty-collection.pdf': ('Nyx PC Checkup report',),
            'escaping-wrapping.pdf': ('Literal (parentheses) and \\ backslash', 'A' * 92, 'A' * 28),
            'pagination.pdf': ('Row 1', 'Row 55'),
            'representative-full.pdf': ('NYX PC CHECKUP - LOCAL DIAGNOSTIC SUMMARY', 'Finding:', 'Recommendation:'),
        }.get(path.name, ())
        assert all(token in text for token in wanted), path.name
        if path.name == 'single-empty-line.pdf':
            assert not text.strip(), 'A blank row must not become fallback text'
        checks.append({'file': path.name, 'pages': len(reader.pages), 'readableExpectedContent': True})
    # Preserve spacing even when a text extractor intentionally omits blank rows.
    def y_positions(name):
        values = {}
        y, leading = 0.0, 0.0
        page = PdfReader(root / name, strict=True).pages[0]
        for operands, operator in page.get_contents().operations:
            if operator == b'TL':
                leading = float(operands[0])
            elif operator == b'Td':
                y += float(operands[1])
            elif operator == b'T*':
                y -= leading
            elif operator == b'Tj' and str(operands[0]) in ('Before', 'After'):
                values[str(operands[0])] = y
        return abs(values['Before'] - values['After'])
    assert y_positions('single-blank.pdf') == 26
    assert y_positions('consecutive-blanks.pdf') == 39
    report = root / 'F024_PDF_READER_RESULT.json'
    with report.open('x', encoding='utf-8') as out:
        json.dump({'Passed': True, 'Reader': 'pypdf', 'Checks': checks, 'BlankLineSpacingPoints': [26, 39]}, out, indent=2)
        out.write('\n')
    print(report)


if __name__ == '__main__':
    main()

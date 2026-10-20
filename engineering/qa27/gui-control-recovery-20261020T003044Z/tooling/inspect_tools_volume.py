"""Read-only preflight of an unmounted dedicated QA27 FAT tools volume."""
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(r"C:\Users\Nyx\Documents\ChatGPT\Nyx Pc Cleanup\qa27-f024\.tools\isolated-vm")
sys.path.insert(0, str(root / "python-deps"))
from pyfatfs.PyFatFS import PyFatFS

image = Path(sys.argv[1]).resolve(strict=True)
output = Path(sys.argv[2])
assert not output.exists(), "Refusing to overwrite evidence"
expected = {item["guestName"]: item["sha256"] for item in json.loads((root / "VM_MEDIA_MANIFEST.json").read_text(encoding="utf-8-sig"))["files"]}
expected["CollectQA27Evidence.exe"] = hashlib.sha256((root / "CollectQA27Evidence.exe").read_bytes()).hexdigest().upper()
report = {"Utc": datetime.now(timezone.utc).isoformat(), "Image": str(image), "ReadOnly": True, "ProductCodeExecuted": False, "Files": []}
with PyFatFS(str(image), read_only=True) as volume:
    report["RootEntries"] = volume.listdir("/")
    for name, wanted in expected.items():
        data = volume.readbytes("/" + name)
        actual = hashlib.sha256(data).hexdigest().upper()
        report["Files"].append({"Name": name, "Bytes": len(data), "SHA256": actual, "ExpectedSHA256": wanted, "Matches": actual == wanted})
    report["FreshExportDirectoryEmpty"] = volume.listdir("/EXPORT") == []
report["AllMatch"] = all(item["Matches"] for item in report["Files"]) and report["FreshExportDirectoryEmpty"]
with output.open("x", encoding="utf-8") as stream:
    json.dump(report, stream, indent=2)
    stream.write("\n")
print(json.dumps(report, indent=2))
assert report["AllMatch"], "Tools volume precondition failed"

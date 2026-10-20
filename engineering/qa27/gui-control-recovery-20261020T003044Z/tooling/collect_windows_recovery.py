"""Copy only Windows-created recovery files from the stopped guest tools disk."""
import hashlib
import json
import sys
from pathlib import Path

root = Path(r"C:\Users\Nyx\Documents\ChatGPT\Nyx Pc Cleanup\qa27-f024\.tools\isolated-vm")
sys.path.insert(0, str(root / "python-deps"))
from pyfatfs.PyFatFS import PyFatFS

target = Path(sys.argv[1])
target.mkdir(exist_ok=False)
records = []
with PyFatFS(str(root / "qa27-io.img"), read_only=True) as volume:
    paths = ["/Recovery.txt"]
    if volume.isdir("/Recovery"):
        paths.extend(volume.walk.files("/Recovery"))
    for name in paths:
        data = volume.readbytes(name)
        relative = Path(name.lstrip("/"))
        assert ".." not in relative.parts
        output = target / relative
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("xb") as stream:
            stream.write(data)
        records.append({"Path": name, "Bytes": len(data), "SHA256": hashlib.sha256(data).hexdigest().upper()})
        if name == "/Recovery.txt":
            print(data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8", errors="replace")[:12000])
with (target / "MANIFEST.json").open("x", encoding="utf-8") as stream:
    json.dump({"ReadOnlySource": True, "QA27ProductExecutions": 0, "Files": records}, stream, indent=2)
print(json.dumps(records, indent=2))

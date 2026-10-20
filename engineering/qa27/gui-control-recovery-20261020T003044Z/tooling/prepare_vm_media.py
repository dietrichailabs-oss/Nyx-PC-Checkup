import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'python-deps'))
from pyfatfs.PyFat import PyFat
from pyfatfs.PyFatFS import PyFatFS

product = ROOT.parents[1] / 'product'
fixture = ROOT.parents[1] / 'engineering' / 'qa27' / 'fixtures' / 'preserved-full-scan.json'
image = ROOT / 'qa27-io.img'
with image.open('xb') as stream:
    stream.truncate(64 * 1024 * 1024)
fat = PyFat()
fat.mkfs(str(image), fat_type=PyFat.FAT_TYPE_FAT16, label='QA27_IO')
fat.close()
records = []
with PyFatFS(str(image)) as fs:
    for source, name in [(product / 'dist' / 'Nyx_PC_Checkup_1.0.0_Setup.exe', 'QA27Setup.exe'),
                         (fixture, 'preserved-full-scan.json'),
                         (ROOT / 'VerifyInstalledQA27.exe', 'VerifyInstalledQA27.exe')]:
        data = source.read_bytes()
        fs.writebytes('/' + name, data)
        records.append({'source': str(source), 'guestName': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest().upper()})
    fs.makedir('/EXPORT')
with (ROOT / 'VM_MEDIA_MANIFEST.json').open('x', encoding='utf-8') as out:
    json.dump({'files': records, 'network': 'none', 'guestOutputDirectory': 'QA27_IO/EXPORT',
               'containsPowerShellHarness': False, 'installerInvocation': 'normal GUI',
               'productLaunch': 'normal installed EXE only'}, out, indent=2)
print(json.dumps({'image': str(image), 'files': records}, indent=2))

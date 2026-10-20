import concurrent.futures
import hashlib
import json
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
FILES = [
    ('windows10-ltsc-eval-x64.iso', 'https://software-static.download.prss.microsoft.com/db/download/444969d5-f34g-4e03-ac9d-1f9786c69161/19044.1288.211006-0501.21h2_release_svc_refresh_CLIENT_LTSC_EVAL_x64FRE_en-us.iso', 'sha256', 'E4AB2E3535BE5748252A8D5D57539A6E59BE8D6726345EE10E7AFD2CB89FEFB5'),
    ('qemu-w64-setup-20260811.exe', 'https://qemu.weilnetz.de/w64/qemu-w64-setup-20260811.exe', 'sha512', '5bcf9eed634e8575a37b74f445af41a2fe4106da512d0c30c368301d4c105037fdfab40a5287367a28a957624cddebbc8c07e16c88ab6634f554cdf3d16bf543'),
    ('7zr.exe', 'https://github.com/ip7z/7zip/releases/download/26.04/7zr.exe', 'sha256', None),
    ('7z2604-extra.7z', 'https://github.com/ip7z/7zip/releases/download/26.04/7z2604-extra.7z', 'sha256', None),
]

def fetch(item):
    name, url, algorithm, expected = item
    path = ROOT / name
    digest = hashlib.new(algorithm)
    started = time.time()
    count = 0
    last = 0
    with urllib.request.urlopen(url, timeout=60) as response, path.open('xb') as out:
        total = response.headers.get('Content-Length')
        while chunk := response.read(4 * 1024 * 1024):
            out.write(chunk)
            digest.update(chunk)
            count += len(chunk)
            if time.time() - last >= 20:
                print(json.dumps({'file': name, 'bytes': count, 'total': total}), flush=True)
                last = time.time()
    actual = digest.hexdigest().upper()
    result = {'file': name, 'url': url, 'bytes': count, algorithm: actual,
              'expected': expected, 'verified': expected is not None and actual == expected.upper(),
              'elapsedSeconds': time.time() - started}
    with (ROOT / (name + '.receipt.json')).open('x', encoding='utf-8') as out:
        json.dump(result, out, indent=2)
    if expected is not None and not result['verified']:
        raise RuntimeError('Hash mismatch: ' + name)
    print(json.dumps(result), flush=True)
    return result

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(fetch, FILES))
    with (ROOT / 'DOWNLOAD_RESULTS.json').open('x', encoding='utf-8') as out:
        json.dump(results, out, indent=2)

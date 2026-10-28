#!/usr/bin/env python3
"""Download the official archive in bounded ranges, verify, then seed Nix's store."""
import base64
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

URL = 'https://wow.aethus.pl/download/AzerothSurvivorsWindowsNew.rar'
ROOT = Path(__file__).resolve().parent.parent

def output(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()

updating = '--update' in sys.argv
source = output('nix', 'eval', '--raw', '.#default.payload.src.outPath')
if not updating and Path(source).exists():
    print(json.dumps({'path': source, 'cached': True}))
    sys.exit(0)
expected = output('nix', 'eval', '--raw', '.#default.payload.src.outputHash')
headers = output('curl', '--head', '--fail', '--silent', '--show-error', '--location', URL)
lengths = [int(line.split(':', 1)[1]) for line in headers.splitlines() if line.lower().startswith('content-length:')]
if not lengths or lengths[-1] <= 0:
    raise RuntimeError('The official archive has no valid Content-Length')
total = lengths[-1]
chunk_size = 4 * 1024 * 1024
with tempfile.TemporaryDirectory(prefix='azeroth-archive-') as tmp:
    root = Path(tmp)
    def fetch(i):
        start = i * chunk_size
        end = min(total, start + chunk_size) - 1
        part = root / f'{i:04d}.part'
        header = root / f'{i:04d}.headers'
        subprocess.run(['curl', '--fail', '--silent', '--show-error', '--retry', '4',
            '--retry-all-errors', '--connect-timeout', '30', '--max-time', '600',
            '--range', f'{start}-{end}', '--dump-header', str(header),
            '--output', str(part), URL], check=True)
        if f'content-range: bytes {start}-{end}/{total}' not in header.read_text().lower():
            raise RuntimeError(f'Unexpected response range for chunk {i}')
        if part.stat().st_size != end-start+1:
            raise RuntimeError(f'Incomplete chunk {i}')
        return part
    count = (total + chunk_size - 1) // chunk_size
    with concurrent.futures.ThreadPoolExecutor(max_workers=32) as pool:
        futures = [pool.submit(fetch, i) for i in range(count)]
        for done, future in enumerate(concurrent.futures.as_completed(futures), 1):
            future.result()
            if done % 10 == 0 or done == count:
                print(f'Archive: {done}/{count} chunks', file=sys.stderr, flush=True)
    archive = root / 'AzerothSurvivorsWindowsNew.rar'
    digest = hashlib.sha256()
    with archive.open('wb') as out:
        for i in range(count):
            with (root / f'{i:04d}.part').open('rb') as part:
                while block := part.read(1024*1024):
                    digest.update(block)
                    out.write(block)
    sri = 'sha256-' + base64.b64encode(digest.digest()).decode()
    if not updating and sri != expected:
        raise RuntimeError(f'Archive changed: expected {expected}, received {sri}')
    added = output('nix-store', '--add-fixed', 'sha256', str(archive))
    if not updating and added != source:
        raise RuntimeError('Seeded archive path does not match the fixed-output source')
    print(json.dumps({'path': added, 'hash': sri}))

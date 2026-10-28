#!/usr/bin/env python3
"""Download and verify the official archive, resuming interrupted range requests."""
import base64
import concurrent.futures
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

URL = 'https://wow.aethus.pl/download/AzerothSurvivorsWindowsNew.rar'
ROOT = Path(__file__).resolve().parent.parent


def output(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def fetch_range(url, root, i, total, chunk_size, retry_delay=2):
    start = i * chunk_size
    end = min(total, start + chunk_size) - 1
    part = root / f'{i:04d}.part'
    header = root / f'{i:04d}.headers'
    for attempt in range(8):
        have = part.stat().st_size if part.exists() else 0
        if have == end - start + 1:
            return part
        if have > end - start + 1:
            raise RuntimeError(f'Oversized chunk {i}')
        offset = start + have
        with part.open('ab') as target:
            result = subprocess.run([
                'curl', '--fail', '--silent', '--show-error',
                '--connect-timeout', '30', '--max-time', '180',
                '--max-filesize', str(end-offset+1),
                '--range', f'{offset}-{end}', '--dump-header', str(header), url,
            ], stdout=target)
        valid_range = f'content-range: bytes {offset}-{end}/{total}' in header.read_text().lower()
        if not valid_range:
            # An HTTP error may have no body. An ignored range with a body is unsafe.
            if part.stat().st_size != have or result.returncode == 0:
                raise RuntimeError(f'Server ignored or changed range for chunk {i}')
        elif part.stat().st_size == end-start+1:
            return part
        if attempt < 7:
            time.sleep(retry_delay)
    raise RuntimeError(f'Chunk {i} failed after resumable retries')


def main():
    updating = '--update' in sys.argv
    source = output('nix', 'eval', '--raw', '.#default.payload.src.outPath')
    if not updating and Path(source).exists():
        print(json.dumps({'path': source, 'cached': True}))
        return
    expected = output('nix', 'eval', '--raw', '.#default.payload.src.outputHash')
    headers = output('curl', '--head', '--fail', '--silent', '--show-error', '--location', URL)
    lengths = [int(line.split(':', 1)[1]) for line in headers.splitlines() if line.lower().startswith('content-length:')]
    if not lengths or lengths[-1] <= 0:
        raise RuntimeError('The official archive has no valid Content-Length')
    total = lengths[-1]
    # Small ranges finish even on throttled connections; retries retain received bytes.
    chunk_size = 1024 * 1024
    with tempfile.TemporaryDirectory(prefix='azeroth-archive-') as tmp:
        root = Path(tmp)
        count = (total + chunk_size - 1) // chunk_size
        with concurrent.futures.ThreadPoolExecutor(max_workers=32) as pool:
            futures = [pool.submit(fetch_range, URL, root, i, total, chunk_size) for i in range(count)]
            for done, future in enumerate(concurrent.futures.as_completed(futures), 1):
                future.result()
                if done % 25 == 0 or done == count:
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


if __name__ == '__main__':
    main()

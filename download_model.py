#!/usr/bin/env python3
"""Download the pinned upstream model, verifying size and Git/LFS content hashes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.request


def download_model(root):
    manifest = json.loads((root / 'runtime.json').read_text())
    repo, revision = manifest['model'], manifest['revision']
    base = f'https://huggingface.co/{repo}/resolve/{revision}'
    api = f'https://huggingface.co/api/models/{repo}/tree/{revision}'
    headers = {'User-Agent': 'Dwemer-Higgs-TTS/1'}
    if os.environ.get('HF_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['HF_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(api, headers=headers), timeout=60) as response:
        entries = {item['path']: item for item in json.load(response)}
    destination = root / 'models' / 'higgs-v3'
    destination.mkdir(parents=True, exist_ok=True)
    for name in manifest['files']:
        item = entries[name]
        size = item['size']
        lfs = item.get('lfs')
        expected = lfs['oid'] if lfs else item['oid']
        target = destination / name

        # Git stores small files as blobs; LFS records the raw file's SHA-256.
        def verified(path):
            if not path.is_file() or path.stat().st_size != size:
                return False
            digest = hashlib.sha256() if lfs else hashlib.sha1()
            if not lfs:
                digest.update(f'blob {size}\0'.encode())
            with path.open('rb') as source:
                for chunk in iter(lambda: source.read(8 * 1024 * 1024), b''):
                    digest.update(chunk)
            return digest.hexdigest() == expected

        if verified(target):
            print(f'Verified {name}', flush=True)
            continue
        temporary = target.with_name(name + '.part')
        print(f'Downloading {name} ({size:,} bytes)', flush=True)
        with urllib.request.urlopen(urllib.request.Request(f'{base}/{name}', headers=headers), timeout=120) as response:
            with temporary.open('wb') as output:
                shutil.copyfileobj(response, output, 8 * 1024 * 1024)
        if not verified(temporary):
            raise RuntimeError(f'Content verification failed for {name}; existing model was preserved')
        temporary.replace(target)
    print('Model download verified. Existing voices and configuration were preserved.')


if __name__ == '__main__':
    download_model(Path(__file__).resolve().parent)

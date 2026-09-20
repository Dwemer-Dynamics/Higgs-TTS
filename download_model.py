#!/usr/bin/env python3
"""Download the pinned upstream model, verifying size and Git/LFS content hashes."""
import hashlib
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import urllib.request


def download_model(root, variant):
    manifest = json.loads((root / 'runtime.json').read_text())
    repo, revision = manifest['model'], manifest['revision']
    base = f'https://huggingface.co/{repo}/resolve/{revision}'
    api = f'https://huggingface.co/api/models/{repo}/tree/{revision}'
    headers = {'User-Agent': 'Dwemer-Higgs-TTS/1'}
    if os.environ.get('HF_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['HF_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(api, headers=headers), timeout=60) as response:
        entries = {item['path']: item for item in json.load(response)}
    if variant == 'q8':
        q8 = manifest['q8']
        base = f"https://huggingface.co/{q8['model']}/resolve/{q8['revision']}"
        name = q8['file']
        entries[name] = {'size': q8['size'], 'lfs': {'oid': q8['sha256']}}
        # Keep the upstream license with either model without downloading full weights.
        files = ['LICENSE', name]
    else:
        files = manifest['files']
    destination = root / 'models' / ('higgs-v3-q8' if variant == 'q8' else 'higgs-v3')
    destination.mkdir(parents=True, exist_ok=True)
    for name in files:
        item = entries[name]
        size = item['size']
        lfs = item.get('lfs')
        expected = lfs['oid'] if lfs else item['oid']
        target = destination / Path(name).name

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
        temporary = target.with_name(target.name + '.part')
        print(f'Downloading {name} ({size:,} bytes)', flush=True)
        file_base = f'https://huggingface.co/{repo}/resolve/{revision}' if name == 'LICENSE' else base
        with urllib.request.urlopen(urllib.request.Request(f'{file_base}/{name}', headers=headers), timeout=120) as response:
            with temporary.open('wb') as output:
                shutil.copyfileobj(response, output, 8 * 1024 * 1024)
        if not verified(temporary):
            raise RuntimeError(f'Content verification failed for {name}; existing model was preserved')
        temporary.replace(target)
    print('Model download verified. Existing voices and configuration were preserved.')
    return destination / Path(manifest['q8']['file']).name if variant == 'q8' else destination


def select_model(root, selection):
    """Resolve interactive selection before any build or download changes."""
    if selection != 'ask':
        return selection
    print('Higgs TTS 3 model selection\n1) Higgs — Full\n   Full-precision model. Highest memory usage.\n2) Higgs — Compact (Q8)\n   Smaller model. Lower memory usage.\n   Download: about 5.1 GB. This is not its VRAM requirement.', file=sys.stderr)
    if (root / 'server.json').exists():
        config = json.loads((root / 'server.json').read_text())
        model = next(m for m in config['models'] if m['id'] == 'higgs-v3')
        print(f"Current model: {model['path']}\nEnter) Keep current model", file=sys.stderr)
    else:
        print('Enter) Higgs — Full (default)', file=sys.stderr)
    print('0) Cancel\nSelect: ', end='', file=sys.stderr, flush=True)
    answer = sys.stdin.readline()
    if not answer or answer.strip() == '0':
        raise SystemExit('Model selection cancelled.')
    choices = {'': 'keep', '1': 'full', '2': 'q8'}
    if answer.strip() not in choices:
        raise SystemExit('Invalid model selection; no changes made.')
    return choices[answer.strip()]


def setup_model(root, selection):
    """Verify selected weights before atomically changing only the Higgs model path."""
    config_path = root / 'server.json'
    exists = config_path.exists()
    config = json.loads((config_path if exists else root / 'server.example.json').read_text())
    matches = [m for m in config['models'] if m['id'] == 'higgs-v3']
    if len(matches) != 1 or matches[0].get('family') != 'higgs_audio_tts':
        raise ValueError('Expected exactly one Higgs model in server.json; configuration was preserved')
    model = matches[0]
    variant = selection
    if selection == 'keep':
        current = (root / model['path']).resolve()
        manifest = json.loads((root / 'runtime.json').read_text())
        q8_path = root / 'models/higgs-v3-q8' / Path(manifest['q8']['file']).name
        if exists and current not in ((root / 'models/higgs-v3').resolve(), q8_path.resolve()):
            print('Keeping custom model path and existing configuration.')
            return
        variant = 'q8' if current == q8_path.resolve() else 'full'
    target = download_model(root, variant)
    if exists and selection == 'keep':
        return
    model['path'] = str(target)
    if not exists:
        config['voice_dir'] = str(root / 'voices')
    temporary = config_path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(config, indent=2) + '\n')
    temporary.replace(config_path)
    label = 'Higgs — Compact (Q8)' if variant == 'q8' else 'Higgs — Full'
    print(f'Model selected: {label}. Port, voices and other settings retained.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('variant', nargs='?', choices=['keep', 'full', 'q8', 'ask'], default='keep')
    parser.add_argument('--select', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    selection = select_model(root, args.variant)
    if args.select:
        print(selection)
    else:
        setup_model(root, selection)

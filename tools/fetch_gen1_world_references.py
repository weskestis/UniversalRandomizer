#!/usr/bin/env python3
"""Fetch and hash-check pinned, public source references used by Gen 1 tests."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / 'tools/gen1_world_references.json').read_text())

def fetch(row):
    target = ROOT / 'dist/world-source-audit' / row['repository'].replace('/', '-') / row['path']
    url = f"https://raw.githubusercontent.com/{row['repository']}/{row['revision']}/{row['path']}"
    data = target.read_bytes() if target.exists() else urllib.request.urlopen(url, timeout=40).read()
    assert hashlib.sha256(data).hexdigest() == row['sha256'], url
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    if row.get('baseline'):
        dest = ROOT / 'dist/baseline/randomizer-1.6.5.lua'
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    return target

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        result = list(pool.map(fetch, SPEC['sources']))
    print(f'Verified {len(result)} pinned source files')

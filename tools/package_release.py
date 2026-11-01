#!/usr/bin/env python3
"""Build the metadata-only launcher update from the verified 1.3.41 asset."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def verify(archive):
    assert archive.testzip() is None, 'ZIP integrity failure'
    names = archive.namelist()
    assert len(names) == len(set(names)), 'Duplicate archive paths'
    manifest = json.loads(archive.read('manifest.json'))
    pack = json.loads(archive.read('.modkit/pack.json'))
    paths = [entry['path'] for entry in pack['files']]
    assert len(paths) == len(set(paths)), 'Duplicate pack paths'
    assert set(paths) == set(names) - {'.modkit/pack.json'}
    for entry in pack['files']:
        data = archive.read(entry['path'])
        assert len(data) == entry['bytes'], entry['path']
        assert sha256(data) == entry['sha256'], entry['path']
    for key in ('id', 'version', 'api'):
        assert manifest[key] == pack[key], key
    assert manifest['game_version'] == pack['engine_range']
    return manifest, pack

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    release = json.loads((ROOT / 'release.json').read_text())
    manifest_bytes = (ROOT / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    assert manifest['version'] == release['version'] == '1.3.42'
    assert manifest['game_version'] == '>=0.2.18 <1.0.0'
    assert manifest['github'] == 'weskestis/UniversalRandomizer'
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.source or args.output / 'source-1.3.41.zip'
    if args.source is None:
        request = urllib.request.Request(release['source_url'], headers={'User-Agent': 'UniversalRandomizer-release'})
        with urllib.request.urlopen(request, timeout=90) as response:
            source.write_bytes(response.read())
    assert sha256(source.read_bytes()) == release['source_sha256'], 'Unexpected source archive'
    output = args.output / f"{manifest['id']}-{manifest['version']}.zip"
    with zipfile.ZipFile(source) as original:
        original_manifest, pack = verify(original)
        expected_manifest = dict(original_manifest, version=manifest['version'])
        assert manifest == expected_manifest, 'Only the package version may change'
        pack['version'] = manifest['version']
        pack['engine_range'] = manifest['game_version']
        pack['packed_at'] = release['packed_at']
        entry = next(x for x in pack['files'] if x['path'] == 'manifest.json')
        entry.update(bytes=len(manifest_bytes), sha256=sha256(manifest_bytes))
        replacement = {
            'manifest.json': manifest_bytes,
            '.modkit/pack.json': (json.dumps(pack, indent=2) + '\n').encode(),
        }
        with zipfile.ZipFile(output, 'w') as updated:
            updated.comment = original.comment
            for info in original.infolist():
                updated.writestr(copy.copy(info), replacement.get(info.filename, original.read(info.filename)))
        with zipfile.ZipFile(output) as updated:
            verify(updated)
            assert original.namelist() == updated.namelist()
            changed = [n for n in original.namelist() if original.read(n) != updated.read(n)]
            assert set(changed) == {'manifest.json', '.modkit/pack.json'}, changed
            unchanged = len(updated.namelist()) - len(changed)
    digest = sha256(output.read_bytes())
    if release.get('asset_sha256'):
        assert digest == release['asset_sha256'], 'Build differs from the locally verified ZIP'
    if release.get('asset_size'):
        assert output.stat().st_size == release['asset_size']
    (args.output / 'SHA256SUMS.txt').write_text(f'{digest}  {output.name}\n')
    notes = (ROOT / 'RELEASE-NOTES-1.3.42.md').read_text()
    (args.output / 'release-notes.md').write_text(notes + f'\nSHA-256: `{digest}`\n')
    result = {'version': manifest['version'], 'asset': output.name, 'sha256': digest,
              'bytes': output.stat().st_size, 'hashes_verified': len(pack['files']),
              'unchanged_entries': unchanged, 'changed_entries': changed}
    (args.output / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Build a native-content-only mod from pinned core helpers and reviewed sources."""
import argparse
import copy
import hashlib
import json
import shutil
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE_FILES = {'core.lua', 'adapters.lua'}

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
    assert manifest['version'] == release['version']
    assert manifest['game_version'] == '>=0.2.18 <1.0.0'
    assert manifest['github'] == 'weskestis/UniversalRandomizer'
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.source or args.output / 'source-1.3.42.zip'
    if args.source is None:
        request = urllib.request.Request(release['source_url'], headers={'User-Agent': 'UniversalRandomizer-release'})
        with urllib.request.urlopen(request, timeout=90) as response:
            source.write_bytes(response.read())
    assert sha256(source.read_bytes()) == release['source_sha256'], 'Unexpected source archive'
    output = args.output / f"{manifest['id']}-{manifest['version']}.zip"
    with zipfile.ZipFile(source) as original:
        original_manifest, pack = verify(original)
        assert original_manifest['id'] == manifest['id']
        assert original_manifest['version'] == '1.3.42'
        pack['version'] = manifest['version']
        pack['engine_range'] = manifest['game_version']
        pack['packed_at'] = release['packed_at']
        replacement = {p.relative_to(ROOT / 'mod').as_posix(): p.read_bytes()
                       for p in sorted((ROOT / 'mod').rglob('*')) if p.is_file()}
        replacement['manifest.json'] = manifest_bytes
        replacement['README.md'] = (ROOT / 'README.md').read_bytes()
        notes_name = f"RELEASE-NOTES-{manifest['version']}.md"
        replacement[notes_name] = (ROOT / notes_name).read_bytes()
        # Nothing else from the old release is implicitly inherited. In
        # particular its expanded content, art and ruleset installer are gone.
        assert all(not p.startswith('expanded493/') and p != 'rulesets.lua' for p in replacement)
        entries = {entry['path']: entry for entry in pack['files'] if entry['path'] in BASE_FILES}
        assert set(entries) == BASE_FILES
        for name, data in replacement.items():
            assert not name.startswith('/') and '..' not in Path(name).parts
            entries[name] = dict(path=name, bytes=len(data), sha256=sha256(data))
        pack['files'] = [entries[name] for name in sorted(entries)]
        replacement['.modkit/pack.json'] = (json.dumps(pack, indent=2) + '\n').encode()
        with zipfile.ZipFile(output, 'w') as updated:
            updated.comment = original.comment
            for info in original.infolist():
                if info.filename not in BASE_FILES and info.filename not in replacement:
                    continue
                updated.writestr(copy.copy(info), replacement.get(info.filename, original.read(info.filename)))
            for name in sorted(set(replacement) - set(original.namelist())):
                info = zipfile.ZipInfo(name, (2026, 11, 1, 15, 47, 24))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                updated.writestr(info, replacement[name])
        with zipfile.ZipFile(output) as updated:
            verify(updated)
            assert set(updated.namelist()) == BASE_FILES | set(replacement)
            retained = set(original.namelist()) & set(updated.namelist())
            removed = sorted(set(original.namelist()) - set(updated.namelist()))
            changed = [n for n in sorted(retained) if original.read(n) != updated.read(n)]
            assert set(changed) <= set(replacement), changed
            unchanged = len(retained) - len(changed)
            for name, data in replacement.items():
                assert updated.read(name) == data, name
            extracted = args.output / 'mod'
            assert extracted.resolve() != (ROOT / 'mod').resolve(), 'Output would overwrite reviewed sources'
            if extracted.exists():
                shutil.rmtree(extracted)
            updated.extractall(extracted)
    digest = sha256(output.read_bytes())
    if release.get('asset_sha256'):
        assert digest == release['asset_sha256'], 'Build differs from the locally verified ZIP'
    if release.get('asset_size'):
        assert output.stat().st_size == release['asset_size']
    (args.output / 'SHA256SUMS.txt').write_text(f'{digest}  {output.name}\n')
    notes = (ROOT / f"RELEASE-NOTES-{manifest['version']}.md").read_text()
    (args.output / 'release-notes.md').write_text(notes + f'\nSHA-256: `{digest}`\n')
    result = {'version': manifest['version'], 'asset': output.name, 'sha256': digest,
              'bytes': output.stat().st_size, 'hashes_verified': len(pack['files']),
              'unchanged_entries': unchanged, 'changed_entries': changed,
              'removed_entries': len(removed)}
    (args.output / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()

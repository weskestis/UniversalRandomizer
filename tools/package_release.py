#!/usr/bin/env python3
"""Repackage the verified 1.8 release without changing any gameplay files."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify(archive):
    assert archive.testzip() is None, 'ZIP integrity failure'
    names = archive.namelist()
    assert len(names) == len(set(names)), 'Duplicate archive paths'
    manifest = json.loads(archive.read('manifest.json'))
    pack = json.loads(archive.read('.modkit/pack.json'))
    assert {e['path'] for e in pack['files']} == set(names) - {'.modkit/pack.json'}
    assert len(pack['files']) == len(names) - 1
    for entry in pack['files']:
        data = archive.read(entry['path'])
        assert len(data) == entry['bytes'], entry['path']
        assert digest(data) == entry['sha256'], entry['path']
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
    assert release['payload_version'] == '1.8.0'
    assert release['source_sha256'] == 'b89d71f11e827309be7d726585405b38eb2cdf20557296c2f872cf4559c7557b'
    args.output.mkdir(parents=True, exist_ok=True)
    source = args.source or args.output / 'original-1.8.0.zip'
    if args.source is None:
        request = urllib.request.Request(release['source_url'], headers={'User-Agent': 'UniversalRandomizer-rollback'})
        source.write_bytes(urllib.request.urlopen(request, timeout=90).read())
    assert digest(source.read_bytes()) == release['source_sha256'], 'Wrong rollback archive'
    manifest_bytes = (ROOT / 'manifest.json').read_bytes()
    manifest = json.loads(manifest_bytes)
    assert manifest['version'] == release['version'] == '1.11.1'
    output = args.output / ('universal_randomizer-' + release['version'] + '.zip')
    metadata = {'manifest.json', '.modkit/pack.json'}
    with zipfile.ZipFile(source) as original:
        old_manifest, pack = verify(original)
        assert old_manifest['version'] == '1.8.0'
        expected = dict(old_manifest, version=release['version'])
        assert manifest == expected, 'Only the launcher version may change'
        pack['version'] = release['version']
        pack['packed_at'] = release['packed_at']
        for entry in pack['files']:
            if entry['path'] == 'manifest.json':
                entry['bytes'] = len(manifest_bytes)
                entry['sha256'] = digest(manifest_bytes)
        replacement = {'manifest.json': manifest_bytes,
                       '.modkit/pack.json': (json.dumps(pack, indent=2) + '\n').encode()}
        # The restored source tree must also match the released runtime.
        if (ROOT / 'mod').exists():
            sources = {p.relative_to(ROOT / 'mod').as_posix(): p.read_bytes()
                       for p in (ROOT / 'mod').rglob('*') if p.is_file()}
            assert set(sources) == {p for p in original.namelist() if p.endswith('.lua')} - {'core.lua', 'adapters.lua'}
            for name, data in sources.items():
                assert data == original.read(name), 'Newer code remains: ' + name
        with zipfile.ZipFile(output, 'w') as updated:
            updated.comment = original.comment
            for info in original.infolist():
                updated.writestr(copy.copy(info), replacement.get(info.filename, original.read(info.filename)))
        with zipfile.ZipFile(output) as updated:
            verify(updated)
            assert updated.namelist() == original.namelist(), 'Rollback added or removed payload files'
            for name in original.namelist():
                if name not in metadata:
                    assert updated.read(name) == original.read(name), 'Gameplay/content changed: ' + name
    sha = digest(output.read_bytes())
    if release.get('asset_sha256'):
        assert sha == release['asset_sha256'], 'Non-reproducible rollback ZIP'
        assert output.stat().st_size == release['asset_size']
    (args.output / 'SHA256SUMS.txt').write_text(sha + '  ' + output.name + '\n')
    (args.output / 'release-notes.md').write_text((ROOT / 'ROLLBACK-1.8.md').read_text() + '\nSHA-256: `' + sha + '`\n')
    result = dict(version=release['version'], gameplay='1.8.0', sha256=sha,
                  bytes=output.stat().st_size, unchanged_payload_files=len(original.namelist()) - 2)
    (args.output / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()

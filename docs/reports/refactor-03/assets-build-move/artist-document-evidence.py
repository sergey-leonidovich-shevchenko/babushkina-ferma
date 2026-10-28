"""Связывает red/green с прежним source SHA и неизменным Git-документом комплекта."""
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def main():
    source = ROOT / 'tools/build/artist_packet.py'
    previous = source.read_text().replace(
        '# Эти две инструкции закреплены комплектом; их живые CLI развиваются отдельно.\n'
        "HISTORICAL_DOCUMENTS = frozenset({'docs/SPRITE_STANDARD.md', 'docs/VISUAL_RESOURCE_FORMAT.md'})",
        '# Этот текст — версия инструкции в принятом комплекте; живой CLI развивается отдельно.\n'
        "HISTORICAL_DOCUMENTS = frozenset({'docs/SPRITE_STANDARD.md'})").encode()
    first = json.loads((REPORT / 'profile.json').read_text())
    expected = next(r['sha256'] for r in first['physical_sources'] if r['target'] == 'tools/build/artist_packet.py')
    assert digest(previous) == expected
    (REPORT / 'artist-before-document-fix.py.gz').write_bytes(gzip.compress(previous, mtime=0))
    manifest_path = 'docs/reports/visual-overhaul/vrelease-005/references.json'
    manifest = json.loads((ROOT / manifest_path).read_text())
    row = next(r for r in manifest['references'] if r['file'] == 'docs/VISUAL_RESOURCE_FORMAT.md')
    old = subprocess.check_output(['git', '-C', str(ROOT), 'show',
        manifest['source_commit'] + ':' + row['file']], env=git_environment())
    assert digest(old) == row['sha256']
    assert (ROOT / manifest_path).read_bytes() == subprocess.check_output(
        ['git', '-C', str(ROOT), 'show', first['base'] + ':' + manifest_path], env=git_environment())
    assert 'Ran 16 tests' in (REPORT / 'artist-red-01.txt').read_text()
    assert 'FAILED (failures=4)' in (REPORT / 'artist-red-01.txt').read_text()
    assert 'Ran 16 tests' in (REPORT / 'artist-green-01.txt').read_text()
    assert (REPORT / 'artist-green-01.txt').read_text().rstrip().endswith('OK')
    result = {'previous_source_reconstructed_and_verified_against_first_profile': expected,
        'current_source_sha256': digest(source.read_bytes()),
        'test_source_sha256': digest((ROOT / 'tools/build/test_artist_packet.py').read_bytes()),
        'manifest_unchanged': True, 'source_commit': manifest['source_commit'], 'reference': row,
        'red': {'exit': 1, 'tests': 16, 'failures': 4}, 'green': {'exit': 0, 'tests': 16, 'failures': 0}}
    with (REPORT / 'artist-document-fix.json').open('x') as file:
        file.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'red_tests': 16, 'green_tests': 16, 'manifest_unchanged': True}))


if __name__ == '__main__':
    main()

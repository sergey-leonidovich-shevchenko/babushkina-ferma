"""Store92 exact Godot stdout files losslessly; never trim raw bytes or alter code/test results."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


freeze = json.loads((REPORT / 'source-freeze.json').read_text())
assert all(sha((ROOT / name).read_bytes()) == expected for name, expected in freeze['source_SHA256'].items())
failed = subprocess.run(['git', '-C', str(ROOT), 'diff', '--cached', '--check'], env=git_environment(), capture_output=True, text=True)
assert failed.returncode == 2
lines = failed.stdout.splitlines()
assert len(lines) == 92 and all('world-core-move/' in line and '-gd-' in line and line.endswith('new blank line at EOF.') for line in lines)
(REPORT / 'stage-whitespace-attempt01.txt').write_text(failed.stdout)
backup = REPORT / 'baseline' / 'before-gd-raw-storage'
assert not backup.exists()
backup.mkdir()
for path in sorted(REPORT.glob('browser-*')):
    path.rename(backup / path.name)
for name in ['catalog.json', 'checks.json', 'before-profile.json', 'after-profile.json', 'before-GD.json', 'after-GD.json']:
    path = REPORT / name
    (backup / (name + '.gz')).write_bytes(gzip.compress(path.read_bytes(), mtime=0))
    if name in {'catalog.json', 'checks.json'}:
        path.unlink()
storage = []
for phase in ['before', 'after']:
    path = REPORT / (phase + '-profile.json')
    profile = json.loads(path.read_text())
    assert len(profile['GD_parse']) == 46
    for row in profile['GD_parse']:
        logical = row['log']
        raw_path = REPORT / logical
        raw = raw_path.read_bytes()
        assert sha(raw) == row['raw_SHA256'] and raw.endswith(b'\n\n')
        stored = logical + '.gz'
        target = REPORT / stored
        assert not target.exists()
        compressed = gzip.compress(raw, mtime=0)
        assert gzip.decompress(compressed) == raw
        target.write_bytes(compressed)
        row.update(log=stored, original_log=logical, storage='gzip', stored_SHA256=sha(compressed))
        storage.append({'logical_raw': logical, 'stored_file': stored, 'raw_SHA256': sha(raw),
                        'stored_SHA256': sha(compressed), 'raw_bytes': len(raw), 'stored_bytes': len(compressed)})
        raw_path.unlink()
    profile['raw_GD_storage'] = 'gzip; exact decompressed bytes, no whitespace normalization'
    path.write_text(json.dumps(profile, indent=2) + '\n')
    (REPORT / (phase + '-GD.json')).write_text(json.dumps(profile['GD_parse'], indent=2) + '\n')
assert len(storage) == 92
(REPORT / 'gd-raw-storage.json').write_text(json.dumps({'raw_files': 92, 'source_SHA_unchanged': True,
    'raw_bytes_changed': False, 'raw_SHA256_unchanged': True, 'whitespace_policy_exemptions_added': 0,
    'before_profiles_and_browser_retained': str(backup.relative_to(REPORT)), 'files': storage}, indent=2) + '\n')
with (REPORT / 'README.md').open('a') as stream:
    stream.write('\nСырой stdout92 compile-only Godot запусков содержал штатную пустую строку в конце. '
        'Первый staged whitespace отказ сохранён. [Контейнеры raw](gd-raw-storage.json) — lossless gzip: '
        'побайтная распаковка и прежние raw SHA проверены, строки не обрезались, исключения whitespace не добавлялись. '
        'Профили сохраняют raw SHA и добавляют явный stored SHA/format. Прежние JSON, каталог и браузерные кадры '
        'сохранены в baseline; после смены report attachment выполняются свежие Wiki check/catalog/browser. '
        'Все167 source SHA и полные architecture/Game результаты прежние.\n')
shutil.copyfile(__file__, REPORT / 'gd-raw-storage.py')
print(json.dumps({'lossless_raw_files': 92, 'source_SHA_unchanged': True,
                  'new_Wiki_export_required': True, 'whitespace_exemptions': 0}))

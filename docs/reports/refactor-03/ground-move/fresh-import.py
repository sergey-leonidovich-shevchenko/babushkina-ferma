"""Fresh owned-QA editor import after the physical move; primary cache and userdata are untouched."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
cache = Q / '.godot'
saved = Path('/private/tmp/refactor03-owned-godot-cache-before379')
assert not saved.exists()
assert not subprocess.check_output(['git', '-C', str(Q), 'ls-files', '--', '.godot'], env=git_environment()).strip()
if cache.exists() or cache.is_symlink():
    shutil.move(str(cache), saved)
log = R / 'fresh-editor-engine.txt'
argv = [os.environ['FARM_GODOT_BIN'], '--headless', '--editor', '--path', str(Q), '--quit', '--log-file', str(log)]
result = subprocess.run(argv, cwd=Q, env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'),
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
record = {'argv': argv, 'exit': result.returncode, 'own_cache_saved': str(saved),
    'primary_cache_untouched': True, 'native_frames': 0, 'FPS_admission': False, 'logs': []}
for name, raw in [('fresh-editor-stdout.txt', result.stdout), ('fresh-editor-engine.txt', log.read_bytes() if log.exists() else b'')]:
    stored = gzip.compress(raw, mtime=0)
    (R / (name + '.gz')).write_bytes(stored)
    record['logs'].append({'path': name + '.gz', 'storage': 'gzip',
        'raw_SHA256': hashlib.sha256(raw).hexdigest(), 'stored_SHA256': hashlib.sha256(stored).hexdigest()})
if log.exists():
    log.unlink()
(R / 'fresh-editor.json').write_text(json.dumps(record, indent=2) + '\n')
assert result.returncode == 0 and not any(token in result.stdout.decode() for token in ['SCRIPT ERROR', 'Parse Error', 'ERROR:']), result.stdout.decode()[-3500:]
print(json.dumps({'fresh_editor_exit': 0, 'cache_saved': str(saved), 'native_frames': 0}))

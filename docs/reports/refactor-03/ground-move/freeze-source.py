"""Freeze source only when profile, layout and documentation are complete and before full gates."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
scope = json.loads((R / 'scope.json').read_text())
assert not scope['docs_not_yet_finalized']
names = scope['source_paths_after']
removed = scope['removed_paths']
assert len(removed) == 113
actual = set(filter(None, subprocess.check_output(['git', '-C', str(Q), 'diff', '--no-renames',
    '--name-only', '-z'], env=git_environment()).decode().split('\0')))
actual.update(filter(None, subprocess.check_output(['git', '-C', str(Q), 'ls-files', '--others',
    '--exclude-standard', '-z'], env=git_environment()).decode().split('\0')))
prefix = str(R.relative_to(Q)) + '/'
assert all(n in names or n in removed or n.startswith(prefix) for n in actual), sorted(actual - set(names) - set(removed))
assert all(not (Q / n).exists() for n in removed)
assert all((Q / n).is_file() for n in names)
before = subprocess.check_output(['git', '-C', str(Q), 'show', scope['base'] + ':docs/epics/refactoring-2026-10/TASKS.md'], env=git_environment())
after = (Q / 'docs/epics/refactoring-2026-10/TASKS.md').read_bytes()
def outer(raw):
    a, b = raw.index(b'## REFACTOR-03 '), raw.index(b'## REFACTOR-04 ')
    return raw[:a], raw[b:]
assert outer(before) == outer(after)
rows = {n: hashlib.sha256((Q / n).read_bytes()).hexdigest() for n in names}
record = {'version': '0.0.379', 'base': scope['base'], 'source_SHA256': rows,
    'removed_source_paths': removed, 'root_sources': 82, 'map': 380,
    'all_before_full_gates': True, 'other_cards_unchanged': True}
(R / 'source-freeze.json').write_text(json.dumps(record, indent=2, ensure_ascii=False) + '\n')
for source, target in [
    ('/private/tmp/refactor03-ground-profile379.py', 'profile.py'),
    ('/private/tmp/refactor03-ground-audit379.py', 'audit.py'),
    ('/private/tmp/refactor03-ground-fresh-import379.py', 'fresh-import.py'),
    ('/private/tmp/refactor03-ground-baseline379.py', 'baseline/write-baseline.py'),
    ('/private/tmp/refactor03-ground-freeze379.py', 'freeze-source.py'),
]:
    shutil.copy2(source, R / target)
print(json.dumps({'source_paths_sealed': len(rows), 'removed_paths': len(removed), 'root': 82, 'map': 380,
    'foreign_and_frozen_scope_preserved': True}))

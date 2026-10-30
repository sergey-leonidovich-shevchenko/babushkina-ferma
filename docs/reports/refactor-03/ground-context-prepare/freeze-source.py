"""Freeze the final candidate source while full gates run; reports remain append-only owned output."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
names = list(filter(None, git('diff', '--name-only', '-z').decode().split('\0'))) + [
    'tools/qa/ground/__init__.py', 'tools/qa/ground/test_ground_context.py']
assert len(names) == len(set(names))
assert not any(n.startswith(('scripts/', 'assets/', 'tests/')) or n.endswith('.uid') for n in names)
assert not any(n.startswith('docs/reports/') for n in names)
rows = {n: hashlib.sha256((Q / n).read_bytes()).hexdigest() for n in names}
(R / 'candidate-source.json').write_text(json.dumps(rows, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'source_paths': len(rows), 'runtime_scripts_assets_tests_changed': False,
    'existing_report_changes': 0, 'UID_changes': 0}))

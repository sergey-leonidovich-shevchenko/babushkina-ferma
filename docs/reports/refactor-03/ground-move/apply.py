"""Apply only the sealed Ground map and explicit source consumers after baseline passes."""
import ast
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
from tools.planning.bump_version import sync_files
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
plan = json.loads((R / 'baseline/move-plan.json').read_text())
baseline = json.loads((R / 'baseline/inventory.json').read_text())
before_profile = json.loads((R / 'before-profile.json').read_text())
assert len(before_profile['commands']) == 22 and len(before_profile['GD']) == 55
assert all(r['exit'] == 0 for r in before_profile['commands'] + before_profile['GD'])
assert git('rev-parse', 'HEAD').decode().strip() == plan['base']
assert not git('diff', '--name-only').strip()
mapping = {r['old_path']: r['target'] for r in plan['moves']}
for name, row in baseline['sources'].items():
    p = Q / name
    assert sha(p.read_bytes()) == row['sha256'] and stat.S_IMODE(p.stat().st_mode) == row['mode'], name
for target in mapping.values():
    assert not (Q / target).exists(), target
for name, row in plan['changes'].items():
    assert sha((Q / name).read_bytes()) == row['before_SHA256'], name
    (Q / name).write_text(row['after'])
for old, target in mapping.items():
    (Q / target).parent.mkdir(parents=True, exist_ok=True)
    (Q / old).rename(Q / target)
    assert not (Q / old).exists()
    assert stat.S_IMODE((Q / target).stat().st_mode) == baseline['sources'][old]['mode']

new_test = (R / 'baseline/test_ground_layout.py').read_text()
module_names = {Path(n).stem for n in mapping if n.endswith('.py')}
imports = 0
def canonical_import(match):
    global imports
    module, alias = match.groups()
    if module not in module_names:
        return match.group(0)
    imports += 1
    return 'from tools.qa.ground import ' + module + ' as ' + alias
new_test = re.sub(r'^import (\w+) as (\w+)$', canonical_import, new_test, flags=re.M)
assert imports == 19
test_path = Q / 'tools/qa/ground/test_ground_layout.py'
assert not test_path.exists()
test_path.write_text(new_test)
old_methods = {n.name: ast.dump(n, include_attributes=False) for n in ast.walk(ast.parse((R / 'baseline/test_ground_layout.py').read_text())) if isinstance(n, ast.FunctionDef)}
new_methods = {n.name: ast.dump(n, include_attributes=False) for n in ast.walk(ast.parse(new_test)) if isinstance(n, ast.FunctionDef)}
assert old_methods == new_methods

p = Q / '.gitignore'
text = p.read_text()
anchor = '!tools/qa/ground/*.py\n'
assert text.count(anchor) == 1
UID = sorted(target for target in mapping.values() if target.endswith('.uid'))
assert len(UID) == 42
text = text.replace(anchor, anchor + '!tools/qa/ground/*.gd\n' + ''.join('!' + n + '\n' for n in UID))
p.write_text(text)
p = Q / 'tools/quality/check_architecture.sh'
text = p.read_text()
for old, target in mapping.items():
    if old.endswith('.py'):
        module = target.removeprefix('tools/').removesuffix('.py').replace('/', '.')
        text = text.replace('python3 ' + old, 'python3 tools/run.py ' + module)
anchor = 'python3 tools/run.py qa.ground.test_ground_context\n'
assert text.count(anchor) == 1
text = text.replace(anchor, anchor + 'python3 tools/run.py qa.ground.test_ground_layout\n')
p.write_text(text)
sync_files('0.0.379')
after_paths = set(mapping.values()) | {mapping.get(n, n) for n in plan['changes']} | {
    '.gitignore', 'tools/quality/check_architecture.sh', 'tools/qa/ground/test_ground_layout.py',
    'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist'}
assert len(after_paths) == 136
record = {'base': plan['base'], 'version': '0.0.379', 'source_paths_after': sorted(after_paths),
    'removed_paths': sorted(mapping), 'physical_source_moves': 71, 'UID_moves': 42,
    'root_after': sum(p.is_file() and p.suffix in {'.py', '.gd', '.sh', '.swift'} for p in (Q / 'tools').iterdir()),
    'new_layout_imports': imports, 'new_layout_methods_AST_equal': True,
    'code_before_SHA256': sha((R / 'baseline/test_ground_layout.py').read_bytes()),
    'code_after_SHA256': sha(test_path.read_bytes()), 'docs_not_yet_finalized': True}
assert record['root_after'] == 82
(R / 'scope-initial.json').write_text(json.dumps(record, indent=2, ensure_ascii=False) + '\n')
shutil.copy2(__file__, R / 'apply.py')
print(json.dumps({'physical_source_moves': 71, 'tracked_UID': 42, 'root': 82, 'map': 380,
    'source_paths_before_docs': len(after_paths), 'new_test_methods_preserved': True}))

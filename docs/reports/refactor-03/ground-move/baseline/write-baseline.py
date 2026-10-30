"""Save accepted378 byte/mode inventory and the prospective move before mutating product source."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys
Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P = Path('/Users/sergeyshevchenko/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
BASE = 'c1cdd9f5842eaf2286be38bd8f95d18767d03c11'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def write(name, data):
    (R / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
assert git(Q, 'rev-parse', 'HEAD').decode().strip() == BASE == git(P, 'rev-parse', 'HEAD').decode().strip()
assert not git(Q, 'status', '--porcelain').strip()
assert not R.exists()
(R / 'baseline').mkdir(parents=True)
plan = json.loads(Path('/private/tmp/refactor03-ground-plan379.json').read_text())
assert plan['base'] == BASE and not plan['unused_candidates']
paths = set(plan['changes']) | {r['old_path'] for r in plan['moves']}
inventory = {}
for name in sorted(paths):
    p = Q / name
    original = git(Q, 'show', BASE + ':' + name)
    assert p.read_bytes() == original, name
    index = git(Q, 'ls-files', '-s', '--', name).decode().split()
    inventory[name] = {'sha256': sha(original), 'bytes': len(original), 'mode': stat.S_IMODE(p.stat().st_mode),
        'Git_mode': index[0], 'blob': index[1]}
for row in plan['moves']:
    assert not (Q / row['target']).exists(), row['target']
UID = {str(p.relative_to(Q)): {'sha256': sha(p.read_bytes()), 'mode': stat.S_IMODE(p.stat().st_mode)}
    for p in (Q / 'tools').rglob('*.uid') if p.is_file()}
assert len(UID) == 302
foreign = ['docs/backlog/README.md', 'docs/epics/refactoring-2026-10/TASKS.md', 'wiki/planning/sources.json']
primary = {n: {'working': sha((P / n).read_bytes()), 'index': sha(git(P, 'show', ':' + n))} for n in foreign}
write('baseline/inventory.json', {'base': BASE, 'sources': inventory, 'all_tools_UID': UID, 'primary_foreign': primary})
for source, target in [
    ('/private/tmp/refactor03-ground-plan379.json', 'baseline/move-plan.json'),
    ('/private/tmp/refactor03-ground-plan379.py', 'baseline/plan.py'),
    ('/private/tmp/refactor03-ground-plan379-before-test-import-cleanup.json', 'baseline/plan-before-test-import-cleanup.json'),
    ('/private/tmp/refactor03-ground-following-census.json', 'baseline/census.json'),
    ('/private/tmp/refactor03-test-ground-layout379.py', 'baseline/test_ground_layout.py'),
    ('/private/tmp/refactor03-ground-layout379-red.txt', 'baseline/layout-red.txt'),
    ('/private/tmp/refactor03-test-ground-layout379-descriptor-attempt00.py', 'baseline/layout-descriptor-attempt00.py'),
    ('/private/tmp/refactor03-ground-layout379-descriptor-attempt00.txt', 'baseline/layout-descriptor-attempt00.txt'),
]:
    shutil.copy2(source, R / target)
write('baseline/layout-red.json', {'base': BASE, 'tests': 22, 'failures': 4, 'errors': 20,
    'subtests_included': True, 'test_SHA256': sha((R / 'baseline/test_ground_layout.py').read_bytes()),
    'raw_SHA256': sha((R / 'baseline/layout-red.txt').read_bytes()), 'native_frames': 0,
    'descriptor_attempt00': 'fixture used absent old_path field; corrected to authoritative dictionary key before meaningful red replay'})
write('PLAN.json', {'task': 'REFACTOR-03', 'phase': 'Ground physical move', 'version': '0.0.379', 'base': BASE,
    'parent_review': 5704521872, 'parent_CI_success': 8, 'Team_intermediate_accepted': True,
    'physical_source_moves': 71, 'Python': 29, 'GD': 42, 'tracked_UID_moves': 42, 'ignored_UID_moves': 0,
    'root_before': 153, 'root_after': 82, 'map_before': 267, 'map_after': 380,
    'history_resolver_sites': 19, 'current_resolver_sites': 19,
    'before_after_CLI': 22, 'before_after_GD_checks': 55, 'new_layout_cases': 22,
    'source_contract_fields': 37, 'source_contract_modules': 21, 'all_tools_UID': 302,
    'P3': 'Path in Ground test and sys in modified performance test; audit includes all changed/new/moved tools tests',
    'full03_done': False, 'native_frames_new': 0, 'FPS_admission': False})
print(json.dumps({'base': BASE, 'source_inventory': len(inventory), 'UID': len(UID), 'new_layout_cases': 22,
    'red_failures': 4, 'red_errors': 20, 'product_mutations': 0}))

"""Freeze accepted376, World-core assignments and real before controls before any product mutation."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

QA = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
PRIMARY = Path('/Users/sergeyshevchenko/my farm')
REPORT = QA / 'docs/reports/refactor-03/world-core-move'
BASE = '7a2d7a5917bede86b3ffa850b1d5c83e9e8cc0bd'
sys.path.insert(0, str(QA))
from tools.common.git import git_environment


def git(root, *arguments):
    return subprocess.check_output(['git', '--no-replace-objects', '-C', str(root), *arguments], env=git_environment())


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


assert not REPORT.exists()
assert git(QA, 'rev-parse', 'HEAD').decode().strip() == BASE == git(PRIMARY, 'rev-parse', 'HEAD').decode().strip()
assert not git(QA, 'status', '--porcelain').strip()
plan = json.loads(Path('/private/tmp/refactor03-world-plan377.json').read_text())
assert plan['base'] == BASE and plan['external_controls_added'] and not plan['parent_review_pending']
producer = json.loads(Path('/private/tmp/refactor03-world-producer14-before377.json').read_text())
history = json.loads(Path('/private/tmp/refactor03-world-history13-before377.json').read_text())
assert producer['base'] == history['base'] == BASE
assert producer['exit'] == 0 and producer['methods'] == 14 and producer['non_import_AST_equal']
assert history['exit'] == 1 and history['methods'] == 13 and history['non_import_AST_equal']
assert 'FAILED (errors=1)' in Path('/private/tmp/refactor03-world-history13-before377.txt').read_text()
ci = json.loads(Path('/private/tmp/refactor03-ci376-final.json').read_text())
assert ci['headRevision'] == BASE and len(ci['checks']) == 8 and all(row['conclusion'] == 'success' for row in ci['checks'])
consumers = ['.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
             'tools/quality/check_architecture.sh', 'TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md',
             'tools/README.md', 'wiki/articles/project-refactoring.md', 'docs/epics/refactoring-2026-10/TASKS.md']
names = set(plan['changes']) | {row['old_path'] for row in plan['moves']} | set(consumers)
baseline = REPORT / 'baseline'
baseline.mkdir(parents=True)
sources = {}
for name in sorted(names):
    path = QA / name
    raw = path.read_bytes()
    assert raw == git(QA, 'show', BASE + ':' + name), name
    sources[name] = {'sha256': sha(raw), 'mode': path.stat().st_mode & 0o777}
    (baseline / (name.replace('/', '--') + '.gz')).write_bytes(gzip.compress(raw, mtime=0))
for row in plan['moves']:
    assert not (QA / row['target']).exists(), row['target']
for row in plan['local_UID']:
    assert sha((QA / row['old_path']).read_bytes()) == row['sha256'] and not (QA / row['target']).exists()
prior = json.loads((QA / 'docs/reports/refactor-03/world-inputs-prepare/baseline/inventory.json').read_text())
uids = prior['author_UID_exact']
assert len(uids) == 85
tracked = set(filter(None, git(QA, 'ls-files', '-z').decode().split('\0')))
for row in uids:
    path = QA / row['path']
    assert row['path'] not in tracked and sha(path.read_bytes()) == row['sha256'] and path.stat().st_mode & 0o777 == row['mode']
    assert git(QA, 'check-ignore', '--', row['path']).strip()
anchors = {}
for name in ['tools/visual_camera_points.gd', 'tools/visual_camera_points.gd.uid', 'tools/encode_coordinate_video.swift',
             'tools/render_order_game.gd', 'tools/render_order_game.gd.uid', 'tools/water_audit.gd',
             'tools/shore_kit.py', 'tools/test_shore_kit.py', 'tools/shore_kit_canvas.gd',
             'tools/shore_kit_capture.gd', 'tools/shore_kit_review.gd']:
    path = QA / name
    anchors[name] = {'sha256': sha(path.read_bytes()), 'mode': path.stat().st_mode & 0o777}
for source, target in [
    ('refactor03-world-plan377.json', 'baseline/move-plan.json'),
    ('refactor03-ci376-final.json', 'baseline/ci376-final.json'),
    ('refactor03-reviews376.json', 'baseline/reviews376.json'),
    ('refactor03-test-world-producer14-before377.py', 'baseline/producer14-before.py'),
    ('refactor03-test-world-history13-before377.py', 'baseline/history13-before.py'),
    ('refactor03-world-producer14-before377.txt', 'producers-before.txt'),
    ('refactor03-world-producer14-before377.json', 'producers-before.json'),
    ('refactor03-world-history13-before377.txt', 'history-red.txt'),
    ('refactor03-world-history13-before377.json', 'history-red.json'),
    ('refactor03-world-shore376-readonly.md', 'baseline/deferred-shore-analysis.md'),
    ('refactor03-world-plan377-before-ast-optimization.py.gz', 'baseline/planner-before-ast-optimization.py.gz'),
    ('refactor03-world-plan377-before-P3.py.gz', 'baseline/plan-before-P3.py.gz'),
    ('refactor03-world-plan377-before-P3.json.gz', 'baseline/plan-before-P3.json.gz'),
]:
    shutil.copyfile(Path('/private/tmp') / source, REPORT / target)
inventory = {'base': BASE, 'version': '0.0.376', 'root_before': 245, 'root_after': 153,
             'sources': sources, 'consumers': consumers, 'moves': plan['moves'],
             'local_UID': plan['local_UID'], 'author_UID_exact': uids,
             'deferred_shared_anchors': anchors, 'source_review': 5695222063,
             'Team_intermediate_accepted': True, 'CI376_success': 8,
             'producer_methods': 14, 'history_methods': 13, 'history_red_errors': 1,
             'physical_source_moves': 92, 'tracked_UID_moves': 42, 'ignored_UID_moves': 2,
             'full03_accepted': False}
(baseline / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n')
foreign = ['docs/backlog/README.md', 'docs/epics/refactoring-2026-10/TASKS.md', 'wiki/planning/sources.json']
Path('/private/tmp/refactor03-before377-primary.json').write_text(json.dumps({
    'base': BASE, 'own_before': {name: sha((PRIMARY / name).read_bytes()) for name in sources},
    'foreign': {name: {'working': sha((PRIMARY / name).read_bytes()), 'index': sha(git(PRIMARY, 'show', ':' + name))} for name in foreign},
}, indent=2) + '\n')
shutil.copyfile(__file__, REPORT / 'baseline.py')
shutil.copyfile('/private/tmp/refactor03-world-plan377.py', REPORT / 'plan.py')
shutil.copyfile('/private/tmp/refactor03-world-tests377.py', REPORT / 'prepare-extra-tests.py')
shutil.copyfile('/private/tmp/refactor03-world-before-tests377.py', REPORT / 'before-extra-tests.py')
print(json.dumps({'baseline_sources': len(sources), 'source_moves': 92, 'tracked_UID': 42,
                  'ignored_UID': 2, 'root_after': 153, 'product_mutated': False}))

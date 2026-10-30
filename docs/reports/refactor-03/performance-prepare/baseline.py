"""Freeze the accepted369 state before performance source-root/Git preparation."""
import gzip
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
PRIMARY = Path('/Users/sergeyshevchenko/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/performance-prepare'
BASE = 'c6f323d821455bfcfb025a03ae18f00e8cbe0f05'


def git(root, *arguments):
    """Read the explicit checkout; the caller has no foreign GIT overrides here."""
    return subprocess.check_output(['git', '-C', str(root), *arguments])


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


assert git(ROOT, 'status', '--porcelain') == b''
assert git(ROOT, 'rev-parse', 'HEAD').decode().strip() == BASE
assert git(PRIMARY, 'rev-parse', 'HEAD').decode().strip() == BASE
assert not REPORT.exists()
plan = json.loads(Path('/private/tmp/refactor03-performance-prepare-plan370.json').read_text())
assert plan['base'] == BASE and not plan['applied']
consumers = [
    '.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
    'tools/quality/check_architecture.sh', 'TESTING.md', 'QA_CHECKLIST.md',
    'docs/DEVELOPMENT.md', 'tools/README.md', 'wiki/articles/project-refactoring.md',
    'docs/epics/refactoring-2026-10/TASKS.md',
]
baseline = REPORT / 'baseline'
baseline.mkdir(parents=True)
sources = {}
for name in [*plan['changes'], *consumers]:
    source = ROOT / name
    raw = source.read_bytes()
    assert raw == git(ROOT, 'show', BASE + ':' + name), name
    sources[name] = {'sha256': digest(raw), 'mode': source.stat().st_mode & 0o777}
    (baseline / (name.replace('/', '--') + '.gz')).write_bytes(gzip.compress(raw, mtime=0))
test = Path('/private/tmp/refactor03-test-performance-context370.py')
red = Path('/private/tmp/refactor03-performance-context-final-before369.txt')
red_metadata = json.loads(Path('/private/tmp/refactor03-performance-context-before369.json').read_text())
assert digest(test.read_bytes()) == red_metadata['test_sha256']
assert digest(red.read_bytes()) == red_metadata['raw_sha256']
assert red_metadata['base'] == BASE and red_metadata['exit'] == 1
assert 'Ran 5 tests' in red.read_text() and 'FAILED (failures=4, errors=1)' in red.read_text()
shutil.copyfile(test, baseline / 'performance-context-test.py')
shutil.copyfile(red, REPORT / 'context-red.txt')
(REPORT / 'context-red.json').write_text(json.dumps(red_metadata, indent=2) + '\n')
shutil.copyfile('/private/tmp/refactor03-performance-prepare-plan370.json', baseline / 'adaptation-plan.json')
shutil.copyfile(__file__, REPORT / 'baseline.py')
inventory = {
    'base': BASE, 'version': '0.0.369', 'root_sources': 314,
    'preparation_source_paths': list(plan['changes']), 'consumers': consumers,
    'sources': sources, 'new_tests': 5, 'source_root_sites': 8, 'Git_read_sites': 8,
    'shell_roots': 2, 'source_review': 5690215352, 'Team_intermediate_accepted': True,
    'CI369_success': 8, 'physical_moves': 0, 'UID_moves': 0,
}
(baseline / 'inventory.json').write_text(json.dumps(inventory, ensure_ascii=False, indent=2) + '\n')
foreign = ['docs/backlog/README.md', 'docs/epics/refactoring-2026-10/TASKS.md', 'wiki/planning/sources.json']
lease = {
    'base': BASE,
    'own_before': {name: digest((PRIMARY / name).read_bytes()) for name in sources},
    'foreign': {name: {
        'working': digest((PRIMARY / name).read_bytes()),
        'index': digest(git(PRIMARY, 'show', ':' + name)),
    } for name in foreign},
}
Path('/private/tmp/refactor03-before370-primary.json').write_text(json.dumps(lease, indent=2) + '\n')
print(json.dumps({'owned_before': len(sources), 'source_files_prepared': 12,
    'red': '5 cases, 4 failures/1 error', 'root_stays': 314, 'physical_moves': 0}))

"""Seal only completed local evidence; a seal is not independent review or CI approval."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
from PIL import Image

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
BASE = 'c47b78add8813392769be8b9d5dfba9b8d5fa1d5'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def load(name):
    return json.loads((R / name).read_text())
assert git('rev-parse', 'HEAD').decode().strip() == BASE
sources = load('candidate-source.json')
assert len(sources) == 31
for n, expected in sources.items():
    assert sha((Q / n).read_bytes()) == expected, n
for row in load('source-edits.json')['documentation']:
    assert row['after_sha256'] == sources[row['path']]
names = set(filter(None, git('diff', '--name-only', '-z').decode().split('\0')))
assert names == set(sources) - {'tools/qa/ground/__init__.py', 'tools/qa/ground/test_ground_context.py'}
assert not any(n.startswith(('scripts/', 'assets/', 'tests/', 'docs/reports/')) or n.endswith('.uid') for n in names)
before = git('show', BASE + ':docs/epics/refactoring-2026-10/TASKS.md')
after = (Q / 'docs/epics/refactoring-2026-10/TASKS.md').read_bytes()
def split_card(raw):
    a, b = raw.index(b'## REFACTOR-03 '), raw.index(b'## REFACTOR-04 ')
    return raw[:a], raw[b:]
assert split_card(before) == split_card(after)
for n in ['tools/assets/contracts/source_paths.py', 'tools/qa/art/current_paths.py',
          'tools/qa/world/source_inputs.py', 'AGENTS.md']:
    assert (Q / n).read_bytes() == git('show', BASE + ':' + n), n
for n in ['tools/qa/ground/__init__.py', 'tools/qa/ground/test_ground_context.py']:
    assert subprocess.run(['git', 'check-ignore', '-q', '--', n], cwd=Q, env=git_environment()).returncode == 1
assert subprocess.run(['git', 'check-ignore', '-q', '--', 'tools/qa/ground/__pycache__/owned.pyc'], cwd=Q, env=git_environment()).returncode == 0
oldtest = (R / 'baseline/test_ground_context.py').read_bytes()
assert oldtest == (Q / 'tools/qa/ground/test_ground_context.py').read_bytes()
assert sha(oldtest) == load('baseline/context-red.json')['test_SHA256']
assert sha((R / 'baseline/context-red.txt').read_bytes()) == load('baseline/context-red.json')['raw_sha256']
assert 'Ran 10 tests' in (R / 'context-green.txt').read_text() and (R / 'context-green.txt').read_text().rstrip().endswith('OK')
assert load('source-contract-audit.json')['fields'] == 37
UID_before = load('baseline/UID-before-Game.json')
UID_after = {str(p.relative_to(Q)): {'sha256': sha(p.read_bytes()), 'mode': stat.S_IMODE(p.stat().st_mode)}
    for p in (Q / 'tools').rglob('*.uid') if p.is_file()}
assert UID_before == UID_after
assert sum(p.is_file() and p.suffix in {'.py', '.gd', '.sh', '.swift'} for p in (Q / 'tools').iterdir()) == 153
producers = [json.loads(p.read_text()) for p in sorted((R / 'producer-probes').glob('*.json'))]
assert len(producers) == 9 and all(p['all_current_Git_archived_bytes_equal'] and
    p['partial_provenance_rejected'] and p['native_frames'] == 0 for p in producers)
gates = load('gates-02/gate-exits.json')
assert [r['gate'] for r in gates] == ['architecture', 'game', 'wiki']
assert all(r['exit'] == 0 and r['version'] == '0.0.378' for r in gates)
architecture = (R / 'gates-02/architecture.txt').read_text()
counts = [int(n) for n in re.findall(r'^Ran (\d+) tests? in ', architecture, re.M)]
assert len(counts) == 102 and sum(counts) == 1349, (len(counts), sum(counts))
game = (R / 'gates-02/game.txt').read_text()
assert 'TESTS: 53502 passed, 0 failed' in game
assert game.count('REDRAW: 90 passed, 0 failed') == 2
wiki = (R / 'gates-02/wiki.txt').read_text()
assert 'ℹ pass 145' in wiki and 'ℹ fail 0' in wiki
catalog = load('catalog.json')
assert catalog['version'] == '0.0.378' and catalog['source_public_dist_equal']
assert catalog['states']['03'] == 'in_progress' and not catalog['VMAP_accepted']
browser = load('browser-article.json')
assert browser['version'] == 'Игра 0.0.378' and browser['ground_context_preparation_present']
assert browser['dimensions'] == {'scrollWidth': 1280, 'width': 1280}
assert load('browser-mobile.json')['dimensions'] == {'scrollWidth': 390, 'width': 390}
cleanup = load('browser-cleanup.json')
assert cleanup['own_tab_closed'] and cleanup['viewport_reset'] and cleanup['own_server_exit'] == 143
for label, size in [('desktop', (1280, 900)), ('mobile', (390, 844))]:
    assert Image.open(R / ('browser-' + label + '.png')).size == size
for source, target in [
    ('/private/tmp/refactor03-prepare378.py', 'prepare.py'),
    ('/private/tmp/refactor03-audit378.py', 'audit.py'),
    ('/private/tmp/refactor03-docs378.py', 'write-docs.py'),
    ('/private/tmp/refactor03-source-freeze378.py', 'freeze-source.py'),
    ('/private/tmp/refactor03-catalog378.mjs', 'check-catalog.mjs'),
    ('/private/tmp/refactor03-seal378.py', 'seal.py'),
    ('/private/tmp/refactor03-publish378.py', 'publish.py'),
]:
    shutil.copy2(source, R / target)
files = [{'path': str(p.relative_to(R)), 'sha256': sha(p.read_bytes()), 'bytes': p.stat().st_size}
         for p in sorted(R.rglob('*')) if p.is_file() and p.name != 'checks.json']
checks = {'task': 'REFACTOR-03', 'phase': 'Ground context preparation', 'version': '0.0.378',
    'base': BASE, 'parent_review': 5697669336, 'parent_CI_success': 8,
    'full03_done': False, 'Task_Complete': False, 'main_changed': False,
    'physical_moves': 0, 'root_sources': 153, 'current_map': 267,
    'cleaned_Git_calls': 28, 'Git_modules': 18, 'new_real_archive_cases': 10,
    'parent_errors': 9, 'current_errors': 0, 'test_source_equal': True,
    'additional_actual_producer_profiles': 9, 'partial_producer_proofs_rejected': 9,
    'source_contract_fields': 37, 'source_contract_modules': 21,
    'unused_import_audit_modules': 19, 'live_current_targets': 32,
    'architecture_suites': len(counts), 'architecture_cases': sum(counts),
    'Game_passed': 53502, 'Game_failed': 0, 'normal_F10_passed_each': 90,
    'Wiki_passed': 145, 'Wiki_failed': 0, 'native_frames': 0, 'FPS_admission': False,
    'source_SHA256': sources, 'report_files': files,
    'independent_review': 'required for exact published head', 'current_CI': 'not yet published',
    'review_scope': 'full local Git and exact incremental commit; PR file-list API is truncated',
    'other_cards_and_frozen_reports_unchanged': True, 'all_tools_UID_bytes_mode_preserved': len(UID_before),
    'source_snapshot_timing': '30 paths fixed throughout; article JSON-link finalized during architecture before Wiki build; separate final documentation recheck and amendment retained'}
(R / 'checks.json').write_text(json.dumps(checks, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({k: checks[k] for k in ['version', 'architecture_suites', 'architecture_cases', 'Game_passed', 'Wiki_passed']}))

"""Seal completed379 source/evidence; independent exact-head review and CI remain external requirements."""
import gzip
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
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def load(name):
    return json.loads((R / name).read_text())
freeze = load('source-freeze.json')
plan = load('baseline/move-plan.json')
baseline = load('baseline/inventory.json')
scope = load('scope.json')
assert git('rev-parse', 'HEAD').decode().strip() == freeze['base'] == plan['base']
sources = freeze['source_SHA256']
assert len(sources) == 146
assert all(sha((Q / n).read_bytes()) == h for n, h in sources.items())
removed = freeze['removed_source_paths']
assert len(removed) == 113 and all(not (Q / n).exists() for n in removed)
changed = set(filter(None, git('diff', '--no-renames', '--name-only', '-z').decode().split('\0')))
changed.update(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
assert all(n in sources or n in removed or n.startswith(str(R.relative_to(Q)) + '/') for n in changed)
mapping = {r['old_path']: r['target'] for r in plan['moves']}
UID = {str(p.relative_to(Q)): {'sha256': sha(p.read_bytes()), 'mode': stat.S_IMODE(p.stat().st_mode)}
    for p in (Q / 'tools').rglob('*.uid') if p.is_file()}
old_UID = {mapping.get(n, n): row for n, row in baseline['all_tools_UID'].items()}
assert all(UID[n] == row for n, row in old_UID.items())
assert sorted(set(UID) - set(old_UID)) == ['tools/qa/ground/compiled_sources.gd.uid', 'tools/qa/ground/compiled_sources_review.gd.uid']
assert len(UID) == 304
assert sum(p.is_file() and p.suffix in {'.py', '.gd', '.sh', '.swift'} for p in (Q / 'tools').iterdir()) == 82
for name in ['tools/qa/art/current_paths.py', 'tools/qa/world/source_inputs.py', 'AGENTS.md']:
    assert (Q / name).read_bytes() == git('show', freeze['base'] + ':' + name), name
before_card = git('show', freeze['base'] + ':docs/epics/refactoring-2026-10/TASKS.md')
after_card = (Q / 'docs/epics/refactoring-2026-10/TASKS.md').read_bytes()
def outer(raw):
    a, b = raw.index(b'## REFACTOR-03 '), raw.index(b'## REFACTOR-04 ')
    return raw[:a], raw[b:]
assert outer(before_card) == outer(after_card)
for name in sources:
    if name.startswith('tools/qa/ground/'):
        assert subprocess.run(['git', 'check-ignore', '-q', '--', name], cwd=Q, env=git_environment()).returncode == 1, name
assert subprocess.run(['git', 'check-ignore', '-q', '--', 'tools/qa/ground/__pycache__/owned.pyc'], cwd=Q, env=git_environment()).returncode == 0

audited = load('unused-import-audit.json')
assert audited['modules'] == 35 and audited['test_modules'] == 15 and not audited['unused_candidates']
assert load('source-contract-audit.json')['fields'] == 37
layout = load('new-layout-test-audit.json')
assert layout['test_cases'] == 22 and layout['methods_equal_after_explicit_fixture_guard_normalization']
assert not layout['source_SHA_equal'] and layout['test_methods_removed'] == 0
assert layout['after_SHA256'] == sha((Q / 'tools/qa/ground/test_ground_layout.py').read_bytes())
red = load('baseline/layout-red.json')
assert red['errors'] == 19 and red['failures'] == 4 and red['positive_controls'] == 1
assert red['test_SHA256'] == sha((R / 'baseline/test_ground_layout.py').read_bytes())
assert red['raw_SHA256'] == sha((R / 'baseline/layout-red.txt').read_bytes())
assert 'FAILED (failures=9)' in (R / 'layout-green-attempt01.txt').read_text()
assert 'Ran 22 tests' in (R / 'layout-green-attempt02.txt').read_text()
assert (R / 'layout-green-attempt02.txt').read_text().rstrip().endswith('OK')
for label in ['before', 'after']:
    profile = load(label + '-profile.json')
    assert len(profile['commands']) == 22 and len(profile['GD']) == 55 and profile['unit_cases'] == 127
    assert all(r['exit'] == 0 and sha((R / r['log']).read_bytes()) == r['SHA256'] for r in profile['commands'])
    for row in profile['GD']:
        assert row['exit'] == 0
        raw = (R / row['log']).read_bytes()
        assert sha(raw) == row['stored_SHA256'] and sha(gzip.decompress(raw)) == row['raw_SHA256']
        raw = (R / row['engine_log']).read_bytes()
        assert sha(raw) == row['engine_stored_SHA256'] and sha(gzip.decompress(raw)) == row['engine_raw_SHA256']
    assert profile['foreign_bytes_preserved'] and profile['native_frames'] == 0 and not profile['FPS_admission']
assert load('after-profile.json')['historical_stdout_byte_equal'] == 10
assert load('fresh-editor.json')['exit'] == 0
ci = load('baseline/ci378-final.json')
assert ci['headRevision'] == freeze['base'] and len(ci['checks']) == 8 and all(r['conclusion'] == 'success' for r in ci['checks'])
assert any(freeze['base'] in r['body'] and 'SOURCE PASS' in r['body'] for r in load('baseline/reviews378.json'))

gates = load('gates-03/gate-exits.json')
assert [r['gate'] for r in gates] == ['architecture', 'game', 'wiki']
assert all(r['exit'] == 0 and r['version'] == '0.0.379' for r in gates)
architecture = (R / 'gates-03/architecture.txt').read_text()
counts = [int(n) for n in re.findall(r'^Ran (\d+) tests? in ', architecture, re.M)]
assert len(counts) == 104 and sum(counts) == 1373, (len(counts), sum(counts))
game = (R / 'gates-03/game.txt').read_text()
assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
wiki = (R / 'gates-03/wiki.txt').read_text()
assert 'ℹ pass 145' in wiki and 'ℹ fail 0' in wiki
bridge = load('source-bridge-checks.json')
assert bridge['tests'] == 2 and bridge['provenance_checks'] == 101 and bridge['fresh_checks'] == 36
assert len(bridge['runtime_resources']) == 9 and all(r['unchanged'] for r in bridge['runtime_resources'])
assert len(bridge['targeted_compiles']) == 10 and all(r['exit'] == 0 for r in bridge['targeted_compiles'])
assert all(sha((Q / r['source']).read_bytes()) == r['source_SHA256'] for r in bridge['targeted_compiles'])
sandbox_failure = load('gates-02/gate-exits.json')
assert len(sandbox_failure) == 1 and sandbox_failure[0]['exit'] == 1
assert 'process inventory unavailable' in (R / 'gates-02/architecture.txt').read_text()
assert '\nOK\n' in (R / 'source-bridge-world-permitted.txt').read_text()
failed = load('gates-01/gate-exits.json')
assert [r['exit'] for r in failed] == [0, 1]
old_game = gzip.decompress((R / 'gates-01/game.txt.gz').read_bytes())
assert 'TESTS: 53477 passed, 25 failed' in old_game.decode()
transcode = load('raw-log-transcoding.json')
assert sha(old_game) == transcode['raw_SHA256'] and not transcode['raw_bytes_changed']
assert sha((R / 'gates-01/game.txt.gz').read_bytes()) == transcode['stored_SHA256']
catalog = load('catalog.json')
assert load('catalog-final.json') == catalog
assert catalog['version'] == '0.0.379' and catalog['root_sources'] == 82 and catalog['map'] == 380
assert catalog['source_public_dist_equal'] and catalog['profile_attachment_equal'] and not catalog['VMAP_accepted']
browser = load('browser-article.json')
assert browser['version'] == 'Игра 0.0.379' and browser['Ground379_present'] and browser['current_root82']
assert browser['dimensions'] == {'scrollWidth': 1280, 'width': 1280}
assert load('browser-mobile.json')['dimensions'] == {'scrollWidth': 390, 'width': 390}
assert load('browser-task.json')['status_in_progress']
cleanup = load('browser-cleanup.json')
assert cleanup['own_tab_closed'] and cleanup['viewport_reset'] and cleanup['own_server_exit'] == 143
for label, size in [('desktop', (1280, 900)), ('mobile', (390, 844))]:
    assert Image.open(R / ('browser-' + label + '.png')).size == size

for source, target in [
    ('/private/tmp/refactor03-ground-audit379.py', 'audit.py'),
    ('/private/tmp/refactor03-ground-docs379.py', 'write-docs.py'),
    ('/private/tmp/refactor03-ground-catalog379.mjs', 'check-catalog.mjs'),
    ('/private/tmp/refactor03-ground-seal379.py', 'seal.py'),
    ('/private/tmp/refactor03-publish379.py', 'publish.py'),
]:
    shutil.copy2(source, R / target)
files = [{'path': str(p.relative_to(R)), 'sha256': sha(p.read_bytes()), 'bytes': p.stat().st_size}
    for p in sorted(R.rglob('*')) if p.is_file() and p.name != 'checks.json']
checks = {'task': 'REFACTOR-03', 'phase': 'Ground physical move', 'version': '0.0.379', 'base': freeze['base'],
    'parent_review': 5704521872, 'parent_CI_success': 8, 'physical_source_moves': 71, 'tracked_UID_moves': 42,
    'ignored_UID_moves': 0, 'root_before': 153, 'root_sources': 82, 'map_before': 267, 'map': 380,
    'source_SHA256': sources, 'removed_source_paths': removed, 'all_tools_UID_bytes_mode_preserved': 302,
    'new_QA_UID': 2, 'all_tools_UID': 304, 'source_bridge_provenance_checks': 101,
    'source_bridge_fresh_checks': 36, 'gate01_failure_retained': 25, 'authoritative_gates': 'gates-03',
    'profile_CLI_each': 22, 'profile_unit_cases_each': 127, 'GD_checks_each': 55, 'historical_stdout_equal': 10,
    'new_layout_cases': 22, 'new_layout_parent_failures_subtests': 4, 'new_layout_parent_errors': 19,
    'new_layout_parent_positive_controls': 1, 'new_layout_after': 22, 'first_after_failures': 9,
    'test_source_SHA_equal': False, 'fixture_guard_repair_explicit': True,
    'expanded_import_audit_modules': 35, 'tools_test_modules_included': 15, 'frozen_contract_fields': 37,
    'architecture_suites': 104, 'architecture_cases': 1373, 'Game_passed': 53502, 'Game_failed': 0,
    'normal_F10_passed_each': 90, 'Wiki_passed': 145, 'native_frames_new': 0, 'FPS_admission': False,
    'full03_done': False, 'Task_Complete': False, 'main_changed': False,
    'current_review_CI': 'required for published exact head; parent does not substitute',
    'other_cards_frozen_reports_and_runtime_scripts_unchanged': True, 'report_files': files}
(R / 'checks.json').write_text(json.dumps(checks, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'source_paths': len(sources), 'removed': len(removed), 'report_files': len(files) + 1,
    'architecture': [104, 1373], 'Game': 53502, 'Wiki': 145, 'root': 82, 'map': 380}))

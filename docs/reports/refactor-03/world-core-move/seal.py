"""Seal the World-core increment only after its own full gates, frozen sources and browser checks."""
import hashlib
import gzip
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*arguments):
    return subprocess.check_output(['git', '--no-replace-objects', '-C', str(ROOT), *arguments], env=git_environment())


scope = json.loads((REPORT / 'scope.json').read_text())
baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
plan = json.loads((REPORT / 'baseline/move-plan.json').read_text())
freeze = json.loads((REPORT / 'source-freeze.json').read_text())
current = {name: sha(ROOT / name) for name in scope['source_paths_after']}
assert current == freeze['source_SHA256'] and len(current) == 167 and freeze['version'] == '0.0.377'
assert git('rev-parse', 'HEAD').decode().strip() == scope['base'] == '7a2d7a5917bede86b3ffa850b1d5c83e9e8cc0bd'
changed = set(filter(None, git('diff', '--no-renames', scope['base'], '--name-only', '-z').decode().split('\0')))
changed.update(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
assert all(name in current or name in scope['removed_source_paths'] or name.startswith(str(REPORT.relative_to(ROOT)) + '/') for name in changed)
tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
local = {row['old_path']: row['target'] for row in plan['local_UID']}
for row in baseline['author_UID_exact']:
    name = local.get(row['path'], row['path'])
    path = ROOT / name
    assert sha(path) == row['sha256'] and path.stat().st_mode & 0o777 == row['mode']
    assert name not in tracked and git('check-ignore', '--', name).strip()
assert len(baseline['author_UID_exact']) == 85
for name, row in baseline['deferred_shared_anchors'].items():
    assert sha(ROOT / name) == row['sha256'] and (ROOT / name).stat().st_mode & 0o777 == row['mode']
gates = json.loads((REPORT / 'gates-01/gate-exits.json').read_text())
assert [row['gate'] for row in gates] == ['architecture', 'game', 'wiki']
assert all(row['exit'] == 0 and row['version'] == '0.0.377' for row in gates)
architecture = (REPORT / 'gates-01/architecture.txt').read_text()
cases = list(map(int, re.findall(r'Ran (\d+) tests? in', architecture)))
assert len(cases) == 101 and sum(cases) == 1339, (len(cases), sum(cases))
game = (REPORT / 'gates-01/game.txt').read_text()
assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
wiki = (REPORT / 'gates-01/wiki.txt').read_text()
assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
ci = json.loads((REPORT / 'baseline/ci376-final.json').read_text())
assert ci['headRevision'] == scope['base'] and len(ci['checks']) == 8 and all(row['conclusion'] == 'success' for row in ci['checks'])
reviews = json.loads((REPORT / 'baseline/reviews376.json').read_text())
assert any(scope['base'] in row['body'] and 'SOURCE PASS' in row['body'] for row in reviews)
assert any(scope['base'] in row['body'] and 'CI CONFIRMED' in row['body'] for row in reviews)
before = json.loads((REPORT / 'before-profile.json').read_text())
after = json.loads((REPORT / 'after-profile.json').read_text())
for profile in [before, after]:
    assert len(profile['commands']) == 38 and len(profile['GD_parse']) == 46
    assert all(row['exit'] == 0 and sha(REPORT / row['log']) == row['sha256'] for row in profile['commands'])
    assert all(row['exit'] == 0 and row['storage'] == 'gzip'
               and sha(REPORT / row['log']) == row['stored_SHA256']
               and hashlib.sha256(gzip.decompress((REPORT / row['log']).read_bytes())).hexdigest() == row['raw_SHA256']
               for row in profile['GD_parse'])
    assert profile['foreign_Git_index_config_unchanged'] and profile['native_sessions'] == 0 and not profile['Game_new'] and not profile['GPU_FPS_admission']
    writer = profile['actual_owned_Water_writer']
    assert writer['owned_raw_mirror'] and writer['diagnostic_old_repeats'] == 48 and not writer['Game_new']
    assert all(sha(REPORT / row['file']) == row['sha256'] for row in writer['outputs'].values())
assert after['historical_stdout_byte_equal'] == 22 and after['owned_water_outputs_byte_equal'] == 2
storage = json.loads((REPORT / 'gd-raw-storage.json').read_text())
assert storage['raw_files'] == 92 and not storage['raw_bytes_changed'] and storage['source_SHA_unchanged']
wiki_storage = json.loads((REPORT / 'gates-01/wiki-storage.json').read_text())
assert wiki_storage['exit'] == 0 and wiki_storage['version'] == '0.0.377'
assert re.search(r'[ℹ#] pass 145\b', (REPORT / 'gates-01/wiki-storage.txt').read_text())
regression = json.loads((REPORT / 'regression.json').read_text())
assert [row['methods'] for row in regression['commands']] == [16, 14, 13, 19]
assert [row['label'] for row in regression['commands']] == ['helper-green', 'producers-after', 'history-green-attempt02', 'context-after']
for row in regression['commands']:
    assert row['exit'] == 0 and sha(REPORT / (row['label'] + '.txt')) == row['raw_sha256']
assert 'FAILED (errors=1)' in (REPORT / 'history-red.txt').read_text()
assert 'FAILED (errors=1)' in (REPORT / 'history-green.txt').read_text()
repair = json.loads((REPORT / 'water-fixture-address-repair.json').read_text())
assert repair['current_fixture_input_sites'] == 1 and repair['test_methods_assertions_removed'] == 0 and not repair['product_algorithms_changed']
assert repair['after_SHA256'] == sha(ROOT / 'tools/qa/world/test_world_source_history.py')
catalog = json.loads((REPORT / 'catalog.json').read_text())
article = json.loads((REPORT / 'browser-article.json').read_text())
assert article['current_world_core'] and article['current_root153'] and not article['stale_stop']
assert article['profile_href'] == catalog['profile_href']
mobile = json.loads((REPORT / 'browser-mobile.json').read_text())
assert mobile['dimensions'] == {'width': 390, 'scrollWidth': 390}
task = json.loads((REPORT / 'browser-task.json').read_text())
assert task['in_progress'] and task['current_world_core'] and not task['stale_stop']
cleanup = json.loads((REPORT / 'browser-cleanup.json').read_text())
assert cleanup['own_tab_closed'] and cleanup['own_server_stop_confirmed'] and cleanup['viewport_reset']
shutil.copyfile(__file__, REPORT / 'seal.py')
result = {'task': 'REFACTOR-03', 'phase': 'World-core physical move', 'version': '0.0.377',
          'base': scope['base'], 'prior_source_review': 5695222063, 'prior_Team_intermediate_accepted': True,
          'prior_CI_success': 8, 'root_sources': 153, 'physical_moves': 92, 'tracked_UID_moves': 42,
          'ignored_UID_moves': 2, 'current_source_map': 267, 'future_history_aliases': 141,
          'architecture_suites': 101, 'architecture_cases': 1339, 'game_passed': 53502, 'game_failed': 0,
          'redraw_each_passed': 90, 'wiki_passed': 145, 'authoritative_gates': gates,
          'functions_AST_checked': 569, 'normalized_address_sites': 38, 'historical_fields_preserved': 37,
          'author_UID_exact': 85, 'actual_profile_CLI_each': 38, 'old_negative_suites': 16,
          'old_negative_cases': 213, 'actual_GD_parse_each': 46, 'historical_stdout_byte_equal': 22,
          'owned_water_outputs_byte_equal': 2, 'regression': regression, 'P3_unused_imports_fixed': True,
          'native_Game_GPU_FPS_admission_from_profile': False, 'full_task03_accepted': False,
          'Task_Complete_added': False, 'source_SHA256': current,
          'removed_source_paths': scope['removed_source_paths'],
          'report_files': [{'path': str(path.relative_to(REPORT)), 'sha256': sha(path), 'bytes': path.stat().st_size}
                           for path in sorted(REPORT.rglob('*')) if path.is_file() and path.name != 'checks.json' and '__pycache__' not in path.parts]}
(REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'version': '0.0.377', 'source_paths': len(current), 'removed': len(scope['removed_source_paths']),
                  'report_files': len(result['report_files']), 'full_gates': '101/1339,Game53502,redraw90x2,Wiki145'}))

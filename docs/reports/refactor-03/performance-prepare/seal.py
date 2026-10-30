"""Seal exact370 code and actual evidence without granting full03 or FPS acceptance."""
import hashlib
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(parent for parent in REPORT.parents if (parent / 'project.godot').is_file())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    scope = json.loads((REPORT / 'scope.json').read_text())
    freeze = json.loads((REPORT / 'source-freeze.json').read_text())
    current = {name: digest(ROOT / name) for name in scope['source_paths_after']}
    assert freeze['source_SHA256'] == current and freeze['version'] == '0.0.370'
    gates = json.loads((REPORT / 'gates-01/gate-exits.json').read_text())
    assert [row['gate'] for row in gates] == ['architecture', 'game', 'wiki']
    assert all(row['exit'] == 0 and row['version'] == '0.0.370' for row in gates)
    architecture = (REPORT / 'gates-01/architecture.txt').read_text()
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', architecture)))
    assert len(cases) == 93 and sum(cases) == 1245, (len(cases), sum(cases))
    game = (REPORT / 'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game
    assert game.count('REDRAW: 90 passed, 0 failed') == 2
    wiki = (REPORT / 'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    raw_ci = json.loads((REPORT / 'baseline/ci369-final.json').read_text())
    ci = json.loads(next(row['text'] for row in raw_ci['content'] if row['type'] == 'text'))
    assert ci['headRevision'] == scope['base'] and len(ci['checks']) == 8
    assert all(row['conclusion'] == 'success' for row in ci['checks'])
    reviews = json.loads((REPORT / 'baseline/reviews369.json').read_text())
    assert any(scope['base'] in row['body'] and 'SOURCE REVIEW PASS' in row['body'] for row in reviews)
    before = json.loads((REPORT / 'before-profile.json').read_text())
    after = json.loads((REPORT / 'after-profile.json').read_text())
    assert before['outputs'] == after['outputs'] and after['actual_before_after_equal']
    assert before['input_json_SHA256'] == after['input_json_SHA256']
    assert len(before['commands']) == 12 and len(after['commands']) == 18
    assert all(row['exit'] == row['expected'] for row in after['commands'])
    assert len(after['outputs']['actual_headless_crash_workers']['cases']) == 14
    assert not after['new_GPU_FPS_admission'] and not after['window_opened']
    isolated = json.loads((REPORT / 'before-isolated-smoke.json').read_text())
    assert isolated['userdata_within_temporary_HOME'] and isolated['stdout_equal_initial_smoke']
    red = json.loads((REPORT / 'context-red.json').read_text())
    green = json.loads((REPORT / 'context-green.json').read_text())
    assert red['test_sha256'] == green['test_sha256'] == digest(ROOT / 'tools/qa/performance/test_performance_context.py')
    assert red['exit'] == 1 and green['exit'] == 0 and green['tests'] == 5
    catalog = json.loads((REPORT / 'catalog.json').read_text())
    browser = json.loads((REPORT / 'browser-article.json').read_text())
    assert browser['current_preparation'] and browser['profile_href'] == catalog['profile_href']
    assert browser['current_root314'] and not browser['stale_stop']
    mobile = json.loads((REPORT / 'browser-mobile.json').read_text())
    assert mobile['dimensions'] == {'width': 390, 'scrollWidth': 390}
    task = json.loads((REPORT / 'browser-task.json').read_text())
    assert task['in_progress'] and task['current_preparation'] and not task['stale_stop']
    cleanup = json.loads((REPORT / 'browser-cleanup.json').read_text())
    assert cleanup['own_tab_closed'] and cleanup['own_server_stop_confirmed']
    result = {
        'task': 'REFACTOR-03', 'phase': 'performance source-root/Git preparation',
        'version': '0.0.370', 'base': scope['base'], 'authoritative_gates': gates,
        'architecture_suites': len(cases), 'architecture_cases': sum(cases),
        'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
        'root_sources': 314, 'source_root_sites': 8, 'Git_read_sites': 9, 'shell_roots': 2,
        'existing_source_files_changed': 12, 'physical_source_moves': 0, 'UID_moves': 0,
        'old_test_methods_and_assertions_preserved': 108, 'new_context_tests': 5,
        'historical_fields_preserved': 37, 'all_author_UID_preserved': 85,
        'actual_worker_checkpoints_each_phase': 14, 'actual_headless_smoke_frames_each_phase': 180,
        'actual_after_commands': 18, 'prior369_source_review': 5690215352, 'prior369_CI_success': 8,
        'full_task03_accepted': False, 'Task_Complete_added': False, 'GPU_FPS_admission': False,
        'source_SHA256': current, 'removed_source_paths': [],
        'report_files': [{'path': path.relative_to(REPORT).as_posix(), 'sha256': digest(path),
            'bytes': path.stat().st_size} for path in sorted(REPORT.rglob('*'))
            if path.is_file() and path.name != 'checks.json' and '__pycache__' not in path.parts],
    }
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'version': '0.0.370', 'suites': len(cases), 'cases': sum(cases), 'root': 314}))


if __name__ == '__main__':
    main()

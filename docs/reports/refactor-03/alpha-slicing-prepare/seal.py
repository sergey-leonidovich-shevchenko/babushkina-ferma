"""Связывает полную новую серию367 с исходниками, не подменяя независимое ревью."""
import hashlib
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    first = json.loads((REPORT / 'gates-01/gate-exits.json').read_text())
    assert len(first) == 1 and first[0]['gate'] == 'architecture' and first[0]['exit'] == 1
    gates = json.loads((REPORT / 'gates-02/gate-exits.json').read_text())
    assert [r['gate'] for r in gates] == ['architecture', 'game', 'wiki']
    assert all(r['exit'] == 0 and r['version'] == '0.0.367' for r in gates)
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', (REPORT / 'gates-02/architecture.txt').read_text())))
    assert len(cases) == 90 and sum(cases) == 1235, (len(cases), sum(cases))
    game = (REPORT / 'gates-02/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
    wiki = (REPORT / 'gates-02/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    scope = json.loads((REPORT / 'scope.json').read_text())
    assert scope['historical_fields'] == 37 and scope['all_ignored_UID_preserved'] == 85
    freeze = json.loads((REPORT / 'source-freeze.json').read_text())
    assert freeze['version'] == '0.0.367'
    assert freeze['source_SHA256'] == {p: sha(ROOT / p) for p in scope['source_paths']}
    catalog = json.loads((REPORT / 'catalog.json').read_text())
    assert catalog['parallel07_excluded_from_QA'] and catalog['refactor_cards_in_candidate'] == 7
    browser = json.loads((REPORT / 'browser-article.json').read_text())
    assert browser['current_preparation'] and browser['profile_href'] == catalog['profile_href']
    assert json.loads((REPORT / 'browser-mobile.json').read_text())['dimensions'] == {'width': 390, 'scrollWidth': 390}
    assert json.loads((REPORT / 'browser-task.json').read_text())['in_progress']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    result = {'task': 'REFACTOR-03', 'phase': 'alpha/slicing history preparation; physical move pending',
        'version': '0.0.367', 'base': scope['base'], 'authoritative_gates': gates,
        'initial_gate_failure_retained': first, 'initial_failure': 'QA worktree had no initial Godot texture import',
        'architecture_suites': len(cases), 'architecture_cases': sum(cases),
        'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
        'new_history_cases': 8, 'before_export_frames': 5603, 'root_sources': 420, 'physical_moves': 0,
        'user_queue_after_full03': ['REFACTOR-07', 'REFACTOR-06', 'first overworld route through VMAP-003'],
        'user_stop_cancelled': True, 'REFACTOR06_started': False,
        'Task_Complete_added': False, 'full_task03_accepted': False, 'GPU_FPS_admission': False,
        'source_SHA256': {p: sha(ROOT / p) for p in scope['source_paths']},
        'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
            for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json'
            and '__pycache__' not in p.parts]}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'version': '0.0.367', 'suites': len(cases), 'cases': sum(cases), 'root': 420}))


if __name__ == '__main__':
    main()

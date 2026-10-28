"""Фиксирует новую полную серию366, не объявляя устранение P2 независимой приёмкой."""
import hashlib
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    gates = json.loads((REPORT / 'gates-01/gate-exits.json').read_text())
    assert [r['gate'] for r in gates] == ['architecture', 'game', 'wiki']
    assert all(r['exit'] == 0 and r['version'] == '0.0.366' for r in gates)
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', (REPORT / 'gates-01/architecture.txt').read_text())))
    assert len(cases) == 89 and sum(cases) == 1227, (len(cases), sum(cases))
    game = (REPORT / 'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
    wiki = (REPORT / 'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    scope = json.loads((REPORT / 'scope.json').read_text())
    assert scope['historical_fields'] == 37 and scope['all_ignored_UID_preserved'] == 85
    assert json.loads((REPORT / 'catalog.json').read_text())['REFACTOR06_requires_new_direct_command']
    catalog = json.loads((REPORT / 'catalog.json').read_text())
    browser = json.loads((REPORT / 'browser-article.json').read_text())
    assert browser['current_P2'] and browser['profile_href'] == catalog['profile_href']
    assert json.loads((REPORT / 'browser-mobile.json').read_text())['dimensions'] == {'width': 390, 'scrollWidth': 390}
    assert json.loads((REPORT / 'browser-task.json').read_text())['in_progress']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    profile = json.loads((REPORT / 'profile.json').read_text())
    assert len(profile['headless_actual_capture_phases']) == 5 and profile['GPU_FPS_admission'] is False
    result = {'task': 'REFACTOR-03', 'phase': 'P2 actual migration fixture producer regression',
        'version': '0.0.366', 'base': scope['base'], 'authoritative_gates': gates,
        'architecture_suites': len(cases), 'architecture_cases': sum(cases),
        'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
        'actual_native_headless_phases': 5, 'new_real_producer_cases': 3, 'root_sources': 420,
        'user_stop_after_full03': True, 'REFACTOR06_started': False, 'Task_Complete_added': False,
        'full_task03_accepted': False, 'GPU_FPS_admission': False,
        'source_SHA256': {p: sha(ROOT / p) for p in scope['source_paths']},
        'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
            for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json'
            and '__pycache__' not in p.parts]}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'version': '0.0.366', 'suites': len(cases), 'cases': sum(cases), 'root': 420}))


if __name__ == '__main__':
    main()

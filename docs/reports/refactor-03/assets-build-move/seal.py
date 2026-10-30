"""Фиксирует проверки365; промежуточный перенос не завершает всю03."""
import hashlib
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    gates = json.loads((REPORT / 'gates-02/gate-exits.json').read_text())
    assert [r['gate'] for r in gates] == ['architecture', 'game', 'wiki']
    assert all(r['exit'] == 0 and r['version'] == '0.0.365' for r in gates)
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', (REPORT / 'gates-02/architecture.txt').read_text())))
    assert len(cases) == 88 and sum(cases) == 1224, (len(cases), sum(cases))
    game = (REPORT / 'gates-02/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
    wiki = (REPORT / 'gates-02/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    scope = json.loads((REPORT / 'scope.json').read_text())
    assert scope['historical_fields'] == 37 and scope['all_ignored_UID_preserved'] == 85
    assert json.loads((REPORT / 'catalog.json').read_text())['REFACTOR06_requires_new_direct_command']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    mobile = json.loads((REPORT / 'browser-mobile.json').read_text())
    assert mobile['current_article'] and mobile['profile_link']
    assert mobile['dimensions'] == {'width': 390, 'scrollWidth': 390}
    assert json.loads((REPORT / 'browser-task.json').read_text())['in_progress']
    artist = json.loads((REPORT / 'artist-document-fix.json').read_text())
    assert artist['manifest_unchanged'] and artist['green'] == {'exit': 0, 'tests': 16, 'failures': 0}
    profile = json.loads((REPORT / 'profile-02.json').read_text())
    assert profile['version'] == '0.0.365'
    result = {'task': 'REFACTOR-03', 'phase': 'connected assets-contracts, migration and build move',
        'version': '0.0.365', 'base': scope['base'], 'authoritative_gates': gates,
        'architecture_suites': len(cases), 'architecture_cases': sum(cases),
        'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
        'physical_source_moves': 61, 'tracked_UID_moves': 8, 'JSON_moves': 2, 'ignored_UID_moves': 18,
        'root_sources': 420, 'user_stop_after_full03': True, 'REFACTOR06_started': False,
        'artist_document_cases_added': 4, 'artist_first_red_preserved': True,
        'local_Python_cache_excluded': True,
        'Task_Complete_added': False, 'full_task03_accepted': False, 'GPU_FPS_admission': False,
        'source_SHA256': {p: sha(ROOT / p) for p in scope['source_paths']},
        'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
            for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json'
            and '__pycache__' not in p.parts]}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['version', 'architecture_suites', 'architecture_cases', 'root_sources']}))


if __name__ == '__main__':
    main()

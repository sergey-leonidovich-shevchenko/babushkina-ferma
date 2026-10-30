"""Фиксирует выполненные проверки364; промежуточный пакет не завершает03."""
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
    assert all(r['exit'] == 0 and r['version'] == '0.0.364' for r in gates)
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', (REPORT / 'gates-01/architecture.txt').read_text())))
    assert len(cases) == 87 and sum(cases) == 1204, (len(cases), sum(cases))
    game = (REPORT / 'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
    wiki = (REPORT / 'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    scope = json.loads((REPORT / 'scope.json').read_text())
    assert scope['historical_fields'] == 37 and scope['all_ignored_UID_preserved'] == 85
    assert json.loads((REPORT / 'catalog.json').read_text())['REFACTOR06_requires_new_direct_command']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    result = {'task': 'REFACTOR-03', 'phase': 'assets/build source-root and scanner history preparation',
              'version': '0.0.364', 'base': scope['base'], 'authoritative_gates': gates,
              'architecture_suites': len(cases), 'architecture_cases': sum(cases),
              'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
              'changed_Python': 16, 'physical_moves': 0, 'root_sources': 481,
              'user_stop_after_full03': True, 'REFACTOR06_started': False,
              'Task_Complete_added': False, 'full_task03_accepted': False, 'GPU_FPS_admission': False,
              'source_SHA256': {p: sha(ROOT / p) for p in scope['source_paths']},
              'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
                               for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json']}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['version', 'architecture_suites', 'architecture_cases', 'root_sources']}))


if __name__ == '__main__':
    main()

"""Запечатывает только завершённые gates и фактические исходники текущего пакета."""
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
    assert all(r['exit'] == 0 and r['version'] == '0.0.361' for r in gates)
    architecture = (REPORT / 'gates-01/architecture.txt').read_text()
    cases = list(map(int, re.findall(r'Ran (\d+) tests? in', architecture)))
    assert len(cases) == 84 and sum(cases) == 1163, (len(cases), sum(cases))
    assert 'FAILED' not in architecture
    game = (REPORT / 'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game
    assert game.count('REDRAW: 90 passed, 0 failed') == 2
    for mode in ['normal', 'f10']:
        summary = json.loads((REPORT / 'gates-01/headless' / mode / 'summary.json').read_text())
        assert summary['passed'] == 90 and summary['failed'] == 0 and summary['mode'] == mode
    wiki = (REPORT / 'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    scope = json.loads((REPORT / 'scope.json').read_text())
    catalog = json.loads((REPORT / 'catalog.json').read_text())
    assert catalog['image_profile_attachment_equal'] and not catalog['accepted_VMAP']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    result = {'task': 'REFACTOR-03', 'phase': 'PIL and dev/art_review; full task in_progress',
              'head_before': scope['head_before'], 'version': '0.0.361', 'authoritative_gates': gates,
              'architecture_suites': len(cases), 'architecture_cases': sum(cases),
              'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
              'profile': 'profile.json', 'replay': 'replay.json', 'scope': 'scope.json',
              'root_tracked_sources': 504, 'source_moves': 5, 'tracked_UID_moves': 1,
              'previous_audio_exact_head_CI': '8/8 success',
              'Task_Complete_added': False, 'full_task03_accepted': False, 'VMAP_FPS_admission': False,
              'source_SHA256': {p: sha(ROOT / p) for p in sorted(set(scope['changed_paths']) | set(scope['new_markers'])) if (ROOT / p).is_file()},
              'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
                               for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json']}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['version', 'architecture_suites', 'architecture_cases', 'root_tracked_sources']}))


if __name__ == '__main__':
    main()

"""Запечатывает собственные завершённые gates и source SHA подготовки art-standard."""
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
    assert all(r['exit'] == 0 and r['version'] == '0.0.362' for r in gates)
    architecture = (REPORT / 'gates-01/architecture.txt').read_text()
    counts = list(map(int, re.findall(r'Ran (\d+) tests? in', architecture)))
    assert len(counts) == 85 and sum(counts) == 1184, (len(counts), sum(counts))
    game = (REPORT / 'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed') == 2
    for mode in ['normal', 'f10']:
        s = json.loads((REPORT / 'gates-01/headless' / mode / 'summary.json').read_text())
        assert s['mode'] == mode and s['passed'] == 90 and s['failed'] == 0
    wiki = (REPORT / 'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b', wiki) and re.search(r'[ℹ#] fail 0\b', wiki)
    followup = json.loads((REPORT / 'wiki-link-fix.json').read_text())
    assert followup['exit'] == 0 and not followup['architecture_and_game_sources_changed']
    followup_raw = (REPORT / followup['raw']).read_text()
    assert re.search(r'[ℹ#] pass 145\b', followup_raw) and re.search(r'[ℹ#] fail 0\b', followup_raw)
    scope = json.loads((REPORT / 'scope.json').read_text())
    assert scope['original_contract_fields'] == 37 and scope['ignored_UID_preserved'] == 85
    assert json.loads((REPORT / 'catalog.json').read_text())['historical_profile_attachment_equal']
    assert json.loads((REPORT / 'browser-cleanup.json').read_text())['own_tab_closed']
    result = {'task': 'REFACTOR-03', 'phase': 'art-standard root/history preparation, no physical moves',
              'version': '0.0.362', 'base': scope['base'], 'authoritative_gates': gates,
              'Wiki_followup_after_evidence_link_fix': followup,
              'architecture_suites': len(counts), 'architecture_cases': sum(counts),
              'game_passed': 53502, 'game_failed': 0, 'redraw_each_passed': 90, 'wiki_passed': 145,
              'new_real_Git_cases': 21, 'historical_reader_cases': 4, 'historical_pins': 5,
              'source_root_preparations': 8, 'physical_moves': 0, 'root_sources': 504,
              'previous_exact_head_361_CI': '8/8 success', 'Task_Complete_added': False,
              'full_task03_accepted': False, 'VMAP_FPS_admission': False,
              'source_SHA256': {p: sha(ROOT / p) for p in scope['source_paths']},
              'report_files': [{'path': str(p.relative_to(REPORT)), 'sha256': sha(p), 'bytes': p.stat().st_size}
                               for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name != 'checks.json']}
    (REPORT / 'checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['version', 'architecture_suites', 'architecture_cases', 'root_sources']}))


if __name__ == '__main__':
    main()

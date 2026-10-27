"""Фиксирует границу пакета и живые/исторические упоминания без изменения входов."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = next(p for p in Path(__file__).resolve().parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

REPORT = Path(__file__).resolve().parent
BASE = 'd27f688fa3ec2670a757acd14019f8ae35e0f693'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def main():
    moves = json.loads((REPORT / 'migration.json').read_text())['moves']
    allowed = {'.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
               'QA_CHECKLIST.md', 'TESTING.md', 'docs/DEVELOPMENT.md', 'tools/README.md',
               'docs/concepts/visual-polish-2026-10-13/v1/README.md',
               'docs/epics/refactoring-2026-10/README.md', 'docs/epics/refactoring-2026-10/TASKS.md',
               'wiki/articles/project-refactoring.md', 'wiki/articles/visual-pilot.md',
               'tools/dev/__init__.py', 'tools/dev/art_review/__init__.py'}
    allowed.update(row[key] for row in moves for key in ['old_path', 'target'])
    changed = set(filter(None, git('diff', '--no-renames', BASE, '--name-only', '-z').decode().split('\0')))
    report_prefix = str(REPORT.relative_to(ROOT)) + '/'
    assert all(p in allowed or p.startswith(report_prefix) for p in changed), changed - allowed
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    assert all(p in allowed or p.startswith(report_prefix) for p in untracked), untracked - allowed
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_sources = sum(p.startswith('tools/') and p.count('/') == 1 and
                       Path(p).suffix in {'.py', '.gd', '.mjs', '.sh', '.gdshader', '.swift'} for p in tracked)
    assert root_sources == 504, root_sources
    uids = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uids['local_only_UID']:
        matches = [ROOT / p for p in [row['old_path'], row['target']] if (ROOT / p).is_file()]
        assert len(matches) == 1 and matches[0].read_text().strip() == row['value'], row
        relative = str(matches[0].relative_to(ROOT))
        assert relative not in tracked and git('check-ignore', '--', relative).strip()
    anchor = uids['retained_anchor_local_UID']
    assert hashlib.sha256((ROOT / anchor['path']).read_bytes()).hexdigest() == anchor['sha256']
    assert anchor['path'] not in tracked and git('check-ignore', '--', anchor['path']).strip()
    for relative in ['tools/dev/__pycache__/probe.pyc', 'tools/dev/art_review/__pycache__/probe.pyc',
                     'tools/dev/art_review/unassigned.gd.uid']:
        assert git('check-ignore', '--', relative).strip()
    other_cards = re.split(r'(?=^## REFACTOR-)', (ROOT / 'docs/epics/refactoring-2026-10/TASKS.md').read_text(), flags=re.M)
    old_cards = re.split(r'(?=^## REFACTOR-)', git('show', BASE + ':docs/epics/refactoring-2026-10/TASKS.md').decode(), flags=re.M)
    assert len(other_cards) == len(old_cards)
    assert all(a == b for a, b in zip(other_cards, old_cards) if not a.startswith('## REFACTOR-03 '))
    pattern = re.compile(r'tools/(?:import_pixabay_assets\.py|check_art_review\.py|test_art_review\.py|art_review_export\.gd(?:\.uid)?|art_review_serve\.mjs)')
    references = []
    for relative in sorted(tracked | untracked):
        path = ROOT / relative
        if path.parent == REPORT and path.name in {'scope.json', 'live-reference-final.json', 'checks.json'}:
            continue
        if not path.is_file() or path.suffix.lower() in {'.gz', '.png', '.jpg', '.webp', '.wav'}:
            continue
        try:
            content = path.read_text()
        except (UnicodeError, OSError):
            continue
        for number, line in enumerate(content.splitlines(), 1):
            if not pattern.search(line):
                continue
            if relative.startswith(report_prefix):
                kind = 'current migration evidence: old_path is intentional'
            elif relative.startswith('docs/reports/'):
                kind = 'immutable prior report'
            elif relative == 'wiki/articles/tools-migration-map.md':
                kind = 'historical original migration map'
            elif relative == 'docs/concepts/visual-polish-2026-10-13/v1/VALIDATION.md':
                kind = 'recorded past validation, not a live command'
            else:
                kind = 'UNCLASSIFIED'
            references.append({'path': relative, 'line': number, 'kind': kind, 'text': line})
    unexplained = [r for r in references if r['kind'] == 'UNCLASSIFIED']
    (REPORT / 'live-reference-final.json').write_text(json.dumps(references, ensure_ascii=False, indent=2) + '\n')
    assert not unexplained, unexplained
    result = {'head_before': BASE, 'version': '0.0.361',
              'changed_paths': sorted(p for p in changed if not p.startswith(report_prefix)),
              'new_markers': ['tools/dev/__init__.py', 'tools/dev/art_review/__init__.py'],
              'moves': 5, 'tracked_UID_moves': 1, 'local_ignored_UID_preserved': len(uids['local_only_UID']),
              'retained_anchor_UID_preserved': True, 'dev_cache_and_unassigned_UID_ignored': True,
              'root_tracked_sources': root_sources, 'other_refactor_cards_unchanged': True,
              'game_artwork_provenance_prior_reports_unchanged_by_Git_scope': True,
              'Task_Complete_added': False, 'full_task03_accepted': False}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_sources, 'scope_ok': True, 'UID': len(uids['local_only_UID']), 'historical_references': len(references)}))


if __name__ == '__main__':
    main()

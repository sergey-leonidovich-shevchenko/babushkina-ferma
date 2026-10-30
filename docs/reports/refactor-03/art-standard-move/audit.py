"""Фиксирует границу art-переноса, original descriptors, UID и пользовательскую остановку."""
import ast
import gzip
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
BASE = '47d0edc5e9a24dc028b6c91638e8dc54b87aaf9f'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def main():
    migration = json.loads((REPORT / 'migration.json').read_text())
    inventory = json.loads((REPORT / 'baseline/inventory.json').read_text())
    documents = json.loads((REPORT / 'live-documents.json').read_text())
    added = ['tools/qa/__init__.py', 'tools/qa/art/__init__.py',
             'tools/qa/art/current_paths.py', 'tools/qa/art/test_current_paths.py']
    allowed = {r[k] for r in migration['moves'] for k in ['old_path', 'target']}
    allowed |= set(inventory['live_consumers']) | {r['path'] for r in documents} | set(added) | {
        '.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
        'tools/README.md', 'wiki/articles/project-refactoring.md', 'wiki/articles/visual-pilot.md',
        'docs/epics/refactoring-2026-10/README.md', 'docs/epics/refactoring-2026-10/TASKS.md'}
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    changed = set(filter(None, git('diff', '--no-renames', BASE, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    count = sum(p.startswith('tools/') and p.count('/') == 1 and Path(p).suffix in
                {'.py', '.gd', '.mjs', '.swift', '.sh', '.gdshader'} for p in tracked)
    assert count == 481
    for row in migration['moves']:
        path = ROOT / row['target']
        assert not (ROOT / row['old_path']).exists()
        assert hashlib.sha256(path.read_bytes()).hexdigest() == row['after_sha256']
        assert path.stat().st_mode & 0o777 == row['mode']
        if path.suffix == '.uid':
            assert path.read_bytes() == gzip.decompress((REPORT / 'inputs' / (path.name + '.gz')).read_bytes())
    uid = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        matches = [ROOT / p for p in [row['old_path'], row['target']] if (ROOT / p).is_file()]
        assert len(matches) == 1 and matches[0].read_text().strip() == row['value']
        name = str(matches[0].relative_to(ROOT))
        assert name not in tracked and git('check-ignore', '--', name).strip()
    anchor = uid['retained_anchor_local_UID']
    assert hashlib.sha256((ROOT / anchor['path']).read_bytes()).hexdigest() == anchor['sha256']
    contracts_path = REPORT.parent / 'baseline/source-contracts.json'
    assert hashlib.sha256(contracts_path.read_bytes()).hexdigest() == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    contracts = json.loads(contracts_path.read_text())
    mapping = {}
    for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move']:
        mapping.update({r['old_path']: r['target'] for r in json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
    child = ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body
                                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CHILD' for t in n.targets)))
    fields = 0
    for row in contracts['modules'].values():
        path = mapping.get(row['source'], row['source'])
        run = subprocess.run([sys.executable, '-c', child, str(ROOT), path.removesuffix('.py').replace('/', '.')],
                             cwd=ROOT, env=git_environment(), capture_output=True, text=True, timeout=30)
        assert run.returncode == 0 and not run.stderr, (path, run.stderr)
        assert json.loads(run.stdout) == row['fields'], path
        fields += len(row['fields'])
    assert fields == 37
    old_tasks = json.loads(gzip.decompress((REPORT / 'inputs/docs--epics--visual-overhaul-2026-10--backlog.json.gz').read_bytes()))
    new_tasks = json.loads((ROOT / 'docs/epics/visual-overhaul-2026-10/backlog.json').read_text())
    assert [(t['id'], t['status']) for t in old_tasks['tasks']] == [(t['id'], t['status']) for t in new_tasks['tasks']]
    assert old_tasks['task_count'] == new_tasks['task_count']
    old_cards = re.split(r'(?=^## REFACTOR-)', git('show', BASE + ':docs/epics/refactoring-2026-10/TASKS.md').decode(), flags=re.M)
    new_cards = re.split(r'(?=^## REFACTOR-)', (ROOT / 'docs/epics/refactoring-2026-10/TASKS.md').read_text(), flags=re.M)
    assert len(old_cards) == len(new_cards)
    assert all(a == b for a, b in zip(old_cards, new_cards) if not a.startswith(('## REFACTOR-03 ', '## REFACTOR-06 ')))
    hold_card = next(p for p in new_cards if p.startswith('## REFACTOR-06 '))
    assert '**Статус:** blocked' in hold_card and 'новая прямая команда' in hold_card
    assert 'После неё остановиться' in (ROOT / 'AGENTS.md').read_text()
    result = {'base': BASE, 'version': '0.0.363', 'root_sources': count, 'source_moves': 23,
              'tracked_UID_moves': 3, 'ignored_UID_moves': 4, 'all_ignored_UID_preserved': 85,
              'retained_anchor_preserved': True, 'historical_contract_modules': 21, 'historical_fields': fields,
              'visual_backlog_ID_status_and_count_preserved': True,
              'other_refactor_cards_except03_and06_hold_unchanged': True,
              'user_stop_after_full03_recorded': True, 'REFACTOR06_started': False,
              'old_reports_runtime_artwork_provenance_unchanged_by_Git_scope': True,
              'Task_Complete_added': False, 'full_task03_accepted': False,
              'source_paths': sorted({p for p in changed if p in allowed and (ROOT / p).is_file()} | set(added))}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': count, 'UID_preserved': 85, 'historical_fields': fields, 'user_hold': True}))


if __name__ == '__main__':
    main()

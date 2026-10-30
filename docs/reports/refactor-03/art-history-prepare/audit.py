"""Сверяет scope, UID и все прежние SOURCES/OVERLAY перед подготовительным commit."""
import ast
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
BASE = '832964d4de4a0a0207500dd185039642738874e7'


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], env=git_environment())


def main():
    original = json.loads((REPORT / 'baseline/sources.json').read_text())
    helpers = ['tools/common/history.py', 'tools/common/test_history.py']
    allowed = set(original['sources']) | set(helpers) | {
        'TESTING.md', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
        'tools/README.md', 'tools/quality/check_architecture.sh', 'wiki/articles/project-refactoring.md',
        'docs/epics/refactoring-2026-10/README.md', 'docs/epics/refactoring-2026-10/TASKS.md'}
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    changed = set(filter(None, git('diff', '--no-renames', BASE, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_count = sum(p.startswith('tools/') and p.count('/') == 1 and Path(p).suffix in
                     {'.gd', '.py', '.sh', '.mjs', '.swift', '.gdshader'} for p in tracked)
    assert root_count == 504
    uid = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        matches = [ROOT / name for name in [row['old_path'], row['target']] if (ROOT / name).is_file()]
        assert len(matches) == 1 and matches[0].read_text().strip() == row['value']
        relative = str(matches[0].relative_to(ROOT))
        assert relative not in tracked and git('check-ignore', '--', relative).strip()
    anchor = uid['retained_anchor_local_UID']
    assert hashlib.sha256((ROOT / anchor['path']).read_bytes()).hexdigest() == anchor['sha256']
    old_cards = re.split(r'(?=^## REFACTOR-)', git('show', BASE + ':docs/epics/refactoring-2026-10/TASKS.md').decode(), flags=re.M)
    new_cards = re.split(r'(?=^## REFACTOR-)', (ROOT / 'docs/epics/refactoring-2026-10/TASKS.md').read_text(), flags=re.M)
    assert len(old_cards) == len(new_cards)
    assert all(a == b for a, b in zip(old_cards, new_cards) if not a.startswith('## REFACTOR-03 '))
    snapshot = REPORT.parent / 'baseline/source-contracts.json'
    assert hashlib.sha256(snapshot.read_bytes()).hexdigest() == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    contracts = json.loads(snapshot.read_text())
    moves = {}
    for phase in ['authoring-move', 'audio-move', 'image-review-move']:
        moves.update({r['old_path']: r['target'] for r in json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
    field_reader = next(n.value for n in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body
                        if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CHILD' for t in n.targets))
    child = ast.literal_eval(field_reader)
    fields = 0
    for row in contracts['modules'].values():
        relative = moves.get(row['source'], row['source'])
        source_before = (ROOT / relative).read_bytes()
        module = relative.removesuffix('.py').replace('/', '.')
        process = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
                                 env=git_environment(), capture_output=True, text=True, timeout=30)
        assert process.returncode == 0 and not process.stderr, (relative, process.stderr)
        assert json.loads(process.stdout) == row['fields'], relative
        assert (ROOT / relative).read_bytes() == source_before
        fields += len(row['fields'])
    assert fields == 37 and len(contracts['modules']) == 21
    pins = json.loads((REPORT / 'baseline/capture-pins.json').read_text())
    for row in pins['rows']:
        raw = (ROOT / row['source']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == row['sha256']
        assert raw == git('show', BASE + ':' + row['source'])
    result = {'base': BASE, 'version': '0.0.362', 'source_addresses_prepared': 8, 'physical_moves': 0,
              'root_sources': root_count, 'historical_pins': 5, 'UID_moves': 0,
              'ignored_UID_preserved': len(uid['local_only_UID']), 'retained_anchor_preserved': True,
              'original_contract_modules': 21, 'original_contract_fields': fields,
              'contract_values_observed_in_separate_import_processes': True,
              'initial_static_audit_correction': 'SOURCES includes AugAssign/comprehensions; accepted CHILD collector used instead of only first AST Assign',
              'other_refactor_cards_unchanged': True, 'previous_reports_runtime_artwork_provenance_unchanged_by_Git_scope': True,
              'Task_Complete_added': False, 'full_task03_accepted': False,
              'source_paths': sorted((allowed & changed) | set(helpers))}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_count, 'UID': len(uid['local_only_UID']), 'historical_fields': fields, 'scope': True}))


if __name__ == '__main__':
    main()

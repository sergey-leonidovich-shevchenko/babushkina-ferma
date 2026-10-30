"""Проверяет границу переноса365, текущие SHA и сохранность прежних контрактов."""
import ast
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(ROOT), *arguments], env=git_environment())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    base = baseline['base']
    mapping = {old: row['target'] for old, row in baseline['assignments'].items()}
    documents = json.loads((REPORT / 'live-documents.json').read_text())
    allowed = set(mapping) | set(mapping.values()) | set(baseline['consumers']) | {
        r['path'] for r in documents
    } | {'.gitignore', 'VERSION', 'project.godot', 'Бабушкина ферма.app/Contents/Info.plist',
         'tools/assets/contracts/__init__.py', 'tools/assets/contracts/source_paths.py',
         'tools/assets/contracts/test_source_paths.py'}
    changed = set(filter(None, git('diff', '--no-renames', base, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    assert allowed == ((changed | untracked) & allowed), allowed - (changed | untracked)
    assert git('show', base + ':AGENTS.md') == (ROOT / 'AGENTS.md').read_bytes()
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_count = sum(p.startswith('tools/') and p.count('/') == 1 and Path(p).suffix in
                     {'.py', '.gd', '.mjs', '.swift', '.sh', '.gdshader'} for p in tracked)
    assert root_count == 420
    before_arch = git('show', base + ':tools/quality/check_architecture.sh').decode()
    expected = before_arch
    for old, new in mapping.items():
        if old.endswith('.py'):
            module = new.removesuffix('.py').replace('/', '.').removeprefix('tools.')
            expected = expected.replace('python3 ' + old, 'python3 tools/run.py ' + module)
    expected = expected.replace('python3 tools/run.py assets.migration.test_scanner_history\n',
        'python3 tools/run.py assets.migration.test_scanner_history\npython3 tools/run.py assets.contracts.test_source_paths\n')
    assert (ROOT / 'tools/quality/check_architecture.sh').read_text() == expected
    for row in documents:
        assert hashlib.sha256(git('show', base + ':' + row['path'])).hexdigest() == row['before_sha256']
        assert sha(ROOT / row['path']) == row['after_sha256']
    preserved = json.loads((REPORT / 'historical-documents-preserved.json').read_text())
    for row in preserved['excluded_from_live_updates']:
        assert sha(ROOT / row['path']) == row['sha256']
        assert (ROOT / row['path']).read_bytes() == git('show', base + ':' + row['path'])
    cards = 'docs/epics/refactoring-2026-10/TASKS.md'
    before_cards = re.split(r'(?=^## REFACTOR-)', git('show', base + ':' + cards).decode(), flags=re.M)
    after_cards = re.split(r'(?=^## REFACTOR-)', (ROOT / cards).read_text(), flags=re.M)
    assert len(before_cards) == len(after_cards)
    assert all(a == b for a, b in zip(before_cards, after_cards) if not a.startswith('## REFACTOR-03 '))
    hold = next(p for p in after_cards if p.startswith('## REFACTOR-06 '))
    assert '**Статус:** blocked' in hold and 'новая прямая команда' in hold
    profile = json.loads((REPORT / 'profile-02.json').read_text())
    assert profile['version'] == '0.0.365' and len(profile['physical_sources']) == 71
    moves = []
    for row in profile['physical_sources']:
        old, new = row['old_path'], row['target']
        assert mapping[old] == new and sha(ROOT / new) == row['sha256']
        assert (ROOT / new).stat().st_mode & 0o777 == row['mode']
        original = gzip.decompress((REPORT / 'inputs' / (old.replace('/', '--') + '.gz')).read_bytes())
        assert original == git('show', base + ':' + old)
        assert not (ROOT / old).exists()
        if old.endswith(('.uid', '.json')):
            assert original == (ROOT / new).read_bytes()
        moves.append({'old_path': old, 'target': new, 'before_sha256': hashlib.sha256(original).hexdigest(),
                      'after_sha256': row['sha256'], 'mode': row['mode']})
    for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move']:
        mapping.update({r['old_path']: r['target'] for r in
                        json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
    contracts_path = REPORT.parent / 'baseline/source-contracts.json'
    assert sha(contracts_path) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    contracts = json.loads(contracts_path.read_text())
    child = ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body
        if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CHILD' for t in n.targets)))
    fields = 0
    for row in contracts['modules'].values():
        module = mapping.get(row['source'], row['source']).removesuffix('.py').replace('/', '.')
        run = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
                             env=git_environment(), capture_output=True, text=True, timeout=30)
        assert run.returncode == 0 and not run.stderr, (module, run.stderr)
        assert json.loads(run.stdout) == row['fields'], module
        fields += len(row['fields'])
    assert fields == 37
    uid = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        paths = [ROOT / p for p in [row['old_path'], row['target']] if (ROOT / p).is_file()]
        assert len(paths) == 1 and paths[0].read_text().strip() == row['value']
        name = str(paths[0].relative_to(ROOT))
        assert name not in tracked and git('check-ignore', '--', name).strip()
    assert len(uid['local_only_UID']) == 85
    anchor = uid['retained_anchor_local_UID']
    assert sha(ROOT / anchor['path']) == anchor['sha256']
    (REPORT / 'migration.json').write_text(json.dumps({'base': base, 'physical_source_moves': 61,
        'tracked_UID_moves': 8, 'JSON_moves': 2, 'ignored_UID_moves': 18, 'moves': moves}, indent=2) + '\n')
    result = {'base': base, 'version': '0.0.365', 'root_sources': root_count,
        'physical_source_moves': 61, 'tracked_UID_moves': 8, 'JSON_moves': 2, 'ignored_UID_moves': 18,
        'historical_fields': fields, 'all_ignored_UID_preserved': 85, 'anchor_preserved': True,
        'previous87_architecture_suites_preserved': True, 'new_path_cases': 12, 'new_preview_cases': 4,
        'new_artist_document_cases': 4,
        'other_refactor_cards_and06_hold_unchanged': True,
        'old_reports_runtime_artwork_plans_unchanged_by_Git_scope': True,
        'historical_documents_preserved': len(preserved['excluded_from_live_updates']),
        'full_task03_accepted': False, 'REFACTOR06_started': False,
        'source_paths': sorted(p for p in allowed if (ROOT / p).is_file())}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_count, 'historical_fields': fields, 'ignored_UID': 85,
                      'current_sources': len(result['source_paths'])}))


if __name__ == '__main__':
    main()

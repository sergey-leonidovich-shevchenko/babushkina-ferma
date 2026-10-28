"""Проверяет узкую границу P2, неизменность прошлых отчётов/контрактов/UID и полный старый suite."""
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
    baseline = json.loads((REPORT / 'baseline/sources.json').read_text())
    base = baseline['base']
    allowed = set(baseline['sources']) | {'tools/assets/migration/test_migration_fixture.py'}
    changed = set(filter(None, git('diff', '--no-renames', base, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    assert allowed == ((changed | untracked) & allowed), allowed - (changed | untracked)
    for name, row in baseline['sources'].items():
        old = gzip.decompress((REPORT / 'baseline' / (name.replace('/', '--') + '.gz')).read_bytes())
        assert old == git('show', base + ':' + name) and hashlib.sha256(old).hexdigest() == row['sha256']
        assert (ROOT / name).stat().st_mode & 0o777 == row['mode']
    assert git('show', base + ':AGENTS.md') == (ROOT / 'AGENTS.md').read_bytes()
    old_arch = git('show', base + ':tools/quality/check_architecture.sh').decode()
    assert (ROOT / 'tools/quality/check_architecture.sh').read_text() == old_arch.replace(
        'python3 tools/run.py assets.migration.test_scanner_history\n',
        'python3 tools/run.py assets.migration.test_scanner_history\npython3 tools/run.py assets.migration.test_migration_fixture\n')
    cards = 'docs/epics/refactoring-2026-10/TASKS.md'
    before = re.split(r'(?=^## REFACTOR-)', git('show', base + ':' + cards).decode(), flags=re.M)
    after = re.split(r'(?=^## REFACTOR-)', (ROOT / cards).read_text(), flags=re.M)
    assert len(before) == len(after)
    assert all(a == b for a, b in zip(before, after) if not a.startswith('## REFACTOR-03 '))
    hold = next(p for p in after if p.startswith('## REFACTOR-06 '))
    assert '**Статус:** blocked' in hold and 'новая прямая команда' in hold
    mapping = {}
    for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move', 'assets-build-move']:
        mapping.update({r['old_path']: r['target'] for r in
                        json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
    contracts_path = REPORT.parent / 'baseline/source-contracts.json'
    assert sha(contracts_path) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    child = ast.literal_eval(next(n.value for n in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body
        if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'CHILD' for t in n.targets)))
    fields = 0
    for row in json.loads(contracts_path.read_text())['modules'].values():
        module = mapping.get(row['source'], row['source']).removesuffix('.py').replace('/', '.')
        result = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
            env=git_environment(), capture_output=True, text=True, timeout=30)
        assert result.returncode == 0 and not result.stderr, (module, result.stderr)
        assert json.loads(result.stdout) == row['fields'], module
        fields += len(row['fields'])
    assert fields == 37
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_count = sum(p.startswith('tools/') and p.count('/') == 1 and Path(p).suffix in
        {'.py', '.gd', '.mjs', '.swift', '.sh', '.gdshader'} for p in tracked)
    assert root_count == 420
    uid = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uid['local_only_UID']:
        paths = [ROOT / p for p in [row['old_path'], row['target']] if (ROOT / p).is_file()]
        assert len(paths) == 1 and paths[0].read_text().strip() == row['value']
        name = str(paths[0].relative_to(ROOT))
        assert name not in tracked and git('check-ignore', '--', name).strip()
    assert len(uid['local_only_UID']) == 85
    anchor = uid['retained_anchor_local_UID']
    assert sha(ROOT / anchor['path']) == anchor['sha256']
    profile = json.loads((REPORT / 'profile.json').read_text())
    assert profile['version'] == '0.0.366'
    assert sha(ROOT / 'tools/assets/migration/migration_fixture.py') == profile['source_sha256']
    assert len(profile['headless_actual_capture_phases']) == 5
    assert profile['exact_function_AST_equal'] == ['closure', 'create', 'phase']
    captures = profile['headless_actual_capture_phases']
    baseline_capture = captures['baseline']
    stable = ['side', 'id', 'pixels', 'source', 'pivot', 'logical_size', 'footprint', 'rgba_sha256', 'png_sha256']
    for capture in captures.values():
        assert {k: v for k, v in capture['document'].items() if k != 'validation'} == {
            k: v for k, v in baseline_capture['document'].items() if k != 'validation'}
        for row, original in zip(capture['rows'], baseline_capture['rows']):
            assert all(row[key] == original[key] for key in stable)
    result = {'base': base, 'version': '0.0.366', 'root_sources': root_count,
        'historical_fields': fields, 'all_ignored_UID_preserved': 85, 'anchor_preserved': True,
        'previous88_architecture_suites_preserved': True, 'new_real_producer_cases': 3,
        'actual_headless_views_and_document_stable': True,
        'other_refactor_cards_and06_hold_unchanged': True,
        'old_reports_runtime_artwork_plans_GD_UID_policies_unchanged_by_Git_scope': True,
        'full_task03_accepted': False, 'REFACTOR06_started': False, 'source_paths': sorted(allowed)}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_count, 'fields': fields, 'UID': 85, 'source_paths': len(allowed)}))


if __name__ == '__main__':
    main()

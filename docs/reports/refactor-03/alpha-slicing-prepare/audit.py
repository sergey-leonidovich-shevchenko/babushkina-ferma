"""Ограничивает подготовку исторических reader, сохраняя реальные before-данные и старые контракты."""
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
    allowed = {'.gitignore', 'AGENTS.md', 'TESTING.md', 'VERSION', 'project.godot',
        'docs/epics/refactoring-2026-10/TASKS.md', 'wiki/articles/project-refactoring.md',
        'tools/quality/check_architecture.sh', 'Бабушкина ферма.app/Contents/Info.plist',
        'tools/alpha_audit.py', 'tools/alpha_proof.py', 'tools/slice_audit.py', 'tools/slice_proof.py',
        'tools/assets/alpha/__init__.py', 'tools/assets/alpha/test_processing_history.py'}
    changed = set(filter(None, git('diff', '--no-renames', base, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    prefix = str(REPORT.relative_to(ROOT)) + '/'
    assert all(p in allowed or p.startswith(prefix) for p in changed | untracked), (changed | untracked) - allowed
    assert allowed == ((changed | untracked) & allowed), allowed - (changed | untracked)
    for name, row in baseline['sources'].items():
        old = gzip.decompress((REPORT / 'baseline' / (name.replace('/', '--') + '.gz')).read_bytes())
        assert old == git('show', base + ':' + name) and hashlib.sha256(old).hexdigest() == row['sha256']
        assert (ROOT / name).stat().st_mode & 0o777 == row['mode']
    for old, row in baseline['planned_assignments'].items():
        assert (ROOT / old).is_file() and not (ROOT / row['target']).exists(), old
    assert len(baseline['planned_assignments']) == 19
    for name in ['docs/backlog/README.md', 'wiki/planning/sources.json']:
        assert git('show', base + ':' + name) == (ROOT / name).read_bytes(), name
    old_agents = git('show', base + ':AGENTS.md').decode().splitlines(keepends=True)
    new_agents = (ROOT / 'AGENTS.md').read_text().splitlines(keepends=True)
    assert len(old_agents) == len(new_agents)
    assert all(a == b for i, (a, b) in enumerate(zip(old_agents, new_agents)) if i != 2)
    assert 'отменяет прежнюю остановку после03/07' in new_agents[2]
    old_arch = git('show', base + ':tools/quality/check_architecture.sh').decode()
    assert (ROOT / 'tools/quality/check_architecture.sh').read_text() == old_arch.replace(
        'python3 tools/run.py assets.migration.test_migration_fixture\n',
        'python3 tools/run.py assets.migration.test_migration_fixture\npython3 tools/run.py assets.alpha.test_processing_history\n')
    cards = 'docs/epics/refactoring-2026-10/TASKS.md'
    before = re.split(r'(?=^## REFACTOR-)', git('show', base + ':' + cards).decode(), flags=re.M)
    after = re.split(r'(?=^## REFACTOR-)', (ROOT / cards).read_text(), flags=re.M)
    assert len(before) == len(after) == 8
    assert all(a == b for a, b in zip(before, after) if not a.startswith('## REFACTOR-03 '))
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
    assert profile['version'] == '0.0.367' and profile['physical_moves'] == 0
    for name, expected in profile['fixed_sources_SHA256'].items():
        assert sha(ROOT / name) == expected == baseline['sources'][name]['sha256'], name
    assert len(profile['actual_control_files_equal_original']) == 9
    assert len(profile['actual_foreign_CLI']) == 9 and len(profile['native']) == 12
    assert len(profile['Git_call_sites_AST']) == 8
    assert profile['actual_Git_calls_in_default_and_record_refusal'] == 4
    assert not profile['later_record_branches_executed'] and not profile['GPU_FPS_admission']
    export = profile['actual_export_before_move']
    assert len(export['frames']) == 5603 and export['measurement_errors'] == []
    inventory_raw = gzip.decompress((REPORT / 'baseline/export-inventory.json.gz').read_bytes())
    assert hashlib.sha256(inventory_raw).hexdigest() == export['inventory_sha256']
    context = json.loads((REPORT / 'qa-context.json').read_text())
    assert context['QA_inputs_equal_primary_before_export']
    for name, expected in context['QA_current_reader_SHA256'].items():
        assert sha(ROOT / name) == expected, ('reader changed during QA environment repair', name)
    repair = json.loads((REPORT / 'environment-repair.json').read_text())
    assert repair['first_exit'] == 1 and repair['subsequent_real_slice_export_exit'] == 0
    # Изменённые функции проверяет реальный профиль и domain-suite; прочие тела остаются прежними.
    modified = {'alpha_audit': {'scan', 'check', 'main'}, 'alpha_proof': {'validate'},
        'slice_audit': {'inputs', 'check', 'main'}, 'slice_proof': {'validate'}}
    added = {'alpha_audit': set(), 'alpha_proof': {'capture_sha'},
        'slice_audit': {'legacy_exporter_sha', 'input_errors'}, 'slice_proof': {'capture_sha'}}
    unchanged_functions = []
    for module, names in modified.items():
        name = 'tools/' + module + '.py'
        old_functions = {n.name: ast.dump(n) for n in ast.parse(git('show', base + ':' + name)).body if isinstance(n, ast.FunctionDef)}
        new_functions = {n.name: ast.dump(n) for n in ast.parse((ROOT / name).read_text()).body if isinstance(n, ast.FunctionDef)}
        assert set(new_functions) == set(old_functions) | added[module]
        for function in set(old_functions) - names:
            assert old_functions[function] == new_functions[function], (module, function)
            unchanged_functions.append(module + '.' + function)
    result = {'base': base, 'version': '0.0.367', 'root_sources': root_count,
        'historical_fields': fields, 'all_ignored_UID_preserved': 85, 'anchor_preserved': True,
        'physical_moves': 0, 'planned_assignments_intact': 19, 'new_history_cases': 8,
        'unchanged_function_AST': sorted(unchanged_functions), 'changed_functions_require_behavior_tests': {m: sorted(n) for m, n in modified.items()},
        'other_six_refactor_cards_unchanged': True, 'parallel07_excluded_from_QA': True,
        'old_reports_runtime_artwork_plans_GD_UID_policies_unchanged_by_Git_scope': True,
        'full_task03_accepted': False, 'REFACTOR06_started': False, 'source_paths': sorted(allowed)}
    (REPORT / 'scope.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'root': root_count, 'fields': fields, 'UID': 85, 'source_paths': len(allowed), 'before_frames': 5603}))


if __name__ == '__main__':
    main()

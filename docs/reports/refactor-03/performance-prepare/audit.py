"""Verify the preparation scope, exact adaptation, old tests and frozen contracts."""
import ast
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPORT = Path(__file__).resolve().parent
ROOT = next(parent for parent in REPORT.parents if (parent / 'project.godot').is_file())
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment


def git(*arguments):
    return subprocess.check_output(['git', '-C', str(ROOT), *arguments], env=git_environment())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def methods(text):
    return {node.name: node for node in ast.walk(ast.parse(text))
        if isinstance(node, ast.FunctionDef) and node.name.startswith('test_')}


def assertions(node):
    return Counter(ast.dump(value) for value in ast.walk(node)
        if isinstance(value, ast.Call) and isinstance(value.func, ast.Attribute)
        and isinstance(value.func.value, ast.Name) and value.func.value.id == 'self'
        and value.func.attr.startswith('assert'))


def main():
    baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
    plan = json.loads((REPORT / 'baseline/adaptation-plan.json').read_text())
    base = baseline['base']
    new = {'tools/qa/performance/__init__.py', 'tools/qa/performance/test_performance_context.py'}
    source_after = set(baseline['sources']) | new
    prefix = REPORT.relative_to(ROOT).as_posix() + '/'
    changed = set(filter(None, git('diff', '--no-renames', base, '--name-only', '-z').decode().split('\0')))
    untracked = set(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
    assert all(name in source_after or name.startswith(prefix) for name in changed | untracked)
    for name, row in baseline['sources'].items():
        original = gzip.decompress((REPORT / 'baseline' / (name.replace('/', '--') + '.gz')).read_bytes())
        assert original == git('show', base + ':' + name)
        assert hashlib.sha256(original).hexdigest() == row['sha256']
        assert (ROOT / name).stat().st_mode & 0o777 == row['mode'], name
    for name, row in plan['changes'].items():
        assert git('show', base + ':' + name).decode() == row['before']
        assert (ROOT / name).read_text() == row['after'], name
    for name in ['AGENTS.md', '.gitattributes', 'docs/backlog/README.md', 'wiki/planning/sources.json',
        'wiki/articles/tools-migration-map.md', 'docs/epics/visual-overhaul-2026-10/backlog.json']:
        assert git('show', base + ':' + name) == (ROOT / name).read_bytes(), name
    cards = 'docs/epics/refactoring-2026-10/TASKS.md'
    before = re.split(r'(?=^## REFACTOR-)', git('show', base + ':' + cards).decode(), flags=re.M)
    after = re.split(r'(?=^## REFACTOR-)', (ROOT / cards).read_text(), flags=re.M)
    assert len(before) == len(after) == 8
    assert all(left == right for left, right in zip(before, after)
        if not left.startswith('## REFACTOR-03 '))
    architecture = 'tools/quality/check_architecture.sh'
    marker = 'python3 tools/run.py qa.compatibility.test_compatibility_cli\n'
    expected = git('show', base + ':' + architecture).decode().replace(marker,
        marker + 'python3 tools/run.py qa.performance.test_performance_context\n')
    assert (ROOT / architecture).read_text() == expected
    preserved = 0
    for name in ['tools/test_optimization_audit.py', 'tools/test_storage_perf.py',
        'tools/test_performance_gate.py', 'tools/test_perf_contract.py', 'tools/test_redraw_output.py']:
        previous, current = methods(git('show', base + ':' + name)), methods((ROOT / name).read_text())
        assert set(previous) == set(current), name
        assert all(assertions(previous[key]) == assertions(current[key]) for key in previous), name
        preserved += len(previous)
    assert preserved == 108

    moves = {}
    for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move',
        'assets-build-move', 'alpha-slicing-move', 'compatibility-move']:
        document = json.loads((REPORT.parent / phase / 'migration.json').read_text())
        moves.update({row['old_path']: row['target'] for row in document['moves']})
    contracts = REPORT.parent / 'baseline/source-contracts.json'
    assert digest(contracts) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
    child = ast.literal_eval(next(node.value for node in ast.parse(
        (REPORT.parent / 'snapshot-contracts.py').read_text()).body
        if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name)
        and target.id == 'CHILD' for target in node.targets)))
    fields = 0
    for row in json.loads(contracts.read_text())['modules'].values():
        module = moves.get(row['source'], row['source']).removesuffix('.py').replace('/', '.')
        process = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
            env=git_environment(), capture_output=True, text=True, timeout=30)
        assert process.returncode == 0 and not process.stderr, (module, process.stderr)
        assert json.loads(process.stdout) == row['fields'], module
        fields += len(row['fields'])
    assert fields == 37
    tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
    root_count = sum(name.startswith('tools/') and name.count('/') == 1
        and Path(name).suffix in {'.py', '.gd', '.mjs', '.swift', '.sh', '.gdshader'} for name in tracked)
    assert root_count == 314
    uids = json.loads((REPORT.parent / 'baseline/local-uids.json').read_text())
    for row in uids['local_only_UID']:
        paths = [ROOT / name for name in [row['old_path'], row['target']] if (ROOT / name).is_file()]
        assert len(paths) == 1 and paths[0].read_text().strip() == row['value']
        name = paths[0].relative_to(ROOT).as_posix()
        assert name not in tracked and git('check-ignore', '--', name).strip()
    assert len(uids['local_only_UID']) == 85
    anchor = uids['retained_anchor_local_UID']
    assert digest(ROOT / anchor['path']) == anchor['sha256']

    red = json.loads((REPORT / 'context-red.json').read_text())
    green = json.loads((REPORT / 'context-green.json').read_text())
    test = ROOT / 'tools/qa/performance/test_performance_context.py'
    assert red['test_sha256'] == green['test_sha256'] == digest(test)
    assert red['exit'] == 1 and green['exit'] == 0 and green['tests'] == 5
    profile = json.loads((REPORT / 'after-profile.json').read_text())
    assert profile['actual_before_after_equal'] and not profile['new_GPU_FPS_admission']
    assert len(profile['outputs']['actual_headless_crash_workers']['cases']) == 14
    scope = {'base': base, 'version': '0.0.370', 'root_sources': 314,
        'source_root_sites': 8, 'Git_read_sites': 9, 'shell_roots': 2,
        'existing_source_files_changed': 12, 'physical_source_moves': 0, 'UID_moves': 0,
        'old_test_methods_and_assertions_preserved': preserved, 'new_real_context_tests': 5,
        'historical_fields': fields, 'author_ignored_UID_preserved': 85, 'anchor_preserved': True,
        'parallel07_excluded': True, 'other_six_refactor_cards_unchanged': True,
        'runtime_artwork_old_reports_plans_unchanged': True, 'full_task03_accepted': False,
        'source_paths_after': sorted(source_after), 'removed_source_paths': []}
    (REPORT / 'scope.json').write_text(json.dumps(scope, ensure_ascii=False, indent=2) + '\n')
    (REPORT / 'migration.json').write_text(json.dumps({'base': base, 'root_sources_after_moves': 314,
        'moves': [], 'phase': 'source-root/Git preparation only'}, indent=2) + '\n')
    print(json.dumps({'source_after': len(source_after), 'root': root_count,
        'old_tests': preserved, 'new_context_tests': 5, 'fields': fields, 'UID': 85}))


if __name__ == '__main__':
    main()

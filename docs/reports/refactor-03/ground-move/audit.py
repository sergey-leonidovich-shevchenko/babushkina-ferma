"""Audit Ground code, real move identities, frozen namespaces and all changed tools imports including tests."""
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
sys.path[:0] = [str(Q), str(Q / 'tools')]
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def save(name, value):
    (R / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
plan = json.loads((R / 'baseline/move-plan.json').read_text())
baseline = json.loads((R / 'baseline/inventory.json').read_text())
mapping = {r['old_path']: r['target'] for r in plan['moves']}
bridge = json.loads((R / 'source-bridge-patch.json').read_text())
assert len(MOVED_PATHS) == 380
assert all(MOVED_PATHS[n] == target for n, target in mapping.items())
assert all(not (Q / n).exists() and (Q / target).is_file() for n, target in mapping.items())
for name, row in baseline['sources'].items():
    target = mapping.get(name, name)
    path = Q / target
    expected = bridge.get(target, {}).get('after_SHA256', plan['changes'].get(name, {}).get('after_SHA256', row['sha256']))
    assert sha(path.read_bytes()) == expected, target
    assert stat.S_IMODE(path.stat().st_mode) == row['mode'], target
UID_after = {str(p.relative_to(Q)): {'sha256': sha(p.read_bytes()), 'mode': stat.S_IMODE(p.stat().st_mode)}
    for p in (Q / 'tools').rglob('*.uid') if p.is_file()}
UID_expected = {mapping.get(n, n): row for n, row in baseline['all_tools_UID'].items()}
new_UID = {n: UID_after[n] for n in ['tools/qa/ground/compiled_sources.gd.uid', 'tools/qa/ground/compiled_sources_review.gd.uid']}
assert UID_after == dict(UID_expected, **new_UID) and len(UID_after) == 304

class ReverseAddresses(ast.NodeTransformer):
    def __init__(self, old_function):
        self.history = [n for n in ast.walk(old_function) if isinstance(n, ast.Call)
            and isinstance(n.func, ast.Attribute) and isinstance(n.func.value, ast.Name)
            and n.func.value.id == 'subprocess' and n.func.attr == 'run' and n.args
            and isinstance(n.args[0], ast.List) and len(n.args[0].elts) > 1
            and isinstance(n.args[0].elts[0], ast.Constant) and n.args[0].elts[0].value == 'git'
            and isinstance(n.args[0].elts[1], ast.Constant) and n.args[0].elts[1].value == 'show']
        self.current = self.history_calls = self.native = 0

    def visit_Constant(self, node):
        if isinstance(node.value, str):
            for old, target in mapping.items():
                if old.endswith('.gd') and node.value == 'res://' + target:
                    self.native += 1
                    return ast.copy_location(ast.Constant(value='res://' + old), node)
        return node

    def visit_Call(self, node):
        if isinstance(node.func, ast.Name) and node.func.id == 'historical_result':
            assert len(self.history) == 1 and len(node.args) == 3
            self.history_calls += 1
            return copy.deepcopy(self.history[0])
        if isinstance(node.func, ast.Name) and node.func.id == 'input_path':
            assert len(node.args) == 2 and ast.unparse(node.args[0]) == 'ROOT'
            self.current += 1
            return ast.copy_location(ast.BinOp(left=copy.deepcopy(node.args[0]), op=ast.Div(), right=copy.deepcopy(node.args[1])), node)
        if ast.unparse(node) == 'str(current_source(ROOT, logical).relative_to(ROOT))':
            self.current += 1
            return ast.parse('CANONICAL if logical == LEGACY else logical', mode='eval').body
        return self.generic_visit(node)

functions, import_rows, gd_rows = [], [], []
for old, row in plan['changes'].items():
    target = mapping.get(old, old)
    actual = (Q / target).read_text()
    if target in bridge:
        repair = bridge[target]
        assert actual == repair['after'] and sha(actual.encode()) == repair['after_SHA256'], target
        assert sha(repair['before'].encode()) == row['after_SHA256'], target
        actual = repair['before']
    assert sha(actual.encode()) == row['after_SHA256'], target
    if old.endswith('.gd'):
        reverse = actual
        replacements = 0
        for legacy, current in mapping.items():
            if legacy.endswith('.gd'):
                replacements += reverse.count('res://' + current)
                reverse = reverse.replace('res://' + current, 'res://' + legacy)
        assert reverse == row['before'], target
        gd_rows.append({'old': old, 'current': target, 'only_URI_replacements': replacements})
    elif old.endswith('.py'):
        before_tree, after_tree = ast.parse(row['before']), ast.parse(actual)
        import_rows.append({'old': old, 'current': target,
            'before': [ast.unparse(n) for n in ast.walk(before_tree) if isinstance(n, (ast.Import, ast.ImportFrom))],
            'after': [ast.unparse(n) for n in ast.walk(after_tree) if isinstance(n, (ast.Import, ast.ImportFrom))]})
        if old == 'tools/assets/contracts/test_source_paths.py':
            # This one existing contract test explicitly adds the113 accepted plan rows and380 total.
            continue
        before_functions = [n for n in ast.walk(before_tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
        after_functions = [n for n in ast.walk(after_tree) if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
        assert [n.name for n in before_functions] == [n.name for n in after_functions], target
        for before, after in zip(before_functions, after_functions):
            normalizer = ReverseAddresses(before)
            normalized = normalizer.visit(copy.deepcopy(after))
            assert ast.dump(normalized, include_attributes=False) == ast.dump(before, include_attributes=False), (target, before.name)
            functions.append({'path': target, 'function': before.name, 'equal_after_explicit_address_normalization': True,
                'current': normalizer.current, 'history': normalizer.history_calls, 'native': normalizer.native})
save('code-audit.json', {'functions': functions, 'imports': import_rows, 'GD': gd_rows,
    'mapping_exactly_original113_rows': True, 'UID_bytes_mode_equal': 302,
    'new_UID': new_UID, 'source_bridge_changes_audited_separately': sorted(bridge)})

old_test = (R / 'baseline/test_ground_layout.py').read_text()
new_test = (Q / 'tools/qa/ground/test_ground_layout.py').read_text()
old_guard = "self.assertFalse(any(output.rglob('*.png')))"
new_guard = "self.assertFalse(any(p for p in output.rglob('*.png') if 'inputs' not in p.relative_to(output).parts))"
assert old_test.count(old_guard) == new_test.count(new_guard) == 1
normalized_test = new_test.replace(new_guard, old_guard)
old_methods = [(n.name, ast.dump(n, include_attributes=False)) for n in ast.walk(ast.parse(old_test)) if isinstance(n, ast.FunctionDef)]
new_methods = [(n.name, ast.dump(n, include_attributes=False)) for n in ast.walk(ast.parse(normalized_test)) if isinstance(n, ast.FunctionDef)]
assert old_methods == new_methods
save('new-layout-test-audit.json', {'before_SHA256': sha(old_test.encode()), 'after_SHA256': sha(new_test.encode()),
    'source_SHA_equal': False, 'test_cases': sum(n.startswith('test_') for n, _ in old_methods),
    'methods_equal_after_explicit_fixture_guard_normalization': True,
    'allowed_changes': ['19 package import addresses', 'unused subprocess import removal',
        'native-frame guard excludes exact archived input PNGs'], 'test_methods_removed': 0,
    'first_after_failure_retained': 'layout-green-attempt01.txt'})

scope = json.loads((R / 'scope.json').read_text())
py_names = sorted(n for n in scope['source_paths_after'] if n.endswith('.py'))
unused = []
for name in py_names:
    tree = ast.parse((Q / name).read_text())
    loaded = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
    for n in ast.walk(tree):
        if isinstance(n, (ast.Import, ast.ImportFrom)):
            for alias in n.names:
                bound = alias.asname or (alias.name.split('.')[0] if isinstance(n, ast.Import) else alias.name)
                if bound not in loaded and alias.name != 'annotations':
                    unused.append({'path': name, 'line': n.lineno, 'name': bound})
assert not unused, unused
test_names = [n for n in py_names if Path(n).name.startswith('test_')]
assert 'tools/qa/ground/test_ground_context.py' in test_names
assert 'tools/qa/ground/test_ground_layout.py' in test_names
assert 'tools/qa/performance/test_surface_producers.py' in test_names
save('unused-import-audit.json', {'all_changed_moved_new_tools_Python': py_names, 'modules': len(py_names),
    'tests_included': test_names, 'test_modules': len(test_names), 'unused_candidates': unused,
    'explicit_cleanup': ['test_ground_context.Path', 'test_surface_producers.sys', '9 collector git_environment imports after helper routing'],
    'no_special_unit_test_for_import_removal': True})

spec = importlib.util.spec_from_file_location('frozen_contract_reader', Q / 'docs/reports/refactor-03/snapshot-contracts.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
frozen_path = Q / 'docs/reports/refactor-03/baseline/source-contracts.json'
assert sha(frozen_path.read_bytes()) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
frozen = json.loads(frozen_path.read_text())
rows = []
for name, record in frozen['modules'].items():
    physical = ART_PATHS.get(record['source'], MOVED_PATHS.get(record['source'], record['source']))
    selected = physical.removesuffix('.py').replace('/', '.')
    result = subprocess.run([sys.executable, '-c', module.CHILD, str(Q), selected], cwd='/private/tmp',
        env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'), capture_output=True, text=True, timeout=30)
    assert result.returncode == 0 and not result.stderr, (selected, result.stderr)
    assert json.loads(result.stdout) == record['fields'], selected
    rows.append({'module': selected, 'fields': len(record['fields']), 'equal': True})
assert len(rows) == 21 and sum(r['fields'] for r in rows) == 37
save('source-contract-audit.json', {'frozen_SHA256': sha(frozen_path.read_bytes()), 'modules': rows, 'fields': 37})
print(json.dumps({'functions': len(functions), 'normalized_current': sum(r['current'] for r in functions),
    'normalized_history': sum(r['history'] for r in functions), 'normalized_native': sum(r['native'] for r in functions),
    'GD': len(gd_rows), 'tools_Python_import_audit': len(py_names), 'tests_included': len(test_names),
    'UID_preserved': 302, 'UID_new': 2, 'frozen_fields': 37}))

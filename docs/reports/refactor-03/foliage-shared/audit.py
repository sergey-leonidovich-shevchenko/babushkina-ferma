"""Audit the remaining tools moves against accepted byte inventories and the original full plan."""
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
R = Q / 'docs/reports/refactor-03/foliage-shared'
sys.path[:0] = [str(Q), str(Q / 'tools')]
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def save(name, value):
    (R / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')

def dump(node):
    return ast.dump(node, include_attributes=False)

plan = json.loads((R / 'move-plan.json').read_text())
mechanical = json.loads((R / 'baseline/mechanical-plan.json').read_text())
baseline = json.loads((R / 'baseline/inventory.json').read_text())
mapping = plan['mapping']
ignored = {n: row['target'] for n, row in baseline['moves']['ignored_UID'].items()}
assert len(mapping) == 111 and len(MOVED_PATHS) == 491
assert all(MOVED_PATHS[n] == target for n, target in mapping.items())
assert all(not (Q / n).exists() and (Q / target).is_file() for n, target in {**mapping, **ignored}.items())

# A real child that executes a moved test must enter through the common launcher.
visibility_name = 'tools/qa/foliage/test_foliage_visibility.py'
visibility_before = (R / 'baseline/test_foliage_visibility-before-child-repair.py').read_text()
visibility_after = (Q / visibility_name).read_text()
assert visibility_after == visibility_before.replace(
    'from tools.common.git import git_environment\n',
    'from tools.common.git import git_environment\nfrom tools.common.paths import project_root\n', 1).replace(
    'sys.executable, str(Path(__file__).resolve()),',
    "sys.executable, str(project_root(__file__) / 'tools/run.py'),\n                'qa.foliage.test_foliage_visibility',", 1)
save('visibility-child-repair.json', {
    'before_SHA256': sha(visibility_before.encode()), 'after_SHA256': sha(visibility_after.encode()),
    'change': 'same actual child testcase through tools/run.py from a foreign cwd; imports and Git controls retained',
    'test_methods_removed': 0, 'failed_profile': 'after-attempt01/after-profile.json',
    'targeted_green': 'visibility-child-green.txt'})

shore_name='tools/qa/world/test_shore_kit.py'
shore_before=(R/'baseline/test_shore_kit-before-fixture-repair.py').read_text()
shore_after=(Q/shore_name).read_text()
assert shore_after==shore_before.replace('from tools.common.git import git_environment\n',
    'from tools.common.git import git_environment\nfrom tools.qa.world.source_inputs import input_path\n',1).replace(
    '(kit.ROOT/name[6:]).resolve()', "(input_path(kit.ROOT,name[6:]) if name.startswith('res://tools/') else kit.ROOT/name[6:]).resolve()",1).replace(
    "target = self.root/'tools/shore_kit_review.gd'", "target = input_path(self.root,'tools/shore_kit_review.gd')",1).replace(
    'target.parent.mkdir(exist_ok=True)', 'target.parent.mkdir(parents=True,exist_ok=True)',1).replace(
    "shutil.copyfile(kit.ROOT/'tools/shore_kit_review.gd',target)", "shutil.copyfile(input_path(kit.ROOT,'tools/shore_kit_review.gd'),target)",1)
save('shore-fixture-repair.json',{'before_SHA256':sha(shore_before.encode()),'after_SHA256':sha(shore_after.encode()),
    'change':'real copy source and target use canonical input paths; original archived metadata and all ten test methods/assertions stay exact',
    'test_methods_removed':0,'failed_profile':'after-attempt02/after-profile.json'})

identity = []
cleanup = json.loads((R / 'unused-import-cleanup.json').read_text())['modules'] if (R / 'unused-import-cleanup.json').is_file() else {}
integration = json.loads((R / 'integration-repairs.json').read_text())['modules'] if (R / 'integration-repairs.json').is_file() else {}
special = {'tools/assets/contracts/source_paths.py', 'tools/assets/contracts/test_source_paths.py',
           'tools/quality/check_architecture.sh'}
for name, row in baseline['sources'].items():
    target = mapping.get(name, name)
    path = Q / target
    if name in special:
        continue
    expected = plan['changes'].get(name, {}).get('after_SHA256', row['SHA256'])
    if target == visibility_name:
        assert sha(visibility_before.encode()) == expected
        expected = sha(visibility_after.encode())
    if target == shore_name:
        assert sha(shore_before.encode()) == expected
        expected = sha(shore_after.encode())
    if target in cleanup:
        assert cleanup[target]['before_SHA256'] == expected
        expected = cleanup[target]['after_SHA256']
    if target in integration:
        assert integration[target]['before_SHA256'] == expected
        expected = integration[target]['after_SHA256']
    assert sha(path.read_bytes()) == expected, target
    assert stat.S_IMODE(path.stat().st_mode) == row['mode'], target
    identity.append({'old': name, 'current': target, 'SHA256': expected, 'mode': row['mode']})

UID_after = {str(p.relative_to(Q)): {'SHA256': sha(p.read_bytes()), 'mode': stat.S_IMODE(p.stat().st_mode)}
    for p in (Q / 'tools').rglob('*.uid') if p.is_file()}
UID_expected = {{**mapping, **ignored}.get(n, n): row for n, row in baseline['all_UID'].items()}
assert UID_after == UID_expected and len(UID_after) == 304

class ReverseAddresses(ast.NodeTransformer):
    """Reverse only inserted address/context calls which correspond to an exact old AST node."""
    def __init__(self, before):
        self.old_calls = [n for n in ast.walk(before) if isinstance(n, ast.Call)]
        self.old_dumps = {dump(n) for n in ast.walk(before)}
        self.counts = dict(current=0, history=0, Git_env=0, native=0, roots=0)

    def visit_Constant(self, node):
        if isinstance(node.value, str):
            for old, target in mapping.items():
                if old.endswith(('.gd', '.gdshader')) and node.value == 'res://' + target:
                    candidate = ast.Constant(value='res://' + old)
                    if dump(candidate) in self.old_dumps:
                        self.counts['native'] += 1
                        return ast.copy_location(candidate, node)
        return node

    def visit_Call(self, node):
        node = self.generic_visit(node)
        if isinstance(node.func, ast.Name) and node.func.id == 'input_path' and len(node.args) == 2:
            candidate = ast.BinOp(left=copy.deepcopy(node.args[0]), op=ast.Div(), right=copy.deepcopy(node.args[1]))
            if dump(candidate) in self.old_dumps:
                self.counts['current'] += 1
                return ast.copy_location(candidate, node)
        if isinstance(node.func, ast.Name) and node.func.id == 'historical_bytes' and len(node.args) == 3:
            if dump(node) in self.old_dumps:
                return node
            for old in self.old_calls:
                if not (isinstance(old.func, ast.Attribute) and isinstance(old.func.value, ast.Name)
                        and old.func.value.id == 'subprocess' and old.func.attr == 'check_output'
                        and old.args and isinstance(old.args[0], ast.List)):
                    continue
                argv = old.args[0].elts
                if len(argv) != 3 or [ast.literal_eval(n) for n in argv[:2]] != ['git', 'show']:
                    continue
                expected = ast.BinOp(left=ast.BinOp(left=copy.deepcopy(node.args[1]), op=ast.Add(),
                    right=ast.Constant(value=':')), op=ast.Add(), right=copy.deepcopy(node.args[2]))
                if dump(argv[2]) == dump(expected):
                    self.counts['history'] += 1
                    return copy.deepcopy(old)
            raise AssertionError(('unmatched history', ast.unparse(node)))
        if ast.unparse(node) == 'project_root(__file__)':
            candidate = ast.parse('Path(__file__).resolve().parents[1]', mode='eval').body
            if dump(candidate) in self.old_dumps:
                self.counts['roots'] += 1
                return candidate
        if isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name) and node.func.value.id == 'subprocess':
            candidate = copy.deepcopy(node)
            candidate.keywords = [k for k in candidate.keywords if not (k.arg == 'env' and ast.unparse(k.value) == 'git_environment()')]
            if len(candidate.keywords) < len(node.keywords) and dump(candidate) in self.old_dumps:
                self.counts['Git_env'] += 1
                return candidate
        return node

code_rows = []
class WithoutImports(ast.NodeTransformer):
    def visit_Import(self, node):
        return None
    def visit_ImportFrom(self, node):
        return None

for old, row in mechanical['changes'].items():
    target = mapping.get(old, old)
    before, after = row['before'], row['after']
    if old.endswith(('.gd', '.gdshader')):
        reversed_text = after
        for logical, current in mapping.items():
            if logical.endswith(('.gd', '.gdshader')):
                reversed_text = reversed_text.replace('res://' + current, 'res://' + logical)
        assert reversed_text == before, target
        code_rows.append({'path': target, 'only_URI_changes': row['sites']['URI']})
    elif old.endswith('.py'):
        before_tree = ast.parse(before)
        after_tree = ast.parse(after)
        before_tree = WithoutImports().visit(before_tree)
        after_tree = WithoutImports().visit(after_tree)
        reverse = ReverseAddresses(before_tree)
        after_tree = reverse.visit(after_tree)
        if dump(before_tree) != dump(after_tree):
            import difflib
            print(''.join(difflib.unified_diff(ast.unparse(before_tree).splitlines(True), ast.unparse(after_tree).splitlines(True))))
            raise AssertionError(target)
        code_rows.append({'path': target, 'AST_equal_after_closed_address_normalization': True, **reverse.counts,
            'functions': sum(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) for n in ast.walk(before_tree)),
            'old_test_methods': [n.name for n in ast.walk(before_tree) if isinstance(n, ast.FunctionDef) and n.name.startswith('test_')]})

# Explicit provenance adapters are separated from the mechanical AST proof.
provenance = {}
for old, row in plan['changes'].items():
    if 'explicit_provenance_changes' in row:
        target = mapping.get(old, old)
        if target in integration:
            assert integration[target]['before_SHA256'] == row['after_SHA256']
            assert sha((Q / target).read_bytes()) == integration[target]['after_SHA256']
        else:
            assert (Q / target).read_text() == row['after']
        provenance[target] = {'reason': row['explicit_provenance_changes'],
            'before_SHA256': row['before_SHA256'], 'after_SHA256': row['after_SHA256'],
            'mechanical_stage_SHA256': mechanical['changes'].get(old, {}).get('after_SHA256')}
save('code-audit.json', {'mechanical_modules': code_rows, 'explicit_provenance': provenance,
    'visibility_test_launcher_audited_separately': True, 'UID_preserved': 304,
    'identity_sources': len(identity), 'mapping_added_original_rows': 111})
save('source-identity.json', {'sources': identity, 'all_UID_after': UID_after})

# Complete original plan, including earlier packages and the documented PIL correction.
original_path = Q / 'docs/reports/refactor-01/integration-1/migration-plan.json'
original = json.loads(original_path.read_text())
coverage = []
for old, row in original['assignments'].items():
    target = row['target']
    if old == 'tools/import_pixabay_assets.py':
        target = 'tools/assets/authoring/import_pixabay_assets.py'
    assert (Q / target).is_file() and not (Q / target).is_symlink(), (old, target)
    if row['action'] in {'move', 'move_uid_with_source'} and old != 'tools/performance_protocol.py':
        assert not (Q / old).exists(), old
    coverage.append({'old': old, 'current': target, 'action': row['action'], 'present': True,
        'retained_extra_facade': old == 'tools/performance_protocol.py'})
root_sources = sorted(str(p.relative_to(Q)) for p in (Q / 'tools').iterdir()
    if p.is_file() and p.suffix in {'.py', '.sh', '.gd', '.mjs', '.swift'})
assert len(coverage) == 779 and len(root_sources) == 11
save('full-plan-coverage.json', {'original_plan_SHA256': sha(original_path.read_bytes()), 'assignments': coverage,
    'original_rows_accounted_for': 779, 'root_source_budget': 30, 'root_sources': root_sources,
    'effective_target_exception': {'tools/import_pixabay_assets.py': {
        'target': 'tools/assets/authoring/import_pixabay_assets.py',
        'evidence': 'docs/reports/refactor-03/image-review-move/migration.json'}},
    'retained_extra_facade': {'tools/performance_protocol.py':
        'Accepted performance package371/372: frozen imports require one identity-preserving facade; tools/README.md'},
    'generic_map_subset': 491, 'generic_map_is_not_full_original_plan': True})

python_names = {mapping.get(n, n) for n in mapping if n.endswith('.py')}
python_names.update(mapping.get(n, n) for n in plan['changes'] if n.startswith('tools/') and n.endswith('.py'))
python_names.update(str(p.relative_to(Q)) for p in (Q / 'tools/qa/foliage').glob('test_*.py'))
python_names.update({'tools/assets/contracts/source_paths.py', 'tools/assets/contracts/test_source_paths.py'})
python_names.update(n for n in integration if n.startswith('tools/') and n.endswith('.py'))
unused = []
for name in sorted(python_names):
    tree = ast.parse((Q / name).read_text())
    loaded = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            for alias in node.names:
                bound = alias.asname or (alias.name.split('.')[0] if isinstance(node, ast.Import) else alias.name)
                if bound not in loaded and alias.name != 'annotations':
                    unused.append({'path': name, 'line': node.lineno, 'name': bound})
save('unused-import-audit.json', {'all_changed_moved_new_tools_Python': sorted(python_names), 'modules': len(python_names),
    'test_modules': len([n for n in python_names if Path(n).name.startswith('test_')]), 'unused_candidates': unused,
    'explicit_import_only_cleanup': sorted(cleanup), 'no_special_unit_test_for_import_removal': True})
assert not unused, unused

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
print(json.dumps({'mechanical_modules': len(code_rows), 'explicit_provenance': len(provenance),
    'UID_preserved': 304, 'original_plan_rows': 779, 'root': 11, 'Python_import_audit': len(python_names),
    'frozen_fields': 37}))

"""Bound every planned address change, then audit actual layout/contracts/UID and preserved evidence."""
import argparse
import ast
from collections import Counter
import copy
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

parser = argparse.ArgumentParser()
parser.add_argument('--plan-only', action='store_true')
args = parser.parse_args()
plan = json.loads((REPORT / 'baseline/move-plan.json').read_text())
baseline = json.loads((REPORT / 'baseline/inventory.json').read_text())
mapping = {row['old_path']: row['target'] for row in plan['moves']}
modules = {Path(name).stem for name in mapping if name.endswith('.py')}


def dump(node):
    return ast.dump(node, include_attributes=False)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def git(*arguments):
    return subprocess.check_output(['git', '--no-replace-objects', '-C', str(ROOT), *arguments], env=git_environment())


def imports(tree):
    return [node for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom))]


def remap_import(node, name):
    """Allow physical package names and only the four independently reported unused aliases."""
    node = copy.deepcopy(node)
    if name == 'tools/post_motion_verify.py' and isinstance(node, ast.Import):
        node.names = [alias for alias in node.names if alias.name != 'subprocess']
    if name in {'tools/post_motion_verify.py', 'tools/object_command_collect.py'} and isinstance(node, ast.ImportFrom) and node.module in {'common.git', 'tools.common.git'}:
        assert [alias.name for alias in node.names] == ['git_environment']
        return None
    if name == 'tools/analyze_water_audit.py' and isinstance(node, ast.ImportFrom) and node.module == 'pathlib':
        assert [alias.name for alias in node.names] == ['Path']
        return None
    if isinstance(node, ast.ImportFrom):
        if node.module in modules:
            node.module = 'tools.qa.world.' + node.module
        elif node.module and node.module.startswith('tools.') and node.module[6:] in modules:
            node.module = 'tools.qa.world.' + node.module[6:]
        elif node.module == 'tools' and any(alias.name in modules for alias in node.names):
            assert all(alias.name in modules for alias in node.names)
            node.module = 'tools.qa.world'
        elif name in mapping and node.module and node.module.startswith('common.'):
            node.module = 'tools.' + node.module
    elif any(alias.name in modules for alias in node.names):
        assert len(node.names) == 1
        node = ast.ImportFrom(module='tools.qa.world', names=node.names, level=0)
    return node


class RemoveImports(ast.NodeTransformer):
    def visit_Import(self, node):
        return None
    def visit_ImportFrom(self, node):
        return None


class PlantInputs(ast.NodeTransformer):
    def __init__(self, name):
        self.name = name
        self.count = 0
    def visit_Call(self, node):
        node = self.generic_visit(node)
        if self.name == 'tools/plant_depth_collect.py' and isinstance(node.func, ast.Name) and node.func.id == 'input_path':
            assert not node.keywords and len(node.args) == 2 and ast.unparse(node.args[0]) == 'ROOT'
            assert ast.unparse(node.args[1]) in {'name', 'n'}
            self.count += 1
            return ast.BinOp(left=node.args[0], op=ast.Div(), right=node.args[1])
        if self.name == 'tools/plant_depth_verify.py' and isinstance(node.func, ast.Name) and node.func.id == 'historical_bytes':
            assert not node.keywords and [ast.unparse(arg) for arg in node.args] == ['ROOT', 'base', 'name']
            self.count += 1
            return ast.parse("subprocess.check_output(['git','show',base+':'+name],cwd=ROOT)", mode='eval').body
        return node


function_count = import_count = address_count = 0
for name, row in plan['changes'].items():
    assert sha(row['before'].encode()) == row['before_SHA256']
    assert sha(row['after'].encode()) == row['after_SHA256']
    assert git('show', plan['base'] + ':' + name).decode() == row['before']
    text = row['after']
    for old, target in mapping.items():
        if old.endswith('.gd'):
            address_count += text.count('res://' + target)
            text = text.replace('res://' + target, 'res://' + old)
    if name.endswith('.gd'):
        assert text == row['before'], name
        continue
    assert name.endswith('.py'), name
    left_text = row['before']
    if name == 'tools/qa/world/test_world_context.py':
        for old, new in {
            '(render_order.ROOT/n).read_bytes()': 'current_source(render_order.ROOT,n).read_bytes()',
            'target=own/name;': 'target=current_source(own,name);',
            '(own/name).read_bytes()': 'current_source(own,name).read_bytes()',
        }.items():
            assert old in left_text and new not in left_text
            address_count += text.count(new)
            text = text.replace(new, old)
    if name == 'tools/qa/world/test_world_source_history.py' and plan.get('water_fixture_current_address_repaired'):
        old = "(render_order.ROOT/'tools/analyze_water_audit.py').read_bytes()"
        new = "current_source(render_order.ROOT,'tools/analyze_water_audit.py').read_bytes()"
        assert text.count(new) == 1
        text = text.replace(new, old)
        address_count += 1
    for label, path in [('producer14', 'tools/qa/world/test_world_producers.py'), ('history13', 'tools/qa/world/test_world_source_history.py')]:
        if name == path:
            before_path = REPORT / 'baseline' / (label + '-before.py')
            assert sha(before_path.read_bytes()) == plan['external_control_test_source'][label]['before_SHA256']
            left_text = before_path.read_text()
    left, right = ast.parse(left_text), ast.parse(text)
    expected_imports = [remap_import(node, name) for node in imports(left)]
    expected_imports = [node for node in expected_imports if node is not None]
    if name == 'tools/qa/world/test_world_source_history.py' and plan.get('water_fixture_current_address_repaired'):
        source_import = [node for node in expected_imports if isinstance(node, ast.ImportFrom) and node.module == 'tools.assets.contracts.source_paths']
        assert len(source_import) == 1 and [alias.name for alias in source_import[0].names] == ['MOVED_PATHS']
        source_import[0].names.append(ast.alias(name='current_source', asname=None))
    if name == 'tools/plant_depth_collect.py':
        expected_imports.append(ast.parse('from tools.qa.world.source_inputs import input_path').body[0])
    if name == 'tools/plant_depth_verify.py':
        expected_imports.append(ast.parse('from tools.qa.world.source_inputs import historical_bytes').body[0])
    assert Counter(map(dump, expected_imports)) == Counter(map(dump, imports(right))), name
    import_count += len(expected_imports)
    for unavailable in ({'subprocess', 'git_environment'} if name == 'tools/post_motion_verify.py'
                        else {'git_environment'} if name == 'tools/object_command_collect.py'
                        else {'Path'} if name == 'tools/analyze_water_audit.py' else set()):
        assert not any(isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load) and node.id == unavailable for node in ast.walk(right)), (name, unavailable)
    normalizer = PlantInputs(name)
    right = normalizer.visit(right)
    address_count += normalizer.count
    if name == 'tools/assets/contracts/source_paths.py':
        def table(tree):
            return next(node for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'MOVED_PATHS' for target in node.targets))
        old, new = table(left), table(right)
        previous = ast.literal_eval(old.value.args[0])
        actual = ast.literal_eval(new.value.args[0])
        assert len(previous) == 133 and len(actual) == 267 and actual == {**previous, **mapping}
        new.value.args[0] = copy.deepcopy(old.value.args[0])
    if name == 'tools/assets/contracts/test_source_paths.py':
        method = next(node for node in ast.walk(right) if isinstance(node, ast.FunctionDef) and node.name == 'test_table_matches_accepted_plan_and_actual_files')
        kept = []
        removed = 0
        for node in method.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and node.targets[0].id in {'world', 'world_deferred'}:
                if node.targets[0].id == 'world_deferred':
                    assert set(ast.literal_eval(node.value)) == set(plan['deferred_within_same_task'])
                else:
                    assert ast.unparse(node.value) == "{old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'world' and old != row['target'] and (old not in world_deferred)}"
                removed += 1
                continue
            if isinstance(node, ast.Expr) and ast.unparse(node) in {'self.assertEqual(len(world), 134)', 'expected.update(world)'}:
                removed += 1
                continue
            if isinstance(node, ast.Expr) and ast.unparse(node) == 'self.assertEqual(len(MOVED_PATHS), 267)':
                node = ast.parse('self.assertEqual(len(MOVED_PATHS), 133)').body[0]
            kept.append(node)
        assert removed == 4
        method.body = kept
    assert dump(RemoveImports().visit(left)) == dump(RemoveImports().visit(right)), name
    function_count += sum(isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) for node in ast.walk(left))
preflight = {'base': plan['base'], 'changed_code_modules': len(plan['changes']),
             'functions_preserved_address_only_or_explicit_test_extensions': function_count,
             'validated_import_bindings': import_count, 'normalized_address_sites': address_count,
             'old_leaf_tests_and_assertions_preserved': True, 'new_producer_methods': 14,
             'new_history_methods': 13, 'new_non_import_test_AST_equal': True,
             'source_map_exact_accepted_assignments': 134, 'source_map_after': 267,
             'physical_moves_planned': 92, 'P3_unused_imports_removed': 4}
if args.plan_only:
    (REPORT / 'plan-preflight.json').write_text(json.dumps(preflight, indent=2) + '\n')
    shutil.copyfile(__file__, REPORT / 'audit.py')
    print(json.dumps(preflight))
    raise SystemExit(0)

assert (ROOT / 'VERSION').read_text().strip() == '0.0.377'
after_names = {mapping.get(name, name) for name in baseline['sources']}
for name, row in baseline['sources'].items():
    target = mapping.get(name, name)
    path = ROOT / target
    assert path.stat().st_mode & 0o777 == row['mode'], target
    if name in plan['changes']:
        assert path.read_text() == plan['changes'][name]['after'], target
    elif name not in baseline['consumers']:
        assert sha(path.read_bytes()) == row['sha256'], target
for row in plan['moves']:
    assert not (ROOT / row['old_path']).exists() and (ROOT / row['target']).is_file()
tracked = set(filter(None, git('ls-files', '-z').decode().split('\0')))
local = {row['old_path']: row['target'] for row in plan['local_UID']}
for row in baseline['author_UID_exact']:
    name = local.get(row['path'], row['path'])
    path = ROOT / name
    assert sha(path.read_bytes()) == row['sha256'] and path.stat().st_mode & 0o777 == row['mode']
    assert path.read_text().strip() == row['value'] and name not in tracked and git('check-ignore', '--', name).strip()
for name, row in baseline['deferred_shared_anchors'].items():
    assert sha((ROOT / name).read_bytes()) == row['sha256'] and (ROOT / name).stat().st_mode & 0o777 == row['mode']
root_count = sum(path.suffix in {'.py', '.gd', '.sh', '.swift', '.mjs', '.gdshader'} for path in (ROOT / 'tools').iterdir() if path.is_file())
assert root_count == 153
prior = {}
for phase in ['authoring-move', 'audio-move', 'image-review-move', 'art-standard-move', 'assets-build-move', 'alpha-slicing-move', 'compatibility-move', 'performance-move', 'camera-move']:
    prior.update({row['old_path']: row['target'] for row in json.loads((REPORT.parent / phase / 'migration.json').read_text())['moves']})
prior.update(mapping)
contracts = REPORT.parent / 'baseline/source-contracts.json'
assert sha(contracts.read_bytes()) == 'bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child = ast.literal_eval(next(node.value for node in ast.parse((REPORT.parent / 'snapshot-contracts.py').read_text()).body if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id == 'CHILD' for target in node.targets)))
fields = 0
for row in json.loads(contracts.read_text())['modules'].values():
    module = prior.get(row['source'], row['source']).removesuffix('.py').replace('/', '.')
    result = subprocess.run([sys.executable, '-c', child, str(ROOT), module], cwd=ROOT,
        env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'), capture_output=True, text=True, timeout=30)
    assert result.returncode == 0 and not result.stderr and json.loads(result.stdout) == row['fields'], (module, result.stderr)
    fields += len(row['fields'])
assert fields == 37
card = 'docs/epics/refactoring-2026-10/TASKS.md'
old = re.split(r'(?=^## REFACTOR-)', git('show', plan['base'] + ':' + card).decode(), flags=re.M)
new = re.split(r'(?=^## REFACTOR-)', (ROOT / card).read_text(), flags=re.M)
assert len(old) == len(new) == 8 and all(a == b for a, b in zip(old, new) if not a.startswith('## REFACTOR-03 '))
for name in ['AGENTS.md', '.gitattributes', 'docs/backlog/README.md', 'wiki/planning/sources.json',
             'wiki/articles/tools-migration-map.md', 'tools/qa/art/current_paths.py', 'tools/qa/world/source_inputs.py',
             'docs/epics/visual-overhaul-2026-10/backlog.json', 'docs/reports/refactor-01/integration-1/migration-plan.json',
             'tools/performance_sampler.gd', 'tools/performance_sampler.gd.uid', 'tools/performance_gate.py',
             'tools/performance_gate.sh', 'tools/performance_protocol.py', 'tools/smoke_test.sh']:
    assert (ROOT / name).read_bytes() == git('show', plan['base'] + ':' + name), name
changed = set(filter(None, git('diff', '--no-renames', plan['base'], '--name-only', '-z').decode().split('\0')))
changed.update(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')))
removed = sorted(mapping)
assert all(name in after_names or name in mapping or name.startswith(str(REPORT.relative_to(ROOT)) + '/') for name in changed), changed - after_names - set(mapping)
scope = dict(preflight, version='0.0.377', root_sources=153, physical_moves=92, tracked_UID_moves=42,
             ignored_UID_moves=2, author_UID_exact=85, historical_fields=37,
             deferred_anchors_preserved=True, other_six_cards_unchanged=True,
             parallel07_excluded=True, full_task03_accepted=False,
             source_paths_after=sorted(after_names), removed_source_paths=removed)
(REPORT / 'scope.json').write_text(json.dumps(scope, indent=2) + '\n')
shutil.copyfile(__file__, REPORT / 'audit.py')
print(json.dumps({'source_after': len(after_names), 'root': 153, 'fields': fields,
                  'UID': 85, 'functions': function_count, 'address_sites': address_count}))

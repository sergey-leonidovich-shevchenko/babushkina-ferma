"""Verify preparation scope, exact frozen contracts and operational documentation."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
sys.path[:0] = [str(Q), str(Q / 'tools')]
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS
BASE = 'c47b78add8813392769be8b9d5dfba9b8d5fa1d5'
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def save(name, data):
    (R / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')

edits = json.loads((R / 'source-edits.json').read_text())['Git']
scope = []
for row in edits:
    path = Q / row['path']
    before = ast.parse(git('show', BASE + ':' + row['path']))
    after = ast.parse(path.read_text())
    old_import = any(isinstance(n, ast.ImportFrom) and n.module == 'tools.common.git' for n in before.body)
    if not old_import:
        after.body = [n for n in after.body if not (isinstance(n, ast.ImportFrom) and n.module == 'tools.common.git')]
    count = 0
    for node in ast.walk(after):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and isinstance(node.func.value, ast.Name) and node.func.value.id == 'subprocess' and node.args and isinstance(node.args[0], ast.List) and node.args[0].elts and isinstance(node.args[0].elts[0], ast.Constant) and node.args[0].elts[0].value == 'git':
            assert any(k.arg == 'env' and ast.unparse(k.value) == 'git_environment()' for k in node.keywords)
            node.keywords = [k for k in node.keywords if k.arg != 'env']
            count += 1
    assert count == row['Git_calls_cleaned']
    assert ast.dump(after, include_attributes=False) == ast.dump(before, include_attributes=False), row['path']
    scope.append({'path': row['path'], 'only_clean_env_and_import': True, 'calls': count})
save('semantic-audit.json', scope)

unused = []
for name in [r['path'] for r in edits] + ['tools/plant_depth_verify.py']:
    tree = ast.parse((Q / name).read_text())
    used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            for item in node.names:
                bound = item.asname or (item.name.split('.')[0] if isinstance(node, ast.Import) else item.name)
                if bound not in used and item.name != 'annotations':
                    unused.append({'path': name, 'line': node.lineno, 'name': bound})
assert not unused, unused
plant_before = ast.parse(git('show', BASE + ':tools/plant_depth_verify.py'))
for node in plant_before.body:
    if isinstance(node, ast.Import):
        node.names = [item for item in node.names if item.name != 'subprocess']
assert ast.dump(plant_before) == ast.dump(ast.parse((Q / 'tools/plant_depth_verify.py').read_text()))
save('unused-import-audit.json', {'modules': 19, 'remaining_candidates': unused,
    'method': 'AST loaded-name audit of changed modules; no unit test for import removal',
    'plant_depth_only_unused_import_removed': True})

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
    fields = json.loads(result.stdout)
    assert fields == record['fields'], selected
    rows.append({'module': selected, 'fields': len(fields), 'equal': True})
assert len(rows) == 21 and sum(r['fields'] for r in rows) == 37
save('source-contract-audit.json', {'frozen_sha256': sha(frozen_path.read_bytes()), 'modules': rows, 'fields': 37})

mapping = {a: b for a, b in MOVED_PATHS.items() if b.startswith('tools/qa/world/')}
bad = []
for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md', 'tools/README.md'] + [str(p.relative_to(Q)) for p in (Q / 'wiki/articles').glob('*.md') if p.name != 'tools-migration-map.md']:
    for number, line in enumerate((Q / name).read_text().splitlines(), 1):
        for old in mapping:
            if re.search(re.escape(old) + r'(?![\w./-])', line):
                bad.append({'path': name, 'line': number, 'old': old})
assert not bad, bad
live = []
for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md']:
    for physical in sorted(set(mapping.values())):
        if physical in (Q / name).read_text():
            assert (Q / physical).is_file(), physical
            live.append({'document': name, 'target': physical})
save('live-command-audit.json', {'removed_World_addresses': bad, 'verified_current_targets': live,
    'frozen_reports_and_historical_map': 'excluded; exact prior bytes retained'})
print(json.dumps({'semantic_modules': len(scope), 'cleaned_Git_calls': sum(r['calls'] for r in scope),
    'unused_import_candidates': len(unused), 'contract_modules': len(rows), 'contract_fields': 37,
    'live_current_targets': len(live), 'physical_moves': 0}))

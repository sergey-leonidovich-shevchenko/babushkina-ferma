"""Build an exact address/history proposal from accepted378; no product files are changed."""
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import pprint
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE = 'c1cdd9f5842eaf2286be38bd8f95d18767d03c11'
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
assert git('rev-parse', 'HEAD').decode().strip() == BASE
assert not git('status', '--porcelain').strip()
original = json.loads((Q / 'docs/reports/refactor-03/baseline/migration.json').read_text())
moves = [r for r in original['assignments'] if r['family'] == 'ground' and r['old_path'] != r['target']]
mapping = {r['old_path']: r['target'] for r in moves}
assert Counter(Path(n).suffix for n in mapping) == {'.py': 29, '.gd': 42, '.uid': 42}
modules = {Path(n).stem for n in mapping if n.endswith('.py')}
changes, counts = {}, {}

def replace_nodes(text, edits):
    lines = text.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    def position(line, column):
        return offsets[line - 1] + len(lines[line - 1].encode()[:column].decode())
    spans = [(position(n.lineno, n.col_offset), position(n.end_lineno, n.end_col_offset), value) for n, value in edits]
    for start, end, value in sorted(spans, reverse=True):
        text = text[:start] + value + text[end:]
    return text

for p in sorted((Q / 'tools').rglob('*.py')):
    if '__pycache__' in p.parts:
        continue
    name, before = str(p.relative_to(Q)), p.read_text()
    edits = []
    for n in ast.walk(ast.parse(before)):
        if not isinstance(n, (ast.ImportFrom, ast.Import)):
            continue
        source = ast.get_source_segment(before, n)
        if isinstance(n, ast.ImportFrom) and n.module in modules:
            edits.append((n, source.replace('from ' + n.module + ' import', 'from tools.qa.ground.' + n.module + ' import', 1)))
        elif isinstance(n, ast.ImportFrom) and n.module and n.module.startswith('tools.') and n.module[6:] in modules:
            edits.append((n, source.replace('from ' + n.module + ' import', 'from tools.qa.ground.' + n.module[6:] + ' import', 1)))
        elif isinstance(n, ast.ImportFrom) and n.module == 'tools' and any(a.name in modules for a in n.names):
            assert all(a.name in modules for a in n.names), (name, source)
            edits.append((n, source.replace('from tools import', 'from tools.qa.ground import', 1)))
        elif isinstance(n, ast.ImportFrom) and name in mapping and n.module and n.module.startswith('common.'):
            edits.append((n, source.replace('from common.', 'from tools.common.', 1)))
        elif isinstance(n, ast.Import) and any(a.name in modules for a in n.names):
            assert len(n.names) == 1, (name, source)
            a = n.names[0]
            edits.append((n, 'from tools.qa.ground import ' + a.name + (' as ' + a.asname if a.asname else '')))
    text = replace_nodes(before, edits)
    address_sites, history_sites, current_sites = 0, 0, 0
    if name in mapping:
        for function in [n for n in ast.parse(text).body if isinstance(n, ast.FunctionDef) and n.name in {'collect', 'capture'}]:
            old = ast.get_source_segment(text, function)
            new = old
            for legacy, target in mapping.items():
                if legacy.endswith('.gd'):
                    address_sites += new.count('res://' + legacy)
                    new = new.replace('res://' + legacy, 'res://' + target)
            text = text.replace(old, new, 1)
        if name.endswith('_collect.py'):
            marker = 'from pathlib import Path\n'
            assert text.count(marker) == 1
            text = text.replace(marker, marker + 'from tools.qa.world.source_inputs import input_path, historical_result\n')
            old = "subprocess.run(['git','show',base+':'+name],cwd=ROOT,capture_output=True,env=git_environment())"
            assert text.count(old) == 1, name
            text = text.replace(old, 'historical_result(ROOT,base,name)')
            history_sites += 1
            for old, new in [('shutil.copyfile(ROOT/name,target)', 'shutil.copyfile(input_path(ROOT,name),target)'),
                             ('sha(ROOT/p)', 'sha(input_path(ROOT,p))')]:
                assert text.count(old) == 1, (name, old)
                text = text.replace(old, new)
                current_sites += 1
            assert text.count('git_environment') == 1
            text = text.replace('from tools.common.git import git_environment\n', '')
        elif name.endswith('_verify.py'):
            marker = 'from pathlib import Path\n'
            assert text.count(marker) == 1
            text = text.replace(marker, marker + 'from tools.qa.world.source_inputs import historical_result\n')
            old = "subprocess.run(['git','show',source['base_commit']+':'+name],cwd=ROOT,capture_output=True,env=git_environment())"
            assert text.count(old) == 1, name
            text = text.replace(old, "historical_result(ROOT,source['base_commit'],name)")
            history_sites += 1
        elif name == 'tools/ground_layers.py':
            marker = 'from tools.qa.performance.source_history import LEGACY_HELPER, historical_helper\n'
            assert text.count(marker) == 1
            text = text.replace(marker, marker + 'from tools.qa.world.source_inputs import historical_bytes\n')
            old = "return subprocess.check_output(['git','--no-replace-objects','show',commit+':'+physical],cwd=ROOT,env=git_environment())"
            assert text.count(old) == 1
            text = text.replace(old, 'return historical_bytes(ROOT,commit,physical)')
            history_sites += 1
    if name == 'tools/qa/ground/test_ground_context.py':
        assert text.count('from pathlib import Path\n') == 1
        text = text.replace('from pathlib import Path\n', '')
    if name == 'tools/qa/performance/test_surface_producers.py':
        assert text.count('import sys\n') == 1
        text = text.replace('import sys\n', '')
        marker = 'from tools.common.git import git_environment\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + 'from tools.assets.contracts.source_paths import current_source\n')
        old = '            physical = CANONICAL if logical == LEGACY else logical\n'
        assert text.count(old) == 1
        text = text.replace(old, '            physical = str(current_source(ROOT,logical).relative_to(ROOT))\n')
        current_sites += 1
    if text != before:
        compile(text, name, 'exec')
        changes[name] = {'before': before, 'after': text}
        counts[name] = {'imports': len(edits), 'native_addresses': address_sites,
                        'history_resolvers': history_sites, 'current_resolvers': current_sites}

name = 'tools/assets/contracts/source_paths.py'
before = (Q / name).read_text()
assignment = next(n for n in ast.parse(before).body if isinstance(n, ast.Assign) and
    any(isinstance(t, ast.Name) and t.id == 'MOVED_PATHS' for t in n.targets))
old_map = ast.literal_eval(assignment.value.args[0])
assert len(old_map) == 267 and not old_map.keys() & mapping.keys()
changes[name] = {'before': before, 'after': replace_nodes(before, [
    (assignment.value.args[0], pprint.pformat({**old_map, **mapping}, width=110, sort_dicts=True))])}
name = 'tools/assets/contracts/test_source_paths.py'
before = (Q / name).read_text()
old = '        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 267)'
assert before.count(old) == 1
new = ("        ground = {old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'ground' and old != row['target']}\n"
       '        self.assertEqual(len(ground), 113)\n        expected.update(ground)\n'
       '        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 380)')
changes[name] = {'before': before, 'after': before.replace(old, new)}
for directory in ['tools', 'tests', 'scripts']:
    for p in sorted((Q / directory).rglob('*.gd')):
        before = text = p.read_text()
        for old, target in mapping.items():
            if old.endswith('.gd'):
                text = text.replace('res://' + old, 'res://' + target)
        if text != before:
            changes[str(p.relative_to(Q))] = {'before': before, 'after': text}

unused = []
for name, row in changes.items():
    row.update(before_SHA256=sha(row['before'].encode()), after_SHA256=sha(row['after'].encode()))
    if name.endswith('.py'):
        tree = ast.parse(row['after'])
        used = {n.id for n in ast.walk(tree) if isinstance(n, ast.Name) and isinstance(n.ctx, ast.Load)}
        for n in ast.walk(tree):
            if isinstance(n, (ast.Import, ast.ImportFrom)):
                for item in n.names:
                    bound = item.asname or (item.name.split('.')[0] if isinstance(n, ast.Import) else item.name)
                    if bound not in used and item.name != 'annotations':
                        unused.append({'path': name, 'line': n.lineno, 'name': bound})
local = json.loads((Q / 'docs/reports/refactor-03/baseline/local-uids.json').read_text())
assert not [r for r in local['local_only_UID'] if r['old_path'].removesuffix('.uid') in mapping]
payload = {'private_proposal_only': True, 'base': BASE, 'moves': moves, 'changes': changes,
    'counts': counts, 'unused_candidates': unused, 'physical_source_moves': 71,
    'tracked_UID_moves': 42, 'ignored_UID_moves': 0, 'root_before': 153, 'root_after': 82,
    'map_before': 267, 'map_after': 380, 'parent_review': 5704521872, 'parent_CI_success': 8,
    'parent_Team_intermediate_accepted': True, 'full03_done': False,
    'frozen_contracts_37_fields': 'must remain exact',
    'expanded_import_audit': 'all new/modified/moved tools Python, including tests'}
output = Path('/private/tmp/refactor03-ground-plan379.json')
assert not output.exists()
output.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'source_moves': 71, 'UID': 42, 'changed_code': len(changes),
    'history_resolvers': sum(r['history_resolvers'] for r in counts.values()),
    'current_resolvers': sum(r['current_resolvers'] for r in counts.values()), 'unused_candidates': unused}))

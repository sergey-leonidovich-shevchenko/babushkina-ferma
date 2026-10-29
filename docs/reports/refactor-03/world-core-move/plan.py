"""Propose an address-only World-core move; write only a private plan until 376 is reviewed."""
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import pprint
import subprocess

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE = '7a2d7a5917bede86b3ffa850b1d5c83e9e8cc0bd'
assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip() == BASE
assert not subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain']).strip()
original = json.loads((ROOT / 'docs/reports/refactor-03/baseline/migration.json').read_text())
deferred = {
    'tools/render_order_game.gd', 'tools/render_order_game.gd.uid',
    'tools/shore_kit.py', 'tools/test_shore_kit.py', 'tools/shore_kit_canvas.gd',
    'tools/shore_kit_capture.gd', 'tools/shore_kit_review.gd',
}
rows = [row for row in original['assignments'] if row['family'] == 'world'
        and row['old_path'] != row['target'] and row['old_path'] not in deferred]
mapping = {row['old_path']: row['target'] for row in rows}
assert Counter(Path(name).suffix for name in mapping) == {'.py': 48, '.gd': 44, '.uid': 42}
modules = {Path(name).stem for name in mapping if name.endswith('.py')}
changes, counts = {}, {}


def replace_nodes(text, replacements):
    """Use AST byte columns correctly even when earlier text contains Cyrillic."""
    lines = text.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    def position(line, column):
        return offsets[line - 1] + len(lines[line - 1].encode()[:column].decode())
    spans = [(position(node.lineno, node.col_offset),
              position(node.end_lineno, node.end_col_offset), value)
             for node, value in replacements]
    for start, end, value in sorted(spans, reverse=True):
        text = text[:start] + value + text[end:]
    return text


for path in sorted((ROOT / 'tools').rglob('*.py')):
    if '__pycache__' in path.parts:
        continue
    name, before = str(path.relative_to(ROOT)), path.read_text()
    replacements = []
    for node in ast.walk(ast.parse(before)):
        if not isinstance(node, (ast.ImportFrom, ast.Import)):
            continue
        source = ast.get_source_segment(before, node)
        if isinstance(node, ast.ImportFrom) and node.module in modules:
            replacements.append((node, source.replace('from ' + node.module + ' import',
                'from tools.qa.world.' + node.module + ' import', 1)))
        elif isinstance(node, ast.ImportFrom) and node.module and node.module.startswith('tools.') and node.module[6:] in modules:
            replacements.append((node, source.replace('from ' + node.module + ' import',
                'from tools.qa.world.' + node.module[6:] + ' import', 1)))
        elif isinstance(node, ast.ImportFrom) and node.module == 'tools' and any(alias.name in modules for alias in node.names):
            assert all(alias.name in modules for alias in node.names), (name, source)
            replacements.append((node, source.replace('from tools import', 'from tools.qa.world import', 1)))
        elif isinstance(node, ast.ImportFrom) and name in mapping and node.module and node.module.startswith('common.'):
            replacements.append((node, source.replace('from common.', 'from tools.common.', 1)))
        elif isinstance(node, ast.Import) and any(alias.name in modules for alias in node.names):
            assert len(node.names) == 1, (name, source)
            alias = node.names[0]
            replacements.append((node, 'from tools.qa.world import ' + alias.name + (' as ' + alias.asname if alias.asname else '')))
    text = replace_nodes(before, replacements)
    native_sites = 0
    if name in mapping:
        # Only public producer launch argv changes; immutable logical SOURCES/archives stay original.
        for function in [node for node in ast.parse(text).body if isinstance(node, ast.FunctionDef) and node.name in {'collect', 'capture'}]:
            old = ast.get_source_segment(text, function)
            new = old
            for legacy, target in mapping.items():
                if legacy.endswith('.gd'):
                    native_sites += new.count('res://' + legacy)
                    new = new.replace('res://' + legacy, 'res://' + target)
            text = text.replace(old, new, 1)
    if name == 'tools/qa/world/test_world_context.py':
        # Keep every old method/assertion and change only current fixture addresses.
        for old, new in {
            '(render_order.ROOT/n).read_bytes()': 'current_source(render_order.ROOT,n).read_bytes()',
            'target=own/name;': 'target=current_source(own,name);',
            '(own/name).read_bytes()': 'current_source(own,name).read_bytes()',
        }.items():
            assert old in text, (name, old)
            text = text.replace(old, new)
    if name == 'tools/plant_depth_collect.py':
        # This external consumer inherits the moved World ORIGINAL/EXTRA namespace.
        marker = 'from pathlib import Path\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + 'from tools.qa.world.source_inputs import input_path\n')
        for old, new in {
            '(ROOT/name).is_file()': 'input_path(ROOT,name).is_file()',
            'shutil.copyfile(ROOT/name,target)': 'shutil.copyfile(input_path(ROOT,name),target)',
            'sha(ROOT/n)': 'sha(input_path(ROOT,n))',
        }.items():
            assert text.count(old) == 1, (name, old)
            text = text.replace(old, new)
    if name == 'tools/plant_depth_verify.py':
        # The existing flat collector establishes project imports for standalone foreign-cwd CLI.
        marker = 'from plant_depth_collect import ORIGINAL,EXTRA\n'
        assert text.count(marker) == 1
        text = text.replace(marker, marker + 'from tools.qa.world.source_inputs import historical_bytes\n')
        old = "return subprocess.check_output(['git','show',base+':'+name],cwd=ROOT)"
        assert text.count(old) == 1
        text = text.replace(old, 'return historical_bytes(ROOT,base,name)')
    if text != before:
        compile(text, name, 'exec')
        changes[name] = {'before': before, 'after': text}
        counts[name] = {'imports': len(replacements), 'native_launch_sites': native_sites}

# Add exactly the accepted physical assignments, leaving the separate art map and World history aliases alone.
name = 'tools/assets/contracts/source_paths.py'
before = (ROOT / name).read_text()
assignment = next(node for node in ast.parse(before).body if isinstance(node, ast.Assign)
    and any(isinstance(target, ast.Name) and target.id == 'MOVED_PATHS' for target in node.targets))
old_map = ast.literal_eval(assignment.value.args[0])
assert len(old_map) == 133 and not old_map.keys() & mapping.keys()
changes[name] = {'before': before, 'after': replace_nodes(before, [
    (assignment.value.args[0], pprint.pformat({**old_map, **mapping}, width=110, sort_dicts=True))])}
name = 'tools/assets/contracts/test_source_paths.py'
before = (ROOT / name).read_text()
old = '        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 133)'
assert before.count(old) == 1
new = ('        world_deferred = ' + repr(sorted(deferred)) + '\n'
       "        world = {old: row['target'] for old, row in plan['assignments'].items() if row['family'] == 'world' and old != row['target'] and old not in world_deferred}\n"
       '        self.assertEqual(len(world), 134)\n        expected.update(world)\n'
       '        self.assertEqual(dict(MOVED_PATHS), expected)\n        self.assertEqual(len(MOVED_PATHS), 267)')
changes[name] = {'before': before, 'after': before.replace(old, new)}

for directory in ['tools', 'tests', 'scripts']:
    for path in sorted((ROOT / directory).rglob('*.gd')):
        before = text = path.read_text()
        for old, target in mapping.items():
            if old.endswith('.gd'):
                text = text.replace('res://' + old, 'res://' + target)
        if text != before:
            changes[str(path.relative_to(ROOT))] = {'before': before, 'after': text}

# Team's nonblocking P3 from exact376: delete only imports whose names are no longer used.
unused = {
    'tools/post_motion_verify.py': [('import argparse,copy,gzip,hashlib,json,math,subprocess', 'import argparse,copy,gzip,hashlib,json,math'), ('from tools.common.git import git_environment\n', '')],
    'tools/object_command_collect.py': [('from tools.common.git import git_environment\n', '')],
    'tools/analyze_water_audit.py': [('from pathlib import Path\n', '')],
}
for name, edits in unused.items():
    assert name in changes
    text = changes[name]['after']
    for old, new in edits:
        assert text.count(old) == 1, (name, old)
        text = text.replace(old, new)
    changes[name]['after'] = text

for name, row in changes.items():
    row.update(before_SHA256=hashlib.sha256(row['before'].encode()).hexdigest(),
               after_SHA256=hashlib.sha256(row['after'].encode()).hexdigest())
local = []
uids = json.loads((ROOT / 'docs/reports/refactor-03/baseline/local-uids.json').read_text())
for row in uids['local_only_UID']:
    if row['old_path'].removesuffix('.uid') in mapping:
        path = ROOT / row['old_path']
        assert path.read_text().strip() == row['value']
        local.append({**row, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'mode': path.stat().st_mode & 0o777})
assert len(local) == 2
payload = {'private_proposal_only': True, 'parent_review_pending': False, 'base': BASE,
           'moves': rows, 'local_UID': local, 'changes': changes, 'source_counts': counts,
           'deferred_within_same_task': sorted(deferred), 'physical_source_moves': 92,
           'tracked_UID_moves': 42, 'ignored_UID_moves': 2, 'root_before': 245,
           'root_after': 153, 'current_map_before': 133, 'current_map_after': 267,
           'new_external_consumer_controls_required': ['actual plant_depth producer', 'actual plant_depth canonical Git source reader'],
           'old_source_contracts_37_fields_unchanged': True,
           'parent_SOURCE_PASS': 5695222063, 'parent_Team_intermediate_accepted': True,
           'parent_CI_success': 8, 'review_P3_import_cleanup': unused}
output = Path('/private/tmp/refactor03-world-plan377.json')
assert not output.exists()
output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'private_plan_only': True, 'sources': 92, 'tracked_UID': 42,
                  'ignored_UID': 2, 'changed_code_modules': len(changes),
                  'root_after': 153, 'new_map_total': 267}))

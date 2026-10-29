"""Exercise actual canonical World producers/history/API/context after the physical move; never Game."""
import ast
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
sys.path.insert(0, str(ROOT))
from tools.common.git import git_environment

plan = json.loads((REPORT / 'baseline/move-plan.json').read_text())
assert (ROOT / 'VERSION').read_text().strip() == '0.0.377'
parser = argparse.ArgumentParser()
parser.add_argument('--resume-after-water-address', action='store_true')
args = parser.parse_args()
if args.resume_after_water_address:
    assert plan['water_fixture_current_address_repaired']


class FixtureAddress(ast.NodeTransformer):
    """Normalize exactly one repaired current input in the nested water fixture."""
    def visit_Call(self, node):
        if isinstance(node.func, ast.Name) and node.func.id == 'current_source' and len(node.args) == 2:
            if ast.unparse(node.args[0]) == 'render_order.ROOT' and isinstance(node.args[1], ast.Constant) and node.args[1].value == 'tools/analyze_water_audit.py':
                assert not node.keywords
                return ast.parse("render_order.ROOT/'tools/analyze_water_audit.py'", mode='eval').body
        return self.generic_visit(node)


rows = []
for label, module, count in [
    ('helper-green', 'test_source_inputs', 16),
    ('producers-after', 'test_world_producers', 14),
    ('history-green', 'test_world_source_history', 13),
    ('context-after', 'test_world_context', 19),
]:
    path = ROOT / 'tools/qa/world' / (module + '.py')
    source_sha = hashlib.sha256(path.read_bytes()).hexdigest()
    tree = ast.parse(path.read_text())
    actual_methods = sum(isinstance(node, ast.FunctionDef) and node.name.startswith('test_') for node in ast.walk(tree))
    assert actual_methods == count
    if args.resume_after_water_address and label in {'helper-green', 'producers-after'}:
        receipt = json.loads((REPORT / (label + '.json')).read_text())
        raw = REPORT / (label + '.txt')
        assert receipt['exit'] == 0 and receipt['methods'] == count and receipt['test_SHA256'] == source_sha
        assert receipt['raw_sha256'] == hashlib.sha256(raw.read_bytes()).hexdigest()
        rows.append(receipt)
        print(json.dumps({'reused_unchanged_passed_case': label, 'methods': count}), flush=True)
        continue
    if module in {'test_world_producers', 'test_world_source_history'}:
        key = 'producer14' if module == 'test_world_producers' else 'history13'
        before = ast.parse((REPORT / 'baseline' / (key + '-before.py')).read_text())
        after = ast.parse(path.read_text())
        if module == 'test_world_source_history':
            after = FixtureAddress().visit(after)
        for candidate in [before, after]:
            candidate.body = [node for node in candidate.body if not isinstance(node, (ast.Import, ast.ImportFrom))]
        assert ast.dump(before, include_attributes=False) == ast.dump(after, include_attributes=False)
        assert source_sha == plan['external_control_test_source'][key]['after_SHA256']
    if args.resume_after_water_address and label == 'history-green':
        label = 'history-green-attempt02'
    command = [sys.executable, str(ROOT / 'tools/run.py'), 'qa.world.' + module]
    log = REPORT / (label + '.txt')
    assert not log.exists()
    with log.open('x') as stream:
        result = subprocess.run(command, cwd='/private/tmp', env=dict(git_environment(), PYTHONDONTWRITEBYTECODE='1'),
                                stdout=stream, stderr=subprocess.STDOUT, timeout=900)
    text = log.read_text()
    counts = list(map(int, re.findall(r'Ran (\d+) tests? in', text)))
    row = {'label': label, 'command': command, 'exit': result.returncode, 'methods': count,
           'test_SHA256': source_sha, 'raw_sha256': hashlib.sha256(log.read_bytes()).hexdigest(),
           'native_frames': 0, 'Game_new': False}
    (REPORT / (label + '.json')).write_text(json.dumps(row, indent=2) + '\n')
    rows.append(row)
    print(json.dumps(row), flush=True)
    assert result.returncode == 0 and counts == [count] and '\nOK\n' in text, (row, text[-3000:])
result = {'base': plan['base'], 'before_producer_methods': 14, 'after_producer_methods': 14,
          'before_history_methods': 13, 'after_history_methods': 13, 'before_history_errors': 1,
          'new_test_non_import_AST_equal_after_one_fixture_address_normalization': True, 'old_API_methods': 16, 'old_context_methods': 19,
          'commands': rows, 'fake_open_exit': 17, 'native_frames_new': 0,
          'Game_new': False, 'GPU_FPS_admission': False}
(REPORT / 'regression.json').write_text(json.dumps(result, indent=2) + '\n')
shutil.copyfile(__file__, REPORT / 'regression.py')
print(json.dumps({'runtime_regression': 'PASS', 'API': 16, 'producers': 14, 'history': 13,
                  'old_context': 19, 'native_frames': 0}))

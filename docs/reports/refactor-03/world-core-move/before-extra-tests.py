"""Run extra consumer controls on accepted376, keeping test imports separate from physical addresses."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
plan = json.loads(Path('/private/tmp/refactor03-world-plan377.json').read_text())
parser = argparse.ArgumentParser()
parser.add_argument('label', choices=['producer14', 'history13'])
args = parser.parse_args()
record = plan['external_control_test_source'][args.label]
source = Path(record['private_before'])
name = 'tools/qa/world/test_world_' + ('producers.py' if args.label == 'producer14' else 'source_history.py')
before = ast.parse(source.read_text())
after = ast.parse(plan['changes'][name]['after'])
for tree in [before, after]:
    tree.body = [node for node in tree.body if not isinstance(node, (ast.Import, ast.ImportFrom))]
assert ast.dump(before, include_attributes=False) == ast.dump(after, include_attributes=False)
methods = [node.name for node in ast.walk(before) if isinstance(node, ast.FunctionDef) and node.name.startswith('test_')]
assert len(methods) == (14 if args.label == 'producer14' else 13)
assert hashlib.sha256(source.read_bytes()).hexdigest() == record['before_SHA256']
assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip() == plan['base']
command = [sys.executable, '-c', 'import runpy,sys;sys.path[:0]=sys.argv[1:3];sys.argv=sys.argv[3:];runpy.run_path(sys.argv[0],run_name="__main__")', str(ROOT), str(ROOT / 'tools'), str(source)]
output = Path('/private/tmp/refactor03-world-' + args.label + '-before377.txt')
assert not output.exists()
environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
environment['PYTHONDONTWRITEBYTECODE'] = '1'
with output.open('x') as stream:
    result = subprocess.run(command, cwd='/private/tmp', env=environment, stdout=stream, stderr=subprocess.STDOUT)
receipt = {'base': plan['base'], 'label': args.label, 'exit': result.returncode,
           'methods': len(methods), 'before_test_SHA256': record['before_SHA256'],
           'after_test_SHA256': record['after_SHA256'], 'non_import_AST_equal': True,
           'actual_cli': command, 'raw_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
           'product_mutated': False, 'native_frames': 0}
Path('/private/tmp/refactor03-world-' + args.label + '-before377.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt))

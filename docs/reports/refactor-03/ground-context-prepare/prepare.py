"""Prepare only Ground Git context and two World review followups; no physical move."""
import ast
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
sys.path.insert(0, str(Q))
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.planning.bump_version import sync_files

BASE = 'c47b78add8813392769be8b9d5dfba9b8d5fa1d5'
R = Q / 'docs/reports/refactor-03/ground-context-prepare'
def git(*args):
    return subprocess.check_output(['git', '-C', str(Q), *args], env=git_environment())
def sha(raw):
    return hashlib.sha256(raw).hexdigest()
def write_json(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')

assert git('rev-parse', 'HEAD').decode().strip() == BASE
existing = set(git('diff', '--name-only').decode().splitlines())
assert existing <= {'tools/' + family + '_' + suffix + '.py' for family in
    ['axial_road', 'decoration', 'garden', 'ground_edge'] for suffix in ['collect', 'verify']}
R.mkdir(parents=True, exist_ok=True)
(R / 'baseline').mkdir(exist_ok=True)
if existing:
    write_json(R / 'baseline/prepare-attempt01.json', {
        'exit': 1, 'before_tests': True, 'partial_paths': sorted(existing),
        'reason': 'prototype included wrapper calls and met an already present Git import',
        'repair': 'derive all edits anew from accepted base; only direct subprocess Git calls',
    })
census = json.loads(Path('/private/tmp/refactor03-ground-census378.json').read_text())
names = [row['old_path'] for row in census['moves'] if row['old_path'].endswith('.py')]
assert len(names) == 29
for source, target in [
    ('/private/tmp/refactor03-test-ground-context378.py', 'baseline/test_ground_context.py'),
    ('/private/tmp/refactor03-ground-context378-red.txt', 'baseline/context-red.txt'),
    ('/private/tmp/refactor03-ground-context378-red.json', 'baseline/context-red.json'),
    ('/private/tmp/refactor03-ground-census378.json', 'baseline/census.json'),
]:
    shutil.copy2(source, R / target)
plan = {
    'task': 'REFACTOR-03', 'phase': 'Ground context preparation', 'base': BASE,
    'version': '0.0.378', 'accepted_parent_review': 5697669336,
    'root_sources_before': 153, 'root_sources_after': 153, 'current_map': 267,
    'physical_moves': 0, 'Git_calls_total': 30, 'Git_calls_to_clean': 28,
    'new_real_archive_cases': 10, 'baseline_errors': 9,
    'source_contract_fields': 37, 'source_contract_modules': 21,
    'native_frames': 0, 'new_FPS_admission': False,
    'followups': ['plant_depth_verify unused subprocess', 'live World/Water commands'],
    'frozen_reports_rewritten': False, 'full03_done': False,
}
write_json(R / 'PLAN.json', plan)
old_bytes = {n: git('show', BASE + ':' + n) for n in names + ['tools/plant_depth_verify.py']}
edits = []
for name in names:
    p = Q / name
    text = old_bytes[name].decode()
    tree = ast.parse(text)
    lines = text.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    positions = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not node.args or not isinstance(node.args[0], (ast.List, ast.Tuple)):
            continue
        if not isinstance(node.func, ast.Attribute) or not isinstance(node.func.value, ast.Name) or node.func.value.id != 'subprocess':
            continue
        items = node.args[0].elts
        if not items or not isinstance(items[0], ast.Constant) or items[0].value != 'git':
            continue
        if any(k.arg == 'env' for k in node.keywords):
            continue
        # Existing commands are ASCII through the closing argument; use AST byte position exactly.
        line = lines[node.end_lineno - 1]
        end = len(line.encode()[:node.end_col_offset].decode())
        positions.append(offsets[node.end_lineno - 1] + end - 1)
    if not positions:
        continue
    for position in sorted(positions, reverse=True):
        assert text[position] == ')'
        text = text[:position] + ',env=git_environment()' + text[position:]
    if 'from tools.common.git import git_environment' not in text:
        text = text.replace('import subprocess\n', 'import subprocess\nfrom tools.common.git import git_environment\n', 1)
    assert text.count('from tools.common.git import git_environment') == 1
    ast.parse(text)
    p.write_text(text)
    edits.append({'path': name, 'Git_calls_cleaned': len(positions),
                  'before_sha256': sha(old_bytes[name]), 'after_sha256': sha(p.read_bytes())})
assert len(edits) == 18 and sum(r['Git_calls_cleaned'] for r in edits) == 28
p = Q / 'tools/plant_depth_verify.py'
text = p.read_text()
assert text.count('subprocess') == 1
p.write_text(text.replace('import argparse,gzip,hashlib,json,math,subprocess', 'import argparse,gzip,hashlib,json,math', 1))
target = Q / 'tools/qa/ground'
assert not target.exists()
target.mkdir()
(target / '__init__.py').write_text('"""Проверки поверхностей первой локации и их архивных доказательств."""\n')
shutil.copy2(R / 'baseline/test_ground_context.py', target / 'test_ground_context.py')
p = Q / 'tools/quality/check_architecture.sh'
text = p.read_text()
anchor = 'python3 tools/run.py qa.world.test_world_context\n'
assert text.count(anchor) == 1
p.write_text(text.replace(anchor, anchor + 'python3 tools/run.py qa.ground.test_ground_context\n'))

# Only live operational documents: archived reports and the historical migration map are excluded.
doc_edits = []
mapping = {a: b for a, b in MOVED_PATHS.items() if b.startswith('tools/qa/world/')}
for name in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md']:
    p = Q / name
    text = p.read_text()
    before = text
    for old, new in sorted(mapping.items(), key=lambda pair: -len(pair[0])):
        if old.endswith('.py'):
            module = new.removeprefix('tools/').removesuffix('.py').replace('/', '.')
            text = text.replace('python3 ' + old, 'python3 tools/run.py ' + module)
        text = re.sub(re.escape(old) + r'(?![\w./-])', lambda match: new, text)
    if text != before:
        p.write_text(text)
        doc_edits.append({'path': name, 'before_sha256': sha(before.encode()), 'after_sha256': sha(text.encode())})
assert len(doc_edits) == 3
sync_files('0.0.378')
write_json(R / 'source-edits.json', {'Git': edits, 'documentation': doc_edits,
    'plant_depth_subprocess_removed': True, 'test_source_exact_to_baseline':
    (target / 'test_ground_context.py').read_bytes() == (R / 'baseline/test_ground_context.py').read_bytes()})
print(json.dumps({'Git_modules': len(edits), 'Git_calls': sum(r['Git_calls_cleaned'] for r in edits),
                  'live_documents': len(doc_edits), 'new_tests': 10, 'physical_moves': 0}))

"""Prevent the frozen import test from writing bytecode into immutable evidence directories."""
import gzip,hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/qa/performance/test_performance_layout.py';before=p.read_text()
(R/'baseline/layout-before-no-bytecode.py.gz').write_bytes(gzip.compress(before.encode(),mtime=0))
old='env=dict(git_environment(), PYTHONPATH=str(foreign)), capture_output=True, text=True, timeout=30)'
new='env=dict(git_environment(), PYTHONPATH=str(foreign), PYTHONDONTWRITEBYTECODE="1"), capture_output=True, text=True, timeout=30)'
assert before.count(old)==1;after=before.replace(old,new);p.write_text(after)
cache=ROOT/'docs/reports/visual-overhaul/vfoliage-006/ci-performance/fixed-gate/instrumentation/__pycache__/performance_protocol.cpython-311.pyc'
assert cache.is_file();metadata={'generated_cache':str(cache.relative_to(ROOT)),'sha256':hashlib.sha256(cache.read_bytes()).hexdigest(),
 'bytes':cache.stat().st_size,'tracked_source_unchanged':True,'cause':'test import default Python bytecode write','fix':'child PYTHONDONTWRITEBYTECODE=1 only; same assertions'}
cache.unlink();(R/'bytecode-cleanup.json').write_text(json.dumps(metadata,indent=2)+'\n')
plan=json.loads((R/'adaptation-plan.json').read_text());plan['changes']['tools/qa/performance/test_performance_layout.py']=after
(R/'adaptation-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(R/'baseline/layout-frozen-graph-test.py',R/'baseline/layout-frozen-graph-before-bytecode.py')
(R/'baseline/layout-frozen-graph-test.py').write_text(after)
shutil.copyfile(R/'frozen-graph-proof.json',R/'frozen-graph-proof-before-bytecode.json')
shutil.copyfile(R/'frozen-graph-red.txt',R/'frozen-graph-red-before-bytecode.txt');shutil.copyfile(R/'frozen-graph-green.txt',R/'frozen-graph-green-before-bytecode.txt')
shutil.copyfile(__file__,R/'no-bytecode-fix.py')
print(json.dumps({'only_environment_flag_changed':True,'same_assertions':True,'generated_cache_removed':True,'final_test_sha256':hashlib.sha256(after.encode()).hexdigest()}))

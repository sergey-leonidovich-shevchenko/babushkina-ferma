"""Keep the first failed raw and repair the nested import discovered by the old34-case suite."""
import gzip,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=ROOT/'docs/reports/refactor-03/performance-move'
path=ROOT/'tools/qa/performance/test_performance_gate.py';before=path.read_text()
old='        from performance_protocol import policy';new='        from tools.qa.performance.performance_protocol import policy'
assert before.count(old)==1
(R/'baseline/test-performance-gate-before-nested-import.py.gz').write_bytes(gzip.compress(before.encode(),mtime=0))
(R/'profile-attempt01.py.gz').write_bytes(gzip.compress((R/'profile.py').read_bytes(),mtime=0))
plan=json.loads((R/'adaptation-plan.json').read_text());assert plan['changes'][str(path.relative_to(ROOT))]==before
plan['changes'][str(path.relative_to(ROOT))]=before.replace(old,new)
shutil.copyfile(R/'adaptation-plan.json',R/'baseline/adaptation-plan-attempt01.json')
(R/'adaptation-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
path.write_text(before.replace(old,new))
(R/'nested-import-fix.json').write_text(json.dumps({'raw':'after-16.txt','before_error':'ModuleNotFoundError: performance_protocol',
 'tests':34,'before_errors':1,'change':'one nested import path only','assertions_changed':False},indent=2)+'\n')
shutil.copyfile(__file__,R/'nested-import-fix.py')

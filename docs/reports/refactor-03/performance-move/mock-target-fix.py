"""Retarget the old PLAN mock to the same canonical module; keep every budget mutation/assertion."""
import gzip,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/qa/performance/test_performance_gate.py';before=p.read_text()
old='patch("performance_protocol.PLAN", path)';new='patch("tools.qa.performance.performance_protocol.PLAN", path)'
assert before.count(old)==1
(R/'baseline/test-performance-gate-before-mock-target.py.gz').write_bytes(gzip.compress(before.encode(),mtime=0))
plan=json.loads((R/'adaptation-plan.json').read_text());assert plan['changes'][str(p.relative_to(ROOT))]==before
plan['changes'][str(p.relative_to(ROOT))]=before.replace(old,new)
shutil.copyfile(R/'adaptation-plan.json',R/'baseline/adaptation-plan-attempt02.json')
(R/'adaptation-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n');p.write_text(before.replace(old,new))
shutil.copyfile(__file__,R/'mock-target-fix.py')

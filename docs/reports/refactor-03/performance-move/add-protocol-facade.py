"""Preserve direct frozen protocol imports through one documented additional public facade."""
import gzip,hashlib,json,shutil
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/performance_protocol.py';assert not p.exists()
assert 'FAILED (failures=1, errors=1)'in(R/'frozen-graph-red.txt').read_text()
text='''#!/usr/bin/env python3
"""Public protocol import for frozen executable reports; one canonical implementation."""
if __package__:
    from .common.launch import facade
else:
    from common.launch import facade

facade(__name__, "tools.qa.performance.performance_protocol")
'''
p.write_text(text);p.chmod(0o644)
plan=json.loads((R/'adaptation-plan.json').read_text());shutil.copyfile(R/'adaptation-plan.json',R/'baseline/adaptation-plan-before-frozen-facade.json')
plan['changes']['tools/performance_protocol.py']=text
plan['changes']['tools/qa/performance/test_performance_layout.py']=(ROOT/'tools/qa/performance/test_performance_layout.py').read_text()
(R/'adaptation-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2)+'\n')
initial=ROOT/'docs/reports/refactor-01/integration-1/migration-plan.json'
consumers=['docs/reports/visual-overhaul/vfoliage-006/redraw-scheduling/verify.py',
 'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/analysis/verify.py',
 'docs/reports/visual-overhaul/vfoliage-006/causal-investigation/instrumentation/causal_capture.py',
 'docs/reports/visual-overhaul/vfoliage-006/ci-performance/fixed-gate/instrumentation/performance_gate.py']
exception={'original_map':str(initial.relative_to(ROOT)),'original_map_sha256':hashlib.sha256(initial.read_bytes()).hexdigest(),
 'original_map_unchanged':True,'old_path':'tools/performance_protocol.py','target':'tools/qa/performance/performance_protocol.py',
 'original_action':'move','current_action':'move_implementation_keep_public_facade',
 'reason':'Full gates-01 discovered actual frozen executable direct protocol imports, including protocol-before-gate order. A fourth root facade preserves them without archive rewriting or import-order hooks.',
 'frozen_consumers':{n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest()for n in consumers},
 'root_sources_after':285,'expected_final_root_adjustment':'historical10 + protocol facade1 =11; final budget remains<=30',
 'review_status':'author implementation proposal, requires independent exact-head review and Team decision'}
(R/'compatibility-exception.json').write_text(json.dumps(exception,ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(R/'after-profile.json',R/'after-profile-attempt03.json');(R/'after-profile.json').unlink()
shutil.copyfile(__file__,R/'add-protocol-facade.py')
print(json.dumps({'public_facades':4,'root':285,'initial_plan_unchanged':True,'frozen_reports_unchanged':True}))

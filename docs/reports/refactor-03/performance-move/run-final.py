"""Serial final profile, scope/freeze and all mandatory gates after the frozen-protocol repair."""
import hashlib,json,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
proof=json.loads((R/'frozen-graph-proof.json').read_text());assert proof['cases']==8 and [r['exit']for r in proof['records']]==[1,0]
assert hashlib.sha256((ROOT/'tools/qa/performance/test_performance_layout.py').read_bytes()).hexdigest()==proof['same_test_SHA256']
exception=json.loads((R/'compatibility-exception.json').read_text());assert hashlib.sha256((ROOT/exception['original_map']).read_bytes()).hexdigest()==exception['original_map_sha256']
for name,digest in {**exception['frozen_consumers'],**exception['self_contained_snapshot_control']}.items():
 assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest,name
commands=[['python3',str(R/'profile.py'),'after','--attempt','5'],['python3','/private/tmp/refactor03-performance-audit-final371.py'],
 ['python3',str(R.parent/'run-gates.py'),str(R/'gates-02')]]
shutil.copyfile(__file__,R/'run-final.py')
for command in commands:
 result=subprocess.run(command,cwd=ROOT)
 assert result.returncode==0,(command,result.returncode)
print(json.dumps({'final_profile':5,'scope_and_freeze':'PASS','full_gates':'gates-02 PASS'}),flush=True)

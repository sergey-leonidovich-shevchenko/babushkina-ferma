"""Same-source controlled red/green; restore only this task's new facade in finally."""
import hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
p=ROOT/'tools/performance_protocol.py';held=R/'protocol-facade-held.txt';assert p.is_file()and not held.exists()
test=ROOT/'tools/qa/performance/test_performance_layout.py';signature=hashlib.sha256(test.read_bytes()).hexdigest();facade=p.read_bytes()
records=[]
try:
 p.rename(held)
 with(R/'frozen-graph-red.txt').open('w')as stream:
  process=subprocess.run([sys.executable,str(ROOT/'tools/run.py'),'qa.performance.test_performance_layout'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
 assert process.returncode==1 and 'FAILED (failures=1, errors=1)'in(R/'frozen-graph-red.txt').read_text()
 records.append({'phase':'red','exit':process.returncode,'test_sha256':signature,'log':'frozen-graph-red.txt'})
finally:
 if held.exists():held.rename(p)
assert p.read_bytes()==facade and hashlib.sha256(test.read_bytes()).hexdigest()==signature
with(R/'frozen-graph-green.txt').open('w')as stream:
 process=subprocess.run([sys.executable,str(ROOT/'tools/run.py'),'qa.performance.test_performance_layout'],cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
assert process.returncode==0 and 'Ran 8 tests'in(R/'frozen-graph-green.txt').read_text()and(R/'frozen-graph-green.txt').read_text().rstrip().endswith('OK')
records.append({'phase':'green','exit':process.returncode,'test_sha256':signature,'log':'frozen-graph-green.txt'})
for row in records:row['raw_sha256']=hashlib.sha256((R/row['log']).read_bytes()).hexdigest()
(R/'frozen-graph-proof.json').write_text(json.dumps({'cases':8,'same_test_SHA256':signature,'records':records,
 'only_new_facade_removed_for_red_then_restored':True,'frozen_sources_unchanged':True,'new_game_or_FPS_admission':False},indent=2)+'\n')
shutil.copyfile(__file__,R/'frozen-proof-final.py');print(json.dumps({'same_source':signature,'red':'1fail/1error','green':'8/0','facade_restored':True}))

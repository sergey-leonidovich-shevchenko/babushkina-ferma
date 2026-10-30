"""Record real parent/current reader replays, unchanged old tests and frozen repository boundaries."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
BASE='2c856d7d3d0a185735f17bdc5fa3f8c258b836d8'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
from tools.qa.foliage import grass_methods as current

def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE
old_path=R/'baseline/grass_methods.py'
assert old_path.read_bytes()==git(Q,'show',BASE+':tools/qa/foliage/grass_methods.py')
spec=importlib.util.spec_from_file_location('launch_boundary_parent',old_path)
parent=importlib.util.module_from_spec(spec);spec.loader.exec_module(parent)
proof=json.loads((R/'baseline/reviewer-launch-boundary.json').read_text());replayed=[]
for row in proof:
 result={'case':row['case'],'command':row['command']}
 with tempfile.TemporaryDirectory(prefix='real launch reader replay ') as directory:
  folder=Path(directory);profile='Codex-VRENDER-002-boundary-review'
  env={'exit_code':0,'jobs_after':[],'profile':profile,'command':row['command']}
  (folder/'environment.json').write_text(json.dumps(env));(folder/'engine.txt').write_text('controlled metadata; no engine/frame\n')
  source={'source_paths':{current.CAPTURE_SOURCE[0]:'tools/qa/foliage/grass_compare/capture.gd'}}
  for label,module in [('parent',parent),('current',current)]:
   try:module.launch(folder,profile,source)
   except ValueError as error:result[label]={'accepted':False,'error':str(error)}
   else:result[label]={'accepted':True}
 assert result['parent']['accepted'] is True
 assert result['current']['accepted']==(row['case']=='valid_before_user_separator')
 replayed.append(result)

old_test=ast.parse((R/'baseline/test_relocation_provenance.py').read_text())
new_test_path=Q/'tools/qa/foliage/test_relocation_provenance.py';new_test=ast.parse(new_test_path.read_text())
def methods(tree):return {n.name:ast.dump(n,include_attributes=False) for n in ast.walk(tree) if isinstance(n,ast.FunctionDef) and n.name.startswith('test_')}
before,after=methods(old_test),methods(new_test)
assert len(before)==10 and len(after)==20 and all(after[n]==body for n,body in before.items())
assert new_test_path.read_bytes()==(R/'baseline/test_red_green.py').read_bytes()
red=(R/'parent-red.txt').read_text();green=(R/'current-green.txt').read_text()
assert 'Ran 20 tests' in red and 'FAILED (failures=32, errors=4)' in red
assert 'Ran 20 tests' in green and green.rstrip().endswith('OK')
UID={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
 for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert len(UID)==304
foreign={n:{'working_SHA256':sha((P/n).read_bytes()),'index_SHA256':sha(git(P,'show',':'+n))}
 for n in ['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']}
result={'task':'REFACTOR-03','parent':BASE,'parent_review':'CHANGES REQUESTED / P2 engine/user CLI boundary',
 'source_permalink':'https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/blob/'+BASE+'/tools/qa/foliage/grass_methods.py#L96-L97',
 'parent_reader_SHA256':sha(old_path.read_bytes()),'current_reader_SHA256':sha((Q/'tools/qa/foliage/grass_methods.py').read_bytes()),
 'same_red_green_test_SHA256':sha(new_test_path.read_bytes()),'test_cases':20,'old_test_methods_unchanged':10,'added_test_methods':10,
 'new_semantic_subcases':54,'parent_failed_subtests':32,'parent_errors':4,'current_passed':20,
 'actual_reviewer_replay':replayed,'engine_launched':False,'native_frames':0,'FPS_admission':False,
 'full_gates':'required separately for candidate381','full03_done':False,'Task_Complete':False,'main_changed':False}
(R/'result.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
(R/'baseline/UID-and-foreign.json').write_text(json.dumps({'UID':UID,'primary_foreign':foreign},indent=2)+'\n')
print(json.dumps({'red':[20,32,4],'green':20,'old_methods_unchanged':10,'reviewer_cases_replayed':3,'UID':304}))

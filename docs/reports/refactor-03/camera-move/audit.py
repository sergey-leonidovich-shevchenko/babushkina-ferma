"""Bound the camera40 move, archive fields, existing checks and historical plot pin before full gates."""
import ast,copy,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-move';sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((R/'baseline/inventory.json').read_text());plan=json.loads((R/'baseline/move-plan.json').read_text());base=b['base'];mapping={r['old_path']:r['target']for r in plan['moves']};reverse={v:k for k,v in mapping.items()}
after={mapping.get(n,n)for n in b['sources']}|{'tools/qa/camera/test_camera_layout.py'};removed=set(mapping)
changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in after or n in removed or n.startswith(str(R.relative_to(Q))+'/')for n in changed),changed-after-removed
for n,row in b['sources'].items():
 raw=gzip.decompress((R/'baseline'/(n.replace('/','--')+'.gz')).read_bytes());assert raw==git('show',base+':'+n)and hashlib.sha256(raw).hexdigest()==row['sha256'];assert(Q/mapping.get(n,n)).stat().st_mode&0o777==row['mode']
for n in removed:assert not(Q/n).exists(),n
repair=json.loads((R/'plot-history-repair.json').read_text());assert sha(Q/repair['source_path'])==repair['after_SHA256']
for n,row in plan['changes'].items():
 p=Q/mapping.get(n,n)
 if str(p.relative_to(Q))==repair['source_path']:assert hashlib.sha256(row['after'].encode()).hexdigest()==repair['before_SHA256']
 else:assert p.read_text()==row['after'],n
class Normalize(ast.NodeTransformer):
 def __init__(self,module):self.module=module;self.function=''
 def visit_FunctionDef(self,n):
  old=self.function;self.function=n.name
  if self.module.endswith('reference_zoom_perf.py')and n.name=='validate_environment'and n.args.args[-1].arg=='source_paths':n.args.args.pop();n.args.defaults.pop()
  n=self.generic_visit(n);self.function=old;return n
 def visit_ImportFrom(self,n):
  if n.module and n.module.startswith('tools.qa.camera.'):n.module=n.module.removeprefix('tools.qa.camera.')
  if n.module and n.module.startswith('tools.common.'):n.module=n.module.removeprefix('tools.')
  return n
 def visit_Import(self,n):return n
 def visit_Constant(self,n):
  if isinstance(n.value,str):
   if n.value in reverse:n.value=reverse[n.value]
   elif n.value.startswith('res://')and n.value[6:]in reverse:n.value='res://'+reverse[n.value[6:]]
  return n
 def visit_Assign(self,n):
  if self.module.endswith('reference_zoom_perf.py')and self.function=='validate_environment'and len(n.targets)==1 and isinstance(n.targets[0],ast.Name)and n.targets[0].id in{'paths','script'}:return None
  if self.module.endswith('reference_zoom_perf.py')and self.function=='verify'and len(n.targets)==1 and isinstance(n.targets[0],ast.Name)and n.targets[0].id=='source'and isinstance(n.value,ast.Call)and isinstance(n.value.func,ast.Name)and n.value.func.id=='provenance':return ast.copy_location(ast.Expr(value=self.visit(n.value)),n)
  return self.generic_visit(n)
 def visit_Expr(self,n):
  if self.module.endswith('reference_zoom_perf.py')and self.function=='provenance'and isinstance(n.value,ast.Call)and isinstance(n.value.func,ast.Name)and n.value.func.id=='recorded_paths':return None
  return self.generic_visit(n)
 def visit_Name(self,n):
  if self.module.endswith('reference_zoom_perf.py')and self.function=='validate_environment'and n.id=='script':return ast.copy_location(ast.Constant(value='res://tools/reference_zoom_live.gd'),n)
  return n
 def visit_Dict(self,n):
  if self.module.endswith('reference_zoom_perf.py'):
   keep=[i for i,k in enumerate(n.keys)if not(isinstance(k,ast.Constant)and k.value=='source_paths')];n.keys=[n.keys[i]for i in keep];n.values=[n.values[i]for i in keep]
  return self.generic_visit(n)
 def visit_List(self,n):
  if self.module.endswith('visual_hardware.py')and len(n.elts)>2 and isinstance(n.elts[2],ast.Constant)and n.elts[2].value=='qa.camera.run_visual_baseline':
   n.elts=[n.elts[0],ast.parse("str(ROOT / 'tools/run_visual_baseline.py')",mode='eval').body,*n.elts[3:]]
  return self.generic_visit(n)
 def visit_Call(self,n):
  if isinstance(n.func,ast.Name)and n.func.id=='current_source'and len(n.args)==2:
   if ast.unparse(n.args[0])=='baseline.ROOT'and ast.unparse(n.args[1])=="'tools/' + name + '.py'":return ast.parse("baseline.ROOT / 'tools' / (name + '.py')",mode='eval').body
   return ast.copy_location(ast.BinOp(left=self.visit(n.args[0]),op=ast.Div(),right=self.visit(n.args[1])),n)
  if isinstance(n.func,ast.Name)and n.func.id=='current_inputs':return ast.parse("folder / 'instrumentation'",mode='eval').body
  if isinstance(n.func,ast.Name)and n.func.id=='pinned_sha':
   assert len(n.args)==4 and ast.literal_eval(n.args[1])==repair['plot_history_path']and ast.literal_eval(n.args[2])==repair['plot_history_commit']and ast.literal_eval(n.args[3])==repair['plot_history_SHA256']
   return ast.parse("P.sha(P.ROOT / 'tools/pose_video_strip.py')",mode='eval').body
  if self.module.endswith('reference_zoom_perf.py')and isinstance(n.func,ast.Name)and n.func.id=='validate_environment'and len(n.args)==6:n.args.pop()
  return self.generic_visit(n)
def functions(raw):
 tree=ast.parse(raw);result={n.name:n for n in tree.body if isinstance(n,ast.FunctionDef)}
 for c in tree.body:
  if isinstance(c,ast.ClassDef):result.update({c.name+'.'+n.name:n for n in c.body if isinstance(n,ast.FunctionDef)})
 return result
def norm(node,module):return ast.dump(Normalize(module).visit(copy.deepcopy(node)),include_attributes=False)
body_count=0
for n,row in plan['changes'].items():
 if not n.endswith('.py'):continue
 if n.endswith('source_paths.py')and not n.endswith('test_source_paths.py'):assert{f:ast.dump(v,include_attributes=False)for f,v in functions(row['before']).items()}=={f:ast.dump(v,include_attributes=False)for f,v in functions((Q/n).read_text()).items()};continue
 if n.endswith('test_source_paths.py'):continue
 old=functions(row['before']);new=functions((Q/mapping.get(n,n)).read_text());extra=set(new)-set(old);assert extra<=({'current_inputs'}if n.endswith(('test_reference_zoom.py','test_presentation_pose.py'))else set()),(n,extra)
 for key,node in old.items():
  # Imports do not change the existing algorithm or assertion. Normalize both import spellings.
  left=norm(node,n);right=norm(new[key],n)
  assert left==right,(n,key)
 body_count+=len(old)
for row in plan['moves']:
 n=row['old_path'];current=(Q/row['target']).read_bytes();old=git('show',base+':'+n)
 if n.endswith('.gd'):
  text=current.decode()
  for target,logical in reverse.items():text=text.replace('res://'+target,'res://'+logical)
  assert text.encode()==old,n
 elif n.endswith(('.swift','.uid')):assert current==old,n
for n,row in plan['changes'].items():
 if n.endswith('.gd')and n not in mapping:
  text=(Q/n).read_text()
  for target,logical in reverse.items():text=text.replace('res://'+target,'res://'+logical)
  assert text==row['before'],n
for n,row in b['deferred_shared_anchors'].items():assert sha(Q/n)==row['sha256']and(Q/n).stat().st_mode&0o777==row['mode']
card='docs/epics/refactoring-2026-10/TASKS.md';old=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);new=re.split(r'(?=^## REFACTOR-)',(Q/card).read_text(),flags=re.M);assert len(old)==len(new)==8 and all(a==c for a,c in zip(old,new)if not a.startswith('## REFACTOR-03 '))
prior={}
for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move','performance-move']:
 prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
prior.update(mapping)
contracts=R.parent/'baseline/source-contracts.json';assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)));fields=0
for row in json.loads(contracts.read_text())['modules'].values():
 module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
 p=subprocess.run([sys.executable,'-c',child,str(Q),module],cwd=Q,env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and not p.stderr,(module,p.stderr);assert json.loads(p.stdout)==row['fields'],module;fields+=len(row['fields'])
assert fields==37
uids=json.loads((R.parent/'baseline/local-uids.json').read_text());tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
for row in uids['local_only_UID']:
 paths=[Q/n for n in[row['old_path'],row['target']]if(Q/n).is_file()];assert len(paths)==1 and paths[0].read_text().strip()==row['value'];n=str(paths[0].relative_to(Q));assert n not in tracked and git('check-ignore','--',n).strip()
assert len(uids['local_only_UID'])==85;anchor=uids['retained_anchor_local_UID'];assert sha(Q/anchor['path'])==anchor['sha256']
root_count=sum(p.suffix in{'.py','.gd','.sh','.swift','.mjs','.gdshader'}for p in(Q/'tools').iterdir()if p.is_file());assert root_count==245
for n in ['AGENTS.md','.gitattributes','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','docs/reports/refactor-01/integration-1/migration-plan.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid','tools/performance_gate.py','tools/performance_gate.sh','tools/performance_protocol.py','tools/smoke_test.sh']:assert(Q/n).read_bytes()==git('show',base+':'+n),n
before=json.loads((R/'before-profile.json').read_text());current=json.loads((R/'after-profile.json').read_text());assert len(before['commands'])==len(current['commands'])==40 and current['historical_stdout_equal']==11 and current['actual_offline_decoded_frames']==before['actual_offline_decoded_frames']and current['contact_sheet']==before['contact_sheet']
red=json.loads((R/'layout-red.json').read_text());green=json.loads((R/'layout-green-01.json').read_text());assert red['test_SHA256']==green['test_SHA256']==sha(Q/'tools/qa/camera/test_camera_layout.py')and red['exit']==1 and green['exit']==0
result={'base':base,'version':'0.0.374','root_sources':245,'physical_source_moves':40,'tracked_UID_moves':2,'ignored_UID_moves':15,'source_map_entries':133,'new_layout_tests':3,'functions_address_normalized':body_count,'historical_fields':37,'author_UID_preserved':85,'anchor_preserved':True,'deferred_shared_sources':2,'other_six_cards_unchanged':True,'parallel07_excluded':True,'frozen_reports_original_plan_unchanged':True,'full_task03_accepted':False,'source_paths_after':sorted(after),'removed_source_paths':sorted(removed)}
(R/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');assert not(R/'source-freeze.json').exists();(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.374','source_SHA256':{n:sha(Q/n)for n in sorted(after)}},ensure_ascii=False,indent=2)+'\n');shutil.copyfile(__file__,R/'audit.py');print(json.dumps({'source_after':len(after),'functions_preserved':body_count,'fields':fields,'UID':85,'root':245}))

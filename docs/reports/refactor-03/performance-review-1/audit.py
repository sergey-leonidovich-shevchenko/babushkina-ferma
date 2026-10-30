"""Audit the narrowly scoped producer repair before full gates; preserve frozen evidence and plan07."""
import ast,copy,collections,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-review-1'
sys.path[:0]=[str(ROOT),str(ROOT/'tools')]
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((R/'baseline/inventory.json').read_text());base=b['base']
after=set(b['sources'])|{'tools/qa/performance/source_history.py','tools/qa/performance/test_surface_producers.py'}
changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
prefix=str(R.relative_to(ROOT))+'/'
assert all(n in after or n.startswith(prefix)for n in changed),[n for n in changed if n not in after and not n.startswith(prefix)]
for name,row in b['sources'].items():
 raw=gzip.decompress((R/'baseline'/(name.replace('/','--')+'.gz')).read_bytes());assert raw==git('show',base+':'+name)and hashlib.sha256(raw).hexdigest()==row['sha256'],name
 assert(ROOT/name).stat().st_mode&0o777==row['mode'],name
class Normalize(ast.NodeTransformer):
 def visit_Assign(self,n):
  if len(n.targets)==1 and isinstance(n.targets[0],ast.Name)and n.targets[0].id=='physical':
   assert isinstance(n.value,ast.IfExp)and isinstance(n.value.body,ast.Call)and n.value.body.func.id=='historical_helper'
   return None
  return self.generic_visit(n)
 def visit_Name(self,n):
  if n.id=='physical':n.id='name'
  return n
 def visit_Call(self,n):
  n=self.generic_visit(n)
  if isinstance(n.func,ast.Name)and n.func.id=='current_source':
   assert len(n.args)==2 and n.args[0].id=='ROOT';return ast.copy_location(ast.BinOp(left=n.args[0],op=ast.Div(),right=n.args[1]),n)
  if isinstance(n.func,ast.Attribute)and isinstance(n.func.value,ast.Name)and n.func.value.id=='subprocess':
   n.keywords=[k for k in n.keywords if k.arg!='env']
   if n.args and isinstance(n.args[0],ast.List):n.args[0].elts=[x for x in n.args[0].elts if not(isinstance(x,ast.Constant)and x.value=='--no-replace-objects')]
  return n
def functions(raw):return{n.name:n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
body_count=0
for name in ['tools/grass_compare_collect.py','tools/ground_layers.py','tools/grass_methods.py']:
 old=functions(git('show',base+':'+name).decode());current=functions((ROOT/name).read_text());assert set(old)==set(current)
 for key,node in old.items():assert ast.dump(node,include_attributes=False)==ast.dump(Normalize().visit(copy.deepcopy(current[key])),include_attributes=False),(name,key)
 body_count+=len(old)
name='tools/assets/contracts/source_paths.py';old=ast.parse(git('show',base+':'+name));new=ast.parse((ROOT/name).read_text())
assert {k:ast.dump(v,include_attributes=False)for k,v in functions(git('show',base+':'+name)).items()}=={k:ast.dump(v,include_attributes=False)for k,v in functions((ROOT/name).read_text()).items()}
from tools.assets.contracts.source_paths import MOVED_PATHS
old_map=ast.literal_eval(next(n.value.args[0]for n in old.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='MOVED_PATHS'for t in n.targets)))
assert len(old_map)==90 and dict(MOVED_PATHS)=={**old_map,'tools/perf_contract_collect.py':'tools/qa/performance/perf_contract_collect.py'}
tests='tools/assets/contracts/test_source_paths.py'
def methods(raw):return{(c.name,n.name):n for c in ast.parse(raw).body if isinstance(c,ast.ClassDef)for n in c.body if isinstance(n,ast.FunctionDef)and n.name.startswith('test_')}
old_tests=methods(git('show',base+':'+tests));new_tests=methods((ROOT/tests).read_text());assert set(old_tests)==set(new_tests)and len(old_tests)==12
for key,node in old_tests.items():
 if key[1]!='test_table_matches_accepted_plan_and_actual_files':assert ast.dump(node,include_attributes=False)==ast.dump(new_tests[key],include_attributes=False)
 else:
  def asserts(node):return collections.Counter(ast.dump(n,include_attributes=False)for n in ast.walk(node)if isinstance(n,ast.Call)and isinstance(n.func,ast.Attribute)and n.func.attr.startswith('assert'))
  assert not(asserts(node)-asserts(new_tests[key]))
assert(ROOT/'.gitattributes').read_bytes()==git('show',base+':.gitattributes')
for name in ['AGENTS.md','.gitignore','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','docs/epics/visual-overhaul-2026-10/backlog.json',
 'docs/reports/refactor-01/integration-1/migration-plan.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid',
 'tools/performance_gate.py','tools/performance_gate.sh','tools/performance_protocol.py','tools/smoke_test.sh','tools/qa/performance/perf_contract_collect.py']:
 assert(ROOT/name).read_bytes()==git('show',base+':'+name),name
card='docs/epics/refactoring-2026-10/TASKS.md';a=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);c=re.split(r'(?=^## REFACTOR-)',(ROOT/card).read_text(),flags=re.M)
assert len(a)==len(c)==8 and all(x==y for x,y in zip(a,c)if not x.startswith('## REFACTOR-03 '))
prior={}
for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move','performance-move']:
 prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
contracts=R.parent/'baseline/source-contracts.json';assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
fields=0
for row in json.loads(contracts.read_text())['modules'].values():
 module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
 p=subprocess.run([sys.executable,'-c',child,str(ROOT),module],cwd=ROOT,env=git_environment(),capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and not p.stderr,(module,p.stderr);assert json.loads(p.stdout)==row['fields'],module;fields+=len(row['fields'])
assert fields==37
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')));uids=json.loads((R.parent/'baseline/local-uids.json').read_text())
for row in uids['local_only_UID']:
 paths=[ROOT/n for n in[row['old_path'],row['target']]if(ROOT/n).is_file()];assert len(paths)==1 and paths[0].read_text().strip()==row['value']
 name=str(paths[0].relative_to(ROOT));assert name not in tracked and git('check-ignore','--',name).strip()
assert len(uids['local_only_UID'])==85;anchor=uids['retained_anchor_local_UID'];assert sha(ROOT/anchor['path'])==anchor['sha256']
root_count=sum(p.suffix in{'.py','.gd','.sh','.swift','.mjs','.gdshader'}for p in(ROOT/'tools').iterdir()if p.is_file());assert root_count==285
profile=json.loads((R/'profile.json').read_text());assert len(profile['paired_actual_producers'])==4 and len(profile['commands'])==6 and all(x['exit']==0 for x in profile['commands'])
regression=json.loads((R/'regression.json').read_text());assert regression['same_test_source']and sha(ROOT/'tools/qa/performance/test_surface_producers.py')==regression['test_SHA256']
result={'base':base,'version':'0.0.372','root_sources':285,'physical_moves':0,'UID_moves':0,'new_producer_tests':9,
 'producer_and_reader_functions_preserved_with_address_only_normalization':body_count,'source_map_original90_exact_plus_one':True,
 'old_source_path_tests_preserved':12,'historical_fields':37,'author_UID_preserved':85,'anchor_preserved':True,
 'other_six_cards_unchanged':True,'parallel07_excluded':True,'runtime_artwork_oldreports_GD_UID_originalplan_unchanged':True,
 'full_task03_accepted':False,'source_paths_after':sorted(after),'removed_source_paths':[]}
(R/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(R/'migration.json').write_text(json.dumps({'base':base,'root_sources_after_moves':285,'moves':[],'phase':'P2surfaceproducerrepair'},indent=2)+'\n')
assert not(R/'source-freeze.json').exists();(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.372','source_SHA256':{n:sha(ROOT/n)for n in sorted(after)}},ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,R/'audit.py');print(json.dumps({'source_after':len(after),'functions_preserved':body_count,'fields':fields,'UID':85,'root':285}))

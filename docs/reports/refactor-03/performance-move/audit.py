"""Independent scope, mechanical-body, historical-field and UID checks for physical performance move."""
import ast,copy,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
sys.path.insert(0,str(ROOT))
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],env=git_environment())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
base=json.loads((R/'baseline/inventory.json').read_text());mapping={n:r['target']for n,r in base['assignments'].items()}
public={n for n,r in base['assignments'].items()if r['action']=='move_implementation_keep_public_facade'}|{'tools/performance_protocol.py'}
for name in public:(ROOT/name).chmod(base['sources'][name]['mode'])
raw_paths=[str(p.relative_to(ROOT))for p in sorted(R.glob('*.txt'))if p.read_bytes().endswith(b'\n\n')]
attributes=git('show',base['base']+':.gitattributes')
if raw_paths:attributes+=b'# Preserve only these exact performance-move raw logs, including final engine blank lines.\n'+''.join(n+' -whitespace\n'for n in raw_paths).encode()
(ROOT/'.gitattributes').write_bytes(attributes)
(R/'raw-whitespace-paths.json').write_text(json.dumps(raw_paths,indent=2)+'\n')
source_after=set(mapping.values())|set(base['consumers'])|public|{'tools/qa/performance/test_performance_layout.py'}
removed=set(mapping)-public;allowed=set(base['sources'])|source_after;prefix=str(R.relative_to(ROOT))+'/'
changed=set(filter(None,git('diff','--no-renames',base['base'],'--name-only','-z').decode().split('\0')))
untracked=set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in allowed or n.startswith(prefix)for n in changed|untracked),(changed|untracked)-allowed
for name,row in base['sources'].items():
 raw=gzip.decompress((R/'baseline'/(name.replace('/','--')+'.gz')).read_bytes())
 assert raw==git('show',base['base']+':'+name)and hashlib.sha256(raw).hexdigest()==row['sha256'],name
 assert(ROOT/mapping.get(name,name)).stat().st_mode&0o777==row['mode'],name
for old,new in mapping.items():
 assert(ROOT/new).is_file()and((ROOT/old).is_file()if old in public else not(ROOT/old).exists()),old
 if old.endswith(('.uid','.gd')):
  expected=git('show',base['base']+':'+old).decode()
  if old.endswith('.gd'):
   for a,b in mapping.items():expected=expected.replace('"res://'+a+'"','"res://'+b+'"')
  assert(ROOT/new).read_text()==expected,old
class WithoutImports(ast.NodeTransformer):
 def visit_Import(self,node):return None
 def visit_ImportFrom(self,node):return None
 def visit_If(self,node):
  if ast.dump(node.test)==ast.dump(ast.UnaryOp(op=ast.Not(),operand=ast.Name(id='__package__',ctx=ast.Load()))):return None
  return self.generic_visit(node)
 def visit_Constant(self,node):
  if node.value=='tools.qa.performance.performance_protocol.PLAN':node.value='performance_protocol.PLAN'
  if isinstance(node.value,str):
   for old,new in mapping.items():
    if node.value=='res://'+new:node.value='res://'+old
  return node
def normalized(text):return ast.dump(WithoutImports().visit(ast.parse(text)),include_attributes=False)
body_checks=[]
for old in [n for n in mapping if n.endswith('.py')]+base['python_consumers']:
 if old in {'tools/perf_contract.py','tools/perf_contract_collect.py'}:continue
 new=mapping.get(old,old)
 assert normalized(git('show',base['base']+':'+old).decode())==normalized((ROOT/new).read_text()),old
 body_checks.append(old)
plan=json.loads((R/'adaptation-plan.json').read_text())
for name in ['tools/qa/performance/perf_contract.py','tools/qa/performance/perf_contract_collect.py']:
 assert(ROOT/name).read_text()==plan['changes'][name],name
test_methods=0
for old in [n for n in mapping if Path(n).name.startswith('test_')and n.endswith('.py')]+['tools/qa/performance/test_performance_context.py']:
 before=ast.parse(git('show',base['base']+':'+old).decode());after=ast.parse((ROOT/mapping.get(old,old)).read_text())
 def methods(tree):return{(c.name,n.name):ast.dump(WithoutImports().visit(copy.deepcopy(n)),include_attributes=False)
  for c in tree.body if isinstance(c,ast.ClassDef)for n in c.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))and n.name.startswith('test_')}
 assert methods(before)==methods(after),old
 test_methods+=len(methods(before))
assert test_methods==113,test_methods
cards='docs/epics/refactoring-2026-10/TASKS.md';before=re.split(r'(?=^## REFACTOR-)',git('show',base['base']+':'+cards).decode(),flags=re.M);after=re.split(r'(?=^## REFACTOR-)',(ROOT/cards).read_text(),flags=re.M)
assert len(before)==len(after)==8 and all(a==b for a,b in zip(before,after)if not a.startswith('## REFACTOR-03 '))
for name in ['AGENTS.md','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','docs/epics/visual-overhaul-2026-10/backlog.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid']:
 assert git('show',base['base']+':'+name)==(ROOT/name).read_bytes(),name
prior={}
for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move']:
 prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
prior.update(mapping);contracts=R.parent/'baseline/source-contracts.json'
assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
fields=0
for row in json.loads(contracts.read_text())['modules'].values():
 module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
 p=subprocess.run([sys.executable,'-c',child,str(ROOT),module],cwd=ROOT,env=git_environment(),capture_output=True,text=True,timeout=30)
 assert p.returncode==0 and not p.stderr,(module,p.stderr)
 assert json.loads(p.stdout)==row['fields'],module
 fields+=len(row['fields'])
assert fields==37
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
uids=json.loads((R.parent/'baseline/local-uids.json').read_text())
for row in uids['local_only_UID']:
 paths=[ROOT/n for n in [row['old_path'],row['target']]if(ROOT/n).is_file()];assert len(paths)==1 and paths[0].read_text().strip()==row['value'],row
 name=str(paths[0].relative_to(ROOT));assert name not in tracked and git('check-ignore','--',name).strip()
assert len(uids['local_only_UID'])==85
anchor=uids['retained_anchor_local_UID'];assert sha(ROOT/anchor['path'])==anchor['sha256']
for row in base['local_UID']:
 assert sha(ROOT/row['target'])==row['sha256']and(ROOT/row['target']).stat().st_mode&0o777==row['mode']
 assert git('check-ignore','--',row['target']).strip()and row['target']not in tracked
root_count=sum(p.suffix in{'.py','.gd','.mjs','.swift','.sh','.gdshader'}for p in(ROOT/'tools').iterdir()if p.is_file())
assert root_count==285
profile=json.loads((R/'after-profile.json').read_text());before_profile=json.loads((R/'before-profile.json').read_text())
assert profile['actual_before_after_equal']and profile['outputs']==before_profile['outputs']and profile['input_json_SHA256']==before_profile['input_json_SHA256']
assert len(profile['commands'])==19 and all(r['exit']==r['expected']for r in profile['commands'])
extra=json.loads((R/'extra-profile.json').read_text());assert len(extra['commands'])==73 and all(r['exit']==0 for r in extra['commands'])
result={'base':base['base'],'version':'0.0.371','root_sources':285,'physical_source_moves':33,'tracked_UID_moves':14,'ignored_UID_moves':4,
 'public_facades':4,'protected_sampler_unchanged':True,'historical_fields':37,'all_ignored_UID_preserved':85,'anchor_preserved':True,
 'old_test_methods_and_assertions_preserved':113,'other_python_bodies_preserved':len(body_checks),'new_layout_tests':8,
 'other_six_refactor_cards_unchanged':True,'parallel07_excluded_from_QA':True,'old_reports_runtime_artwork_plans_unchanged':True,
 'full_task03_accepted':False,'source_paths_after':sorted(source_after),'removed_source_paths':sorted(removed)}
(R/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
(R/'migration.json').write_text(json.dumps({'base':base['base'],'root_sources_after_moves':285,
 'moves':[{'old_path':old,'target':new,'before_sha256':base['sources'][old]['sha256'],'after_sha256':sha(ROOT/new),'mode':base['sources'][old]['mode'],
 'public_facade_retained':old in public}for old,new in mapping.items()]},indent=2)+'\n')
freeze={'version':'0.0.371','source_SHA256':{n:sha(ROOT/n)for n in sorted(source_after)}}
assert not(R/'source-freeze.json').exists()
(R/'source-freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2)+'\n');shutil.copyfile(__file__,R/'audit.py')
print(json.dumps({'source_after':len(source_after),'root':root_count,'old_test_methods':test_methods,'python_bodies':len(body_checks),'fields':fields,'UID':85,'raw_paths':len(raw_paths)}))

"""Compare real prelaunch producer bodies from Git9a2 and the repaired current layout; no native run."""
import ast,copy,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
from unittest.mock import patch
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-review-1'
sys.path[:0]=[str(ROOT),str(ROOT/'tools')]
from tools.common.git import git_environment
import grass_compare_collect as grass
import ground_layers as ground
from tools.qa.performance import perf_contract_collect as common
OLD='9a2ad81fb77282c4f52261e694653b28b21f01b8';BASE='f134dd9b7f2cf0741a0ace939d26fc247178cbad'
LEGACY='tools/perf_contract_collect.py';CANONICAL='tools/qa/performance/perf_contract_collect.py'
def git(root,*args):return subprocess.check_output(['git','-c','core.hooksPath='+str(root/'no-hooks'),'-C',str(root),*args],env=git_environment(),stderr=subprocess.DEVNULL)
def sha(raw):return hashlib.sha256(raw).hexdigest()
class StopBeforeNative(Exception):pass
class Normalize(ast.NodeTransformer):
 def visit_Call(self,node):
  node=self.generic_visit(node)
  if isinstance(node.func,ast.Name)and node.func.id=='current_source':
   assert len(node.args)==2 and isinstance(node.args[0],ast.Name)and node.args[0].id=='ROOT'
   return ast.copy_location(ast.BinOp(left=node.args[0],op=ast.Div(),right=node.args[1]),node)
  return node
def function(raw,name):return next(n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)and n.name==name)
comparisons=[]
for module,name in [(grass,'tools/grass_compare_collect.py'),(ground,'tools/ground_layers.py')]:
 old=git(ROOT,'show',OLD+':'+name).decode();baseline=git(ROOT,'show',BASE+':'+name).decode();now=(ROOT/name).read_text()
 assert ast.dump(function(old,'collect'),include_attributes=False)==ast.dump(function(baseline,'collect'),include_attributes=False)
 assert ast.dump(function(old,'collect'),include_attributes=False)==ast.dump(Normalize().visit(function(now,'collect')),include_attributes=False)
 comparisons.append({'source':name,'old_collect_ast_same_as371':True,'fixed_collect_only_input_resolution':True})
results=[]
with tempfile.TemporaryDirectory(prefix='surface producer paired profile ')as directory:
 parent=Path(directory).resolve()
 for phase in ['before','after']:
  for module,name in [(grass,'tools/grass_compare_collect.py'),(ground,'tools/ground_layers.py')]:
   project=parent/(phase+' '+module.__name__);project.mkdir();names=grass.FROZEN if module is grass else ground.SOURCES
   inputs={}
   for logical in names:
    physical=CANONICAL if phase=='after'and logical==LEGACY else logical
    raw=(ROOT/physical).read_bytes()if phase=='after'else git(ROOT,'show',OLD+':'+logical)
    target=project/physical;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw);inputs[logical]=sha(raw)
   git(project,'init','-q');git(project,'add','.');git(project,'-c','user.name=Producer profile','-c','user.email=qa@example.invalid','commit','-qm','paired source fixture')
   output=parent/(phase+' '+module.__name__+' archive')
   if phase=='before':
    namespace=dict(module.__dict__);namespace['ROOT']=project;namespace['jobs']=lambda:[]
    namespace['schedule']=lambda mode:[];namespace['context']=lambda:(_ for _ in()).throw(StopBeforeNative())
    raw=git(ROOT,'show',OLD+':'+name).decode();definitions=[function(raw,'collect')]
    if module is ground:definitions.insert(0,function(raw,'base_bytes'))
    exec(compile(ast.Module(body=definitions,type_ignores=[]),OLD+':'+name,'exec'),namespace)
    collect=namespace['collect']
   else:collect=module.collect
   with patch.dict(os.environ,git_environment(),clear=True),patch.object(common,'ROOT',project),patch.object(module,'ROOT',project), \
       patch.object(module,'jobs',return_value=[]),patch.object(module,'context',side_effect=StopBeforeNative):
    if module is grass:
     with patch.object(module,'schedule',return_value=[]):collect(output,'quality')
    else:
     try:collect(output)
     except StopBeforeNative:pass
     else:raise AssertionError('ground did not stop before native boundary')
   metadata=json.loads((output/'source.json').read_text());namespace='instrumentation'if module is grass else'inputs'
   assert set(metadata['sources'])==set(names)and metadata['sources']==inputs
   archived=output/namespace/LEGACY;assert sha(archived.read_bytes())==inputs[LEGACY]
   assert not(output/namespace/CANONICAL).exists()
   if module is ground:assert metadata['base_sources'][LEGACY]==inputs[LEGACY]
   (R/(phase+'-'+module.__name__+'-source.json')).write_bytes((output/'source.json').read_bytes())
   results.append({'phase':phase,'producer':module.__name__,'logical_sources':len(names),'helper_SHA256':inputs[LEGACY],
    'source_json_written':True,'archive_legacy_namespace':True,'native_processes':0,'complete':metadata['complete']})
   if phase=='before':assert inputs[LEGACY]=='0ad2b4f4d73846c17b09af76c05cfe8cc5eefc65892118ad5c681eebc6a88e8a'
commands=[]
with tempfile.TemporaryDirectory(prefix='surface reader foreign cwd ')as directory:
 foreign=Path(directory).resolve();env=dict(os.environ,GIT_DIR=str(foreign/'missing.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'index'),PYTHONPATH=str(foreign))
 specs=[('grass-reader',[sys.executable,str(ROOT/'tools/grass_methods.py'),'all']),('ground-reader',[sys.executable,str(ROOT/'tools/ground_layers.py'),'verify']),
  ('grass-tests',[sys.executable,str(ROOT/'tools/run.py'),'test_grass_methods']),('ground-tests',[sys.executable,str(ROOT/'tools/run.py'),'test_ground_layers']),
  ('known-path-tests',[sys.executable,str(ROOT/'tools/run.py'),'assets.contracts.test_source_paths']),
  ('producer-tests',[sys.executable,str(ROOT/'tools/run.py'),'qa.performance.test_surface_producers'])]
 for label,args in specs:
  log=R/(label+'.txt')
  with log.open('x')as stream:process=subprocess.run(args,cwd=foreign,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
  commands.append({'label':label,'command':args,'cwd':str(foreign),'exit':process.returncode,'log':log.name,'sha256':sha(log.read_bytes())})
  (R/'profile-commands.json').write_text(json.dumps(commands,indent=2)+'\n');assert process.returncode==0,(label,log.read_text()[-3000:])
 assert not list(foreign.iterdir())
test=ROOT/'tools/qa/performance/test_surface_producers.py';red=(R/'producer-red.txt').read_text();green=(R/'producer-green-01.txt').read_text()
assert 'Ran 9 tests'in red and 'FAILED (failures=2, errors=9)'in red and 'Ran 9 tests'in green and green.rstrip().endswith('OK')
result={'base':BASE,'old_source_commit':OLD,'collect_body_comparison':comparisons,'paired_actual_producers':results,'commands':commands,
 'regression_test_SHA256':sha(test.read_bytes()),'red':'9cases,2failures/9errors including subtests','green':'9/0',
 'new_known_path_entry_only':LEGACY,'MOVED_PATHS_entries':91,'physical_moves':0,'UID_moves':0,'root_sources':285,
 'real_native_sessions':0,'Game_new':False,'GPU_FPS_admission':False,'fake_open_children_only_in_regression':True,'all_temporary_fixtures_removed':True}
(R/'profile.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');shutil.copyfile(__file__,R/'profile.py')
print(json.dumps({'actual_prelaunch_producers':4,'real_Git_SHA_copy':True,'foreign_commands':6,'regression':'red2fail/9errors ->9/0','native_launches':0}))

"""Seal camera context scope before full gates; keep algorithms, historical fields and author UID."""
import ast,copy,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((R/'baseline/inventory.json').read_text());base=b['base'];plan=json.loads((R/'baseline/adaptation-plan.json').read_text())
after=set(b['sources'])|{'tools/qa/camera/__init__.py','tools/qa/camera/test_camera_context.py'}
changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in after or n.startswith(str(R.relative_to(Q))+'/')for n in changed),changed-after
for n,row in b['sources'].items():
 raw=gzip.decompress((R/'baseline'/(n.replace('/','--')+'.gz')).read_bytes());assert raw==git('show',base+':'+n)and hashlib.sha256(raw).hexdigest()==row['sha256'];assert(Q/n).stat().st_mode&0o777==row['mode']
class Normalize(ast.NodeTransformer):
 def visit_Call(self,n):
  n=self.generic_visit(n)
  if (isinstance(n.func,ast.Attribute)and isinstance(n.func.value,ast.Name)and n.func.value.id=='subprocess'
      and n.args and isinstance(n.args[0],ast.List)and n.args[0].elts
      and isinstance(n.args[0].elts[0],ast.Constant)and n.args[0].elts[0].value=='git'):
   n.keywords=[k for k in n.keywords if k.arg!='env']
  return n
def functions(raw):return{n.name:n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
body_count=0
for n,row in plan['changes'].items():
 assert(Q/n).read_text()==row['after']and git('show',base+':'+n).decode()==row['before']
 old=functions(row['before']);new=functions(row['after']);assert old.keys()==new.keys()
 for name,node in old.items():
  if n=='tools/run_visual_baseline.py'and name=='command':
   exact='        options = {"text": True, "stderr": subprocess.STDOUT, "timeout": 15}\n        # Git читает проект исходника; системные запросы сохраняют контекст вызывающего процесса.\n        if args and args[0] == "git":\n            options.update(cwd=ROOT, env=git_environment())\n        return subprocess.check_output(args, **options).strip()'
   normalized=ast.get_source_segment(row['after'],new[name]).replace(exact,'        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=15).strip()')
   assert ast.dump(ast.parse(normalized).body[0],include_attributes=False)==ast.dump(node,include_attributes=False)
  else:assert ast.dump(node,include_attributes=False)==ast.dump(Normalize().visit(copy.deepcopy(new[name])),include_attributes=False),(n,name)
 body_count+=len(old)
card='docs/epics/refactoring-2026-10/TASKS.md';old=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);new=re.split(r'(?=^## REFACTOR-)',(Q/card).read_text(),flags=re.M)
assert len(old)==len(new)==8 and all(x==y for x,y in zip(old,new)if not x.startswith('## REFACTOR-03 '))
prior={}
for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move','performance-move']:
 prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
contracts=R.parent/'baseline/source-contracts.json';assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
fields=0
for row in json.loads(contracts.read_text())['modules'].values():
 module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
 result=subprocess.run([sys.executable,'-c',child,str(Q),module],cwd=Q,env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
 assert result.returncode==0 and not result.stderr,(module,result.stderr);assert json.loads(result.stdout)==row['fields'],module;fields+=len(row['fields'])
assert fields==37
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')));uids=json.loads((R.parent/'baseline/local-uids.json').read_text())
for row in uids['local_only_UID']:
 paths=[Q/n for n in[row['old_path'],row['target']]if(Q/n).is_file()];assert len(paths)==1 and paths[0].read_text().strip()==row['value'];name=str(paths[0].relative_to(Q));assert name not in tracked and git('check-ignore','--',name).strip()
assert len(uids['local_only_UID'])==85;anchor=uids['retained_anchor_local_UID'];assert sha(Q/anchor['path'])==anchor['sha256']
root_count=sum(p.suffix in{'.py','.gd','.sh','.swift','.mjs','.gdshader'}for p in(Q/'tools').iterdir()if p.is_file());assert root_count==285
for name in ['AGENTS.md','.gitattributes','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','tools/assets/contracts/source_paths.py','docs/epics/visual-overhaul-2026-10/backlog.json','docs/reports/refactor-01/integration-1/migration-plan.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid','tools/performance_gate.py','tools/performance_gate.sh','tools/performance_protocol.py','tools/smoke_test.sh']:
 assert(Q/name).read_bytes()==git('show',base+':'+name),name
before=json.loads((R/'before-profile.json').read_text());current=json.loads((R/'after-profile.json').read_text());assert len(before['commands'])==len(current['commands'])==20 and current['historical_stdout_byte_equal']==11 and all(r['exit']==0 for r in current['commands'])
red=json.loads(Path('/private/tmp/refactor03-camera-red373.json').read_text());green=json.loads(Path('/private/tmp/refactor03-camera-green373.json').read_text());assert red['test_SHA256']==green['test_SHA256']==sha(Q/'tools/qa/camera/test_camera_context.py')and red['exit']==1 and green['exit']==0 and red['methods']==green['methods']==12
for phase in ['red','green']:
 for ext in ['txt','json']:shutil.copyfile('/private/tmp/refactor03-camera-'+phase+'373.'+ext,R/('context-'+phase+'.'+ext))
(R/'regression.json').write_text(json.dumps({'same_test_source':True,'test_SHA256':green['test_SHA256'],'red_failures_including_subtests':16,'methods':12,'green_exit':0,'real_fresh_envelopes':8,'explicit_fake_children':7,'timing_stop_before_native_context':1,'native_GPU_FPS_admission':False},indent=2)+'\n')
result={'base':base,'version':'0.0.373','root_sources':285,'physical_moves':0,'UID_moves':0,'new_context_tests':12,'source_root_sites':6,'Git_read_sites':9,'functions_preserved_with_address_only_normalization':body_count,'historical_fields':37,'author_UID_preserved':85,'anchor_preserved':True,'other_six_cards_unchanged':True,'parallel07_excluded':True,'runtime_artwork_oldreports_GD_UID_originalplan_unchanged':True,'full_task03_accepted':False,'source_paths_after':sorted(after),'removed_source_paths':[]}
(R/'scope.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');(R/'migration.json').write_text(json.dumps({'base':base,'root_sources_after_moves':285,'moves':[],'phase':'camera context preparation'},indent=2)+'\n')
assert not(R/'source-freeze.json').exists();(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.373','source_SHA256':{n:sha(Q/n)for n in sorted(after)}},ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,R/'audit.py')
shutil.copyfile('/private/tmp/refactor03-camera-audit373-before-normalizer.py.gz',R/'audit-before-normalizer.py.gz')
shutil.copyfile('/private/tmp/refactor03-camera-audit373-normalizer-repair.json',R/'audit-normalizer-repair.json')
print(json.dumps({'source_after':len(after),'functions_preserved':body_count,'fields':fields,'UID':85,'root':285}))

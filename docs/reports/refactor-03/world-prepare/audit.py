"""Freeze World preparation after unchanged real profiles; no algorithm, source-contract or UID relaxation."""
import ast,copy,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-prepare'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((R/'baseline/inventory.json').read_text());base=b['base'];plan=json.loads((R/'baseline/adaptation-plan.json').read_text())
after=set(b['sources'])|{'tools/qa/world/__init__.py','tools/qa/world/test_world_context.py'}
changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in after or n.startswith(str(R.relative_to(Q))+'/')for n in changed),changed-after
for name,row in b['sources'].items():
    raw=gzip.decompress((R/'baseline'/(name.replace('/','--')+'.gz')).read_bytes())
    assert raw==git('show',base+':'+name)and hashlib.sha256(raw).hexdigest()==row['sha256']
    assert(Q/name).stat().st_mode&0o777==row['mode']
class Normalize(ast.NodeTransformer):
    def visit_Call(self,node):
        node=self.generic_visit(node)
        if isinstance(node.func,ast.Attribute)and isinstance(node.func.value,ast.Name)and node.func.value.id=='subprocess'and node.args and isinstance(node.args[0],ast.List)and node.args[0].elts and isinstance(node.args[0].elts[0],ast.Constant)and node.args[0].elts[0].value=='git':
            node.keywords=[k for k in node.keywords if k.arg!='env']
        return node
functions=0;old_test_methods=0
for name,row in plan['changes'].items():
    assert(Q/name).read_text()==row['after']and git('show',base+':'+name).decode()==row['before']
    left=[n for n in ast.walk(ast.parse(row['before']))if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))]
    right=[n for n in ast.walk(ast.parse(row['after']))if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))]
    assert len(left)==len(right)
    for old,new in zip(left,right):
        normalized=copy.deepcopy(new)
        def git_calls(function):
            return[n for n in ast.walk(function)if isinstance(n,ast.Call)and isinstance(n.func,ast.Attribute)and isinstance(n.func.value,ast.Name)and n.func.value.id=='subprocess'and n.args and isinstance(n.args[0],ast.List)and n.args[0].elts and isinstance(n.args[0].elts[0],ast.Constant)and n.args[0].elts[0].value=='git']
        a,c=git_calls(old),git_calls(normalized);assert len(a)==len(c)
        for prior,current in zip(a,c):
            if not any(k.arg=='env'for k in prior.keywords):
                added=[k for k in current.keywords if k.arg=='env'];assert len(added)==1 and ast.unparse(added[0].value)=='git_environment()'
                current.keywords=[k for k in current.keywords if k.arg!='env']
        assert old.name==new.name and ast.dump(old,include_attributes=False)==ast.dump(normalized,include_attributes=False),(name,old.name)
        functions+=1
        if name.startswith('tools/test_')and old.name.startswith('test_'):old_test_methods+=1
card='docs/epics/refactoring-2026-10/TASKS.md'
left=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);right=re.split(r'(?=^## REFACTOR-)',(Q/card).read_text(),flags=re.M)
assert len(left)==len(right)==8 and all(x==y for x,y in zip(left,right)if not x.startswith('## REFACTOR-03 '))
prior={}
for phase in ['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move','performance-move','camera-move']:
    prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
contracts=R.parent/'baseline/source-contracts.json';assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
fields=0
for row in json.loads(contracts.read_text())['modules'].values():
    module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
    result=subprocess.run([sys.executable,'-c',child,str(Q),module],cwd=Q,env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
    assert result.returncode==0 and not result.stderr,(module,result.stderr)
    assert json.loads(result.stdout)==row['fields'],module;fields+=len(row['fields'])
assert fields==37
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')));uids=json.loads((R.parent/'baseline/local-uids.json').read_text())
for row in uids['local_only_UID']:
    paths=[Q/n for n in[row['old_path'],row['target']]if(Q/n).is_file()]
    assert len(paths)==1 and paths[0].read_text().strip()==row['value']
    name=str(paths[0].relative_to(Q));assert name not in tracked and git('check-ignore','--',name).strip()
assert len(uids['local_only_UID'])==85
anchor=uids['retained_anchor_local_UID'];assert sha(Q/anchor['path'])==anchor['sha256']
root_count=sum(p.suffix in{'.py','.gd','.sh','.swift','.mjs','.gdshader'}for p in(Q/'tools').iterdir()if p.is_file());assert root_count==245
for name in ['AGENTS.md','.gitattributes','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','tools/assets/contracts/source_paths.py','docs/epics/visual-overhaul-2026-10/backlog.json','docs/reports/refactor-01/integration-1/migration-plan.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid','tools/performance_gate.py','tools/performance_gate.sh','tools/performance_protocol.py','tools/smoke_test.sh','tools/visual_camera_points.gd','tools/encode_coordinate_video.swift']:
    assert(Q/name).read_bytes()==git('show',base+':'+name),name
before=json.loads((R/'before-profile.json').read_text());current=json.loads((R/'after-profile.json').read_text())
assert len(before['commands'])==len(current['commands'])==35 and current['historical_stdout_byte_equal']==21 and all(r['exit']==0 for r in current['commands'])
red=json.loads(Path('/private/tmp/refactor03-world-red375.json').read_text());green=json.loads(Path('/private/tmp/refactor03-world-green375.json').read_text())
assert red['test_SHA256']==green['test_SHA256']==sha(Q/'tools/qa/world/test_world_context.py')and red['exit']==1 and green['exit']==0 and red['methods']==green['methods']==19
for phase in ['red','green']:
    for ext in ['txt','json']:shutil.copyfile('/private/tmp/refactor03-world-'+phase+'375.'+ext,R/('context-'+phase+'.'+ext))
original=gzip.decompress((R/'baseline/world-context-test-attempt02.py.gz').read_bytes()).decode().replace('with self.assertRaises((ValueError,FileNotFoundError)):', 'with self.assertRaises(ValueError):',1)
first=json.loads((R/'context-red-attempt01.json').read_text());assert hashlib.sha256(original.encode()).hexdigest()==first['test_SHA256']
(R/'baseline/world-context-test-attempt01.py.gz').write_bytes(gzip.compress(original.encode(),mtime=0))
regression={'same_test_source':True,'test_SHA256':green['test_SHA256'],'red_failures_including_subtests':12,'red_errors':19,'methods':19,'green_exit':0,'nested_imports':9,'actual_fresh_writers_producers':4,'source_envelope_stop_before_native_context':2,'inventory_stop_after_real_JSON_CSV':1,'native_GPU_FPS_admission':False}
(R/'regression.json').write_text(json.dumps(regression,indent=2)+'\n')
scope={'base':base,'version':'0.0.375','root_sources':245,'physical_moves':0,'UID_moves':0,'new_context_tests':19,'source_root_sites':9,'Git_read_sites':42,'already_clean_Git_read_sites':9,'functions_preserved_with_address_only_normalization':functions,'existing_test_methods_in_changed_modules':old_test_methods,'historical_fields':37,'author_UID_preserved':85,'anchor_preserved':True,'other_six_cards_unchanged':True,'parallel07_excluded':True,'runtime_artwork_oldreports_GD_UID_originalplan_unchanged':True,'full_task03_accepted':False,'source_paths_after':sorted(after),'removed_source_paths':[]}
(R/'scope.json').write_text(json.dumps(scope,ensure_ascii=False,indent=2)+'\n')
(R/'migration.json').write_text(json.dumps({'base':base,'root_sources_after_moves':245,'moves':[],'phase':'World source-root/Git preparation'},indent=2)+'\n')
assert not(R/'source-freeze.json').exists()
(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.375','source_SHA256':{n:sha(Q/n)for n in sorted(after)}},ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,R/'audit.py')
print(json.dumps({'source_after':len(after),'functions_preserved':functions,'existing_test_methods_in_changed_modules':old_test_methods,'fields':fields,'UID':85,'root':245}))

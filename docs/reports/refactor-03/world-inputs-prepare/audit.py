"""Audit exact World I/O address substitutions, frozen contracts/UID and scope before full gates."""
import ast,copy,gzip,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-inputs-prepare'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
b=json.loads((R/'baseline/inventory.json').read_text());base=b['base'];plan=json.loads((R/'baseline/adaptation-plan.json').read_text())
new_files={'tools/qa/world/source_inputs.py','tools/qa/world/test_source_inputs.py','tools/qa/world/test_world_source_history.py','tools/qa/world/test_world_producers.py'}
after=set(b['sources'])|new_files
changed=set(filter(None,git('diff','--no-renames',base,'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in after or n.startswith(str(R.relative_to(Q))+'/')for n in changed),changed-after
for name,row in b['sources'].items():
    raw=gzip.decompress((R/'baseline'/(name.replace('/','--')+'.gz')).read_bytes());assert raw==git('show',base+':'+name)and hashlib.sha256(raw).hexdigest()==row['sha256'];assert(Q/name).stat().st_mode&0o777==row['mode']
def dump(node):return ast.dump(node,include_attributes=False)
def parts(node):return parts(node.left)+parts(node.right)if isinstance(node,ast.BinOp)and isinstance(node.op,ast.Add)else[node]
def old_git_calls(function):
    rows={}
    for node in ast.walk(function):
        if not(isinstance(node,ast.Call)and isinstance(node.func,ast.Attribute)and isinstance(node.func.value,ast.Name)and node.func.value.id=='subprocess'and node.args and isinstance(node.args[0],ast.List)):continue
        items=node.args[0].elts
        if len(items)<3 or not isinstance(items[0],ast.Constant)or items[0].value!='git':continue
        tag='show'if len(items)==3 and isinstance(items[1],ast.Constant)and items[1].value=='show'else'kind'if len(items)==4 and isinstance(items[1],ast.Constant)and items[1].value=='cat-file'and isinstance(items[2],ast.Constant)and items[2].value=='-t'else None
        if not tag:continue
        ref=parts(items[-1])
        if not(len(ref)==3 and isinstance(ref[1],ast.Constant)and ref[1].value==':'):continue
        root=next(k.value for k in node.keywords if k.arg=='cwd')
        key=(tag,dump(root),dump(ref[0]),dump(ref[2]),node.func.attr)
        rows.setdefault(key,[]).append(node)
    return rows
class Addresses(ast.NodeTransformer):
    def __init__(self, name, original):self.name=name;self.original=old_git_calls(original);self.normalized=0
    def visit_IfExp(self,node):
        # The only new conditional explicitly distinguishes current source root from archived instrumentation.
        if (isinstance(node.body,ast.Call)and isinstance(node.body.func,ast.Name)and node.body.func.id=='input_path'
                and ast.unparse(node.test)=='Path(folder).resolve() == ROOT.resolve()'and ast.unparse(node.orelse)=='folder / name'):
            self.normalized+=1;return copy.deepcopy(node.orelse)
        return self.generic_visit(node)
    def visit_Call(self,node):
        node=self.generic_visit(node)
        if isinstance(node.func,ast.Name):
            method=node.func.id
            if method=='input_path':
                assert len(node.args)==2 and not node.keywords and isinstance(node.args[0],ast.Name)and node.args[0].id=='ROOT'
                self.normalized+=1
                if self.name=='tools/pilot_static_collect.py':return ast.Call(func=ast.Name(id='source_path',ctx=ast.Load()),args=node.args,keywords=[])
                return ast.BinOp(left=node.args[0],op=ast.Div(),right=node.args[1])
            if method=='validate_contract'and len(node.args)==2 and ast.unparse(node.args[1])=='ROOT':
                self.normalized+=1;node.args=node.args[:1];return node
            if method in{'historical_bytes','historical_result','historical_kind'}:
                assert len(node.args)==3 and all(k.arg in{'text','allow_tree'}for k in node.keywords)
                if any(k.arg=='allow_tree'for k in node.keywords):assert self.name=='tools/pilot_static_audit.py'and any(k.arg=='allow_tree'and isinstance(k.value,ast.Constant)and k.value.value is True for k in node.keywords)
                tag='kind'if method=='historical_kind'else'show';call='run'if method=='historical_result'else'check_output'
                key=(tag,*(dump(a)for a in node.args),call);matches=self.original.get(key,[]);assert matches,(self.name,key)
                # Matching old operations are identical; preserve their original argv/keyword order exactly.
                assert all(dump(x)==dump(matches[0])for x in matches)
                self.normalized+=1;return copy.deepcopy(matches[0])
        return node
functions=0;normalized=0
for name,row in plan['changes'].items():
    assert(Q/name).read_text()==row['after']and git('show',base+':'+name).decode()==row['before']
    old=[n for n in ast.walk(ast.parse(row['before']))if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))]
    current=[n for n in ast.walk(ast.parse(row['after']))if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))]
    assert len(old)==len(current)
    for left,right in zip(old,current):
        normalizer=Addresses(name,left);adjusted=normalizer.visit(copy.deepcopy(right))
        assert left.name==right.name and dump(left)==dump(adjusted),(name,left.name)
        functions+=1;normalized+=normalizer.normalized
assert(Q/'tools/qa/world/source_inputs.py').read_text()==plan['new_helper']['source']
assert'from common.git import git_environment\n'not in(Q/'tools/pilot_static_verify.py').read_text()
assert(Q/'tools/pilot_static_verify.py').read_text().count('from tools.common.git import git_environment\n')==1
card='docs/epics/refactoring-2026-10/TASKS.md';left=re.split(r'(?=^## REFACTOR-)',git('show',base+':'+card).decode(),flags=re.M);right=re.split(r'(?=^## REFACTOR-)',(Q/card).read_text(),flags=re.M)
assert len(left)==len(right)==8 and all(a==c for a,c in zip(left,right)if not a.startswith('## REFACTOR-03 '))
prior={}
for phase in['authoring-move','audio-move','image-review-move','art-standard-move','assets-build-move','alpha-slicing-move','compatibility-move','performance-move','camera-move']:
    prior.update({r['old_path']:r['target']for r in json.loads((R.parent/phase/'migration.json').read_text())['moves']})
contracts=R.parent/'baseline/source-contracts.json';assert sha(contracts)=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
child=ast.literal_eval(next(n.value for n in ast.parse((R.parent/'snapshot-contracts.py').read_text()).body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='CHILD'for t in n.targets)))
fields=0
for row in json.loads(contracts.read_text())['modules'].values():
    module=prior.get(row['source'],row['source']).removesuffix('.py').replace('/','.')
    result=subprocess.run([sys.executable,'-c',child,str(Q),module],cwd=Q,env=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1'),capture_output=True,text=True,timeout=30)
    assert result.returncode==0 and not result.stderr,(module,result.stderr);assert json.loads(result.stdout)==row['fields'],module;fields+=len(row['fields'])
assert fields==37
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
for row in b['author_UID_exact']:
    p=Q/row['path'];assert sha(p)==row['sha256']and p.stat().st_mode&0o777==row['mode']and p.read_text().strip()==row['value'];assert row['path']not in tracked and git('check-ignore','--',row['path']).strip()
assert len(b['author_UID_exact'])==85 and sha(Q/b['anchor']['path'])==b['anchor']['sha256']
root_count=sum(p.suffix in{'.py','.gd','.sh','.swift','.mjs','.gdshader'}for p in(Q/'tools').iterdir()if p.is_file());assert root_count==245
for name in['AGENTS.md','.gitattributes','docs/backlog/README.md','wiki/planning/sources.json','wiki/articles/tools-migration-map.md','tools/assets/contracts/source_paths.py','tools/qa/art/current_paths.py','tools/qa/world/test_world_context.py','docs/epics/visual-overhaul-2026-10/backlog.json','docs/reports/refactor-01/integration-1/migration-plan.json','tools/performance_sampler.gd','tools/performance_sampler.gd.uid','tools/performance_gate.py','tools/performance_gate.sh','tools/performance_protocol.py','tools/smoke_test.sh','tools/visual_camera_points.gd','tools/encode_coordinate_video.swift','tools/render_order_game.gd','tools/render_order_game.gd.uid']:
    assert(Q/name).read_bytes()==git('show',base+':'+name),name
before=json.loads((R/'before-profile.json').read_text());current=json.loads((R/'after-profile.json').read_text());assert len(before['commands'])==len(current['commands'])==36 and current['historical_stdout_byte_equal']==21 and current['owned_water_outputs_byte_equal']==2 and all(r['exit']==0 for r in current['commands'])
history_old=json.loads((R/'history-red.json').read_text());history_new=json.loads((R/'history-green.json').read_text());assert history_old['test_SHA256']==history_new['test_SHA256']==sha(Q/'tools/qa/world/test_world_source_history.py')and history_old['methods']==history_new['methods']==12 and history_old['exit']==1 and history_new['exit']==0
producer_old=json.loads((R/'producers-before.json').read_text());producer_new=json.loads((R/'producers-after.json').read_text());assert producer_old['test_SHA256']==producer_new['test_SHA256']==sha(Q/'tools/qa/world/test_world_producers.py')and producer_old['methods']==producer_new['methods']==13 and producer_old['exit']==producer_new['exit']==0
api=json.loads((R/'helper-green.json').read_text());context=json.loads((R/'context-after.json').read_text());assert api['methods']==16 and context['methods']==19 and api['exit']==context['exit']==0
reg={'history_same_test_source':True,'history_test_SHA256':history_new['test_SHA256'],'history_methods':12,'history_red_failures':1,'history_red_errors':10,'history_parent_positive_control':1,'history_green_exit':0,'helper_new_API_methods':16,'producer_same_test_source':True,'producer_test_SHA256':producer_new['test_SHA256'],'producer_methods':13,'producer_before_after_exit':0,'old_context_methods':19,'old_context_source_unchanged':True,'fake_inventory_context_open':True,'native_Game_GPU_FPS_admission':False}
(R/'regression.json').write_text(json.dumps(reg,indent=2)+'\n')
scope={'base':base,'version':'0.0.376','root_sources':245,'physical_moves':0,'UID_moves':0,'current_input_sites':37,'historical_sites':14,'future_history_aliases':141,'current_source_map':133,'functions_preserved_with_address_only_normalization':functions,'address_normalizations':normalized,'historical_fields':37,'author_UID_exact':85,'anchor_preserved':True,'other_six_cards_unchanged':True,'parallel07_excluded':True,'review_P3_fixed':True,'water_FOLDER_fixed':True,'live_README_matches_latest_human_queue':True,'full_task03_accepted':False,'source_paths_after':sorted(after),'removed_source_paths':[]}
(R/'scope.json').write_text(json.dumps(scope,indent=2)+'\n');(R/'migration.json').write_text(json.dumps({'base':base,'root_sources_after_moves':245,'moves':[],'phase':'World current/history input preparation'},indent=2)+'\n')
assert not(R/'source-freeze.json').exists();(R/'source-freeze.json').write_text(json.dumps({'version':'0.0.376','source_SHA256':{n:sha(Q/n)for n in sorted(after)}},ensure_ascii=False,indent=2)+'\n')
shutil.copyfile(__file__,R/'audit.py');print(json.dumps({'source_after':len(after),'functions_preserved':functions,'address_normalizations':normalized,'fields':fields,'UID':85,'root':245}))

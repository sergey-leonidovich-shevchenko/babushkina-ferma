"""Plan World input/history preparation only; this script never changes repository files."""
import ast,hashlib,json,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE='e205c00729214358308f14c46b63c3bd2fdde2d9'
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==BASE
assert not subprocess.check_output(['git','-C',str(Q),'status','--porcelain'])
def original(name):return subprocess.check_output(['git','-C',str(Q),'show',BASE+':'+name]).decode()
def offset(lines,line,column):return sum(map(len,lines[:line-1]))+len(lines[line-1].encode()[:column].decode())
def span(source,node):
    lines=source.splitlines(keepends=True)
    return offset(lines,node.lineno,node.col_offset),offset(lines,node.end_lineno,node.end_col_offset)
def sum_parts(node):
    return sum_parts(node.left)+sum_parts(node.right)if isinstance(node,ast.BinOp)and isinstance(node.op,ast.Add)else[node]
def root_for(source,node):
    for keyword in node.keywords:
        if keyword.arg=='cwd':return ast.get_source_segment(source,keyword.value)
    raise AssertionError('missing explicit Git root')
changes={};sites={};current_sites={};helpers={}
collectors=['object_command_collect','pilot_pass_collect','pilot_static_collect','post_motion_collect',
            'shadow_inventory_collect','transient_save_collect']+['village_'+n+'_collect'for n in ['bench','board','fence','lamp','street','trade']]
show_selection={
 'object_command_collect':'first','object_command_verify':'first','pilot_pass_verify':'first',
 'pilot_static_verify':'first','post_motion_verify':'first','render_order':'first',
 **{'village_'+n+'_verify':'first'for n in ['bench','board','fence','lamp','street','trade']},
 'pilot_static_audit':'last'}
for module in sorted(set(collectors)|set(show_selection)|{'render_order','analyze_water_audit'}):
    name='tools/'+module+'.py';before=original(name);source=before;edits=[];used=set()
    if module in collectors or module=='render_order':
        for node in ast.walk(ast.parse(source)):
            if isinstance(node,ast.BinOp)and isinstance(node.op,ast.Div)and isinstance(node.left,ast.Name)and node.left.id=='ROOT'and not isinstance(node.right,ast.Constant):
                a,b=span(source,node);edits.append((a,b,'input_path(ROOT, '+ast.get_source_segment(source,node.right)+')'));used.add('input_path')
        current_sites[name]=len(edits)
        if module=='pilot_static_collect':
            needle='current=source_path(ROOT,name)';assert source.count(needle)==1
            a=source.index(needle);edits.append((a,a+len(needle),'current=input_path(ROOT,name)'));used.add('input_path')
            current_sites[name]+=1
    if module in show_selection:
        calls=[]
        for node in ast.walk(ast.parse(source)):
            if not(isinstance(node,ast.Call)and isinstance(node.func,ast.Attribute)and isinstance(node.func.value,ast.Name)and node.func.value.id=='subprocess'and node.func.attr in{'run','check_output'}and node.args and isinstance(node.args[0],ast.List)):continue
            elements=node.args[0].elts
            if len(elements)==3 and all(isinstance(x,ast.Constant)for x in elements[:2])and[e.value for e in elements[:2]]==['git','show']:
                parts=sum_parts(elements[2])
                if len(parts)==3 and isinstance(parts[1],ast.Constant)and parts[1].value==':':calls.append((node,parts[0],parts[2]))
        calls.sort(key=lambda x:x[0].lineno);assert calls,module
        node,base,logical=calls[0 if show_selection[module]=='first'else-1]
        assert all(k.arg in{'cwd','env','text','capture_output'}for k in node.keywords)
        method='historical_result'if node.func.attr=='run'else'historical_bytes';used.add(method)
        kwargs=', text=True'if any(k.arg=='text'and isinstance(k.value,ast.Constant)and k.value.value is True for k in node.keywords)else''
        if module=='pilot_static_audit':kwargs+=', allow_tree=True'
        replacement=method+'('+root_for(source,node)+', '+ast.get_source_segment(source,base)+', '+ast.get_source_segment(source,logical)+kwargs+')'
        a,b=span(source,node);edits.append((a,b,replacement));sites[name]=1
    if module=='pilot_static_audit':
        matching=[n for n in ast.walk(ast.parse(source))if isinstance(n,ast.Call)and isinstance(n.func,ast.Attribute)and isinstance(n.func.value,ast.Name)and n.func.value.id=='subprocess'and n.func.attr=='check_output'and n.args and isinstance(n.args[0],ast.List)and len(n.args[0].elts)==4 and isinstance(n.args[0].elts[1],ast.Constant)and n.args[0].elts[1].value=='cat-file']
        assert len(matching)==1
        node=matching[0];parts=sum_parts(node.args[0].elts[3]);assert len(parts)==3 and isinstance(parts[1],ast.Constant)and parts[1].value==':'
        a,b=span(source,node);edits.append((a,b,'historical_kind(ROOT, '+ast.get_source_segment(source,parts[0])+', '+ast.get_source_segment(source,parts[2])+')'));used.add('historical_kind');sites[name]+=1
    for a,b,replacement in sorted(edits,reverse=True):
        assert all(b<=c or a>=d for c,d,_ in edits if(c,d)!=(a,b)),(name,a,b)
        source=source[:a]+replacement+source[b:]
    if module=='render_order':
        needle='for name,digest in contract[\'sources\'].items(): require(sha(folder/name)==digest,\'source changed: \'+name)'
        assert source.count(needle)==1
        source=source.replace(needle,'for name,digest in contract[\'sources\'].items(): require(sha(input_path(ROOT,name) if Path(folder).resolve()==ROOT.resolve() else folder/name)==digest,\'source changed: \'+name)')
        assert source.count('validate_contract(contract)')==2
        source=source.replace('validate_contract(contract)','validate_contract(contract,ROOT)')
        used.add('input_path');current_sites[name]+=3
    if module=='pilot_static_verify':
        assert source.count('from common.git import git_environment\n')==1 and source.count('from tools.common.git import git_environment\n')==1
        source=source.replace('from common.git import git_environment\n','',1)
    if module=='pilot_static_collect':
        assert source.count('from tools.qa.art.current_paths import captured_paths, source_path\n')==1
        source=source.replace('from tools.qa.art.current_paths import captured_paths, source_path\n','from tools.qa.art.current_paths import captured_paths\n')
    if module=='analyze_water_audit':
        old="FOLDER = Path(__file__).resolve().parents[1] / 'docs/reports/water-2026-10'";assert source.count(old)==1
        source=source.replace(old,"from tools.common.paths import project_root\n\nFOLDER = project_root(__file__) / 'docs/reports/water-2026-10'")
    if used:
        line='from tools.qa.world.source_inputs import '+', '.join(sorted(used))+'\n'
        if 'prepare_imports(ROOT)\n'in source:
            source=source.replace('prepare_imports(ROOT)\n','prepare_imports(ROOT)\n'+line,1)
        elif module=='pilot_static_audit':
            marker='prepare_imports(project_root(__file__))\n';assert source.count(marker)==1
            source=source.replace(marker,marker+line,1)
        else:
            marker='from pathlib import Path\n';assert marker in source,name
            source=source.replace(marker,marker+line,1)
        helpers[name]=sorted(used)
    assert source!=before,name;compile(source,name,'exec')
    changes[name]={'before':before,'after':source,'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(source.encode()).hexdigest()}
helper=Path('/private/tmp/refactor03-source-inputs376.py').read_text();compile(helper,'source_inputs.py','exec')
out=Path('/private/tmp/refactor03-world-plan376.json');assert not out.exists()
out.write_text(json.dumps({'base':BASE,'applied':False,'physical_moves':0,'changes':changes,'historical_sites':sites,'current_sites':current_sites,'imports':helpers,'new_helper':{'target':'tools/qa/world/source_inputs.py','source':helper,'sha256':hashlib.sha256(helper.encode()).hexdigest()},'review_P3_removed':True,'water_FOLDER_fixed':True,'future_history_aliases':141,'current_source_map':133},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(changes),'history_sites':sum(sites.values()),'current_input_sites':sum(current_sites.values()),'root_sources':245,'physical_moves':0,'repository_changed':False}))

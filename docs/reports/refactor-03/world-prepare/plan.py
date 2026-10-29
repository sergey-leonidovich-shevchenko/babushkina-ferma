"""Prepare World source-root/Git reads only; keep the accepted map and archived namespaces intact."""
import ast, hashlib, json, re, subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
BASE='6b13af8ebf9ec603705c6d4e04577ce8774095da'
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==BASE
audit=json.loads(Path('/private/tmp/refactor03-world-readonly374.json').read_text())
changes={};roots=[];sites={};clean={}
def original(name):return subprocess.check_output(['git','-C',str(Q),'show',BASE+':'+name]).decode()
for row in audit['fixed_source_roots']:
    if 'parents[1]' not in row['binding']:continue
    name=row['source'];before=original(name)
    after,n=re.subn(r'(?m)^ROOT\s*=\s*Path\(__file__\)\.resolve\(\)\.parents\[1\]$',lambda _:'from common.paths import project_root\nfrom common.launch import prepare_imports\n\nROOT = project_root(__file__)\nprepare_imports(ROOT)',before)
    assert n==1,(name,n);roots.append(name);changes[name]={'before':before,'after':after}
for name in sorted({r['source']for r in audit['literal_Git_reads']}):
    before=original(name);source=changes.get(name,{}).get('after',before);lines=source.splitlines(keepends=True);positions=[];already=0
    for node in ast.walk(ast.parse(source)):
        if not(isinstance(node,ast.Call)and isinstance(node.func,ast.Attribute)and isinstance(node.func.value,ast.Name)and node.func.value.id=='subprocess'and node.args and isinstance(node.args[0],ast.List)and node.args[0].elts and isinstance(node.args[0].elts[0],ast.Constant)and node.args[0].elts[0].value=='git'):continue
        if any(k.arg=='env'for k in node.keywords):already+=1;continue
        assert any(k.arg=='cwd'and (isinstance(k.value,ast.Name)and k.value.id=='ROOT' or isinstance(k.value,ast.Attribute)and k.value.attr=='ROOT')for k in node.keywords),name
        positions.append(sum(map(len,lines[:node.end_lineno-1]))+node.end_col_offset-1)
    clean[name]=already
    if not positions:continue
    for end in sorted(positions,reverse=True):
        assert source[end]==')';source=source[:end]+', env=git_environment()'+source[end:]
    if 'from common.git import git_environment'not in source:
        # Insert an ordinary absolute helper import before the existing pathlib import.
        marker='from pathlib import Path';assert marker in source,name
        source=source.replace(marker,'from common.git import git_environment\n'+marker,1)
    changes[name]={'before':before,'after':source};sites[name]=len(positions)
assert len(roots)==9 and sum(sites.values())==42 and sum(clean.values())==9
for name,row in changes.items():
    compile(row['after'],name,'exec')
    row.update(before_sha256=hashlib.sha256(row['before'].encode()).hexdigest(),after_sha256=hashlib.sha256(row['after'].encode()).hexdigest())
out=Path('/private/tmp/refactor03-world-plan375.json');assert not out.exists()
out.write_text(json.dumps({'base':BASE,'applied':False,'roots':roots,'git_sites':sites,'already_clean':clean,'changes':changes},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'files':len(changes),'root_sites':len(roots),'git_sites':sum(sites.values()),'already_clean':9,'physical_moves':0}))

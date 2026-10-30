"""Plan mechanical imports/current/history/Git/GD address changes; do not apply product edits."""
import ast
import copy
import hashlib
import json
from pathlib import Path
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
inventory=json.loads((R/'baseline/inventory.json').read_text())
mapping={n:r['target'] for n,r in inventory['moves']['rows'].items()}
modules={Path(n).stem:target.removesuffix('.py').replace('/','.') for n,target in mapping.items()
    if n.endswith('.py') and Path(n).parent==Path('tools')}
sha=lambda raw:hashlib.sha256(raw).hexdigest()
changes={}

def replace_nodes(text,edits):
    lines=text.splitlines(keepends=True);offsets=[0]
    for line in lines:offsets.append(offsets[-1]+len(line))
    def pos(line,col):return offsets[line-1]+len(lines[line-1].encode()[:col].decode())
    spans=[(pos(n.lineno,n.col_offset),pos(n.end_lineno,n.end_col_offset),s) for n,s in edits]
    for a,b,s in sorted(spans,reverse=True):text=text[:a]+s+text[b:]
    return text

def import_text(module,alias):
    parent,leaf=module.rsplit('.',1)
    return 'from '+parent+' import '+leaf+(' as '+alias if alias and alias!=leaf else '')

def insert_imports(text,needed):
    tree=ast.parse(text)
    existing={}
    for n in tree.body:
        if isinstance(n,ast.ImportFrom):existing.setdefault(n.module,set()).update(a.name for a in n.names)
    lines=[]
    for module,names in sorted(needed.items()):
        names=set(names)-existing.get(module,set())
        if names:lines.append('from '+module+' import '+', '.join(sorted(names))+'\n')
    if not lines:return text
    index=next(n.lineno-1 for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom))
        and not(isinstance(n,ast.ImportFrom) and n.module=='__future__'))
    old=text.splitlines(keepends=True);return ''.join(old[:index]+lines+old[index:])

for name in sorted(inventory['sources']):
    p=Q/name
    if not name.endswith('.py'):continue
    before=p.read_text();text=before;edits=[];counts={'imports':0,'roots':0,'current':0,'history':0,'Git_env':0,'native_URI':0}
    for n in ast.walk(ast.parse(text)):
        if isinstance(n,ast.ImportFrom):
            target=modules.get(n.module or '') or modules.get((n.module or '').removeprefix('tools.'))
            old=ast.get_source_segment(text,n)
            if target:
                edits.append((n,old.replace('from '+n.module+' import','from '+target+' import',1)));counts['imports']+=1
            elif n.module=='tools' and any(a.name in modules for a in n.names):
                parts=[]
                for a in n.names:
                    parts.append(import_text(modules[a.name],a.asname) if a.name in modules else
                        'from tools import '+a.name+(' as '+a.asname if a.asname else ''))
                edits.append((n,'\n'.join(parts)));counts['imports']+=1
            elif name in mapping and n.module and n.module.startswith('common.'):
                edits.append((n,old.replace('from common.','from tools.common.',1)));counts['imports']+=1
        elif isinstance(n,ast.Import) and any(a.name in modules or a.name.removeprefix('tools.') in modules for a in n.names):
            parts=[]
            for a in n.names:
                key=a.name if a.name in modules else a.name.removeprefix('tools.')
                if key in modules:
                    assert not(a.name.startswith('tools.') and not a.asname),(name,ast.unparse(n))
                    parts.append(import_text(modules[key],a.asname or a.name))
                else:parts.append('import '+a.name+(' as '+a.asname if a.asname else ''))
            edits.append((n,'\n'.join(parts)));counts['imports']+=1
    text=replace_nodes(text,edits);edits=[];needed={}
    def need(module,name):needed.setdefault(module,set()).add(name)
    for n in ast.walk(ast.parse(text)):
        if name in mapping and isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='ROOT' for t in n.targets):
            if ast.unparse(n.value)=='Path(__file__).resolve().parents[1]':
                edits.append((n.value,'project_root(__file__)'));need('tools.common.paths','project_root');counts['roots']+=1
        if isinstance(n,ast.BinOp) and isinstance(n.op,ast.Div) and isinstance(n.left,ast.Name):
            current=(name in mapping and name.endswith('_collect.py') and n.left.id=='ROOT' and isinstance(n.right,ast.Name))
            current=current or(n.left.id in {'ROOT','root'} and isinstance(n.right,ast.Constant) and n.right.value in mapping)
            if current:
                edits.append((n,'input_path('+ast.unparse(n.left)+','+ast.unparse(n.right)+')'))
                need('tools.qa.world.source_inputs','input_path');counts['current']+=1
        if isinstance(n,ast.Call) and isinstance(n.func,ast.Attribute) and isinstance(n.func.value,ast.Name) and n.func.value.id=='subprocess' and n.args:
            argv=n.args[0]
            isgit=isinstance(argv,(ast.List,ast.Tuple)) and argv.elts and isinstance(argv.elts[0],ast.Constant) and argv.elts[0].value=='git'
            if not isgit or name not in mapping:continue
            special=name in {'tools/grass_methods.py','tools/plant_depth_verify.py'}
            if not special and n.func.attr=='check_output' and len(argv.elts)==3 and isinstance(argv.elts[1],ast.Constant) and argv.elts[1].value=='show':
                value=argv.elts[2]
                if isinstance(value,ast.BinOp) and isinstance(value.op,ast.Add) and isinstance(value.left,ast.BinOp) and isinstance(value.left.op,ast.Add) and isinstance(value.left.right,ast.Constant) and value.left.right.value==':':
                    base=ast.unparse(value.left.left);logical=ast.unparse(value.right)
                    edits.append((n,'historical_bytes(ROOT,'+base+','+logical+')'))
                    need('tools.qa.world.source_inputs','historical_bytes');counts['history']+=1;continue
            if not any(k.arg=='env' for k in n.keywords):
                old=ast.get_source_segment(text,n);assert old.endswith(')')
                delimiter='' if old[:-1].rstrip().endswith(',') else ','
                edits.append((n,old[:-1]+delimiter+'env=git_environment())'))
                need('tools.common.git','git_environment');counts['Git_env']+=1
        if name not in {'tools/grass_methods.py','tools/shore_kit.py'} and isinstance(n,ast.Constant) and isinstance(n.value,str) and n.value.startswith('res://') and n.value[6:] in mapping:
            edits.append((n,repr('res://'+mapping[n.value[6:]])));counts['native_URI']+=1
    text=replace_nodes(text,edits);text=insert_imports(text,needed)
    if before!=text:
        ast.parse(text)
        changes[name]={'target':mapping.get(name,name),'before':before,'after':text,
            'before_SHA256':sha(before.encode()),'after_SHA256':sha(text.encode()),'sites':counts}

for name in sorted(inventory['sources']):
    if not name.endswith(('.gd','.gdshader')):continue
    before=(Q/name).read_text();after=before;sites=0
    for old,target in mapping.items():
        if old.endswith(('.gd','.gdshader')):
            sites+=after.count('res://'+old);after=after.replace('res://'+old,'res://'+target)
    if before!=after:changes[name]={'target':mapping.get(name,name),'before':before,'after':after,
        'before_SHA256':sha(before.encode()),'after_SHA256':sha(after.encode()),'sites':{'URI':sites}}

plan={'base':inventory['base'],'phase':'mechanical proposal only; explicit Grass/Shore provenance bridge still required',
    'mapping':mapping,'changes':changes,'source_contracts_must_remain_exact':True,'applied':False}
Path('/private/tmp/refactor03-mechanical-plan380.json').write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'changed':len(changes),'Python':sum(n.endswith('.py') for n in changes),
    'GD':sum(n.endswith('.gd') for n in changes),'mapping':len(mapping),
    'sites':{key:sum(r['sites'].get(key,0) for r in changes.values()) for key in ['imports','roots','current','history','Git_env','native_URI','URI']}}))

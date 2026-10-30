"""Plan narrow legacy/fresh launch and Shore source compatibility; keep all frozen evidence unchanged."""
import ast
import hashlib
import json
from pathlib import Path

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
plan=json.loads(Path('/private/tmp/refactor03-mechanical-plan380.json').read_text())
changes=plan['changes']
sha=lambda s:hashlib.sha256(s.encode()).hexdigest()
def text(name):return changes.get(name,{}).get('after',(Q/name).read_text())
def save(name,value,reason):
    row=changes.setdefault(name,{'target':plan['mapping'].get(name,name),'before':(Q/name).read_text(),'sites':{}})
    row.update(after=value,before_SHA256=sha(row['before']),after_SHA256=sha(value))
    row.setdefault('explicit_provenance_changes',[]).append(reason)
    ast.parse(value)
def add_import(value,module,names):
    tree=ast.parse(value)
    node=next((n for n in tree.body if isinstance(n,ast.ImportFrom) and n.module==module),None)
    if node:
        existing={a.name for a in node.names}
        for name in names:
            if name not in existing:node.names.append(ast.alias(name=name))
        old=ast.get_source_segment(value,node)
        return value.replace(old,ast.unparse(node),1)
    marker=next(n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom)) and not(isinstance(n,ast.ImportFrom) and n.module=='__future__'))
    lines=value.splitlines(keepends=True);lines.insert(marker.lineno-1,'from '+module+' import '+', '.join(names)+'\n')
    return ''.join(lines)

name='tools/grass_compare_collect.py';value=text(name)
value=add_import(value,'tools.assets.contracts.source_paths',['captured_paths'])
marker='\n\ndef schedule(mode):';assert value.count(marker)==1
value=value.replace(marker,"\n\nCAPTURE_SOURCE=('tools/grass_compare/capture.gd',)"+marker)
old="'complete':False,'schedule':schedule(mode)";assert value.count(old)==1
value=value.replace(old,"'complete':False,'source_paths':captured_paths(CAPTURE_SOURCE),'schedule':schedule(mode)")
save(name,value,'fresh source.json records one complete known capture path; logical FROZEN stays exact')

name='tools/grass_methods.py';value=text(name)
value=add_import(value,'tools.qa.foliage.grass_compare_collect',['CAPTURE_SOURCE'])
value=add_import(value,'tools.assets.contracts.source_paths',['recorded_paths'])
marker="    source=read(folder/'source.json')\n";assert value.count(marker)==1
value=value.replace(marker,marker+"    recorded_paths(CAPTURE_SOURCE,source.get('source_paths',{}))\n")
node=next(n for n in ast.parse(value).body if isinstance(n,ast.FunctionDef) and n.name=='launch')
old=ast.get_source_segment(value,node)
new='''def launch(target,profile,source=None):
    """Bind exactly one launch URI to legacy absence or a complete known captured-path record."""
    env=read(target/'environment.json'); command=env['command']; log=(target/'engine.txt').read_text()
    require(env['exit_code']==0 and env['jobs_after']==[] and env['profile']==profile and profile.startswith('Codex-VRENDER-002-'),'native launch/profile failed')
    paths=recorded_paths(CAPTURE_SOURCE,(source or {}).get('source_paths',{}))
    logical=CAPTURE_SOURCE[0]; expected='res://'+paths.get(logical,logical)
    require(isinstance(command,list),'wrong launch')
    index=command.index('--script') if command.count('--script')==1 else -1
    require('--headless' not in command and index>=0 and index+1<len(command) and command[index+1]==expected,'wrong launch')
    require('ERROR:' not in log and 'SCRIPT ERROR' not in log,'native engine error')
    return env'''
value=value.replace(old,new,1)
assert value.count("launch(target,data['profile'])")==2
value=value.replace("launch(target,data['profile'])","launch(target,data['profile'],source)")
save(name,value,'strict legacy/fresh URI selected by complete recorded path; preserve profile/error/headless criteria')

name='tools/shore_kit.py';value=text(name)
value=add_import(value,'tools.assets.contracts.source_paths',['MOVED_PATHS'])
marker='\n\ndef verify_native(';assert value.count(marker)==1
helper='''

SHORE_CAPTURE_SOURCES=('tools/shore_kit_canvas.gd','tools/shore_kit_capture.gd')


def relocated_source_matches(root: Path, logical: str, expected: str, *, legacy: bool) -> bool:
    """Read canonical bytes only; old Shore proofs permit solely the two quoted URI relocations."""
    try:
        raw=input_path(root,logical).read_bytes()
    except (OSError,ValueError):
        return False
    if hashlib.sha256(raw).hexdigest()==expected:return True
    if not legacy or logical not in SHORE_CAPTURE_SOURCES:return False
    try:text=raw.decode('utf-8')
    except UnicodeDecodeError:return False
    for old in SHORE_CAPTURE_SOURCES:
        current=MOVED_PATHS[old]
        for quote in ['"',"'"]:
            text=text.replace(quote+'res://'+current+quote,quote+'res://'+old+quote)
    return hashlib.sha256(text.encode('utf-8')).hexdigest()==expected
'''
value=value.replace(marker,helper+marker)
old='''    mandatory = ['res://'+str(REPORT/'profile.json'),'res://'+str(REPORT/'source.json'),
                 'res://tools/shore_kit_canvas.gd','res://tools/shore_kit_capture.gd']
    if not set(mandatory) <= proof['sources'].keys(): errors.append('missing capture sources')
    for name, sha in proof['sources'].items():
        if name.startswith('res://scripts/'):
            valid = historical(root,proof['base_commit'],name[6:],sha)
        else:
            valid = name.startswith('res://') and digest(local(root,root,name[6:])) == sha
        if not valid:
            errors.append('capture source SHA: '+name)'''
new='''    old_tools={'res://'+name for name in SHORE_CAPTURE_SOURCES}
    new_tools={'res://'+MOVED_PATHS[name] for name in SHORE_CAPTURE_SOURCES}
    keys=set(proof['sources'])
    legacy=old_tools<=keys and not(keys & new_tools)
    current=new_tools<=keys and not(keys & old_tools)
    mandatory={'res://'+str(REPORT/'profile.json'),'res://'+str(REPORT/'source.json')}
    if not mandatory<=keys or not(legacy or current):errors.append('missing capture sources')
    inverse={MOVED_PATHS[name]:name for name in SHORE_CAPTURE_SOURCES}
    for name, sha in proof['sources'].items():
        if name.startswith('res://scripts/'):
            valid = historical(root,proof['base_commit'],name[6:],sha)
        elif name in old_tools|new_tools:
            logical=inverse.get(name[6:],name[6:])
            valid=relocated_source_matches(root,logical,sha,legacy=legacy)
        else:
            valid = name.startswith('res://') and not name.startswith('res://tools/') and digest(local(root,root,name[6:])) == sha
        if not valid:
            errors.append('capture source SHA: '+name)'''
assert value.count(old)==1
value=value.replace(old,new)
save(name,value,'Shore accepts one complete legacy or canonical key scheme, rejects mixed/unknown tool aliases, checks exact current or URI-only legacy source bytes')

plan['phase']='mechanical plus explicit Grass/Shore provenance proposal; still not applied'
Path('/private/tmp/refactor03-plan380.json').write_text(json.dumps(plan,indent=2)+'\n')
print(json.dumps({'changes':len(changes),'explicit_provenance':{n:r['explicit_provenance_changes'] for n,r in changes.items() if 'explicit_provenance_changes' in r}}))

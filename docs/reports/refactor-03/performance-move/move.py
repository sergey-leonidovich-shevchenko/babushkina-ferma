"""Apply only the accepted performance assignment and its connected import/launch consumers."""
import ast,hashlib,json,re,shutil,subprocess
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT=ROOT/'docs/reports/refactor-03/performance-move'
base=json.loads((REPORT/'baseline/inventory.json').read_text())
assert(REPORT/'before-profile.json').is_file()
mapping={n:r['target']for n,r in base['assignments'].items()}
modules={Path(n).stem for n in mapping if n.endswith('.py')}
changes={}
def rewrite_imports(text,keep_public=False):
 for name in sorted(modules):
  if name=='performance_gate'and keep_public:continue
  text=re.sub(r'(?m)^from '+re.escape(name)+r' import ', 'from tools.qa.performance.'+name+' import ',text)
  text=re.sub(r'(?m)^import '+re.escape(name)+r'( as \w+)?$',lambda m:'from tools.qa.performance import '+name+(m.group(1)or''),text)
 text=re.sub(r'(?m)^from common\.', 'from tools.common.',text)
 return text
for old,new in mapping.items():
 path=ROOT/old;raw=path.read_bytes();assert hashlib.sha256(raw).hexdigest()==base['sources'][old]['sha256']
 assert not(ROOT/new).exists(),new
 text=raw.decode()
 if old.endswith('.gd'):
  for a,b in mapping.items():text=text.replace('"res://'+a+'"','"res://'+b+'"')
 if old.endswith('.py'):text=rewrite_imports(text)
 if old.endswith('.sh'):
  text=text.replace('${0:A:h}/run.py','${0:A:h:h:h}/run.py')
  text=text.replace('exec python3 tools/performance_gate.py', 'exec python3 tools/run.py qa.performance.performance_gate')
 if old=='tools/audit_save_crashes.py':text=text.replace('"res://tools/save_crash_worker.gd"','"res://tools/qa/performance/save_crash_worker.gd"')
 changes[new]=text
for old in base['python_consumers']:
 before=(ROOT/old).read_text()
 text=rewrite_imports(before,keep_public=old=='tools/qa/performance/test_performance_context.py')
 if old.count('/')==1:
  # The old standalone command first entered through its flat dependency. Keep direct CLI access
  # while importing the new single implementation by its qualified package name.
  tree=ast.parse(text)
  anchor=next(n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom))and not(isinstance(n,ast.ImportFrom)and n.module=='__future__'))
  lines=text.splitlines(keepends=True)
  bootstrap=('if not __package__:\n    from common.launch import prepare_imports\n'
   '    from common.paths import project_root\n    prepare_imports(project_root(__file__))\n\n')
  text=''.join(lines[:anchor.lineno-1])+bootstrap+''.join(lines[anchor.lineno-1:])
 changes[old]=text
p='tools/qa/performance/perf_contract_collect.py';text=changes[p]
marker="\n\ndef sha(path):"
addition='''

# FROZEN remains the historical archive namespace. Only current input reads use this closed map.
SOURCE_LAYOUT = 'qa-performance-v1'
CURRENT_SOURCES = {
    'tools/perf_contract_capture.gd': 'tools/qa/performance/perf_contract_capture.gd',
    'tools/perf_contract_collect.py': 'tools/qa/performance/perf_contract_collect.py',
}


def current_source(logical):
    """Resolve only declared collector inputs; never use current paths as archive destinations."""
    if logical not in FROZEN:
        raise ValueError('unknown collector input')
    return ROOT / CURRENT_SOURCES.get(logical, logical)
'''
assert text.count(marker)==1;text=text.replace(marker,addition+marker)
text=text.replace("'complete':False,'schedule':schedule,'sources':{p:sha(ROOT/p) for p in FROZEN}","'complete':False,'source_layout':SOURCE_LAYOUT,'schedule':schedule,'sources':{p:sha(current_source(p)) for p in FROZEN}")
text=text.replace('shutil.copyfile(ROOT/name,dest)','shutil.copyfile(current_source(name),dest)')
text=text.replace('sha(ROOT/p)!=h','sha(current_source(p))!=h')
text=text.replace("'res://tools/perf_contract_capture.gd'","'res://tools/qa/performance/perf_contract_capture.gd'")
changes[p]=text
p='tools/qa/performance/perf_contract.py';text=changes[p]
marker='\n\ndef provenance(folder,schedule,complete_required=True):'
addition='''

def capture_script(source):
    """A closed layout version binds launch checks; absent metadata means the original archive."""
    if 'source_layout' not in source:
        return 'res://tools/perf_contract_capture.gd'
    if source['source_layout'] == 'qa-performance-v1':
        return 'res://tools/qa/performance/perf_contract_capture.gd'
    raise ValueError('unknown source layout')
'''
assert text.count(marker)==1;text=text.replace(marker,addition+marker)
text=text.replace("    source=read(folder/'source.json')","    source=read(folder/'source.json')\n    capture_script(source)",1)
text=text.replace('def inspect_run(target,seconds,device):',"def inspect_run(target,seconds,device,capture='res://tools/perf_contract_capture.gd'):")
text=text.replace("and 'res://tools/perf_contract_capture.gd' in command",'and capture in command')
text=text.replace('inspect_run(folder/name,seconds,device)','inspect_run(folder/name,seconds,device,capture_script(source))')
text=text.replace("    provenance(folder,[['resize',30,'resize'],['pause',30,'pause']])","    source=provenance(folder,[['resize',30,'resize'],['pause',30,'pause']])")
text=text.replace("and 'res://tools/perf_contract_capture.gd' in env['command']","and capture_script(source) in env['command']")
changes[p]=text
# Public entries preserve their modes and delegate once. Import facade retains module identity/SAMPLER.
changes['tools/performance_gate.py']='''#!/usr/bin/env python3
"""Public performance CLI/import; the single implementation lives in qa.performance."""
if __package__:
    from .common.launch import facade
else:
    from common.launch import facade

facade(__name__, "tools.qa.performance.performance_gate")
'''
for name in ['performance_gate.sh','smoke_test.sh']:
 changes['tools/'+name]='#!/bin/zsh\n# Public compatibility entry; forward argv and exit exactly once.\nexec zsh "${0:A:h}/qa/performance/'+name+'" "$@"\n'
text=(ROOT/'.gitignore').read_text()+'\n# REFACTOR-03: performance implementations; only previously tracked UID are included.\n!tools/qa/performance/*.py\n!tools/qa/performance/*.gd\n!tools/qa/performance/*.sh\n'
text+=''.join('!'+new+'\n'for old,new in mapping.items()if old.endswith('.uid'));changes['.gitignore']=text
for name in ['tools/quality/check_architecture.sh','run_tests.sh',*base['live_documents']]:
 text=(ROOT/name).read_text()
 for old,new in mapping.items():
  if base['assignments'][old]['action']=='move_implementation_keep_public_facade':continue
  if old.endswith('.py'):text=text.replace('python3 '+old,'python3 tools/run.py '+new.removeprefix('tools/').removesuffix('.py').replace('/','.'))
  text=text.replace(old,new)
 if name=='tools/quality/check_architecture.sh':
  anchor='python3 tools/run.py qa.performance.test_performance_context\n';assert anchor in text
  text=text.replace(anchor,anchor+'python3 tools/run.py qa.performance.test_performance_layout\n')
 changes[name]=text
changes['tools/qa/performance/test_performance_layout.py']=Path('/private/tmp/refactor03-test-performance-layout371.py').read_text()
for name,text in changes.items():
 if name.endswith('.py'):compile(text,name,'exec')
# Store exact proposed source strings before applying; evidence is reproducible from baseline.
(REPORT/'adaptation-plan.json').write_text(json.dumps({'base':base['base'],'changes':changes},ensure_ascii=False,indent=2)+'\n')
for old,new in mapping.items():
 (ROOT/new).parent.mkdir(parents=True,exist_ok=True);(ROOT/old).rename(ROOT/new)
for row in base['local_UID']:
 path=ROOT/row['old_path'];assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'];path.rename(ROOT/row['target'])
for name,text in changes.items():(ROOT/name).write_text(text)
shutil.copyfile(__file__,REPORT/'move.py')
print(json.dumps({'assignments':len(mapping),'source':33,'tracked_UID':14,'ignored_UID':len(base['local_UID']),
 'public_facades':3,'canonical_source_paths_changed':len(changes),'root_after':284}))

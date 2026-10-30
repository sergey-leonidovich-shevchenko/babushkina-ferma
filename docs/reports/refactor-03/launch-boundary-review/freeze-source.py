"""Freeze the narrow381 repair, actual37-field contract and primary's unrelated07 state."""
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/launch-boundary-review'
BASE='2c856d7d3d0a185735f17bdc5fa3f8c258b836d8'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
from tools.assets.contracts.source_paths import MOVED_PATHS
from tools.qa.art.current_paths import MOVED_PATHS as ART_PATHS

def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE==git(P,'rev-parse','HEAD').decode().strip()
assert (Q/'VERSION').read_text().strip()=='0.0.381'
expected={'tools/qa/foliage/grass_methods.py','tools/qa/foliage/test_relocation_provenance.py',
 'VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist','TESTING.md',
 'wiki/articles/project-refactoring.md','docs/epics/refactoring-2026-10/TASKS.md'}
changed=set(filter(None,git(Q,'diff','--no-renames','--name-only','-z').decode().split('\0')))
untracked=set(filter(None,git(Q,'ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert changed==expected,(changed-expected,expected-changed)
assert all(n.startswith(str(R.relative_to(Q))+'/') for n in untracked)
def outer(raw):
 a,b=raw.index(b'## REFACTOR-03 '),raw.index(b'## REFACTOR-04 ');return raw[:a],raw[b:]
assert outer((Q/'docs/epics/refactoring-2026-10/TASKS.md').read_bytes())==outer(git(Q,'show',BASE+':docs/epics/refactoring-2026-10/TASKS.md'))
foreign=json.loads((R/'baseline/UID-and-foreign.json').read_text())['primary_foreign']
for name,row in foreign.items():
 assert sha((P/name).read_bytes())==row['working_SHA256'] and sha(git(P,'show',':'+name))==row['index_SHA256']
for name in ['VERSION','project.godot','Бабушкина ферма.app/Contents/Info.plist']:
 assert (Q/name).read_bytes()==git(Q,'show',BASE+':'+name).replace(b'0.0.380',b'0.0.381')
assert len(MOVED_PATHS)==491
spec=importlib.util.spec_from_file_location('frozen_contract_reader',Q/'docs/reports/refactor-03/snapshot-contracts.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
frozen_path=Q/'docs/reports/refactor-03/baseline/source-contracts.json'
assert sha(frozen_path.read_bytes())=='bef5233df7f09ab065cd19728a008debd97707aa297167868d97f8ffc92c1090'
rows=[]
for name,record in json.loads(frozen_path.read_text())['modules'].items():
 physical=ART_PATHS.get(record['source'],MOVED_PATHS.get(record['source'],record['source']))
 selected=physical.removesuffix('.py').replace('/','.')
 result=subprocess.run([sys.executable,'-c',module.CHILD,str(Q),selected],cwd='/private/tmp',env=git_environment(),capture_output=True,text=True,timeout=30)
 assert result.returncode==0 and not result.stderr and json.loads(result.stdout)==record['fields'],(selected,result.stderr)
 rows.append({'module':selected,'fields':len(record['fields']),'equal':True})
assert len(rows)==21 and sum(row['fields'] for row in rows)==37
(R/'source-contract-audit.json').write_text(json.dumps({'modules':rows,'fields':37,'frozen_SHA256':sha(frozen_path.read_bytes())},indent=2)+'\n')
unused=[]
for name in sorted(expected):
 if not name.endswith('.py'):continue
 tree=ast.parse((Q/name).read_text());loaded={n.id for n in ast.walk(tree) if isinstance(n,ast.Name) and isinstance(n.ctx,ast.Load)}
 for node in ast.walk(tree):
  if not isinstance(node,(ast.Import,ast.ImportFrom)):continue
  for alias in node.names:
   bound=alias.asname or (alias.name.split('.')[0] if isinstance(node,ast.Import) else alias.name)
   if bound not in loaded and alias.name!='annotations':unused.append((name,bound))
assert not unused,unused
record={'task':'REFACTOR-03','version':'0.0.381','base':BASE,'source_SHA256':{n:sha((Q/n).read_bytes()) for n in sorted(expected)},
 'report_content_inputs':{'result.json':sha((R/'result.json').read_bytes())},'unused_imports':unused,
 'other_cards_unchanged':True,'runtime_art_frozen_evidence_unchanged':True,'primary_foreign_preserved':True,
 'all_before_full_gates':True,'main_changed':False,'Task_Complete':False}
(R/'source-freeze.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
shutil.copy2(__file__,R/'freeze-source.py')
print(json.dumps({'source_files':len(expected),'frozen_fields':37,'foreign07_preserved':True,'version':'0.0.381'}))

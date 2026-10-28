"""Actual canonical Godot parses and direct-import contexts, isolated from user state."""
import hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT=ROOT/'docs/reports/refactor-03/performance-move'
base=json.loads((REPORT/'baseline/inventory.json').read_text())
rows=[]
with tempfile.TemporaryDirectory(prefix='performance move native and imports ')as directory:
 parent=Path(directory).resolve();foreign=parent/'foreign cwd';foreign.mkdir();home=parent/'home';home.mkdir()
 env=dict(os.environ,HOME=str(home),XDG_DATA_HOME=str(home/'data'),PYTHONPATH=str(foreign),
  GIT_DIR=str(foreign/'absent.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'wrong-index'))
 def run(command,kind):
  path=REPORT/('extra-%03d.txt'%(len(rows)+1))
  with path.open('x')as stream:p=subprocess.run(command,cwd=foreign,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=240)
  text=path.read_text();row={'kind':kind,'command':command,'cwd':str(foreign),'exit':p.returncode,'log':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()};rows.append(row)
  (REPORT/'extra-commands.json').write_text(json.dumps(rows,indent=2)+'\n')
  assert p.returncode==0 and not any(x in text for x in ['SCRIPT ERROR','Parse Error','\nERROR:']),row
  print(json.dumps({'command':len(rows),'kind':kind,'exit':p.returncode}),flush=True)
 godot=os.environ['FARM_GODOT_BIN']
 run([godot,'--headless','--editor','--path',str(ROOT),'--quit'],'actual editor import')
 for old,row in base['assignments'].items():
  if old.endswith('.gd'):run([godot,'--headless','--path',str(ROOT),'--check-only','--script','res://'+row['target']],'actual canonical GD parse')
 for source in base['python_consumers']:
  # run_path sets no package context like the old direct CLI, but does not enter its __main__ action.
  child='import runpy; runpy.run_path('+repr(str(ROOT/source))+',run_name="qa_direct_import")'
  if source.count('/')!=1:
   child='import sys;sys.path.insert(0,'+repr(str(ROOT))+');'+child
  run([sys.executable,'-c',child],'actual direct consumer import')
 assert not list(foreign.iterdir())
 result={'base':base['base'],'commands':rows,'canonical_GD_parses':18,'direct_consumer_imports':len(base['python_consumers']),
  'temporary_HOME_XDG':True,'foreign_cwd_Git':True,'window_opened':False,'GPU_FPS_admission':False}
 assert len([r for r in rows if r['kind']=='actual canonical GD parse'])==18
 (REPORT/'extra-profile.json').write_text(json.dumps(result,indent=2)+'\n')

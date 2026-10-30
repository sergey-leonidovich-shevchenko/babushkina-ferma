"""Resume only the remaining19 import contexts, modeling the canonical test's actual launcher."""
import hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
base=json.loads((R/'baseline/inventory.json').read_text());initial=json.loads((R/'extra-commands-attempt01.json').read_text())
records=json.loads((R/'consumer-commands.json').read_text());assert len(records)==36 and records[-1]['exit']==1
assert all(r['exit']==0 for r in records[:35]);shutil.copyfile(R/'consumer-commands.json',R/'consumer-commands-attempt01.json')
shutil.copyfile('/private/tmp/refactor03-performance-consumers371.py',R/'consumer-profile-attempt01.py')
records=records[:35]
with tempfile.TemporaryDirectory(prefix='performance import remaining ')as directory:
 parent=Path(directory).resolve();foreign=parent/'foreign cwd';foreign.mkdir();home=parent/'home';home.mkdir()
 env=dict(os.environ,HOME=str(home),XDG_DATA_HOME=str(home/'data'),PYTHONPATH=str(foreign),
  GIT_DIR=str(foreign/'absent.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'wrong-index'))
 for source in base['python_consumers'][35:]:
  if source.count('/')==1:
   child='import sys,runpy;sys.path.insert(0,'+repr(str(ROOT/'tools'))+');'
   kind='actual direct consumer import'
  else:
   child='import sys,runpy;from pathlib import Path;sys.path.insert(0,'+repr(str(ROOT))+');from tools.common.launch import prepare_imports;prepare_imports(Path('+repr(str(ROOT))+'));'
   kind='actual canonical launcher consumer import'
  child+='runpy.run_path('+repr(str(ROOT/source))+',run_name="qa_consumer_import")'
  path=R/('consumer-final-%03d.txt'%(len(records)+1))
  with path.open('x')as stream:p=subprocess.run([sys.executable,'-c',child],cwd=foreign,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
  records.append({'kind':kind,'source':source,'command':[sys.executable,'-c',child],'cwd':str(foreign),
   'exit':p.returncode,'log':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
  (R/'consumer-commands.json').write_text(json.dumps(records,indent=2)+'\n');assert p.returncode==0,(source,path.read_text())
 assert not list(foreign.iterdir())
assert len(records)==54
result={'base':base['base'],'commands':initial[:19]+records,'canonical_GD_parses':18,'consumer_imports':54,
 'direct_root_CLI_imports':53,'canonical_launcher_imports':1,
 'retained_harness_failures':['extra-020.txt omitted direct script directory','consumer-036.txt omitted canonical launcher prepare_imports for existing public-name test'],
 'temporary_HOME_XDG':True,'foreign_cwd_Git':True,'window_opened':False,'GPU_FPS_admission':False}
(R/'extra-profile.json').write_text(json.dumps(result,indent=2)+'\n');shutil.copyfile(__file__,R/'consumer-profile.py')
print(json.dumps({'GD_parse':18,'direct_root_imports':53,'canonical_launcher_imports':1,'product_changes_for_harness':0}))

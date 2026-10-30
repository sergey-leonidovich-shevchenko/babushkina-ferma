"""Correct only the import harness: Python's direct CLI adds its script directory to sys.path."""
import gzip,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-move'
base=json.loads((R/'baseline/inventory.json').read_text());previous=json.loads((R/'extra-commands.json').read_text())
assert len(previous)==20 and previous[-1]['exit']==1
assert 'ModuleNotFoundError' in(R/'extra-020.txt').read_text()
shutil.copyfile('/private/tmp/refactor03-performance-extra371.py',R/'extra-attempt01.py')
shutil.copyfile(R/'extra-commands.json',R/'extra-commands-attempt01.json')
for old,new in [('ci370-final-for371.json','ci370-final.json'),('reviews370-for371.json','reviews370.json')]:
 shutil.copyfile('/private/tmp/refactor03-'+old,R/'baseline'/new)
inventory=json.loads((R/'baseline/inventory.json').read_text());inventory.update(CI370_final_pending=False,CI370_success=8)
(R/'baseline/inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2)+'\n')
records=[]
with tempfile.TemporaryDirectory(prefix='performance direct import corrected ')as directory:
 parent=Path(directory).resolve();foreign=parent/'foreign cwd';foreign.mkdir();home=parent/'home';home.mkdir()
 env=dict(os.environ,HOME=str(home),XDG_DATA_HOME=str(home/'data'),PYTHONPATH=str(foreign),
  GIT_DIR=str(foreign/'absent.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'wrong-index'))
 for source in base['python_consumers']:
  entry=ROOT/'tools'if source.count('/')==1 else ROOT
  child='import sys,runpy;sys.path.insert(0,'+repr(str(entry))+');runpy.run_path('+repr(str(ROOT/source))+',run_name="qa_direct_import")'
  path=R/('consumer-%03d.txt'%(len(records)+1))
  with path.open('x')as stream:p=subprocess.run([sys.executable,'-c',child],cwd=foreign,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
  row={'kind':'actual direct consumer import','source':source,'command':[sys.executable,'-c',child],'cwd':str(foreign),
   'exit':p.returncode,'log':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()};records.append(row)
  (R/'consumer-commands.json').write_text(json.dumps(records,indent=2)+'\n')
  assert p.returncode==0,(row,path.read_text())
 assert not list(foreign.iterdir())
result={'base':base['base'],'commands':previous[:19]+records,'canonical_GD_parses':18,'direct_consumer_imports':54,
 'retained_harness_failure':'extra-020.txt: run_path initially omitted script directory supplied by real direct CLI',
 'temporary_HOME_XDG':True,'foreign_cwd_Git':True,'window_opened':False,'GPU_FPS_admission':False}
(R/'extra-profile.json').write_text(json.dumps(result,indent=2)+'\n');shutil.copyfile(__file__,R/'consumer-profile.py')
print(json.dumps({'GD_parse':18,'consumer_imports':54,'old_failed_harness_retained':True}))

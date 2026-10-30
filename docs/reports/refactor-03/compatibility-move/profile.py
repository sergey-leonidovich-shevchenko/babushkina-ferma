"""Compare real compatibility commands across their physical move, without GPU/FPS claims."""
import argparse,gzip,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
REPORT=Path(__file__).resolve().parent
ROOT=next(p for p in REPORT.parents if(p/'project.godot').is_file())
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 parser=argparse.ArgumentParser();parser.add_argument('phase',choices=['before','after']);phase=parser.parse_args().phase
 output=REPORT/(phase+'-profile.json');assert not output.exists()
 baseline=json.loads((REPORT/'baseline/inventory.json').read_text());mapping={n:r['target']for n,r in baseline['assignments'].items()}
 records=[]
 def run(command,cwd,env,expected=0,timeout=600):
  row={'command':list(map(str,command)),'cwd':str(cwd),'expected':expected}
  i=len(records)+1;log=REPORT/(phase+'-%03d.txt'%i)
  with log.open('x')as stream:
   p=subprocess.run(command,cwd=cwd,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=timeout)
  row.update(exit=p.returncode,log=log.name,sha256=sha(log.read_bytes()));records.append(row)
  (REPORT/(phase+'-commands.json')).write_text(json.dumps(records,indent=2)+'\n')
  text=log.read_text();assert p.returncode==expected,row
  if expected==0:assert not any(s in text for s in ['SCRIPT ERROR','Parse Error','\nERROR:']),text
  print(json.dumps({'phase':phase,'command':i,'exit':p.returncode,'script':str(command[-1])}),flush=True)
  return text
 with tempfile.TemporaryDirectory(prefix='compatibility '+phase+' ')as directory:
  parent=Path(directory).resolve();foreign=parent/'foreign cwd';foreign.mkdir();home=parent/'home';home.mkdir()
  env=dict(os.environ,HOME=str(home),XDG_DATA_HOME=str(parent/'data'),PYTHONPATH=str(foreign),
   GIT_DIR=str(foreign/'absent.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'wrong-index'))
  godot=os.environ['FARM_GODOT_BIN'];prefix=[godot,'--headless','--path',str(ROOT)]
  run([godot,'--headless','--editor','--path',str(ROOT),'--quit'],foreign,env)
  if phase=='after':
   for old,new in mapping.items():
    if old.endswith('.gd'):run([*prefix,'--check-only','--script','res://'+new],foreign,env,timeout=120)
   for name in ['tools/assets/slicing/slice_review.gd','tools/water_fishing_review.gd','tools/water_navigation_review.gd','tools/water_topology_review.gd']:
    run([*prefix,'--check-only','--script','res://'+name],foreign,env,timeout=120)
  def current(name):return mapping[name]if phase=='after'else name
  exports=parent/'catalog.json';outcomes={}
  for name in ['tools/content_reference_audit.gd','tools/qa_teleport_review.gd','tools/held_weapon_review.gd','tools/farm_review.gd']:
   args=['--','--output='+str(exports)]if name.endswith('farm_review.gd')else[]
   text=run([*prefix,'--script','res://'+current(name),*args],foreign,env)
   # The raw log keeps elapsed validation time; comparison retains semantic counters.
   if name.endswith('content_reference_audit.gd'):
    data=json.loads(next(l.split('CONTENT REFERENCES: ',1)[1]for l in text.splitlines()if l.startswith('CONTENT REFERENCES: ')));data.pop('validation_usec');outcomes[name]=data
   else:
    import re
    match=re.search(r'(\d+) passed, (\d+) failed',text);assert match and match.group(2)=='0',text
    outcomes[name]=list(map(int,match.groups()))
  catalog=json.loads(exports.read_text());projection={k:catalog[k]for k in ['recipes','research']}
  (REPORT/(phase+'-catalog.json.gz')).write_bytes(gzip.compress(json.dumps(projection,ensure_ascii=False,sort_keys=True).encode(),mtime=0))
  cycles=parent/'cycles.json'
  command=[sys.executable,str(ROOT/'tools/run.py'),'qa.compatibility.farm_cycles']if phase=='after'else[sys.executable,str(ROOT/'tools/farm_cycles.py')]
  run([*command,str(exports),str(cycles)],foreign,env);cycledata=json.loads(cycles.read_text())
  (REPORT/(phase+'-cycles.json.gz')).write_bytes(gzip.compress(cycles.read_bytes(),mtime=0))
  command=[sys.executable,str(ROOT/'tools/run.py'),'qa.compatibility.check_alchemy_reports']if phase=='after'else[sys.executable,str(ROOT/'tools/check_alchemy_reports.py')]
  alchemy=run(command,foreign,env,expected=1)
  assert 'assert len(herbs) == 24 and len(catalog["items"]) == 148' in alchemy and 'AssertionError' in alchemy
  if phase=='after':
   run([sys.executable,str(ROOT/'tools/run.py'),'qa.compatibility.test_compatibility_cli'],foreign,env)
  comparison=[]
  if phase=='after':
   for old,new in mapping.items():
    raw=gzip.decompress((REPORT/'baseline'/(old.replace('/','--')+'.gz')).read_bytes());expected=raw.decode()
    if old.endswith('.gd'):
     for a,b in mapping.items():expected=expected.replace('"res://'+a+'"','"res://'+b+'"')
    if old=='tools/check_alchemy_reports.py':expected=expected.replace('ROOT = Path(__file__).resolve().parents[1]', 'from tools.common.paths import project_root\n\nROOT = project_root(__file__)')
    assert(ROOT/new).read_bytes()==expected.encode(),old
    comparison.append({'old_path':old,'target':new,'permitted_change':'URI only'if old.endswith('.gd')else'source-root only'if old.endswith('check_alchemy_reports.py')else'byte exact'})
   before=json.loads((REPORT/'before-profile.json').read_text())
   assert before['outcomes']==outcomes
   assert before['alchemy_expected_legacy_rejection'] is True
   assert gzip.decompress((REPORT/'before-catalog.json.gz').read_bytes())==gzip.decompress((REPORT/'after-catalog.json.gz').read_bytes())
   assert json.loads(gzip.decompress((REPORT/'before-cycles.json.gz').read_bytes()))==cycledata
  result={'phase':phase,'base':baseline['base'],'commands':records,'outcomes':outcomes,'alchemy_expected_legacy_rejection':True,
   'recipes':len(projection['recipes']),'research':len(projection['research']),'cycle_components':len(cycledata['components']),
   'source_comparison':comparison,'actual_before_after_equal':phase=='after','GPU_FPS_admission':False,
   'actual_window_opened':False,'foreign_index_created':(foreign/'wrong-index').exists()}
  assert not result['foreign_index_created']
  output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
  print(json.dumps({'phase':phase,'commands':len(records),'recipes':len(projection['recipes']),'outcomes':outcomes}),flush=True)
if __name__=='__main__':main()

"""Compare actual historical camera readers and their unchanged negative suites; never capture."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
p=argparse.ArgumentParser();p.add_argument('phase',choices=['before','after']);a=p.parse_args();phase=a.phase
assert not(R/(phase+'-profile.json')).exists()
commands=[['visual_camera.py','check'],['visual_camera.py','verify'],['visual_static.py','verify'],['visual_coordinates.py','verify'],['camera_quantization.py','verify'],['presentation_pose.py','verify'],['reference_zoom.py','verify'],['reference_zoom_perf.py','verify'],['visual_motion.py','verify'],['visual_hardware.py','verify'],['check_native_frame_reports.py']]
commands += [[n+'.py']for n in ['test_visual_camera','test_visual_coordinates','test_camera_quantization','test_presentation_pose','test_reference_zoom','test_visual_motion','test_visual_static','test_visual_baseline','test_visual_hardware']]
rows=[]
with tempfile.TemporaryDirectory(prefix='camera '+phase+' foreign ')as directory:
 foreign=Path(directory).resolve();(foreign/'note.txt').write_text('foreign camera reader fixture')
 subprocess.run(['git','init','-q',str(foreign)],env=git_environment(),check=True)
 subprocess.run(['git','-C',str(foreign),'add','.'],env=git_environment(),check=True)
 before={n:(foreign/'.git'/n).read_bytes()for n in ['index','config']}
 environment=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(foreign),GIT_DIR=str(foreign/'.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'.git/index'),GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true')
 for command in commands:
  name=phase+'-%02d.txt'%(len(rows)+1);argv=[sys.executable,str(Q/'tools'/command[0]),*command[1:]]
  with(R/name).open('x')as f:result=subprocess.run(argv,cwd=foreign,env=environment,stdout=f,stderr=subprocess.STDOUT,timeout=360)
  output=(R/name).read_text();row={'command':argv,'cwd':str(foreign),'exit':result.returncode,'log':name,'sha256':hashlib.sha256((R/name).read_bytes()).hexdigest()};rows.append(row)
  (R/(phase+'-commands.json')).write_text(json.dumps(rows,indent=2)+'\n');assert result.returncode==0,(row,output[-4000:]);assert not any(x in output for x in ['SCRIPT ERROR','Parse Error','\nERROR:'])
  print(json.dumps({'phase':phase,'command':len(rows),'exit':result.returncode}),flush=True)
 assert all((foreign/'.git'/n).read_bytes()==raw for n,raw in before.items())
result={'phase':phase,'base':json.loads((R/'baseline/inventory.json').read_text())['base'],'commands':rows,'foreign_Git_index_config_unchanged':True,'historical_verifier_commands':11,'old_negative_suites':9,'Game_new':False,'native_sessions':0,'GPU_FPS_admission':False,'input_reports_unmodified':True}
if phase=='after':
 before=json.loads((R/'before-profile.json').read_text());assert len(before['commands'])==len(rows)
 for left,right in zip(before['commands'],rows):
  assert left['command']==right['command']
  if not Path(left['command'][1]).name.startswith('test_'):assert(R/left['log']).read_bytes()==(R/right['log']).read_bytes(),left['command']
 result['historical_stdout_byte_equal']=11
(R/(phase+'-profile.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'phase':phase,'actual_commands':len(rows),'native_sessions':0,'Game_new':False}))

"""Compare actual camera CLI, Godot parses and offline AVFoundation decode before/after move."""
import argparse,gzip,hashlib,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
from PIL import Image
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-move';sys.path.insert(0,str(Q))
from tools.common.git import git_environment
p=argparse.ArgumentParser();p.add_argument('phase',choices=['before','after']);p.add_argument('--attempt',type=int,default=1);a=p.parse_args();phase=a.phase;prefix=phase if a.attempt==1 else phase+'-attempt%02d'%a.attempt
assert not(R/(phase+'-profile.json')).exists();plan=json.loads((R/'baseline/move-plan.json').read_text());moves={r['old_path']:r['target']for r in plan['moves']};rows=[]
def physical(name):return Q/(moves.get(name,name)if phase=='after'else name)
def command(name,args=()):return[sys.executable,str(Q/'tools/run.py'),'qa.camera.'+Path(name).stem,*args]if phase=='after'else[sys.executable,str(Q/'tools'/name),*args]
def run(argv,env,cwd,kind='CLI',timeout=360):
 name=prefix+'-%03d.txt'%(len(rows)+1);result=subprocess.run(list(map(str,argv)),cwd=cwd,env=env,capture_output=True,timeout=timeout);raw=result.stdout+result.stderr
 if kind in{'GD','Swift'}:name+='.gz';(R/name).write_bytes(gzip.compress(raw,mtime=0))
 else:(R/name).write_bytes(raw)
 row={'argv':list(map(str,argv)),'kind':kind,'exit':result.returncode,'log':name,'raw_SHA256':hashlib.sha256(raw).hexdigest(),'stored_SHA256':hashlib.sha256((R/name).read_bytes()).hexdigest()};rows.append(row);(R/(prefix+'-commands.json')).write_text(json.dumps(rows,indent=2)+'\n')
 assert result.returncode==0,(row,raw[-4000:]);assert not any(s in raw for s in[b'SCRIPT ERROR',b'Parse Error',b'\nERROR:']),(row,raw[-4000:]);print(json.dumps({'phase':phase,'command':len(rows),'kind':kind,'exit':result.returncode}),flush=True);return raw
with tempfile.TemporaryDirectory(prefix='camera move '+phase+' ')as directory:
 root=Path(directory).resolve();foreign=root/'foreign cwd';foreign.mkdir();(foreign/'note.txt').write_text('isolated foreign camera QA')
 subprocess.run(['git','init','-q',str(foreign)],env=git_environment(),check=True);subprocess.run(['git','-C',str(foreign),'add','.'],env=git_environment(),check=True)
 original={n:(foreign/'.git'/n).read_bytes()for n in ['index','config']}
 env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(foreign),GIT_DIR=str(foreign/'.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'.git/index'),GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true')
 specs=[['visual_camera.py','check'],['visual_camera.py','verify'],['visual_static.py','verify'],['visual_coordinates.py','verify'],['camera_quantization.py','verify'],['presentation_pose.py','verify'],['reference_zoom.py','verify'],['reference_zoom_perf.py','verify'],['visual_motion.py','verify'],['visual_hardware.py','verify'],['check_native_frame_reports.py']]+[[n+'.py']for n in ['test_visual_camera','test_visual_coordinates','test_camera_quantization','test_presentation_pose','test_reference_zoom','test_visual_motion','test_visual_static','test_visual_baseline','test_visual_hardware']]
 stdout=[]
 for spec in specs:stdout.append(run(command(spec[0],spec[1:]),env,foreign))
 run([sys.executable,str(Q/'tools/run.py'),'qa.camera.test_camera_context'],env,foreign)
 # Actual compile-only Godot processes do not instantiate Game or run a scene.
 godot=os.environ['FARM_GODOT_BIN'];engine_env=dict(git_environment(),HOME=str(root/'engine-home'),XDG_DATA_HOME=str(root/'engine-data'))
 for row in plan['moves']:
  if row['old_path'].endswith('.gd'):run([godot,'--headless','--path',str(Q),'--log-file',str(root/('parse-%d.log'%len(rows))),'--check-only','--script','res://'+str(physical(row['old_path']).relative_to(Q))],engine_env,Q,'GD',120)
 # Re-decode immutable original MP4s, then run the actual contact-sheet command at native pixel size.
 videos=[Q/'docs/reports/visual-overhaul/vcamera-003/native'/('base-'+mode)/'walk.mp4'for mode in ['physical','shared']]
 swift_env=dict(git_environment(),CLANG_MODULE_CACHE_PATH=str(root/'clang-cache'),SWIFT_MODULECACHE_PATH=str(root/'swift-cache'))
 decoded=root/'decoded';run(['swift',physical('tools/pose_video_frames.swift'),*videos,decoded],swift_env,foreign,'Swift',300)
 frame_rows=[]
 for path in sorted(decoded.glob('*.png')):
  with Image.open(path)as im:rgba=im.convert('RGBA');frame_rows.append({'name':path.name,'size':list(rgba.size),'RGBA_SHA256':hashlib.sha256(rgba.tobytes()).hexdigest(),'PNG_SHA256':hashlib.sha256(path.read_bytes()).hexdigest()})
 assert len(frame_rows)==16 and all(r['size']==[1152,648]for r in frame_rows)
 sheet=root/'contact sheet';run(command('pose_video_strip.py',[str(decoded),str(sheet)]),env,foreign)
 with Image.open(sheet/'frames-90-97.png')as im:sheet_signature={'size':list(im.size),'RGBA_SHA256':hashlib.sha256(im.convert('RGBA').tobytes()).hexdigest(),'PNG_SHA256':hashlib.sha256((sheet/'frames-90-97.png').read_bytes()).hexdigest()}
 shutil.copyfile(sheet/'source.json',R/(phase+'-contact-sheet-source.json'))
 assert all((foreign/'.git'/n).read_bytes()==raw for n,raw in original.items())
 result={'phase':phase,'attempt':a.attempt,'base':plan['base'],'commands':rows,'historical_CLI':20,'context_suite':12,'GD_parse_only':17,'actual_offline_decoded_frames':frame_rows,'contact_sheet':sheet_signature,'source_videos_SHA256':[hashlib.sha256(v.read_bytes()).hexdigest()for v in videos],'Game_new':False,'new_native_sessions':0,'GPU_FPS_admission':False,'foreign_index_config_unchanged':True}
 if phase=='after':
  before=json.loads((R/'before-profile.json').read_text());assert before['actual_offline_decoded_frames']==frame_rows and before['contact_sheet']==sheet_signature and before['source_videos_SHA256']==result['source_videos_SHA256']
  for i in range(11):assert rows[i]['raw_SHA256']==before['commands'][i]['raw_SHA256'],rows[i]
  result['historical_stdout_equal']=11
 (R/(phase+'-profile.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'phase':phase,'CLI':22,'GD':17,'Swift':1,'actual_decoded_frames':16,'Game_new':False}))

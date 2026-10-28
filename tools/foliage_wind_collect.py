#!/usr/bin/env python3
"""Freeze exact production sources and collect two fresh native wind windows."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,json,os,shutil,signal,subprocess,uuid,hashlib
from pathlib import Path
from tools.qa.performance.perf_contract_collect import ROOT,command,context,jobs,native_pid,write,sha
from PIL import Image
REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-003'
RUNTIME=['scripts/game_core.gd','scripts/systems/village_ambient_renderer.gd','scripts/presentation/foliage_wind.gd','scripts/presentation/foliage_wind_batch.gd','scripts/presentation/foliage_wind.gdshader']
QA=['tools/foliage_wind_capture.gd','tools/foliage_wind_collect.py','tools/visual_camera_points.gd','tools/render_order_game.gd']

def pack_motion(target):
    """Store the sampled windows as lossless APNG and verify every decoded RGBA before removing duplicates."""
    frames=[Image.open(target/f'wind-{i:02d}'/'window.png').convert('RGBA') for i in range(49)]
    movie=target/'motion.png'
    frames[0].save(movie,save_all=True,append_images=frames[1:],duration=[83]*48+[16],loop=0,disposal=0,blend=0)
    decoded=Image.open(movie);proof=[]
    if decoded.n_frames!=49:raise ValueError('motion archive lost sample boundaries')
    for index,original in enumerate(frames):
        decoded.seek(index)
        if decoded.convert('RGBA').tobytes()!=original.tobytes():raise ValueError('lossless motion archive differs')
        proof.append({'case':f'wind-{index:02d}','rgba_sha':hashlib.sha256(original.tobytes()).hexdigest(),'frame':index})
    write(target/'motion.json',{'format':'lossless APNG','scope':'49 controlled shader-time samples over four simulation seconds; not a measured game frame rate','frames':proof})
    for i in range(49):
        if i not in [0,24,48]:(target/f'wind-{i:02d}'/'window.png').unlink()

def collect(output):
    """Reject overwritten evidence, changed artwork and production outside the selected card."""
    folder=Path(output).resolve()
    if folder.exists():raise ValueError('fresh output required')
    base=command(['git','rev-parse','main']);paths=command(['git','ls-tree','-r','--name-only',base]).splitlines()
    production=sorted({n for n in paths if n.startswith('scripts/') and n.endswith(('.gd','.gdshader'))}|set(RUNTIME))
    sources={n:sha(ROOT/n) for n in sorted(set(production+QA+['project.godot','main.tscn','assets/game/environment/village_ambient_atlas_v1.png']))}
    for n in production:
        if n not in RUNTIME and hashlib.sha256(subprocess.check_output(['git','show',base+':'+n],cwd=ROOT)).hexdigest()!=sources[n]:raise ValueError('unexpected source change: '+n)
    if command(['git','diff',base,'--name-only','--','assets/game']):raise ValueError('unexpected artwork change')
    folder.mkdir(parents=True)
    manifest={'task':'VFOLIAGE-003','base_commit':base,'asset_tree':command(['git','rev-parse',base+':assets/game']),'complete':False,'sources':sources,'production':production,'overlay':sorted(set(RUNTIME+QA+['project.godot'])),'artifacts':{},'performance_eligible':False}
    for name in manifest['overlay']:
        target=folder/'inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
    write(folder/'source.json',manifest);existing=jobs()
    for width in [1152,1280]:
        if set(jobs())-set(existing):raise ValueError('unexpected concurrent Godot')
        target=folder/str(width);target.mkdir();profile='Codex-VFOLIAGE-003-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{width*9//16}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/foliage_wind_capture.gd','--','--output='+str(target/'capture'),'--profile='+profile]
        if width==1280:args.append('--wide')
        print('WIND NATIVE',width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try:code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid:os.kill(pid,signal.SIGTERM)
                child.terminate();child.wait(timeout=10);raise ValueError('own capture timeout')
        write(target/'environment.json',{'command':args,'exit_code':code,'context':context(),'existing_jobs':existing})
        if not (target/'capture').is_dir():raise ValueError('native did not start; inspect engine.txt')
        for p in (target/'capture').iterdir():shutil.move(str(p),target/p.name)
        (target/'capture').rmdir()
        if code or json.loads((target/'capture.json').read_text())['errors'] or any(s in (target/'engine.txt').read_text() for s in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('native capture failed')
        if any(sha(ROOT/n)!=h for n,h in sources.items()):raise ValueError('frozen source changed')
        pack_motion(target)
    manifest['complete']=True
    manifest['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    write(folder/'source.json',manifest)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',default=str(REPORT/'native'));collect(parser.parse_args().output)

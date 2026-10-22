#!/usr/bin/env python3
"""Capture native root passports and actual gameplay/query pairs without user saves."""
import argparse,json,os,shutil,signal,subprocess,uuid
from pathlib import Path
from perf_contract_collect import ROOT,command,context,jobs,native_pid,write,sha

REPORT=ROOT/'docs/reports/visual-overhaul/vfoliage-001'
RUNTIME=['scripts/presentation/foliage_root_profile.gd','scripts/systems/village_ambient_renderer.gd']
QA=['tools/foliage_root_capture.gd','tools/foliage_root_board.gd','tools/foliage_root_observer.gd','tools/foliage_root_collect.py','tools/visual_camera_points.gd','tools/render_order_game.gd','tests/suites/foliage_root_suite.gd']
ART=['assets/game/environment/village_ambient_atlas_v1.png','docs/reports/visual-overhaul/vart-008/native/sprites/grass-low.png']

def collect(output):
    """Freeze reviewed inputs and archive only deviations from an immutable full Git base."""
    folder=Path(output).resolve()
    if folder.exists():raise ValueError('fresh native directory required')
    base=command(['git','rev-parse','main'])
    if command(['git','diff',base,'--name-only','--','assets/game']):raise ValueError('production artwork changed')
    paths=command(['git','ls-tree','-r','--name-only',base]).splitlines()
    production=sorted(set(n for n in paths if n.startswith('scripts/') and n.endswith('.gd'))|set(RUNTIME))
    frozen=sorted(set(production+QA+ART+['project.godot','main.tscn']))
    hashes={n:sha(ROOT/n) for n in frozen}
    for n in production:
        if n not in RUNTIME and hashlib_sha(subprocess.check_output(['git','show',base+':'+n],cwd=ROOT))!=hashes[n]:raise ValueError('unreviewed production change: '+n)
    folder.mkdir(parents=True)
    evidence={'task':'VFOLIAGE-001','base_commit':base,'complete':False,'performance_eligible':False,'asset_tree':command(['git','rev-parse',base+':assets/game']),'sources':hashes,'production':production,'overlay':sorted(set(RUNTIME+QA+['project.godot'])),'artifacts':{}}
    for n in evidence['overlay']:
        p=folder/'inputs'/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/n,p)
    write(folder/'source.json',evidence)
    existing=jobs()
    for width in [1152,1280]:
        if set(jobs())-set(existing):raise ValueError('unexpected Godot process')
        target=folder/str(width);target.mkdir();profile='Codex-VFOLIAGE-001-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{width*9//16}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/foliage_root_capture.gd','--','--output='+str(target/'native'),'--profile='+profile]
        if width==1280:args.append('--wide')
        print('ROOT NATIVE',width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try:code=child.wait(timeout=150)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid:os.kill(pid,signal.SIGTERM)
                child.terminate();child.wait(timeout=10);raise ValueError('own capture timed out')
        write(target/'environment.json',{'command':args,'exit_code':code,'context':context(),'existing_jobs':existing})
        if (target/'native').exists():
            for p in (target/'native').iterdir():shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        evidence['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts};write(folder/'source.json',evidence)
        if code or not (target/'capture.json').is_file() or json.loads((target/'capture.json').read_text())['errors'] or any(v in (target/'engine.txt').read_text() for v in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('native collection failed')
        if any(sha(ROOT/n)!=h for n,h in hashes.items()):raise ValueError('frozen input changed')
    evidence['complete']=True;write(folder/'source.json',evidence)

def hashlib_sha(data):
    """Match immutable Git blobs without decoding their exact bytes."""
    import hashlib
    return hashlib.sha256(data).hexdigest()

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',default=str(REPORT/'native'));collect(parser.parse_args().output)

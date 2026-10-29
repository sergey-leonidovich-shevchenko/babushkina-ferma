#!/usr/bin/env python3
"""Collect visible static shadow-ownership controls; never claim a solar or FPS pass."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,hashlib,json,os,shutil,signal,subprocess,uuid
from common.git import git_environment
from pathlib import Path
from tools.qa.world.source_inputs import input_path
from tools.qa.performance.perf_contract_collect import ROOT,command,context,jobs,native_pid,write,sha

QA=['tools/shadow_inventory_canvas.gd','tools/shadow_inventory_capture.gd','tools/shadow_inventory_collect.py','tools/visual_camera_points.gd','tools/render_order_game.gd']

def collect(output):
    """Freeze all production scripts against Git; only the isolated QA overlay may differ."""
    folder=Path(output).resolve()
    if folder.exists():raise ValueError('fresh directory required')
    base=command(['git','rev-parse','HEAD'])
    if command(['git','diff',base,'--name-only','--','assets/game','scripts']):raise ValueError('audit must not change production')
    production=sorted(n for n in command(['git','ls-tree','-r','--name-only',base]).splitlines() if n.startswith('scripts/') and n.endswith(('.gd','.gdshader')))
    frozen=production+QA+['project.godot','main.tscn']
    sources={n:sha(input_path(ROOT, n)) for n in frozen}
    for n in production:
        if hashlib.sha256(subprocess.check_output(['git','show',base+':'+n],cwd=ROOT, env=git_environment())).hexdigest()!=sources[n]:raise ValueError('production mismatch: '+n)
    folder.mkdir(parents=True)
    source={'task':'VSHADOW-001','base_commit':base,'production':production,'asset_tree':command(['git','rev-parse',base+':assets/game']),'complete':False,'performance_eligible':False,'sources':sources,'overlay':QA+['project.godot'],'artifacts':{}}
    for n in source['overlay']:
        p=folder/'inputs'/n;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(input_path(ROOT, n),p)
    write(folder/'source.json',source);initial=jobs()
    for width in [1152,1280]:
        if set(jobs())-set(initial):raise ValueError('unexpected native process')
        target=folder/str(width);target.mkdir();profile='Codex-VSHADOW-001-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{width*9//16}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/shadow_inventory_capture.gd','--','--output='+str(target/'native'),'--profile='+profile]
        if width==1280:args.append('--wide')
        print('SHADOW INVENTORY',width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try:code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid:os.kill(pid,signal.SIGTERM)
                child.terminate();child.wait(timeout=10);raise ValueError('own capture timed out')
        write(target/'environment.json',{'command':args,'exit_code':code,'context':context(),'existing_jobs':initial})
        if (target/'native').exists():
            for p in (target/'native').iterdir():shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts};write(folder/'source.json',source)
        if code or not (target/'capture.json').exists() or json.loads((target/'capture.json').read_text())['errors'] or any(t in (target/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('native collection failed')
        if any(sha(input_path(ROOT, n))!=h for n,h in sources.items()):raise ValueError('frozen input changed')
    source['complete']=True;write(folder/'source.json',source)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--output',required=True);collect(parser.parse_args().output)

#!/usr/bin/env python3
"""Collect two real-window save-boundary controls with immutable Git-bound assets."""
if not __package__:
    from tools.common.launch import prepare_imports
    from tools.common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,hashlib,json,shutil,signal,subprocess,uuid
from pathlib import Path
from tools.qa.world.source_inputs import input_path
from tools.qa.performance.perf_contract_collect import ROOT,command,context,jobs,native_pid,write,sha
REPORT=ROOT/'docs/reports/visual-overhaul/vcompat-001'
QA=['tools/visual_camera_points.gd','tools/render_order_game.gd','tools/transient_save_probe.gd','tools/transient_save_capture.gd','tools/transient_save_collect.py']

def collect(phase):
    """Never reuse a phase directory or an ordinary user profile."""
    folder=REPORT/'native'/phase
    if folder.exists():raise ValueError('fresh phase required')
    base=command(['git','rev-parse','main'])
    if command(['git','diff',base,'--name-only','--','assets/game']):raise ValueError('native assets must match accepted main')
    tracked=command(['git','ls-files']).splitlines()
    names=sorted(set([n for n in tracked if n.startswith('scripts/') and n.endswith('.gd')]+['project.godot','main.tscn']+QA))
    folder.mkdir(parents=True)
    source={'task':'VCOMPAT-001','phase':phase,'base_commit':base,'asset_tree':command(['git','rev-parse',base+':assets/game']),'complete':False,'performance_eligible':False,'sources':{},'artifacts':{}}
    for name in names:
        target=folder/'inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(input_path(ROOT, name),target);source['sources'][name]=sha(target)
    initial=jobs();write(folder/'source.json',source)
    for width in [1152,1280]:
        if set(jobs())-set(initial):raise ValueError('unexpected Godot process')
        target=folder/str(width);target.mkdir();profile='Codex-VCOMPAT-001-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{width*9//16}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/qa/world/transient_save_capture.gd','--','--output='+str(target/'native'),'--profile='+profile,'--phase='+phase]
        if width==1280:args.append('--wide')
        print('TRANSIENT NATIVE',phase,width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try:code=child.wait(timeout=120)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid:
                    import os
                    os.kill(pid,signal.SIGTERM)
                child.terminate();child.wait(timeout=10);raise ValueError('own capture timed out')
        write(target/'environment.json',{'command':args,'exit_code':code,'context':context(),'existing_jobs':initial})
        if (target/'native').exists():
            for p in (target/'native').iterdir():shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts};write(folder/'source.json',source)
        if code or not (target/'capture.json').is_file() or json.loads((target/'capture.json').read_text())['errors'] or any(t in (target/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('native capture failed')
        if any(sha(input_path(ROOT, n))!=h for n,h in source['sources'].items()) or command(['git','diff',base,'--name-only','--','assets/game']):raise ValueError('frozen input changed')
    source['complete']=True;write(folder/'source.json',source)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--phase',choices=['before','after'],required=True);collect(p.parse_args().phase)

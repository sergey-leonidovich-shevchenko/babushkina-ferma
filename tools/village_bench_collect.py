#!/usr/bin/env python3
"""Collect source-bound before/after native bench captures without touching ordinary Godot."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,shutil,signal,subprocess,uuid
from pathlib import Path
from tools.qa.world.source_inputs import input_path
from tools.qa.performance.perf_contract_collect import ROOT,command,context,jobs,native_pid,sha,write
from object_command_collect import SOURCES as ORIGINAL

EXTRA=['scripts/systems/village_layout_system.gd','scripts/systems/world_visual_profile_system.gd','scripts/systems/visual_resource_catalog.gd','scripts/presentation/visual_sampling_system.gd','scripts/presentation/village_bench_visual.gd','assets/game/visual_resources.json','tools/village_bench_capture.gd','tools/village_bench_gallery.gd','tools/village_bench_collect.py']

def collect(folder,phase):
    """Preserve exact inputs and bounded real-window sessions for each independent phase."""
    if folder.exists():raise ValueError('fresh phase directory required')
    folder.mkdir(parents=True);initial=jobs();sources=sorted(set(ORIGINAL+EXTRA+[str(p.relative_to(ROOT)) for p in (ROOT/'assets/game/locations/overworld/benches').glob('*') if p.suffix in ['.png','.json','.import']]))
    source={'task':'VPROP-002','phase':phase,'base_commit':command(['git','rev-parse','HEAD']),'complete':False,'performance_eligible':False,'initial_jobs':initial,'sources':{},'artifacts':{}}
    for name in sources:
        if not (input_path(ROOT, name)).is_file():
            if phase=='before' and name in ['scripts/presentation/village_bench_visual.gd','tools/village_bench_gallery.gd']:continue
            raise ValueError('missing input '+name)
        target=folder/'inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(input_path(ROOT, name),target);source['sources'][name]=sha(target)
    write(folder/'source.json',source)
    for width in [1152,1280]:
        if set(jobs())-set(initial):raise ValueError('unexpected Godot appeared')
        target=folder/str(width);target.mkdir();profile='Codex-VPROP-002-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{round(width*9/16)}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/village_bench_capture.gd','--','--output='+str(target/'native'),'--profile='+profile,'--phase='+phase]
        if width==1280:args.append('--wide')
        before=context();print('BENCH NATIVE',phase,width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try:code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid:
                    import os
                    os.kill(pid,signal.SIGTERM)
                child.terminate();child.wait(timeout=10);raise ValueError('own capture timeout')
        write(target/'environment.json',{'command':args,'exit_code':code,'before':before,'after':context(),'existing_jobs':initial})
        if (target/'native').exists():
            for p in (target/'native').iterdir():shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        for p in target.glob('*-draws.json'):
            with gzip.GzipFile(str(p)+'.gz','wb',mtime=0) as out:out.write(p.read_bytes())
            p.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts};write(folder/'source.json',source)
        if code or not (target/'capture.json').is_file() or json.loads((target/'capture.json').read_text())['errors'] or any(t in (target/'engine.txt').read_text() for t in ['ERROR:','SCRIPT ERROR','Parse Error']):raise ValueError('native capture failed; partial data rejected')
        if any(sha(input_path(ROOT, n))!=h for n,h in source['sources'].items()):raise ValueError('frozen input changed')
    source['complete']=True;write(folder/'source.json',source)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--phase',choices=['before','after'],required=True);args=parser.parse_args()
    collect(ROOT/'docs/reports/visual-overhaul/vprop-002/native'/args.phase,args.phase)

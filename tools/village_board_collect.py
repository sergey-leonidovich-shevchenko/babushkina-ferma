#!/usr/bin/env python3
"""Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse,gzip,hashlib,json,shutil,signal,subprocess,uuid
from pathlib import Path
from tools.qa.world.source_inputs import input_path
from tools.qa.performance.perf_contract_collect import ROOT,command,context,jobs,native_pid,sha,write
from village_fence_collect import ORIGINAL as COMMON, EXTRA as STREET_EXTRA, FENCE_ASSETS as STREET_ASSETS
ORIGINAL=sorted(set(COMMON+STREET_EXTRA+STREET_ASSETS+['scripts/systems/atmosphere_renderer.gd','scripts/systems/world_event_system.gd','scripts/presentation/village_ground_clock.gd','assets/game/environment/buildable_fence_atlas_v1.png','scripts/systems/livestock_data.gd','scripts/systems/livestock_renderer.gd','scripts/systems/fence_renderer.gd','scripts/systems/fence_system.gd','scripts/systems/village_map_data.gd','scripts/systems/village_region_system.gd','scripts/systems/village_region_data.gd','scripts/systems/village_wayfinding_system.gd','scripts/systems/locale_system.gd','scripts/presentation/world_label_renderer.gd','scripts/presentation/moon_theme.gd','assets/game/fonts/ui_font.tres','assets/game/locations/overworld/modular/prop_board_v1.png']))
EXTRA=['scripts/presentation/village_board_visual.gd','tools/village_board_capture.gd','tools/village_board_gallery.gd','tools/village_board_collect.py']
FENCE_ASSETS=['assets/game/locations/overworld/boards/profile.json']+['assets/game/locations/overworld/boards/'+kind+'_'+side+'_v1.png'+suffix for kind in ['board','sign'] for side in ['south','west','east'] for suffix in ['', '.import']]

def collect(folder,phase):
    """Preserve exact inputs and bounded real-window sessions for each independent phase."""
    if folder.exists():raise ValueError('fresh phase directory required')
    folder.mkdir(parents=True);initial=jobs();sources=sorted(set(ORIGINAL+EXTRA+(FENCE_ASSETS if phase=='after' else [])))
    source={'task':'VPROP-006','phase':phase,'base_commit':command(['git','rev-parse','HEAD']),'complete':False,'performance_eligible':False,'initial_jobs':initial,'sources':{},'artifacts':{}}
    for name in sources:
        if not (input_path(ROOT, name)).is_file():
            if phase=='before' and name=='scripts/presentation/village_board_visual.gd':continue
            raise ValueError('missing input '+name)
        target=folder/'inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(input_path(ROOT, name),target);source['sources'][name]=sha(target)
    write(folder/'source.json',source)
    for width in [1152,1280]:
        if set(jobs())-set(initial):raise ValueError('unexpected Godot appeared')
        target=folder/str(width);target.mkdir();profile='Codex-VPROP-006-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',f'{width}x{round(width*9/16)}','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/village_board_capture.gd','--','--output='+str(target/'native'),'--profile='+profile,'--phase='+phase]
        if width==1280:args.append('--wide')
        before=context();print('BOARD NATIVE',phase,width,flush=True)
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
    collect(ROOT/'docs/reports/visual-overhaul/vprop-006/native'/args.phase,args.phase)

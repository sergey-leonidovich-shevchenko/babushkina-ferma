#!/usr/bin/env python3
"""Collect isolated, source-bound VGROUND-006 native images. No FPS claims."""
if not __package__:
    from common.launch import prepare_imports
    from common.paths import project_root
    prepare_imports(project_root(__file__))

import argparse
import gzip
import hashlib
import json
import shutil
import signal
import subprocess
from tools.common.git import git_environment
import uuid
from pathlib import Path
from tools.qa.performance.perf_contract_collect import ROOT, command, context, jobs, native_pid, sha, write

SOURCES = ['scripts/presentation/plaza_ground.gd','scripts/presentation/village_terrain_canvas.gd','scripts/systems/village_terrain_renderer.gd','scripts/world_background.gd',
 'assets/game/locations/overworld/modular/plaza_limestone_v1.png','assets/game/locations/overworld/modular/plaza_limestone_v1.png.import',
 'assets/game/locations/overworld/plaza_masks/apron.res','assets/game/locations/overworld/plaza_masks/contact.res','assets/game/locations/overworld/plaza_masks/stone.res',
 'tools/plaza_capture.gd','tools/plaza_board.gd','tools/plaza_collect.py','tools/plaza_compile.gd','tools/plaza_builder.gd','tools/plaza_field.gd','tools/plaza_import.gd',
 'scripts/presentation/ground_edge_masks.gd','scripts/presentation/village_ground_layer.gd','scripts/presentation/village_region_terrain.gd',
 'scripts/presentation/meadow_ground.gd','scripts/systems/village_map_data.gd','scripts/systems/village_region_data.gd','scripts/systems/cardinal_path_system.gd',
 'scripts/systems/navigation_system.gd','scripts/systems/world_farming_system.gd','scripts/presentation/visual_reference_mode.gd','scripts/systems/world_projection_system.gd',
 'tools/visual_camera_points.gd','tools/render_order_game.gd','tools/ground_edge_field.gd','project.godot','main.tscn']
SOURCES += ['assets/game/locations/overworld/road_network_masks/main.res','assets/game/locations/overworld/road_network_masks/connectors.res']
SOURCES += ['assets/game/locations/overworld/modular/'+name for name in ['grass_painted_v2.png','path_material_v1.png','dirt_material_v1.png','stone_material_v1.png','water_material_v1.png','bridge_modular_v1.png']]
OVERLAY = set(SOURCES[:16]+['project.godot'])


def collect(folder, static_coexistence=False):
    """Archive exact inputs before opening two fresh native processes, preserving partial failures."""
    if folder.exists(): raise ValueError('unused output required')
    initial_jobs=jobs()
    if initial_jobs and not static_coexistence: raise ValueError('another Godot is active; static-only coexistence must be explicit')
    changed=set(command(['git','diff','HEAD','--name-only','--','scripts','assets/game','main.tscn']).splitlines())
    if not changed <= OVERLAY|{'assets/game/world_sprite_manifest.json'}: raise ValueError('unrelated runtime changes')
    folder.mkdir(parents=True)
    base=command(['git','rev-parse','HEAD']); source={'task':'VGROUND-006','base_commit':base,'complete':False,'static_coexistence':static_coexistence,'initial_jobs':initial_jobs,'performance_eligible':False,'sources':{},'base_sources':{},'artifacts':{}}
    for name in SOURCES:
        target=folder/'inputs'/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)
        source['sources'][name]=sha(target)
        historical=subprocess.run(['git','show',base+':'+name],cwd=ROOT,capture_output=True,env=git_environment())
        source['base_sources'][name]=hashlib.sha256(historical.stdout).hexdigest() if historical.returncode==0 else None
    write(folder/'source.json',source)
    for width in [1152,1280]:
        if set(jobs())-set(initial_jobs): raise ValueError('another unexpected Godot appeared')
        target=folder/str(width); target.mkdir(); profile='Codex-VGROUND-006-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--resolution',str(width)+'x'+str(round(width*9/16)),'--audio-driver','Dummy',
            '--log-file',str(target/'engine.txt'),'--script','res://tools/plaza_capture.gd','--','--output='+str(target/'native'),'--profile='+profile]
        if width==1280: args.append('--wide')
        before=context(); print('PLAZA NATIVE',width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try: code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid: import os; os.kill(pid,signal.SIGTERM)
                child.terminate(); child.wait(timeout=10); raise ValueError('own capture timed out')
        write(target/'environment.json',{'command':args,'profile':profile,'exit_code':code,'before':before,'after':context(),'existing_jobs_before':initial_jobs,'jobs_after':jobs(),'static_coexistence':static_coexistence})
        if (target/'native').exists():
            for p in (target/'native').iterdir(): shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        for p in target.glob('*-draws.json'):
            with gzip.GzipFile(str(p)+'.gz','wb',mtime=0) as stream: stream.write(p.read_bytes())
            p.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
        write(folder/'source.json',source)
        if code or json.loads((target/'capture.json').read_text()).get('errors') or any(sha(ROOT/p)!=s for p,s in source['sources'].items()): raise ValueError('capture failed or frozen input changed')
    source['complete']=True; write(folder/'source.json',source)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--static-coexistence',action='store_true',help='Frozen visual proof only; record existing Godot without touching it; never performance evidence')
    args=parser.parse_args(); collect(args.output.resolve(),args.static_coexistence)

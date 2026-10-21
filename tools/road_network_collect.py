#!/usr/bin/env python3
"""Collect isolated, source-bound VGROUND-005 native images. No FPS claims."""
import argparse
import gzip
import hashlib
import shutil
import signal
import subprocess
import uuid
from pathlib import Path
from perf_contract_collect import ROOT, command, context, jobs, native_pid, sha, write

SOURCES = ['scripts/presentation/ground_edge_masks.gd','scripts/presentation/village_terrain_canvas.gd',
    'scripts/presentation/village_ground_layer.gd','scripts/presentation/village_region_terrain.gd',
    'scripts/systems/village_terrain_renderer.gd','scripts/world_background.gd',
    'assets/game/locations/overworld/axial_road_masks/main.res','assets/game/locations/overworld/axial_road_masks/connectors.res',
    'scripts/systems/village_map_data.gd','scripts/systems/village_region_data.gd','scripts/systems/navigation_system.gd',
    'scripts/systems/world_farming_system.gd','scripts/presentation/meadow_ground.gd',
    'scripts/presentation/visual_reference_mode.gd','scripts/systems/world_projection_system.gd',
    'tools/visual_camera_points.gd','tools/render_order_game.gd','tools/road_network_capture.gd','tools/road_network_board.gd',
    'tools/road_network_collect.py','tools/axial_road_compile.gd','tools/axial_road_builder.gd','tools/axial_road_field.gd',
    'project.godot','main.tscn']
SOURCES += ['scripts/systems/cardinal_path_system.gd','tools/ground_edge_field.gd','tools/ground_edge_builder.gd','assets/game/locations/overworld/ground_masks/main.res','assets/game/locations/overworld/ground_masks/connectors.res']
SOURCES += ['assets/game/locations/overworld/modular/'+name for name in ['grass_painted_v2.png','path_material_v1.png','dirt_material_v1.png','stone_material_v1.png','water_material_v1.png','bridge_modular_v1.png']]

SOURCES += ['tools/road_network_builder.gd','tools/road_network_compile.gd','assets/game/locations/overworld/road_network_masks/main.res','assets/game/locations/overworld/road_network_masks/connectors.res']
OVERLAY = set(SOURCES[:6]+[p for p in SOURCES if p.startswith('tools/road_network') or '/road_network_masks/' in p]+['project.godot'])


def collect(folder):
    """Archive exact inputs before opening two fresh native processes, preserving partial failures."""
    if folder.exists() or jobs(): raise ValueError('unused output and no competing Godot required')
    changed=set(command(['git','diff','HEAD','--name-only','--','scripts','assets/game','main.tscn']).splitlines())
    if not changed <= OVERLAY|{'assets/game/world_sprite_manifest.json'}: raise ValueError('unrelated runtime changes')
    folder.mkdir(parents=True)
    base=command(['git','rev-parse','HEAD']); source={'task':'VGROUND-005','base_commit':base,'complete':False,'sources':{},'base_sources':{},'artifacts':{}}
    for name in SOURCES:
        target=folder/'inputs'/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)
        source['sources'][name]=sha(target)
        historical=subprocess.run(['git','show',base+':'+name],cwd=ROOT,capture_output=True)
        source['base_sources'][name]=hashlib.sha256(historical.stdout).hexdigest() if historical.returncode==0 else None
    write(folder/'source.json',source)
    for width in [1152,1280]:
        if jobs(): raise ValueError('competing Godot appeared')
        target=folder/str(width); target.mkdir(); profile='Codex-VGROUND-005-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
            '--log-file',str(target/'engine.txt'),'--script','res://tools/road_network_capture.gd','--','--output='+str(target/'native'),'--profile='+profile]
        if width==1280: args.append('--wide')
        before=context(); print('NETWORK NATIVE',width,flush=True)
        with (target/'stdout.txt').open('w') as out:
            child=subprocess.Popen(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT)
            try: code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid: import os; os.kill(pid,signal.SIGTERM)
                child.terminate(); child.wait(timeout=10); raise ValueError('own capture timed out')
        write(target/'environment.json',{'command':args,'profile':profile,'exit_code':code,'before':before,'after':context()})
        if (target/'native').exists():
            for p in (target/'native').iterdir(): shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        for p in target.glob('*-draws.json'):
            with gzip.GzipFile(str(p)+'.gz','wb',mtime=0) as stream: stream.write(p.read_bytes())
            p.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
        write(folder/'source.json',source)
        if code or any(sha(ROOT/p)!=s for p,s in source['sources'].items()): raise ValueError('capture failed or frozen input changed')
    source['complete']=True; write(folder/'source.json',source)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,required=True)
    collect(parser.parse_args().output.resolve())

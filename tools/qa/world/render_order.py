#!/usr/bin/env python3
"""VRENDER-001: source-bound command inventory and native draw-purity evidence, never an FPS gate."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import json
import os
from tools.common.git import git_environment
from pathlib import Path
import re
import shutil
import signal
import subprocess
import uuid
from PIL import Image, ImageChops

from tools.common.paths import project_root
from tools.common.launch import prepare_imports

ROOT = project_root(__file__)
prepare_imports(ROOT)
from tools.qa.world.source_inputs import historical_bytes, input_path
REPORT=ROOT/'docs/reports/visual-overhaul/vrender-001'
SOURCES=['main.tscn','project.godot','scripts/systems/render_system.gd','scripts/game_renderer.gd',
 'scripts/world_background.gd','scripts/presentation/village_terrain_canvas.gd','scripts/systems/world_projection_system.gd',
 'scripts/systems/tree_occlusion_system.gd','scripts/systems/orchard_system.gd','scripts/systems/village_foreground_renderer.gd',
 'scripts/systems/village_prop_renderer.gd','scripts/systems/village_terrain_renderer.gd',
 'scripts/presentation/village_region_renderer.gd','scripts/presentation/visual_reference_mode.gd',
 'scripts/systems/save_system.gd','tools/visual_camera_points.gd','tools/render_order_game.gd',
 'tools/render_order_capture.gd','tools/render_order.py']
CASES=['village','tree-behind','tree-front','bush','bridge','manual-pause','opaque-storage','interior','returned']
CALL=re.compile(r'(preload\("res://[^"\n]+"\)|game(?:\.[A-Za-z_]\w*)?|[A-Z]\w*)\.([A-Za-z_]\w*)\(')


def require(condition,message):
    """Rejects missing or stale evidence rather than generating a replacement during validation."""
    if not condition: raise ValueError(message)


def sha(path):
    """Hashes exact source/artifact bytes."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    """Reads only explicitly selected report files."""
    return json.loads(Path(path).read_text())


def write(path,data):
    """Explicit authoring is separate from the read-only gate."""
    Path(path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


def inventory(text):
    """Keeps source order and exact guards; source order is not a claim that all branches execute."""
    calls=[]; function=''
    for line_no,line in enumerate(text.splitlines(),1):
        match=re.match(r'static func (\w+)\(',line)
        if match: function=match[1]
        if not line.startswith('\t') or line.lstrip().startswith('#'): continue
        for match in CALL.finditer(line):
            receiver,method=match.groups()
            calls.append({'function':function,'line':line_no,'receiver':receiver,'method':method,'source':line.strip(),
                'drawing_or_transform':method.startswith('draw') or (receiver in ['WorldProjection','TreeOcclusion'] and method in ['apply','begin_frame'])})
    return calls


def build_contract():
    """Authors the reviewed source snapshot; this command never marks a native run accepted."""
    write(REPORT/'contract.json',{'task':'VRENDER-001','base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip(),
        'sources':{p:sha(input_path(ROOT, p)) for p in SOURCES},'calls':inventory((ROOT/'scripts/systems/render_system.gd').read_text()),
        'coordinates':{'world':'WorldProjection: zoom * (world - camera); first overworld 1.2, HUD 1.0',
            'background':'separate Node2D, show_behind_parent; matching position/scale',
            'terrain_cache':'world-space offscreen SubViewport, UPDATE_ONCE; not a second camera',
            'screen':'identity draw transform, then atmosphere/HUD/modals/feedback'},
        'material':'default CanvasItem material (null) on game/background/terrain; tinted texture/primitive commands; no new shader',
        'scope':'inventory and preservation; batching/material implementation belongs to VRENDER-002 onward'})


def validate_contract(contract,folder=ROOT):
    """Checks all reviewed calls and the exact source version without silently re-authoring it."""
    require(contract.get('task')=='VRENDER-001' and set(contract['sources'])==set(SOURCES),'source coverage')
    for name,digest in contract['sources'].items(): require(sha(input_path(ROOT,name) if Path(folder).resolve()==ROOT.resolve() else folder/name)==digest,'source changed: '+name)
    calls=inventory((folder/'scripts/systems/render_system.gd').read_text())
    require(calls==contract['calls'],'command inventory stale')
    world=[x['receiver']+'.'+x['method'] for x in calls if x['function']=='draw']
    require(world.index('WorldProjection.apply')<world.index('game.draw_player')<world.index('game.VillageForegroundRenderer.draw')<world.index('game.AtmosphereRenderer.draw'),'world/foreground/screen order')
    require('game.PublishedLevelRenderer.draw_layer' in world and 'game.LevelEditorRenderer.draw_layer' in world,'published/editor paths lost')
    require('screen' in contract['coordinates'] and 'null' in contract['material'],'coordinates/material missing')


def native_jobs():
    """Does not compete with another native capture or terminate another engine."""
    raw=subprocess.check_output(['ps','-axo','pid=,comm='],text=True)
    return [line for line in raw.splitlines() if line.rstrip().endswith('/Godot')]


def capture(folder):
    """Runs two isolated native windows serially; all readbacks are diagnostic, not performance samples."""
    require(not folder.exists(),'fresh output required'); require(not native_jobs(),'another Godot active')
    require(not subprocess.check_output(['git','diff','HEAD','--','scripts','assets/game','main.tscn'],cwd=ROOT,text=True, env=git_environment()),'runtime changed')
    contract=read(REPORT/'contract.json'); validate_contract(contract,ROOT)
    folder.mkdir(parents=True)
    for name in SOURCES:
        target=folder/'instrumentation'/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(input_path(ROOT, name),target)
    source={'task':'VRENDER-001','base_commit':contract['base_commit'],'complete':False,'sources':contract['sources'],'artifacts':{}}
    write(folder/'source.json',source)
    for width in [1152,1280]:
        require(not native_jobs(),'competing Godot appeared')
        name=str(width); target=folder/name; target.mkdir(); profile='Codex-VRENDER-001-'+uuid.uuid4().hex
        command=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
            '--log-file',str(target/'engine.txt'),'--script','res://tools/qa/world/render_order_capture.gd','--',
            '--output='+str(target/'frames'),'--profile='+profile]
        if width==1280: command.append('--wide')
        print('RENDER NATIVE',width,flush=True)
        try:
            with (target/'stdout.txt').open('w') as output:
                result=subprocess.run(command,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,timeout=180)
        except subprocess.TimeoutExpired:
            # Stop only this unique diagnostic launch; another task's engine is never targeted.
            raw=subprocess.check_output(['ps','-axo','pid=,command='],text=True)
            for line in raw.splitlines():
                fields=line.strip().split(None,1)
                if len(fields)==2 and '/Godot ' in fields[1] and '--profile='+profile in fields[1]: os.kill(int(fields[0]),signal.SIGTERM)
            raise
        require(not native_jobs(),'engine did not exit')
        write(target/'launch.json',{'command':command,'exit_code':result.returncode,'profile':profile})
        require((target/'frames').exists(),'native frames missing')
        for path in (target/'frames').iterdir(): shutil.move(str(path),target/path.name)
        (target/'frames').rmdir()
        for path in target.glob('*-draws.json'):
            with gzip.GzipFile(str(path)+'.gz','wb',mtime=0) as output: output.write(path.read_bytes())
            path.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
        write(folder/'source.json',source)
        require(result.returncode==0,'native capture failed')
        validate_contract(contract,ROOT)
    source['complete']=True; write(folder/'source.json',source)


def validate_draws(values):
    """Compares actual full snapshots, not only a self-reported green boolean."""
    require(len(values)>=4,'draw callbacks missing')
    for row in values:
        require(row['before']==row['after'] and row['equal'] is True,'draw changed saved gameplay state')
        require(row['geometry_before']==row['geometry_after'] and row['geometry_equal'] is True,'draw changed camera/location/menu')
        require(row['queue_after']==0,'foreground queue not consumed')


def verify(folder=REPORT/'native'):
    """Validates source-bound native pairs and purity; never grants shader, FPS or whole-map acceptance."""
    contract=read(REPORT/'contract.json')
    source=read(folder/'source.json'); require(source.get('complete') is True and source['sources']==contract['sources']
        and source['task']==contract['task'] and source['base_commit']==contract['base_commit'],'collection incomplete or sources differ')
    require(subprocess.run(['git','cat-file','-e',source['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True, env=git_environment()).returncode==0,'Git base absent')
    validate_contract(contract,folder/'instrumentation')
    overlay={'project.godot','tools/render_order.py','tools/render_order_game.gd','tools/render_order_capture.gd'}
    for name,digest in source['sources'].items():
        if name in overlay: continue
        base=historical_bytes(ROOT, source['base_commit'], name)
        require(hashlib.sha256(base).hexdigest()==digest,'archived runtime differs from Git base: '+name)
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts,'artifact path escapes')
        require(sha(folder/name)==digest,'artifact changed: '+name)
    totals={'pairs':0,'draws':0,'pixel_differences':{}}; profiles=[]; pids=[]
    for width,height in [(1152,648),(1280,720)]:
        target=folder/str(width); data=read(target/'capture.json'); launch=read(target/'launch.json')
        require(launch['exit_code']==0 and '--headless' not in launch['command'] and data['display_server']=='macOS' and data['driver']=='opengl3','native launch required')
        require(launch['profile']==data['profile'] and data['profile'].startswith('Codex-VRENDER-001-'),'isolated profile mismatch')
        require(data['task']=='VRENDER-001' and not data['errors'] and data['simulation_frozen'] is True and data['performance_eligible'] is False,'capture rejected or mislabelled')
        require('ERROR:' not in (target/'engine.txt').read_text() and 'SCRIPT ERROR' not in (target/'engine.txt').read_text(),'engine error')
        require([c['id'] for c in data['cases']]==CASES,'case coverage/order')
        profiles.append(data['profile']); pids.append(data['pid'])
        for case in data['cases']:
            name=case['id']; expected_location='cottage_interior' if name=='interior' else 'overworld'
            require(case['location']==expected_location and case['pause']==(name=='manual-pause') and case['storage']==(name=='opaque-storage'),'actual route differs')
            require(case['zoom']==(1 if name=='interior' else 1.2),'world zoom differs')
            if name=='tree-behind': require(case['tree_alpha']==.34 and case['player'][1]<case['tree_position'][1]+12,'actual tree occlusion missing')
            if name=='tree-front': require(case['tree_alpha']==1 and case['player'][1]>case['tree_position'][1]+18,'actual front tree placement missing')
            require(case['window']==[width,height] and case['readback']==[width,height],'physical window/readback mismatch')
            require(case['visible']==[1152,648] and case['focused'] is True,'logical canvas/focus differs')
            require(all(case[k] is True for k in ['root_material_null','background_material_null','terrain_material_null','background_behind_parent']),'material/background contract differs')
            with gzip.open(target/(name+'-draws.json.gz'),'rt') as stream: draws=json.load(stream)
            validate_draws(draws); require(len(draws)==case['draws'],'draw count differs'); totals['draws']+=len(draws)
            with Image.open(target/(name+'-baseline.png')) as a,Image.open(target/(name+'-observed.png')) as b:
                require(a.size==b.size==(width,height),'PNG dimensions differ')
                diff=ImageChops.difference(a.convert('RGBA'),b.convert('RGBA'))
                changed=sum(1 for pixel in diff.getdata() if any(pixel))
            totals['pixel_differences'][str(width)+'/'+name]=changed
            require(changed==0,'observer changed pixels: '+str(width)+'/'+name)
            totals['pairs']+=1
    require(len(set(profiles))==len(set(pids))==2,'independent profiles/processes missing')
    return {'task':'VRENDER-001','accepted':True,'fps_accepted':False,'new_shader_accepted':False,'whole_map_accepted':False,
        'calls':len(contract['calls']),**totals}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--write',action='store_true'); parser.add_argument('--capture',type=Path)
    parser.add_argument('--output',type=Path,default=REPORT/'native'); args=parser.parse_args()
    if args.write: build_contract()
    elif args.capture: capture(args.capture.resolve())
    else: print(json.dumps(verify(args.output),indent=2))

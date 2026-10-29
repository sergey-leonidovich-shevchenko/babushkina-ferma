#!/usr/bin/env python3
"""VCAMERA-006: identical world trajectories at 100/120%, separate from live timing."""
from __future__ import annotations
from tools.assets.contracts.source_paths import current_source
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
from tools.common.git import git_environment
import uuid
from PIL import Image, ImageChops, ImageStat
from tools.qa.camera.camera_quantization import ROOT, CASES, SOURCES as BASE_SOURCES, read, sha, require, near, manifest
from tools.qa.camera.presentation_pose import recording_scratch

REPORT=ROOT/'docs/reports/visual-overhaul/vcamera-006'
MODES={'100':1.0,'120':1.2}
LEGACY_SOURCES=list(dict.fromkeys(BASE_SOURCES+[
    'scripts/systems/world_projection_system.gd','scripts/systems/render_system.gd',
    'scripts/systems/presentation_pose_system.gd','scripts/systems/world_visibility_system.gd',
    'scripts/systems/directional_character_system.gd','scripts/systems/livestock_visual_system.gd',
    'scripts/systems/world_polish_renderer.gd','scripts/game_renderer.gd',
    'scripts/presentation/apiary_visual_system.gd','scripts/presentation/world_label_renderer.gd',
    'scripts/systems/adventure_polish_system.gd','scripts/systems/adventure_polish_renderer.gd',
    'scripts/systems/debug_playground_system.gd','scripts/systems/debug_object_inspector_system.gd',
    'scripts/systems/debug_overlay_system.gd','scripts/systems/atmosphere_renderer.gd',
    'scripts/systems/level_editor_system.gd','scripts/systems/level_editor_renderer.gd',
    'scripts/systems/fence_renderer.gd','tools/presentation_pose_capture.gd',
    'tools/presentation_pose.py','tools/reference_zoom_capture.gd','tools/reference_zoom.py']))
SOURCES=LEGACY_SOURCES+['scripts/systems/published_level_system.gd','scripts/presentation/village_region_renderer.gd']


def expected_sources(source):
    """Keeps the original packet immutable while pinning all new runtime consumers in schema 2."""
    schema=source.get('schema',1)
    require(schema in [1,2],'unsupported zoom source schema')
    return LEGACY_SOURCES if schema==1 else SOURCES


def validate_run(data, size, amount, native=True):
    """Uses independent geometry/phase equations and actual per-frame GPU/input observations."""
    require(data.get('task')=='VCAMERA-006' and data.get('kind')==('zoom-native' if native else 'zoom-probe'),'native zoom recording required')
    require(data.get('performance_eligible') is False and not data.get('errors'),'diagnostic classification/errors')
    require(data.get('requested')==size and data.get('zoom')==amount,'profile/size differs')
    require(data.get('physics_hz')==30 and data.get('video_hz')==60,'controlled phase schedule differs')
    require(data.get('profile','').startswith('Codex-VCAMERA-006-'),'isolated profile required')
    if native:
        require(data.get('display_server')=='macOS' and data.get('renderer')=='opengl3','native GPU required')
        require(data.get('initial')=={'window':size,'root':size,'focused':True,'mode':0},'native initial window/focus')
        require(data.get('content_scale_mode')==1 and data.get('content_scale_size')==[1152,648] and data.get('content_scale_factor')==1,'logical HUD canvas changed')
        if size==[2304,1296]: require(data.get('hidpi') is True and data.get('screen_scale',0)>=2,'Retina not observed')
    rows=data.get('frames',[]); require(len(rows)==240,'incomplete recording')
    inputs=[]
    for start,end,key in [(0,120,'D'),(120,240,'A')]:
        inputs += [{'after_rows':start,'key':k,'pressed':True} for k in [key,'S']]
        inputs += [{'after_rows':end,'key':k,'pressed':False} for k in [key,'S']]
    require(data.get('inputs')==inputs,'routed input edges differ')
    field=[1152/amount,648/amount]; scale=size[0]/1152
    hud=[]
    for i,row in enumerate(rows):
        stage,frame=divmod(i,120); alpha=(frame%2)*0.5; physical_step=frame>0 and frame%2==0
        if frame==0: previous=[600.25 if stage==0 else 60.25,700.25 if stage==0 else 672.25]; previous_clock=0
        elif physical_step: previous=rows[i-1]['player']; previous_clock=rows[i-1]['physical_walk_clock']
        require(row.get('index')==i and row.get('stage')==stage and row.get('frame')==frame and row.get('alpha')==alpha and row.get('physical_step') is physical_step,'phase order')
        require(row.get('location')=='overworld' and row.get('walkable') is True and row.get('automatic_physics') is False and row.get('automatic_render') is False,'uncontrolled simulation/collision')
        player=row['player']; require(near(player,player),'nonfinite physics')
        require(abs(row['minutes']-(720+(frame//2)/30))<1e-5,'render changed world clock')
        if frame==0: require(near(player,previous),'prepared start differs')
        elif not physical_step: require(player==rows[i-1]['player'] and row['physical_walk_clock']==rows[i-1]['physical_walk_clock'],'render changed physics/clock')
        else: require(0<=player[1]-previous[1]<=0.601 and math.dist(player,previous)<=0.601,'invalid physical step')
        if stage==0:
            require(near(player,[600.25+(frame//2)*18/math.sqrt(2)/30,700.25+(frame//2)*18/math.sqrt(2)/30],0.01),'physical trajectory differs')
        expected=[previous[j]+(player[j]-previous[j])*alpha for j in range(2)]
        require(near(row.get('previous'),previous) and near(row.get('ground'),expected) and near(row.get('foot_world'),expected),'displayed foot phase mismatch')
        start_clock=min(previous_clock,row['physical_walk_clock']); clock=start_clock+(row['physical_walk_clock']-start_clock)*alpha
        require(math.isfinite(clock) and abs(row['walk_clock']-clock)<1e-5,'animation phase mismatch')
        camera=[max(0,min(2400-field[0],expected[0]-field[0]/2)),max(0,min(1368-field[1],expected[1]-field[1]/2))]
        project=lambda point:[(point[j]-camera[j])*amount for j in range(2)]
        require(row.get('zoom')==amount and near(row.get('field'),field),'world field/profile mismatch')
        require(near(row.get('camera'),camera) and near(row.get('background'),[-v*amount for v in camera]) and near(row.get('background_scale'),[amount,amount]),'terrain/camera scale mismatch')
        require(all(near(a,b) for a,b in zip(row.get('matrix',[]),[[amount,0],[0,amount],[-v*amount for v in camera]])) and len(row.get('matrix',[]))==3,'world matrix mismatch')
        require(near(row.get('foot_canvas'),project(expected)) and near(row.get('hero_frame_projected'),[96*amount,96*amount]),'hero projected size/foot mismatch')
        if stage==0: require(near(row['foot_canvas'],[576,324]),'world center differs')
        root=[624.25 if stage==0 else 84.25,732.25 if stage==0 else 704.25]
        offset=[expected[j]-root[j] for j in range(2)]; contact=[v/72 for v in offset] if math.hypot(*offset)<72 else [0,0]
        require(row.get('radius')==72 and near(row.get('root'),root) and near(row.get('root_canvas'),project(root)) and near(row.get('contact'),contact),'root anchor/phase mismatch')
        pointer=[624+(-0.125 if frame%2==0 else 0.125),720.125] if stage==0 else [[0.125,23.875,24.125][frame%3],720.125]
        canvas=project(pointer); cell=[math.floor(v/24) for v in pointer]
        require(near(row.get('pointer_world'),pointer) and near(row.get('pointer_canvas'),canvas) and near(row.get('pointer_received'),canvas),'inverse pointer mismatch')
        require(row.get('pointer_cell')==cell,'interaction cell mismatch')
        if native: require(near(row.get('pointer_window'),[v*scale for v in canvas]),'window/DPI mismatch')
        require(near(row.get('cell_size'),[24*amount,24*amount]) and near(row.get('cell_origin_canvas'),project([v*24 for v in cell])),'projected cell mismatch')
        require(row.get('hud_bounds')==[0,0,1152,80] and row.get('hud_hotbar')==rows[0]['hud_hotbar'],'HUD geometry changed')
        if native:
            require(row.get('window')==size and row.get('readback')==size and row.get('visible')==[1152,648] and row.get('window_mode')==0 and row.get('focused') is True,'native window/readback/focus')
            require(row.get('fiducial') is True and row.get('foot_pixel') is True and near(row.get('stretch_scale'),[scale,scale]),'GPU marker/scale')
            require(near(row.get('shader_contact'),contact),'shader reads a different foot')
            crop=[int(v*scale) for v in [30,23,160,28]]
            require(row.get('hud_crop')==crop,'HUD pixel crop geometry changed')
            require(len(row.get('hud_sha256',''))==64 and all(c in '0123456789abcdef' for c in row['hud_sha256']),'HUD pixel crop missing'); hud.append(row['hud_sha256'])
    require(40<=rows[-1]['player'][0]<40+18/math.sqrt(2)/30,'left collision edge not reached')
    steps=[rows[i]['camera'][1]-rows[i-1]['camera'][1] for i in range(31,120)]
    return {'zoom':amount,'field':field,'camera_stalls':sum(abs(v)<1e-6 for v in steps),'max_world_camera_step':max(steps),'hud_hashes':hud}


def archived_collectors(folder, source):
    """Checks safe source coverage for the initial and any resumed collector."""
    result={source['sources']['tools/reference_zoom.py']}
    for item in source.get('resume_tools',[]):
        p=Path(item['path'])
        require(not p.is_absolute() and '..' not in p.parts and len(p.parts)==2 and p.parts[0]=='collection-tools','unsafe collector path')
        require(source['artifacts'].get(str(p))==item['sha256'] and sha(folder/p)==item['sha256'],'collector archive hash')
        result.add(item['sha256'])
    return result


def verify(folder):
    """Rejects missing/changed artifacts and compares exact physics and real HUD pixels in each pair."""
    source=read(folder/'source.json')
    require(source.get('task')=='VCAMERA-006' and source.get('complete') is True and source.get('performance_eligible') is False,'incomplete provenance')
    expected=expected_sources(source)
    require(set(source.get('sources',{}))==set(expected),'source coverage')
    archived={str(p.relative_to(folder/'instrumentation')) for p in (folder/'instrumentation').rglob('*') if p.is_file()}
    require(archived==set(expected),'unexpected archived source')
    for name,digest in source['sources'].items(): require(sha(folder/'instrumentation'/name)==digest,'source hash: '+name)
    files={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    require(files==set(source['artifacts']),'artifact coverage')
    for name,digest in source['artifacts'].items(): require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/name)==digest,'artifact hash: '+name)
    collectors=archived_collectors(folder,source); metrics={}; profiles=[]; pids=[]
    for case,size in CASES.items():
        pair=[]; hashes=[]
        for mode,amount in MODES.items():
            name=case+'-'+mode; path=folder/name; data=read(path/'capture.json')
            metric=validate_run(data,size,amount); hashes.append(metric.pop('hud_hashes')); metrics[name]=metric
            pair.append(data['frames']); profiles.append(data['profile']); pids.append(data['pid'])
            env=read(path/'environment.json')
            require(env['exit_code']==0 and '--headless' not in env['command'] and 'ERROR:' not in (path/'engine.txt').read_text(),'native launch/engine error')
            require('--zoom='+str(amount) in env['command'] and '--size=%dx%d'%tuple(size) in env['command'] and '--profile='+data['profile'] in env['command'],'native launch profile differs')
            require(env['collector_sha256'] in collectors,'unknown collector')
            video=read(path/'walk.json')
            require([video['width'],video['height']]==size and video['frames']==240 and video['fps']==60 and abs(video['duration']-4)<0.01,'video metadata')
            require((path/'walk.mp4').read_bytes()[4:8]==b'ftyp' and (path/'walk.mp4').stat().st_size<8*1024*1024,'bounded MP4 required')
            first=Image.open(path/'frame-0000.png').convert('RGB'); decoded=Image.open(path/'walk.decoded.png').convert('RGB')
            require(list(first.size)==size and decoded.size==first.size,'PNG dimensions')
            require(sum(ImageStat.Stat(ImageChops.difference(first,decoded)).mean)/3<6,'decoded video content/orientation')
            scale=size[0]/1152
            require(sum(abs(a-b) for a,b in zip(first.getpixel((round(20*scale),round(164*scale))),[255,0,255]))<10,'PNG fiducial')
            with Image.open(path/'frame-0000.png') as image:
                x,y,w,h=data['frames'][0]['hud_crop']
                actual=hashlib.sha256(image.crop((x,y,x+w,y+h)).tobytes().hex().encode()).hexdigest()
                require(actual==data['frames'][0]['hud_sha256'],'actual HUD pixels differ from trace')
        require(all(a['player']==b['player'] and a['minutes']==b['minutes'] and a['physical_walk_clock']==b['physical_walk_clock'] and near(a['ground'],b['ground']) and near(a['pointer_world'],b['pointer_world']) for a,b in zip(*pair)),'paired simulation/input differs')
        require(hashes[0]==hashes[1],'real HUD pixel crops differ between zoom profiles')
    require(len(set(profiles))==6 and len(set(pids))==6,'six independent native runs required')
    return metrics


def capture(folder, resume=False):
    """Freezes runtime sources and keeps raw frames on failure; completed clips are never overwritten."""
    digest=sha(Path(__file__))
    if resume:
        source=read(folder/'source.json')
        require(source.get('task')=='VCAMERA-006' and source.get('complete') is False,'only an incomplete same-task packet can resume')
        require(set(source['sources'])==set(expected_sources(source)),'resumed source coverage')
        for p,h in source['sources'].items():
            require(sha(folder/'instrumentation'/p)==h,'original source changed: '+p)
            if p!='tools/reference_zoom.py': require(sha(current_source(ROOT, p))==h,'runtime/instrumentation changed; new packet required: '+p)
        archived_collectors(folder,source)
        for case in CASES:
            for mode in MODES:
                name=case+'-'+mode
                if (folder/name/'walk.json').is_file():
                    for p,h in source['artifacts'].items():
                        if p.startswith(name+'/'): require('..' not in Path(p).parts and sha(folder/p)==h,'completed artifact changed: '+p)
        require(source.get('schema',1)==2,'legacy packet cannot pin added consumers; a fresh schema 2 packet is required')
        target=folder/'collection-tools'/(digest+'.py'); target.parent.mkdir(exist_ok=True); shutil.copy2(__file__,target)
        source.setdefault('resume_tools',[]).append({'path':str(target.relative_to(folder)),'sha256':sha(target)})
    else:
        require(not folder.exists(),'fresh output required'); folder.mkdir(parents=True)
        source={'schema':2,'task':'VCAMERA-006','complete':False,'performance_eligible':False,
                'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip(),
                'sources':{p:sha(current_source(ROOT, p)) for p in SOURCES},'artifacts':{}}
        for p in SOURCES:
            target=folder/'instrumentation'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(current_source(ROOT, p),target)
    manifest(folder,source)
    with recording_scratch() as temporary:
        for case,size in CASES.items():
            for mode,amount in MODES.items():
                name=case+'-'+mode; target=folder/name
                if resume and (target/'walk.json').is_file():
                    validate_run(read(target/'capture.json'),size,amount); print('REUSE_COMPLETE '+name,flush=True); continue
                require(not target.exists(),'preserve incomplete case separately before retry: '+name)
                print('CAPTURE '+name,flush=True); target.mkdir(); raw=temporary/name
                launch=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
                    '--log-file',str(target/'engine.txt'),'--script','res://tools/qa/camera/reference_zoom_capture.gd','--','--output='+str(raw),
                    '--profile=Codex-VCAMERA-006-'+uuid.uuid4().hex,'--size=%dx%d'%tuple(size),'--zoom='+str(amount)]
                with (target/'stdout.txt').open('w') as log: result=subprocess.run(launch,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600)
                (target/'environment.json').write_text(json.dumps({'command':launch,'exit_code':result.returncode,'collector_sha256':digest,'exit_code_scope':'LaunchServices; actual engine completion in capture.json'},indent=2)+'\n')
                if (raw/'capture.json').is_file(): shutil.copy2(raw/'capture.json',target/'capture.json')
                for frame in [0,120]:
                    if (raw/('frames/%04d.png'%frame)).is_file() and (frame==0 or case=='base'): shutil.copy2(raw/('frames/%04d.png'%frame),target/('frame-%04d.png'%frame))
                manifest(folder,source)
                require(result.returncode==0 and 'ERROR:' not in (target/'engine.txt').read_text(),'native launch/engine error: '+name)
                validate_run(read(target/'capture.json'),size,amount)
                env=dict(os.environ,SWIFT_MODULECACHE_PATH=str(temporary/'swift-cache'),CLANG_MODULE_CACHE_PATH=str(temporary/'clang-cache'))
                with (target/'encoder.txt').open('w') as log: subprocess.run(['swift',str(ROOT/'tools/encode_coordinate_video.swift'),str(raw/'frames'),str(target/'walk.mp4'),'60','4000000'],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
                shutil.rmtree(raw); manifest(folder,source)
    source['complete']=True; manifest(folder,source)
    metrics=verify(folder); (folder.parent/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    print('VALID_REFERENCE_ZOOM',flush=True)


def main():
    """Records a fresh native packet or validates frozen evidence without a display."""
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('command',choices=['capture','resume','verify','probe'])
    parser.add_argument('--output',type=Path,default=REPORT/'native'); args=parser.parse_args()
    try:
        if args.command in ['capture','resume']: capture(args.output.resolve(),args.command=='resume')
        elif args.command=='probe': print(validate_run(read(args.output/'capture.json'),[1152,648],1.2,False))
        else: print(json.dumps(verify(args.output.resolve()),indent=2))
    except (OSError,ValueError,KeyError,TypeError) as error: raise SystemExit(str(error)) from error


if __name__=='__main__': main()

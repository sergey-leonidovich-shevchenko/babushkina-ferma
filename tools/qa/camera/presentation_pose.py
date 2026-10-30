#!/usr/bin/env python3
"""VCAMERA-003: paired native presentation phases and root shader contact, never FPS."""
from __future__ import annotations
from tools.qa.world.source_inputs import input_path
from tools.assets.contracts.source_paths import current_source
import argparse
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
from tools.common.git import git_environment
import tempfile
import uuid
from contextlib import contextmanager
from PIL import Image, ImageChops, ImageStat
from tools.qa.camera.camera_quantization import ROOT, CASES, SOURCES as BASE_SOURCES, read, sha, require, near, manifest

REPORT = ROOT/'docs/reports/visual-overhaul/vcamera-003'
MODES = {'physical': True, 'shared': False}
SOURCES = BASE_SOURCES + ['scripts/systems/presentation_pose_system.gd',
    'scripts/systems/tree_occlusion_system.gd', 'scripts/systems/village_prop_renderer.gd',
    'tools/presentation_pose_capture.gd', 'tools/presentation_pose.py']


def validate_run(data, size, legacy, retina=False):
    """Checks every phase against independent interpolation, clamps, input and physics equations."""
    require(data.get('kind') == 'pose-native' and data.get('task') == 'VCAMERA-003', 'native pose recording required')
    require(data.get('performance_eligible') is False and not data.get('errors'), 'diagnostic classification/errors')
    require(data.get('legacy') is legacy and data.get('requested') == size, 'variant/size')
    require(data.get('display_server') == 'macOS' and data.get('renderer') == 'opengl3', 'native GPU required')
    require(data.get('physics_hz') == 30 and data.get('video_hz') == 60, 'controlled phase schedule differs')
    require(data.get('profile', '').startswith('Codex-VCAMERA-003-'), 'isolated profile required')
    require(data.get('initial') == {'window':size, 'root':size, 'focused':True, 'mode':0}, 'initial window/focus')
    require(data.get('content_scale_mode') == 1 and data.get('content_scale_size') == [1152,648] and data.get('content_scale_factor') == 1, 'logical viewport changed')
    if retina: require(data.get('hidpi') is True and data.get('screen_scale',0) >= 2, 'Retina not observed')
    rows = data.get('frames', [])
    require(len(rows) == 360, 'incomplete recording')
    inputs = []
    for start,end,key in [(0,180,'D'),(180,360,'A')]:
        inputs += [{'after_rows':start,'key':k,'pressed':True} for k in [key,'S']]
        inputs += [{'after_rows':end,'key':k,'pressed':False} for k in [key,'S']]
    require(data.get('inputs') == inputs, 'routed input edges differ')
    scale = size[0]/1152
    for i,row in enumerate(rows):
        stage,frame = divmod(i,180)
        alpha = (frame%2)*0.5
        physical_step = frame>0 and frame%2 == 0
        if frame == 0:
            previous = [562.25 if stage == 0 else 60.25,672.25]
            previous_clock = 0
        elif physical_step:
            previous = rows[i-1]['player']
            previous_clock = rows[i-1]['physical_walk_clock']
        require(row.get('index') == i and row.get('stage') == stage and row.get('frame') == frame and row.get('alpha') == alpha and row.get('physical_step') is physical_step, 'phase order')
        require(row.get('location') == 'overworld' and row.get('walkable') is True and row.get('automatic_physics') is False and row.get('automatic_render') is False, 'uncontrolled simulation or collision')
        require(row.get('window') == size and row.get('readback') == size and row.get('visible') == [1152,648] and row.get('window_mode') == 0 and row.get('focused') is True, 'native window/readback/focus')
        require(row.get('fiducial') is True and row.get('foot_pixel') is True and near(row.get('stretch_scale'),[scale,scale]), 'GPU marker/scale')
        player = row['player']
        require(near(player,player), 'nonfinite physics')
        require(abs(row['minutes']-(720+(frame//2)/30))<1e-5, 'world clock changed with render phase')
        if frame == 0: require(near(player,previous), 'prepared start differs')
        elif not physical_step: require(player == rows[i-1]['player'] and row['physical_walk_clock'] == rows[i-1]['physical_walk_clock'], 'render phase changed physics or animation clock')
        else: require(0 <= player[1]-previous[1] <= 0.601 and math.dist(player,previous) <= 0.601, 'teleport/invalid physical step')
        if stage == 0:
            require(near(player,[562.25+(frame//2)*18/math.sqrt(2)/30,672.25+(frame//2)*18/math.sqrt(2)/30],0.01), 'physical trajectory differs')
        expected = player if legacy else [previous[j]+(player[j]-previous[j])*alpha for j in range(2)]
        require(near(row.get('previous'),player if legacy else previous) and near(row.get('ground'),expected) and near(row.get('foot_world'),expected), 'displayed foot phase mismatch')
        # Остановка сбрасывает цикл ног: runtime не интерполирует часы назад через весь цикл.
        start_clock = min(previous_clock,row['physical_walk_clock'])
        clock = row['physical_walk_clock'] if legacy else start_clock+(row['physical_walk_clock']-start_clock)*alpha
        require(math.isfinite(clock) and abs(row['walk_clock']-clock)<1e-5, 'animation phase mismatch')
        camera = [max(0,min(1248,expected[0]-576)),max(0,min(720,expected[1]-324))]
        require(near(row.get('camera'),camera) and near(row.get('background'),[-x for x in camera]), 'camera/background phase mismatch')
        require(near(row.get('foot_canvas'),[expected[j]-camera[j] for j in range(2)]), 'foot projection mismatch')
        root = [586.25 if stage == 0 else 84.25,704.25]
        offset = [expected[j]-root[j] for j in range(2)]
        contact = [v/72 for v in offset] if math.hypot(*offset)<72 else [0,0]
        require(row.get('radius') == 72 and near(row.get('root'),root) and near(row.get('root_canvas'),[root[j]-camera[j] for j in range(2)]), 'root detached from world')
        require(near(row.get('contact'),contact) and near(row.get('shader_contact'),contact), 'root shader uses a different hero phase')
        pointer = [600+(-0.125 if frame%2 == 0 else 0.125),696.125] if stage == 0 else [[0.125,23.875,24.125][frame%3],720.125]
        canvas = [pointer[j]-camera[j] for j in range(2)]
        require(near(row.get('pointer_world'),pointer) and near(row.get('pointer_canvas'),canvas) and near(row.get('pointer_received'),canvas), 'pointer inverse mismatch')
        require(near(row.get('pointer_window'),[x*scale for x in canvas]), 'extra DPI transform')
        cell = [math.floor(x/24) for x in pointer]
        require(row.get('pointer_cell') == cell and near(row.get('cell_origin_canvas'),[cell[j]*24-camera[j] for j in range(2)]), 'interaction cell drift')
    # При 30 Hz последний допустимый x находится в пределах одного шага до стены x=40.
    require(40 <= rows[-1]['player'][0]<40+18/math.sqrt(2)/30 and rows[179]['camera'][0]>20, 'edge/follow not reached')
    steps = [rows[i]['camera'][1]-rows[i-1]['camera'][1] for i in range(91,180)]
    return {'stalled_steps':sum(abs(x)<1e-6 for x in steps),'max_step_logical':max(steps),
            'step_range_logical':max(steps)-min(steps),'max_physical_visual_distance':max(math.dist(r['player'],r['ground']) for r in rows)}


def verify(folder):
    """Checks exact source/artifact coverage, actual media and independent paired physics."""
    source = read(folder/'source.json')
    require(source.get('task') == 'VCAMERA-003' and source.get('complete') is True and source.get('performance_eligible') is False, 'incomplete provenance')
    require(set(source.get('sources',{})) == set(SOURCES), 'source coverage')
    for name,digest in source['sources'].items(): require(sha(folder/'instrumentation'/name) == digest,'source hash: '+name)
    files = {str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name != 'source.json' and 'instrumentation' not in p.parts}
    require(files == set(source['artifacts']), 'artifact coverage')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and sha(folder/name) == digest,'artifact hash: '+name)
    collectors = collector_sources(folder,source)
    metrics,profiles,pids = {},[],[]
    for case,size in CASES.items():
        pair = []
        for mode,legacy in MODES.items():
            name = case+'-'+mode; path = folder/name; data = read(path/'capture.json')
            metrics[name] = validate_run(data,size,legacy,case == 'retina-2x')
            pair.append(data['frames']); profiles.append(data['profile']); pids.append(data['pid'])
            env = read(path/'environment.json')
            require(env.get('collector_sha256',source['sources']['tools/presentation_pose.py']) in collectors,'unknown collector source')
            require(env['exit_code'] == 0 and '--headless' not in env['command'] and 'ERROR:' not in (path/'engine.txt').read_text(), 'native launch/engine error')
            video = read(path/'walk.json')
            require([video['width'],video['height']] == size and video['frames'] == 360 and video['fps'] == 60 and abs(video['duration']-6)<0.01,'video metadata')
            require((path/'walk.mp4').read_bytes()[4:8] == b'ftyp' and (path/'walk.mp4').stat().st_size < 8*1024*1024,'bounded MP4 required')
            for frame in [0,180,359]:
                image = Image.open(path/('frame-%04d.png'%frame)).convert('RGB')
                require(list(image.size) == size,'PNG dimensions')
                require(sum(abs(a-b) for a,b in zip(image.getpixel((round(20*scale_for(size)),round(164*scale_for(size)))),[255,0,255]))<10,'PNG fiducial')
            first = Image.open(path/'frame-0000.png').convert('RGB'); decoded = Image.open(path/'walk.decoded.png').convert('RGB')
            require(decoded.size == first.size and sum(ImageStat.Stat(ImageChops.difference(first,decoded)).mean)/3<6,'decoded video content/orientation')
        require(all(a['player'] == b['player'] and a['minutes'] == b['minutes'] and a['physical_walk_clock'] == b['physical_walk_clock'] and near(a['pointer_world'],b['pointer_world']) for a,b in zip(*pair)),'paired physics or input differs')
        require(metrics[case+'-physical']['stalled_steps']>35 and metrics[case+'-shared']['stalled_steps'] == 0,'control must expose and candidate remove temporal stalls')
    require(len(set(profiles)) == 6 and len(set(pids)) == 6,'six independent native runs required')
    return metrics


def scale_for(size):
    """Returns the single logical-to-framebuffer transform."""
    return size[0]/1152


def collector_sources(folder, source):
    """Accepts only archived collectors covered by the packet artifact manifest."""
    allowed={source['sources']['tools/presentation_pose.py']}
    for item in source.get('resume_tools',[]):
        path=Path(item['path'])
        require(not path.is_absolute() and '..' not in path.parts and len(path.parts)==2 and path.parts[0]=='collection-tools','unsafe resume collector path')
        require(source['artifacts'].get(str(path))==item['sha256'] and sha(folder/path)==item['sha256'],'resume collector source hash')
        allowed.add(item['sha256'])
    return allowed


@contextmanager
def recording_scratch():
    """Preserves immutable raw frames on failure instead of losing an expensive GPU recording."""
    folder=Path(tempfile.mkdtemp(prefix='farm-pose-'))
    try: yield folder
    except BaseException:
        print('RAW_CAPTURE_RETAINED '+str(folder),flush=True)
        raise
    else: shutil.rmtree(folder)


def capture(folder, resume=False):
    """Records six focused GPU series, retaining raw traces and exact instrumentation."""
    collector_digest=sha(Path(__file__))
    if resume:
        source=read(folder/'source.json')
        require(source.get('task') == 'VCAMERA-003' and source.get('complete') is False,'only the same incomplete task may resume')
        require(set(source['sources']) == set(SOURCES),'resumed source coverage')
        for p,digest in source['sources'].items():
            require(sha(folder/'instrumentation'/p) == digest,'original source changed: '+p)
            if p != 'tools/presentation_pose.py': require(sha(current_source(ROOT, p)) == digest,'runtime/instrumentation changed; new packet required: '+p)
        collector_sources(folder,source)
        # Reusing a completed clip must never re-sign damaged evidence as a fresh success.
        for case in CASES:
            for mode in MODES:
                name=case+'-'+mode
                if not (folder/name/'walk.json').is_file(): continue
                for artifact,digest in source['artifacts'].items():
                    if artifact.startswith(name+'/'):
                        require('..' not in Path(artifact).parts and sha(folder/artifact)==digest,'completed artifact changed: '+artifact)
        tool=folder/'collection-tools'/(collector_digest+'.py'); tool.parent.mkdir(exist_ok=True); shutil.copy2(__file__,tool)
        source.setdefault('resume_tools',[]).append({'path':str(tool.relative_to(folder)),'sha256':sha(tool)})
    else:
        require(not folder.exists(),'fresh output required'); folder.mkdir(parents=True)
        source = {'schema':1,'task':'VCAMERA-003','complete':False,'performance_eligible':False,
            'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip(),
            'sources':{p:sha(current_source(ROOT, p)) for p in SOURCES},'artifacts':{}}
        for p in SOURCES:
            target=folder/'instrumentation'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(current_source(ROOT, p),target)
    manifest(folder,source)
    with recording_scratch() as raw:
        temporary=Path(raw)
        for case,size in CASES.items():
            for mode,legacy in MODES.items():
                name=case+'-'+mode; target=folder/name
                if resume and (target/'walk.json').is_file():
                    validate_run(read(target/'capture.json'),size,legacy,case == 'retina-2x')
                    video=read(target/'walk.json')
                    require(video['frames']==360 and [video['width'],video['height']]==size and (target/'walk.decoded.png').is_file(),'incomplete existing video')
                    print('REUSE_COMPLETE '+name,flush=True); continue
                require(not target.exists(),'incomplete case must be preserved separately before retry: '+name)
                print('CAPTURE '+name,flush=True)
                target.mkdir(); native=temporary/name
                args=['--path',str(ROOT),'--windowed','--audio-driver','Dummy','--log-file',str(target/'engine.txt'),
                      '--script','res://tools/qa/camera/presentation_pose_capture.gd','--','--output='+str(native),
                      '--profile=Codex-VCAMERA-003-'+uuid.uuid4().hex,'--size=%dx%d'%tuple(size)]
                if legacy: args.append('--legacy')
                launch=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args',*args]
                with (target/'stdout.txt').open('w') as log: result=subprocess.run(launch,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600)
                (target/'environment.json').write_text(json.dumps({'command':launch,'exit_code':result.returncode,'collector_sha256':collector_digest,'exit_code_scope':'LaunchServices; engine completion checked in capture.json'},indent=2)+'\n')
                if (native/'capture.json').exists(): shutil.copy2(native/'capture.json',target/'capture.json')
                for frame in [0,180,359]:
                    if (native/('frames/%04d.png'%frame)).exists(): shutil.copy2(native/('frames/%04d.png'%frame),target/('frame-%04d.png'%frame))
                manifest(folder,source)
                require(result.returncode == 0 and (target/'engine.txt').is_file() and 'ERROR:' not in (target/'engine.txt').read_text(),'native launch/engine error: '+name)
                validate_run(read(target/'capture.json'),size,legacy,case == 'retina-2x')
                environment=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(temporary/'clang-cache'),SWIFT_MODULECACHE_PATH=str(temporary/'swift-cache'))
                with (target/'encoder.txt').open('w') as log:
                    subprocess.run(['swift',str(input_path(ROOT,'tools/encode_coordinate_video.swift')),str(native/'frames'),str(target/'walk.mp4'),'60','4000000'],env=environment,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=240)
                shutil.rmtree(native); manifest(folder,source)
    source['complete']=True; manifest(folder,source)
    metrics=verify(folder); (folder.parent/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    print('VALID_PRESENTATION_POSE',flush=True)


def main():
    """Collects new evidence or validates the frozen packet offline."""
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('command',choices=['capture','resume','verify'])
    parser.add_argument('--output',type=Path,default=REPORT/'native'); args=parser.parse_args()
    try:
        if args.command in ['capture','resume']: capture(args.output.resolve(),args.command == 'resume')
        else: print(json.dumps(verify(args.output.resolve()),indent=2))
    except (OSError,ValueError,KeyError,TypeError) as error: raise SystemExit(str(error)) from error


if __name__ == '__main__': main()

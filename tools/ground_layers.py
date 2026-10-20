#!/usr/bin/env python3
"""VRENDER-003: native static/live separation evidence, independent of physical FPS acceptance."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import uuid
from PIL import Image,ImageChops
from perf_contract_collect import ROOT,context,jobs,command,sha,write,native_pid
from grass_methods import require,image_difference
from render_order import validate_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vrender-003'
OVERLAY=['scripts/world_background.gd','scripts/presentation/village_terrain_canvas.gd','scripts/presentation/village_ground_layer.gd',
 'scripts/presentation/village_ground_clock.gd','scripts/systems/village_terrain_renderer.gd','scripts/systems/village_ambient_renderer.gd',
 'scripts/systems/water_visual_system.gd','scripts/core/game_loop.gd','scripts/presentation/terrain_cutout.gdshader','project.godot']
SOURCES=OVERLAY+['main.tscn','scripts/game_core.gd','scripts/systems/world_projection_system.gd','scripts/presentation/visual_reference_mode.gd',
 'tools/visual_camera_points.gd','tools/render_order_game.gd','tools/ground_layers_capture.gd','tools/ground_layers_review.gd','tools/ground_layers.py',
 'tools/perf_contract_collect.py','tests/suites/ground_layers_suite.gd']
NEW={'scripts/presentation/village_ground_layer.gd','scripts/presentation/village_ground_clock.gd','scripts/presentation/terrain_cutout.gdshader','tools/ground_layers_capture.gd',
 'tools/ground_layers_review.gd','tools/ground_layers.py','tests/suites/ground_layers_suite.gd'}
PAIRS=['village','tree-behind','tree-front','bush','bridge-west','bridge-east','winter','rain','manual-pause','interior','returned']
EXTRA=['cold-reference','direct-fallback','direct-return','water-white','water-tinted','live-zero','live-five','live-paused','live-resumed']


def load(path):
    """Loads one explicit evidence document without changing native artifacts."""
    return json.loads(Path(path).read_text())


def base_bytes(commit,name):
    """Reads the exact historical Git source rather than the evolving current checkout."""
    return subprocess.check_output(['git','show',commit+':'+name],cwd=ROOT)


def collect(folder):
    """Collects two fresh native processes, archiving the reviewed overlay and complete raw draws."""
    require(not folder.exists() and not jobs(),'fresh output and no other Godot required')
    changed=set(command(['git','diff','HEAD','--name-only','--','scripts','assets/game','main.tscn']).splitlines())
    require(changed<=set(OVERLAY)|{p+'.uid' for p in OVERLAY},'unrelated runtime changes')
    folder.mkdir(parents=True)
    source={'task':'VRENDER-003','schema':1,'base_commit':command(['git','rev-parse','HEAD']),'complete':False,
        'sources':{p:sha(ROOT/p) for p in SOURCES},'base_sources':{},'artifacts':{}}
    for name in SOURCES:
        target=folder/'inputs'/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)
        if name not in NEW: source['base_sources'][name]=hashlib.sha256(base_bytes(source['base_commit'],name)).hexdigest()
    write(folder/'source.json',source)
    for width in [1152,1280]:
        require(not jobs(),'another Godot appeared')
        target=folder/str(width); target.mkdir(); profile='Codex-VRENDER-003-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
            '--log-file',str(target/'engine.txt'),'--script','res://tools/ground_layers_capture.gd','--','--output='+str(target/'native'),'--profile='+profile]
        if width==1280: args.append('--wide')
        print('GROUND NATIVE '+str(width),flush=True); before=context()
        with (target/'stdout.txt').open('w') as stream:
            child=subprocess.Popen(args,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
            try: code=child.wait(timeout=180)
            except subprocess.TimeoutExpired:
                pid=native_pid(profile)
                if pid and '--profile='+profile in command(['ps','-o','command=','-p',str(pid)]): os.kill(pid,signal.SIGTERM)
                child.terminate(); child.wait(timeout=10)
                raise ValueError('own native process timed out')
        write(target/'environment.json',{'command':args,'exit_code':code,'profile':profile,'before':before,'after':context(),'jobs_after':jobs()})
        if (target/'native').exists():
            for path in (target/'native').iterdir(): shutil.move(str(path),target/path.name)
            (target/'native').rmdir()
        for path in target.glob('*-draws.json'):
            with gzip.GzipFile(str(path)+'.gz','wb',mtime=0) as stream: stream.write(path.read_bytes())
            path.unlink()
        require(code==0,'native process failed')
        require(all(sha(ROOT/p)==digest for p,digest in source['sources'].items()),'frozen sources changed')
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
        write(folder/'source.json',source)
    source['complete']=True; write(folder/'source.json',source)


def provenance(folder):
    """Checks historical base, exact overlay bytes and complete Git-tracked native artifacts."""
    source=load(folder/'source.json'); require(source.get('complete') is True and source.get('task')=='VRENDER-003','incomplete collection')
    require(set(source['sources'])==set(SOURCES) and set(source['base_sources'])==set(SOURCES)-NEW,'source coverage')
    for name,digest in source['sources'].items():
        require((folder/'inputs'/name).resolve().is_relative_to(folder.resolve()) and sha(folder/'inputs'/name)==digest,'archived input changed')
        if name not in NEW:
            historical=hashlib.sha256(base_bytes(source['base_commit'],name)).hexdigest()
            require(historical==source['base_sources'][name],'Git base changed')
            if name not in OVERLAY: require(historical==digest,'unreviewed input differs from Git base')
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'inputs' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts and (folder/name).resolve().is_relative_to(folder.resolve()),'artifact path escapes')
        require(sha(folder/name)==digest,'artifact changed')
    if folder.resolve()==(REPORT/'native').resolve():
        paths=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*paths],cwd=ROOT,capture_output=True).returncode==0,'native proof absent from Git index')
    return source


def state(row):
    """Keeps node ownership, visibility, one viewport and retained/static coverage independently testable."""
    active=row['location']=='overworld'
    require(row['child_viewports']==1 and row['ready'] and row['viewport_mode']==0,'cache/viewport ownership differs')
    require(row['surface_behind_parent'] and row['cover_inside_cache'] and row['cutout_before_cover'],'water covers bridge/fence pass')
    require(row['cutout_visible']==row['cover_visible'],'water cutout visibility differs')
    require(row['cover_visible']==(active and row['split']) and row['surface_visible']==(active and row['split'] and row['ready'] and not row['direct']),'layer visibility/leak/double draw')
    if active: require(row['base_only']==row['split'] and row['viewport_size']==[2400,1368],'cache contains wrong coverage')
    return row


def hot_loop(data):
    """Three hundred real callbacks may change decorative time but never rebuild the retained ground."""
    require(data['callbacks']==300 and data['performance_eligible'] is False,'hot loop truncated or mislabelled')
    a,b=state(data['before']),state(data['after'])
    for key in ['requests','base_paints','surface_paints','cover_paints','cutout_paints']: require(a[key]==b[key],'clock rebuilt ground commands')
    require(data['cache_before']==data['cache_after'] and len(data['cache_before'])==64,'clock changed static texture')
    require(abs(b['time']-a['time']-5.0)<.0001,'decorative phase not actually advancing')


def opaque_hud(first,second,width):
    """Opaque HUD interiors must remain exact, independently of one-level water quantization."""
    with Image.open(first) as a,Image.open(second) as b:
        for box in [(30,24,220,73),(325,597,825,633)]:
            rect=tuple(round(v*width/1152) for v in box)
            diff=ImageChops.difference(a.convert('RGB').crop(rect),b.convert('RGB').crop(rect))
            require(max(p[1] for p in diff.getextrema())==0,'opaque HUD changed')


def cold_draws(values):
    """A single first-frame witness stays one real draw, with full state/geometry checks rather than duplicated rows."""
    require(len(values)==1,'cold draw missing')
    row=values[0]
    require(row['before']==row['after'] and row['equal'] is True,'cold draw mutated saved gameplay')
    require(row['geometry_before']==row['geometry_after'] and row['geometry_equal'] is True,'cold draw mutated geometry')
    require(row['queue_after']==0,'cold draw left foreground queue')


def image_quality(metric):
    """Allows only one RGBA8 quantization step across the complete compared framebuffer."""
    require(metric['mean_channel_error']<=.1 and metric['max_channel_error']<=1,'split image exceeds single-step quantization tolerance')


def cold_image_quality(metric):
    """Both first-frame and reference use the same direct path, so even one changed channel is invalid."""
    require(metric['max_channel_error']==0,'cold first frame differs from complete direct reference')


def verify(folder=REPORT/'native'):
    """Verifies complete native frames, full state purity and real cache invariants; no FPS inference."""
    source=provenance(folder); result={'task':'VRENDER-003','accepted':True,'frames':0,'draws':0,'comparisons':{},'controls':{},
        'live_gameplay_fps_accepted':False,'whole_map_accepted':False,'new_water_art_accepted':False,'gpu_time_ms':None}
    expected=[p+'-'+mode for p in PAIRS for mode in ['legacy','split']]+EXTRA
    profiles=[]; pids=[]
    for width,height in [(1152,648),(1280,720)]:
        target=folder/str(width); data=load(target/'capture.json'); env=load(target/'environment.json')
        require(data['task']=='VRENDER-003' and data['window']==[width,height] and data['display_server']=='macOS' and not data['errors'],'native capture rejected')
        require(data['simulation_frozen'] is True and data['performance_eligible'] is False,'diagnostic capture claims performance')
        require(env['exit_code']==0 and not env['jobs_after'] and env['profile']==data['profile'] and '--headless' not in env['command'],'native process/profile differs')
        require('ERROR:' not in (target/'engine.txt').read_text() and 'SCRIPT ERROR' not in (target/'engine.txt').read_text(),'native engine error')
        require([r['id'] for r in data['records']]==expected,'native matrix incomplete'); profiles.append(data['profile']); pids.append(data['pid'])
        for row in data['records']:
            state(row); require(row['readback']==[width,height] and row['logical']==[1152,648] and row['draws']==4,'actual viewport/draw count differs')
            with Image.open(target/(row['id']+'.png')) as image: require(image.size==(width,height),'PNG size differs'); image.verify()
            with gzip.open(target/(row['id']+'-draws.json.gz'),'rt') as stream: draws=json.load(stream)
            validate_draws(draws); require(len(draws)==4,'raw draws missing'); result['frames']+=1; result['draws']+=len(draws)
        for pair in PAIRS:
            legacy=next(r for r in data['records'] if r['id']==pair+'-legacy'); split=next(r for r in data['records'] if r['id']==pair+'-split')
            require(all(legacy[k]==split[k] for k in ['camera','player','location','season','weather','pause']),'pair composition changed')
            metric=image_difference(target/(pair+'-legacy.png'),target/(pair+'-split.png')); result['comparisons'][f'{width}/{pair}']=metric
            image_quality(metric)
            opaque_hud(target/(pair+'-legacy.png'),target/(pair+'-split.png'),width)
        cold=load(target/'cold.json')
        require(not cold['before']['ready'] and not cold['before']['surface_visible'] and cold['draws']==1 and cold['readback']==[width,height],'cold fallback admission')
        state(cold['after'])
        with gzip.open(target/'cold-first-draws.json.gz','rt') as stream: draws=json.load(stream)
        cold_draws(draws); result['frames']+=1; result['draws']+=1
        with Image.open(target/'cold-first.png') as image: require(image.size==(width,height),'cold readback'); image.verify()
        cold_metric=image_difference(target/'cold-first.png',target/'cold-reference.png'); cold_image_quality(cold_metric)
        hot_loop(load(target/'hot-loop.json'))
        rows={r['id']:r for r in data['records']}
        historical=base_bytes(source['base_commit'],f'docs/reports/visual-overhaul/vrender-001/native/{width}/village-baseline.png')
        with Image.open(io.BytesIO(historical)) as old,Image.open(target/'village-legacy.png') as current:
            require(old.size==current.size and ImageChops.difference(old.convert('RGB'),current.convert('RGB')).getbbox() is None,'legacy control differs from pinned historical scene')
        require(image_difference(target/'direct-return.png',target/'winter-split.png')['max_channel_error']==0,'direct fallback return corrupted cached coverage')
        require(rows['live-five']['time']==rows['live-paused']['time'] and rows['live-paused']['pause'],'pause phase advanced')
        require(abs(rows['live-resumed']['time']-rows['live-five']['time']-.25)<.0001,'resume catch-up')
        result['controls'][str(width)]={'cold_first_frame':cold_metric,'water':image_difference(target/'water-white.png',target/'water-tinted.png'),
            'motion':image_difference(target/'live-zero.png',target/'live-five.png'),
            'legacy_draw_calls':rows['village-legacy']['draw_calls'],'split_draw_calls':rows['village-split']['draw_calls']}
        require(result['controls'][str(width)]['water']['changed_pixels']>100 and result['controls'][str(width)]['motion']['changed_pixels']>5,'surface/motion control did not visibly change')
        rect=tuple(round(v*width/1152) for v in (395,505,470,570))
        with Image.open(target/'live-zero.png') as a,Image.open(target/'live-five.png') as b:
            require(ImageChops.difference(a.convert('RGB').crop(rect),b.convert('RGB').crop(rect)).getbbox() is not None,'existing reeds ROI did not move')
        result['controls'][str(width)]['live_reeds_roi']=list(rect)
        opaque_hud(target/'water-white.png',target/'water-tinted.png',width)
        probe=rows['water-white']; scale=width/1152*1.2
        point=(round((probe['player'][0]-8-probe['camera'][0])*scale),round((probe['player'][1]+52-probe['camera'][1])*scale))
        bridge=base_bytes(source['base_commit'],'assets/game/locations/overworld/modular/bridge_modular_v1.png')
        with Image.open(io.BytesIO(bridge)) as image: require(image.convert('RGBA').getpixel((64,160))[3]==255,'bridge probe is not actually opaque')
        with Image.open(target/'water-white.png') as a,Image.open(target/'water-tinted.png') as b:
            require(a.convert('RGB').getpixel(point)==b.convert('RGB').getpixel(point),'surface tint leaked above opaque bridge deck')
        result['controls'][str(width)]['opaque_bridge_probe']=list(point)
    require(len(set(profiles))==len(set(pids))==2,'native processes not independent')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('mode',choices=['capture','verify']); parser.add_argument('--output',type=Path); args=parser.parse_args()
    if args.mode=='capture': require(args.output is not None,'fresh output required'); collect(args.output.resolve())
    else:
        result=verify(args.output or REPORT/'native')
        if not args.output and (REPORT/'summary.json').exists(): require(load(REPORT/'summary.json')==result,'published summary differs from native evidence')
        print(json.dumps(result,indent=2))

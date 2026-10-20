#!/usr/bin/env python3
"""Read-only VRENDER-002 evidence analysis. Frozen visual microbenchmarks never accept live gameplay FPS."""
from __future__ import annotations
import argparse
import csv
import gzip
import hashlib
import json
import math
import re
from pathlib import Path
import statistics
import subprocess
from PIL import Image,ImageChops,ImageStat
from grass_compare_collect import ROOT,FROZEN,schedule,sha
from perf_contract import distribution,validate_environment,cpu_seconds
from render_order import validate_draws

REPORT=ROOT/'docs/reports/visual-overhaul/vrender-002'
FIELDS=['usec','interval_ms','update_ms','engine_frame_ms','draw_calls','static_bytes','texture_bytes','wind_time','camera_x','camera_y','focused','window_x','window_y','modal']
RENDER_FIELDS=['usec','interval_ms','render_frame','process_frame']
METHODS=['cpu','items','batch']
CASES=['phase-0','phase-1','phase-2','tree','bush','bridge','pause','interior','returned']
OVERLAY={'project.godot','tools/grass_compare_collect.py',*[p for p in FROZEN if p.startswith('tools/grass_compare/')]}


def require(condition,message):
    """Rejects incomplete evidence without truncating a run or re-signing its contents."""
    if not condition: raise ValueError(message)


def read(path):
    """Loads an explicit report document."""
    return json.loads(Path(path).read_text())


def zipped(path):
    """Preserves all raw snapshots from the native draw observer."""
    with gzip.open(path,'rt') as stream: return json.load(stream)


def rows(path,fields):
    """Rejects changed schemas or non-finite data, never discarding outliers."""
    with gzip.open(path,'rt') as stream:
        reader=csv.DictReader(stream); require(reader.fieldnames==fields,'raw schema changed')
        result=[{key:float(value) for key,value in row.items()} for row in reader]
    require(all(all(math.isfinite(value) for value in row.values()) for row in result),'non-finite raw observation')
    return result


def provenance(folder,mode):
    """Checks the immutable archived overlay and tracked production inputs against the captured Git base."""
    source=read(folder/'source.json')
    require(source.get('complete') is True and source.get('task')=='VRENDER-002' and source.get('mode')==mode and source.get('schedule')==schedule(mode),'incomplete collection/schedule')
    require(set(source['sources'])==set(FROZEN),'source coverage')
    require(subprocess.run(['git','cat-file','-e',source['base_commit']+'^{commit}'],cwd=ROOT,capture_output=True).returncode==0,'Git base absent')
    for name,digest in source['sources'].items():
        require((folder/'instrumentation'/name).resolve().is_relative_to(folder.resolve()),'source symlink escapes')
        require(sha(folder/'instrumentation'/name)==digest,'archived source changed: '+name)
        if name not in OVERLAY:
            require(hashlib.sha256(subprocess.check_output(['git','show',source['base_commit']+':'+name],cwd=ROOT)).hexdigest()==digest,'production/reference differs from Git base: '+name)
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts,'artifact path escapes')
        require((folder/name).resolve().is_relative_to(folder.resolve()),'artifact symlink escapes')
        require(sha(folder/name)==digest,'artifact changed: '+name)
    if folder.resolve() in [(REPORT/name).resolve() for name in ['quality','bench','cpu-only']]:
        paths=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','ls-files','--error-unmatch','--',*paths],cwd=ROOT,capture_output=True).returncode==0,'native evidence missing from Git index')
    return source


def launch(target,profile):
    """Rejects engine errors, headless fallback or a mismatched fresh-profile launch."""
    env=read(target/'environment.json'); command=env['command']; log=(target/'engine.txt').read_text()
    require(env['exit_code']==0 and env['jobs_after']==[] and env['profile']==profile and profile.startswith('Codex-VRENDER-002-'),'native launch/profile failed')
    require('--headless' not in command and 'res://tools/grass_compare/capture.gd' in command,'wrong launch')
    require('ERROR:' not in log and 'SCRIPT ERROR' not in log,'native engine error')
    return env


def image_difference(first,second):
    """Measures the entire decoded RGB frame; no region or tail is hidden from method comparisons."""
    with Image.open(first) as a,Image.open(second) as b:
        require(a.size==b.size,'comparison dimensions changed')
        diff=ImageChops.difference(a.convert('RGB'),b.convert('RGB'))
        red,green,blue=diff.split(); maximum=ImageChops.lighter(red,ImageChops.lighter(green,blue))
        return {'mean_channel_error':sum(ImageStat.Stat(diff).mean)/3,'max_channel_error':max(p[1] for p in diff.getextrema()),
            'changed_pixels':diff.width*diff.height-maximum.histogram()[0]}


def statistics_shape(stats,method,count):
    """The three measured structures differ only in geometry submission and deformation ownership."""
    expected=0 if method=='none' else (count if method=='items' else math.ceil(count/64))
    require(stats['method']==method and stats['roots']==count and stats['canvas_items']==expected and stats['mesh_builds']==expected,'geometry structure/count differs')
    require(stats['input_array_bytes']==(0 if method=='none' else count*816),'input geometry payload differs')
    require((stats['vertex_updates']>0 and stats['cpu_upload_bytes']>0) if method=='cpu' else (stats['vertex_updates']==stats['cpu_upload_bytes']==0),'unexpected CPU vertex upload')


def quality_row(row,width,height,draws):
    """Checks actual route/uniform/state facts, independently of image-hash assertions."""
    method,case=row['id'].split('-',1); stats=row['statistics']
    require(method in METHODS and case in CASES,'unknown quality case'); statistics_shape(stats,method,256)
    require(row['size']==[width,height] and row['logical']==[1152,648],'quality host/logical size differs')
    require(row['location']==('cottage_interior' if case=='interior' else 'overworld') and row['visible']==(case!='interior'),'map lifecycle/visibility differs')
    require(row['pause']==(case=='pause') and abs(row['shader_time']-stats['wind_time'])<1e-5,'pause/uniform clock mismatch')
    if case.startswith('phase-'): require(stats['wind_time']==[0,1.25,3.5][int(case[-1])],'controlled phase differs')
    validate_draws(draws); require(len(draws)==row['draws'],'draw snapshot count differs')
    return len(draws)


def quality(folder=REPORT/'quality'):
    """Admits native phase/route comparisons while leaving complete wind/contact/map release open."""
    source=provenance(folder,'quality'); result={'frames':0,'draws':0,'comparisons':{},'motion':{},'hud_controls':{}}; profiles=[]; pids=[]
    require(not re.search(r'\bTIME\b',(folder/'instrumentation/tools/grass_compare/wind.gdshader').read_text()),'shader uses non-pausing TIME')
    expected=[method+'-'+case for method in METHODS for case in CASES]
    for width,height in [(1152,648),(1280,720)]:
        target=folder/str(width); data=read(target/'quality.json'); launch(target,data['profile'])
        require(data['display_server']=='macOS' and data['performance_eligible'] is False and not data['errors'],'quality capture failed or mislabelled')
        require(data['size']==[width,height] and [row['id'] for row in data['results']]==expected,'quality matrix incomplete')
        profiles.append(data['profile']); pids.append(data['pid'])
        for row in data['results']:
            draws=zipped(target/(row['id']+'-draws.json.gz')); result['draws']+=quality_row(row,width,height,draws)
            with Image.open(target/(row['id']+'.png')) as image: require(image.size==(width,height),'PNG readback mismatch'); image.verify()
            result['frames']+=1
        for case in CASES:
            if case=='pause': continue # Real-time start phase differs between variants; actual freeze is separately checked in native code/uniform records.
            for method in ['items','batch']:
                metric=image_difference(target/('cpu-'+case+'.png'),target/(method+'-'+case+'.png'))
                require(metric['mean_channel_error']<=.1 and metric['max_channel_error']<=8,'method image mismatch: '+str(width)+'/'+method+'/'+case)
                result['comparisons'][str(width)+'/'+method+'/'+case]=metric
        for method in METHODS:
            metric=image_difference(target/(method+'-phase-0.png'),target/(method+'-phase-1.png'))
            require(metric['changed_pixels']>=100,'shader/CPU phase did not move the image')
            result['motion'][str(width)+'/'+method]=metric['changed_pixels']
        reference=REPORT/'controls'/(str(width)+'.png')
        original=f'docs/reports/visual-overhaul/vrender-001/native/{width}/village-baseline.png'
        require(hashlib.sha256(subprocess.check_output(['git','show',source['base_commit']+':'+original],cwd=ROOT)).hexdigest()==sha(reference),'HUD reference differs from Git base')
        # Opaque HUD interiors, avoiding panel edges that intentionally reveal the world through alpha.
        scale=width/1152; boxes=[(30,24,220,73),(325,597,825,633)]
        with Image.open(reference) as baseline:
            for method in METHODS:
                with Image.open(target/(method+'-phase-1.png')) as frame:
                    for index,box in enumerate(boxes):
                        region=tuple(round(v*scale) for v in box)
                        diff=ImageChops.difference(frame.convert('RGB').crop(region),baseline.convert('RGB').crop(region))
                        maximum=max(v[1] for v in diff.getextrema())
                        require(maximum==0,'opaque HUD changed under grass shader')
                        result['hud_controls'][f'{width}/{method}/{index}']=maximum
    require(len(set(profiles))==len(set(pids))==2,'quality processes not independent')
    return {'task':'VRENDER-002','quality_accepted':True,'live_gameplay_fps_accepted':False,'full_foliage_contact_accepted':False,**result}


def external_metrics(env,data):
    """Twenty-second probes require at least three independent OS samples; RSS is not VRAM or a peak guarantee."""
    samples=[]
    for row in env['rss_cpu_samples']:
        require(row['other_godot_pids']==[] and math.isfinite(row['utc']),'competing engine/unknown OS timestamp')
        if not data['started_utc']<=row['utc']<=data['ended_utc']: continue
        fields=row['raw'].split()
        require(len(fields)==4 and int(fields[0])==data['pid']==row['pid'],'wrong process CPU/RSS')
        value={'utc':row['utc'],'rss':int(fields[1])*1024,'cpu':cpu_seconds(fields[2])}
        require(value['rss']>0 and math.isfinite(value['cpu']) and value['cpu']>=0,'OS memory/CPU unavailable'); samples.append(value)
    require(len(samples)>=3,'OS sample coverage too short')
    require(all(b['utc']>a['utc'] and b['cpu']>=a['cpu'] for a,b in zip(samples,samples[1:])),'OS sample clock order')
    first,last=samples[0],samples[-1]
    return {'samples':len(samples),'rss_first':first['rss'],'rss_last':last['rss'],'rss_max':max(s['rss'] for s in samples),
        'cpu_percent_one_core':100*(last['cpu']-first['cpu'])/(last['utc']-first['utc'])}


def validate_rows(data,values,rendered):
    """Keeps idle/render/CPU update distinct and verifies native conditions on every observed callback."""
    require(data['seconds']==20 and data['simulation_frozen'] is True and data['gpu_time_ms'] is None,'wrong duration/scope/GPU inference')
    require(data['vsync']==1 and data['max_fps']==0 and data['display_server']=='macOS' and data['driver']=='opengl3' and not data['errors'],'native pacing/admission failed')
    require(data['readback']==[1152,648] and data['focused'] is True and math.dist(data['camera'],[120.25,430.25])<.001,'final host/focus/camera differs')
    require(data['observer_buffer_bytes']==1728000,'observer allocation differs')
    require(len(values)==data['samples'] and len(values)>60 and len(rendered)==data['render_samples'] and len(rendered)>60,'raw trace truncated')
    for i,row in enumerate(values):
        require(row['interval_ms']>0 and row['update_ms']>=0 and row['engine_frame_ms']>=0 and row['draw_calls']>0 and row['static_bytes']>0 and row['texture_bytes']>0,'invalid frame/counter')
        require(row['focused']==1 and row['window_x']==1152 and row['window_y']==648 and row['modal']==0 and math.dist([row['camera_x'],row['camera_y']],[120.25,430.25])<.001,'mid-run conditions changed')
        if i:
            require(abs((row['usec']-values[i-1]['usec'])/1000-row['interval_ms'])<.002 and row['wind_time']>=values[i-1]['wind_time'],'idle clock order')
    for i,row in enumerate(rendered):
        require(row['interval_ms']>0,'invalid render interval')
        if i:
            previous=rendered[i-1]
            require(abs((row['usec']-previous['usec'])/1000-row['interval_ms'])<.002 and row['render_frame']==previous['render_frame']+1 and row['process_frame']>=previous['process_frame'],'render clock/counter order')
    duration=sum(row['interval_ms'] for row in values)/1000
    require(20<=duration<25 and 19<=sum(row['interval_ms'] for row in rendered)/1000<25,'run shortened/stalled')
    require(10<values[-1]['wind_time']-values[0]['wind_time']<25,'visual clock not advancing')
    require(abs(data['ended_utc']-data['started_utc']-duration)<2,'system clock shifted')
    return {'seconds':duration,'frames':len(values),'render_frames':len(rendered),
        'idle_ms':distribution([row['interval_ms'] for row in values]),'render_interval_ms':distribution([row['interval_ms'] for row in rendered]),
        'update_ms':distribution([row['update_ms'] for row in values]),'engine_frame_ms':distribution([row['engine_frame_ms'] for row in values]),
        'draw_calls':distribution([row['draw_calls'] for row in values]),'static_bytes_max':max(row['static_bytes'] for row in values),
        'texture_counter_max':max(row['texture_bytes'] for row in values),'statistics':data['statistics'],'gpu_time_ms':None}


def benchmark(folder=REPORT/'bench',mode='bench'):
    """Compares all three repeats/densities with their controls; absolute game/release FPS is never granted."""
    source=provenance(folder,mode); policy=read(folder/'instrumentation/docs/reports/visual-overhaul/vbase-002/profile.json')
    device=next(d for d in policy['devices'] if d['id']==policy['selected_device'])
    profiles=[]; pids=[]; powers=[]; metrics={}; root_sets={}
    for item in source['schedule']:
        target=folder/item['name']; data=read(target/'run.json'); env=launch(target,data['profile'])
        require(data['task']=='VRENDER-002' and data['method']==item['method'] and data['count']==item['count'] and data['pid']==env['pid'],'method/density/process mismatch')
        powers.append(validate_environment(env,data,device)); profiles.append(data['profile']); pids.append(data['pid'])
        states=zipped(target/'states.json.gz'); require(states['before']==states['after'],'effect benchmark mutated saved gameplay')
        geometry=read(target/'geometry.json'); roots=geometry['roots']; require(len(roots)==item['count'] and len({tuple(p) for p in roots})==item['count'],'root count/uniqueness differs')
        if item['count'] not in root_sets: root_sets[item['count']]=roots
        require(root_sets[item['count']]==roots,'method/repeat used different roots')
        statistics_shape(data['statistics'],item['method'],item['count'])
        metric=validate_rows(data,rows(target/'rows.csv.gz',FIELDS),rows(target/'render.csv.gz',RENDER_FIELDS))
        metric['process']=external_metrics(env,data); metric['build_usec']=geometry['statistics']['build_usec']; metrics[item['name']]=metric
        for name in ['before.png','after.png']:
            with Image.open(target/name) as image: require(image.size==(1152,648),'GPU witness size'); image.verify()
    require(len(set(profiles))==len(set(pids))==len(schedule(mode)) and len(set(powers))==1,'independent runs or single power profile missing')
    aggregate={}
    for count in [256,1024]:
        aggregate[str(count)]={}
        for method in (['cpu'] if mode=='cpu-only' else ['none',*METHODS]):
            values=[metrics[f'r{repeat}-{count}-{method}'] for repeat in [1,2,3]]
            aggregate[str(count)][method]={'update_p95_median_ms':statistics.median(v['update_ms']['p95'] for v in values),
                'update_p95_range_ms':[min(v['update_ms']['p95'] for v in values),max(v['update_ms']['p95'] for v in values)],
                'render_p95_median_ms':statistics.median(v['render_interval_ms']['p95'] for v in values),
                'draw_calls_p50_median':statistics.median(v['draw_calls']['p50'] for v in values),
                'rss_max_observed':max(v['process']['rss_max'] for v in values),'build_usec_median':statistics.median(v['build_usec'] for v in values)}
            aggregate[str(count)][method]['cpu_percent_one_core_median']=statistics.median(v['process']['cpu_percent_one_core'] for v in values)
    return {'task':'VRENDER-002','microbenchmark_accepted':True,'live_gameplay_fps_accepted':False,'gpu_time_ms':None,
        'power_source':powers[0],'run_count':len(metrics),'runs':metrics,'aggregate':aggregate}


def combined():
    """Uses the remeasured CPU comparator, keeping the first implementation as explicit history."""
    q=quality(); b=benchmark(); cpu=benchmark(REPORT/'cpu-only','cpu-only')
    old=read(REPORT/'bench/source.json'); optimized=read(REPORT/'cpu-only/source.json'); visual=read(REPORT/'quality/source.json')
    require(old['base_commit']==optimized['base_commit']==visual['base_commit'],'experiment Git bases differ')
    require(optimized['sources']==visual['sources'],'final quality does not cover optimized inputs')
    changed={name for name in old['sources'] if old['sources'][name]!=optimized['sources'][name]}
    require(changed=={'tools/grass_compare/mesh_data.gd','tools/grass_compare_collect.py'},'unrelated implementation changes between cost series')
    old_data=(REPORT/'bench/instrumentation/tools/grass_compare/mesh_data.gd').read_text()
    new_data=(REPORT/'cpu-only/instrumentation/tools/grass_compare/mesh_data.gd').read_text()
    require(old_data.split('static func deform(')[0]==new_data.split('static func deform(')[0]
        and old_data.split('static func mesh(')[1]==new_data.split('static func mesh(')[1],'CPU optimization changed root generation/topology')
    require(b['power_source']==cpu['power_source'],'CPU rerun used another power profile')
    for count in [256,1024]:
        original=read(REPORT/f'bench/r1-{count}-cpu/geometry.json')['roots']
        for repeat in [1,2,3]: require(read(REPORT/f'cpu-only/r{repeat}-{count}-cpu/geometry.json')['roots']==original,'optimized CPU used other roots')
    final=copy_aggregate(b['aggregate'],cpu['aggregate'])
    return {'task':'VRENDER-002','accepted':True,'chosen':'batch','reason':'same accepted image, lower total CPU and far fewer CanvasItems/draw calls at stress density; no live-FPS claim',
        'quality':q,'original_cost':b,'optimized_cpu_cost':cpu,'decision_cost':final,
        'live_gameplay_fps_accepted':False,'gpu_time_ms':None,'whole_map_accepted':False}


def copy_aggregate(original,cpu):
    """Labels exactly which implementation supplies each final table cell; it does not average incompatible sources."""
    result=json.loads(json.dumps(original))
    for count in ['256','1024']:
        result[count]['cpu_original']=result[count]['cpu']
        result[count]['cpu']=cpu[count]['cpu']
        result[count]['cpu']['source']='cpu-only; invariant weights moved outside plant loop'
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('mode',choices=['quality','bench','cpu-only','all']); parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    if args.mode=='all':
        result=combined()
        if (REPORT/'summary.json').exists(): require(read(REPORT/'summary.json')==result,'published summary differs from raw evidence')
    elif args.mode=='quality': result=quality(args.output) if args.output else quality()
    else: result=benchmark(args.output or (REPORT/('cpu-only' if args.mode=='cpu-only' else 'bench')),args.mode)
    print(json.dumps(result,indent=2))

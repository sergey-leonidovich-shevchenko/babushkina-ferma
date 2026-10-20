#!/usr/bin/env python3
"""Validate VPERF-001 protocol evidence without turning an observation into a release FPS gate."""
from __future__ import annotations
import argparse
import csv
import gzip
import json
import math
import re
from pathlib import Path
import statistics
import subprocess
from PIL import Image
from perf_contract_collect import ROOT, FROZEN, sha

REPORT=ROOT/'docs/reports/visual-overhaul/vperf-001'
FIELDS=['usec','interval_ms','engine_frame_ms','engine_physics_ms','callback_span_ms','draw_calls','static_bytes','texture_bytes',
        'process_frame','physics_frame','absolute_minutes','camera_x','camera_y','focused','window_x','window_y','modal','maintenance_cycles']
SCHEDULE=[['repeat-1',30,''],['repeat-2',30,''],['repeat-3',30,''],['long-cycle',600,'']]


def require(condition,message):
    """Invalid or missing evidence is rejected instead of silently shortened."""
    if not condition: raise ValueError(message)


def read(path):
    """Reads explicit report documents; no runtime or user saves are opened."""
    return json.loads(Path(path).read_text())


def quantile(values,fraction):
    """Linear interpolation uses every interval, including the worst hitch."""
    values=sorted(values); rank=(len(values)-1)*fraction; lo=math.floor(rank); hi=math.ceil(rank)
    return values[lo]+(values[hi]-values[lo])*(rank-lo)


def distribution(values):
    """Keeps p50/p95/p99/max distinct; does not infer GPU time or CPU usage."""
    return {'p50':statistics.median(values),'p95':quantile(values,.95),'p99':quantile(values,.99),'max':max(values)}


def rows(path,fields=FIELDS):
    """Loads all compressed raw observations; a changed header is a schema error."""
    with gzip.open(path,'rt') as stream:
        reader=csv.DictReader(stream); require(reader.fieldnames==fields,'raw schema mismatch')
        return [{k:float(v) for k,v in row.items()} for row in reader]


def validate_run(data,values,seconds):
    """Admits matching native dimensions/focus/live simulation; keeps unavailable GPU values null."""
    require(data.get('schema')==1 and data.get('task')=='VPERF-001' and data.get('fault')=='','native protocol metadata')
    require(data.get('display_server')=='macOS' and data.get('driver')=='opengl3','native driver required')
    require(not data.get('errors') and data.get('seconds')==seconds,'incomplete or rejected sample')
    require(data.get('vsync')==1 and data.get('physics_hz')==60 and data.get('max_fps')==0,'VSync/physics/pacing differs')
    require(data.get('zoom')==1.2 and data.get('hud_zoom')==1 and abs(data['field'][0]-960)<.001 and abs(data['field'][1]-540)<.001,'projection differs')
    require(data.get('warmup_frames')==120 and data.get('readback_during_samples') is False and data.get('manual_simulation') is False and data.get('disk_io_during_samples') is False,'instrumentation interval contaminated')
    require(data.get('observer_buffer_bytes')==15840000,'observer memory reservation differs')
    require(data.get('gpu_time_ms') is None and 'unavailable' in data.get('gpu_time_status',''),'GPU time unavailable; cannot derive it from CPU')
    require(data.get('profile','').startswith('Codex-VPERF-001-') and data.get('reduced_motion') is True and data.get('audio_enabled') is False,'isolated settings differ')
    for stamp in ['initial','final']:
        state=data[stamp]
        require(all(state[k]==[1152,648] for k in ['window','root','readback','visible']),'host/framebuffer mismatch')
        require(state['focused'] is True and state['mode']==0,'native focus/window mode')
        require(math.dist(state['camera'],[120.25,430.25])<.001,'comparison camera differs')
    require(len(values)==data.get('samples') and len(values)>seconds*5,'raw count/truncated run')
    for index,row in enumerate(values):
        require(set(row)==set(FIELDS) and all(math.isfinite(v) for v in row.values()),'non-finite raw observation')
        require(row['interval_ms']>0 and row['draw_calls']>0 and row['static_bytes']>0,'interval/draws/memory unavailable')
        require(all(row[k]>=0 for k in ['engine_frame_ms','engine_physics_ms','callback_span_ms','texture_bytes']),'negative engine counter')
        require(row['focused']==1 and row['window_x']==1152 and row['window_y']==648 and row['modal']==0,'per-frame native conditions')
        require(math.dist([row['camera_x'],row['camera_y']],[120.25,430.25])<.001,'per-frame camera differs')
        if index:
            prev=values[index-1]
            require(abs((row['usec']-prev['usec'])/1000-row['interval_ms'])<.002,'clock interval differs')
            require(row['process_frame']==prev['process_frame']+1 and row['physics_frame']>=prev['physics_frame'] and row['absolute_minutes']>=prev['absolute_minutes'],'frame/world order')
    duration=sum(r['interval_ms'] for r in values)/1000
    require(seconds<=duration<seconds+5,'duration truncated or stalled')
    require(values[-1]['physics_frame']-values[0]['physics_frame']>=seconds*20 and values[-1]['absolute_minutes']-values[0]['absolute_minutes']>=seconds*.5,'world is not live')
    metrics={k:distribution([r[k] for r in values]) for k in ['interval_ms','engine_frame_ms','engine_physics_ms','callback_span_ms','draw_calls']}
    metrics.update(seconds=duration,frames=len(values),static_bytes={'first':values[0]['static_bytes'],'last':values[-1]['static_bytes'],'max':max(r['static_bytes'] for r in values)},
        texture_bytes_max=max(r['texture_bytes'] for r in values),maintenance_cycles=values[-1]['maintenance_cycles']-values[0]['maintenance_cycles'],gpu_time_ms=None)
    return metrics


def validate_render(data,values,seconds):
    """Validates actual rendering boundaries independently from idle loop frequency and GPU execution time."""
    require(data.get('render_boundary','').startswith('RenderingServer.frame_post_draw;'),'real render boundary required')
    require(len(values)==data.get('render_samples') and len(values)>seconds*5,'render sample count/incomplete')
    for i,row in enumerate(values):
        require(set(row)=={'usec','interval_ms','render_frame','process_frame'} and all(math.isfinite(v) for v in row.values()),'invalid render observation')
        require(row['interval_ms']>0,'nonpositive render interval')
        if i:
            previous=values[i-1]
            require(abs((row['usec']-previous['usec'])/1000-row['interval_ms'])<.002,'render clock interval differs')
            require(row['render_frame']==previous['render_frame']+1 and row['process_frame']>=previous['process_frame'],'render frame order')
    duration=sum(r['interval_ms'] for r in values)/1000
    require(seconds-1<=duration<seconds+5,'render duration truncated/stalled')
    return {'frames':len(values),'seconds':duration,'interval_ms':distribution([r['interval_ms'] for r in values])}


def cpu_seconds(value):
    """Parses ps cumulative process CPU time, separately from monotonic frame intervals."""
    parts=[float(p) for p in value.split(':')]
    require(len(parts) in [2,3],'unsupported ps CPU time')
    return sum(v*60**i for i,v in enumerate(reversed(parts)))


def process_samples(environment,data):
    """Uses only external samples within the measured UTC boundaries, preserving RSS and CPU meanings."""
    admitted=[]
    for sample in environment['rss_cpu_samples']:
        require(sample.get('other_godot_pids')==[],'competing Godot during sampling')
        require(math.isfinite(sample['utc']),'external timestamp unavailable')
        if not data['started_utc']<=sample['utc']<=data['ended_utc']: continue
        fields=sample['raw'].split(); require(len(fields)==4 and int(fields[0])==data['pid']==sample['pid'],'RSS/CPU process mismatch')
        value={'utc':sample['utc'],'rss_bytes':int(fields[1])*1024,'cpu_seconds':cpu_seconds(fields[2]),'ps_cpu_percent':float(fields[3])}
        require(value['rss_bytes']>0 and value['cpu_seconds']>=0 and math.isfinite(value['ps_cpu_percent']) and value['ps_cpu_percent']>=0,'external CPU/RSS invalid')
        admitted.append(value)
    require(len(admitted)>=4,'external RSS/CPU samples missing')
    require(all(b['utc']>a['utc'] and b['cpu_seconds']>=a['cpu_seconds'] for a,b in zip(admitted,admitted[1:])),'external CPU clock order')
    first,last=admitted[0],admitted[-1]
    return {'samples':len(admitted),'rss_first':first['rss_bytes'],'rss_last':last['rss_bytes'],'rss_max':max(r['rss_bytes'] for r in admitted),
        'cpu_seconds_delta':last['cpu_seconds']-first['cpu_seconds'],'wall_seconds':last['utc']-first['utc'],
        'cpu_percent_of_one_core':100*(last['cpu_seconds']-first['cpu_seconds'])/(last['utc']-first['utc'])}


def provenance(folder,schedule,complete_required=True):
    """Checks all artifacts and the archived collector overlay tied to an existing immutable Git base."""
    source=read(folder/'source.json')
    require(isinstance(source.get('complete'),bool) and (source['complete'] or not complete_required)
        and source.get('schedule')==schedule and source.get('task')=='VPERF-001','collection incomplete/schedule mismatch')
    require(subprocess.run(['git','-C',str(ROOT),'cat-file','-e',source['base_commit']+'^{commit}'],capture_output=True).returncode==0,'Git base missing')
    require(set(source['sources'])==set(FROZEN),'collector source coverage')
    for name,digest in source['sources'].items(): require(sha(folder/'instrumentation'/name)==digest,'collector archive changed: '+name)
    actual={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    require(actual==set(source['artifacts']),'artifact coverage differs')
    for name,digest in source['artifacts'].items():
        require(not Path(name).is_absolute() and '..' not in Path(name).parts,'artifact path escapes')
        require(sha(folder/name)==digest,'artifact hash changed: '+name)
    return source


def validate_environment(env,data,device):
    """Binds the available machine and active power settings; AC and battery never mix in one series."""
    powers=[]
    require(data.get('adapter')==device['adapter'] and data.get('engine')==device['engine'],'reference adapter/engine differs')
    for name in ['before','after']:
        ctx=env[name]
        require(not any('UNAVAILABLE' in str(ctx[k]) for k in ['power','power_settings','thermal']),'environment unavailable')
        hardware=ctx['hardware']
        require(all(hardware[k]==device[k] for k in ['system','os_version','architecture','machine']),'reference machine differs')
        power=ctx['power'].splitlines()[0]; powers.append(power)
        require(power in ["Now drawing from 'AC Power'","Now drawing from 'Battery Power'"],'unknown power source')
        mode='AC Power' if "'AC Power'" in power else 'Battery Power'
        settings=ctx['power_settings'].split(mode+':',1)[1].split('Power:',1)[0]
        for key,value in [('lowpowermode','0'),('gpuswitch','2')]:
            require(re.search(r'(?m)^\s*'+key+r'\s+'+value+r'\s*$',settings),'active power setting differs')
        limits=re.findall(r'CPU_(?:Scheduler|Speed)_Limit\s*=\s*(\d+)',ctx['thermal'])
        require(limits and all(int(v)==100 for v in limits),'thermal boundary throttling/unknown')
    powers.extend(s['power_source'] for s in env['rss_cpu_samples'])
    require(len(set(powers))==1,'power changed during run')
    return powers[0]


def inspect_run(target,seconds,device):
    """Checks one native run identically for audit and complete-series verification."""
    data=read(target/'run.json'); env=read(target/'environment.json')
    require(env['exit_code']==0 and env['profile']==data['profile'] and env['pid']==data['pid'] and not env['jobs_after'],'launch or competing job')
    log=(target/'engine.txt').read_text()
    require('ERROR:' not in log and 'SCRIPT ERROR' not in log,'engine error')
    command=env['command']; require('--headless' not in command and '--script' in command and 'res://tools/perf_contract_capture.gd' in command,'wrong launch')
    power=validate_environment(env,data,device)
    metric=validate_run(data,rows(target/'rows.csv.gz'),seconds); metric['process']=process_samples(env,data)
    metric['render']=validate_render(data,rows(target/'render-rows.csv.gz',['usec','interval_ms','render_frame','process_frame']),seconds)
    require(abs((data['ended_utc']-data['started_utc'])-metric['seconds'])<2,'system clock shifted')
    for frame in ['before.png','after.png']:
        with Image.open(target/frame) as im: require(im.size==(1152,648),'GPU witness size differs'); im.verify()
    return data,power,metric


def audit(folder):
    """Classifies signed partial evidence; this path never grants contract or release acceptance."""
    source=provenance(folder,SCHEDULE,False)
    policy=read(folder/'instrumentation/docs/reports/visual-overhaul/vbase-002/profile.json')
    device=next(d for d in policy['devices'] if d['id']==policy['selected_device'])
    classified={}; counts={'valid':0,'rejected':0,'missing':0}
    for name,seconds,_ in SCHEDULE:
        if not (folder/name/'run.json').is_file():
            classified[name]={'classification':'missing'}; counts['missing']+=1; continue
        try: data,power,metric=inspect_run(folder/name,seconds,device)
        except (OSError,ValueError,KeyError,TypeError) as error:
            classified[name]={'classification':'rejected','reason':str(error)}; counts['rejected']+=1; continue
        classified[name]={'classification':'valid individual run','power_source':power,'metrics':metric}; counts['valid']+=1
    return {'task':'VPERF-001','source_complete':source['complete'],'acceptance_granted':False,
        'release_fps_accepted':False,'classification':'offline audit, not full contract acceptance','counts':counts,'runs':classified}


def verify(folder):
    """Accepts the measurement contract only; absolute FPS, leak plateau and pilot cost remain open."""
    source=provenance(folder,SCHEDULE); result={}; powers=[]; profiles=[]; pids=[]
    policy=read(folder/'instrumentation/docs/reports/visual-overhaul/vbase-002/profile.json')
    device=next(d for d in policy['devices'] if d['id']==policy['selected_device'])
    if folder.resolve()==(REPORT/'native').resolve():
        paths=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','-C',str(ROOT),'ls-files','--error-unmatch','--',*paths],capture_output=True).returncode==0,'required evidence not in Git index')
    for name,seconds,_ in SCHEDULE:
        data,power,metric=inspect_run(folder/name,seconds,device); powers.append(power)
        result[name]=metric; profiles.append(data['profile']); pids.append(data['pid'])
    require(len(set(profiles))==4 and len(set(pids))==4,'independent processes required')
    require(len(set(powers))==1,'compared power source differs')
    long_rows=rows(folder/'long-cycle/rows.csv.gz'); first_usec=long_rows[0]['usec']
    long_render=rows(folder/'long-cycle/render-rows.csv.gz',['usec','interval_ms','render_frame','process_frame'])
    windows=[]
    for i in range(10):
        section=[r for r in long_rows if i*60<=(r['usec']-first_usec)/1e6<(i+1)*60]
        require(section,'long cycle missing minute')
        windows.append({'minute':i+1,'frames':len(section),'interval_ms':distribution([r['interval_ms'] for r in section]),
            'render_interval_ms':distribution([r['interval_ms'] for r in long_render if i*60<=(r['usec']-first_usec)/1e6<(i+1)*60]),
            'static_bytes_last':section[-1]['static_bytes'],'draw_calls':distribution([r['draw_calls'] for r in section])})
    return {'task':'VPERF-001','contract_accepted':True,'release_fps_accepted':False,'leak_plateau_accepted':False,'gpu_time_ms':None,
        'base_commit':source['base_commit'],'power_source':powers[0],'runs':result,'long_cycle_minutes':windows,
        'repeat_p95_median_ms':statistics.median(result['repeat-'+str(i)]['render']['interval_ms']['p95'] for i in [1,2,3])}


def verify_controls(folder):
    """Requires two actual native denials; synthetic mutation tests do not replace them."""
    provenance(folder,[['resize',30,'resize'],['pause',30,'pause']])
    if folder.resolve()==(REPORT/'controls').resolve():
        paths=[str(p.relative_to(ROOT)) for p in folder.rglob('*') if p.is_file()]
        require(subprocess.run(['git','-C',str(ROOT),'ls-files','--error-unmatch','--',*paths],capture_output=True).returncode==0,'required controls not in Git index')
    for name,fault in [('resize','resize'),('pause','pause')]:
        env=read(folder/name/'environment.json')
        require('--fault='+fault in env['command'] and 'res://tools/perf_contract_capture.gd' in env['command'],'wrong native control launch')
        log=(folder/name/'engine.txt').read_text()
        require(not env['jobs_after'] and 'SCRIPT ERROR' not in log and 'ERROR:' not in log,'control failed to execute')
    resize=read(folder/'resize/rejected.json')['initial']
    require(resize['window']==[960,540] and resize['readback']==[960,540],'actual host-window mismatch missing')
    pause=read(folder/'pause/run.json'); values=rows(folder/'pause/rows.csv.gz')
    require(pause['fault']=='pause' and pause['errors'] and any(r['modal']==1 for r in values),'actual pause denial missing')
    require(len(values)<100 and pause['seconds']==30,'pause was measured as a complete run')
    try: validate_run(pause,values,30)
    except ValueError: return {'resize':'rejected: requested host/framebuffer mismatch','pause':'rejected: actual modal state'}
    raise ValueError('paused sample admitted')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--output',type=Path,default=REPORT/'native')
    mode=p.add_mutually_exclusive_group(); mode.add_argument('--controls',action='store_true'); mode.add_argument('--audit',action='store_true'); args=p.parse_args()
    action=verify_controls if args.controls else audit if args.audit else verify
    print(json.dumps(action(args.output.resolve()),indent=2))

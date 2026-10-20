#!/usr/bin/env python3
"""Native live timing for VCAMERA-006; no fixed steps, screenshots or tests during samples."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import shutil
import statistics
import subprocess
import uuid
from PIL import Image
import reference_zoom as Z

ROOT=Z.ROOT
REPORT=Z.REPORT
SOURCES=Z.SOURCES+['tools/reference_zoom_live.gd','tools/reference_zoom_perf.py']
REPEATS=3


def percentile(values, fraction):
    """Uses linear interpolation over the complete recorded sample set."""
    ordered=sorted(values); rank=(len(ordered)-1)*fraction; lo=math.floor(rank); hi=math.ceil(rank)
    return ordered[lo]+(ordered[hi]-ordered[lo])*(rank-lo)


def validate_run(data, size, amount):
    """Rejects headless, paused/static, resized, unfocused and manually advanced runs."""
    Z.require(data.get('task')=='VCAMERA-006' and data.get('kind')=='zoom-live-timing' and data.get('performance_eligible') is True,'live native timing required')
    Z.require(data.get('gpu_readback_during_samples') is False and data.get('manual_simulation') is False,'capture/manual clocks cannot measure cost')
    Z.require(data.get('display_server')=='macOS' and data.get('renderer')=='opengl3' and not data.get('errors'),'native driver/errors')
    Z.require(data.get('zoom')==amount and data.get('world_zoom')==amount and data.get('hud_zoom')==1.0 and data.get('requested')==size,'projection/format changed')
    Z.require(data.get('profile','').startswith('Codex-VCAMERA-006-') and data.get('physics_hz')==60 and data.get('vsync_mode')==1,'isolated 60 Hz physics and observed VSync required')
    Z.require(data.get('warmup_frames')==120 and data.get('sample_frames')==240,'warmup/sample schedule differs')
    Z.require(data.get('initial')=={'window':size,'root':size,'readback':size,'focused':True,'mode':0},'initial window/readback/focus')
    Z.require(data.get('final')=={'window':size,'readback':size,'focused':True,'mode':0},'final window/readback/focus')
    if size==[2304,1296]: Z.require(data.get('hidpi') is True and data.get('screen_scale',0)>=2,'Retina not observed')
    Z.require(Z.near(data.get('field'),[1152/amount,648/amount]),'field differs')
    rows=data.get('samples',[]); Z.require(len(rows)==240,'incomplete live sample')
    for index,row in enumerate(rows):
        Z.require(row.get('index')==index and row.get('focused') is True and row.get('mode')==0 and row.get('window')==size and row.get('visible')==[1152,648],'per-frame native conditions')
        Z.require(row.get('automatic_physics') is True and row.get('automatic_render') is True and row.get('paused') is False and row.get('location')=='overworld','automatic unpaused gameplay required')
        Z.require(math.isfinite(row['interval_ms']) and row['interval_ms']>0 and row['draw_calls']>0 and row['static_bytes']>0,'clock/draws/memory not observed')
        Z.require(0<=row['interpolation']<=1,'invalid interpolation fraction')
        field=[1152/amount,648/amount]; ground=row['ground']
        camera=[max(0,min(2400-field[0],ground[0]-field[0]/2)),max(0,min(1368-field[1],ground[1]-field[1]/2))]
        Z.require(Z.near(row['camera'],camera),'live camera/foot projection differs')
        if index:
            previous=rows[index-1]
            Z.require(row['process_frame']==previous['process_frame']+1 and row['physics_frame']>=previous['physics_frame'],'frame order')
            Z.require(abs((row['usec']-previous['usec'])/1000-row['interval_ms'])<0.002,'wall clock interval differs')
            Z.require(row['minutes']>=previous['minutes'],'world time went backwards')
    Z.require(rows[-1]['physics_frame']-rows[0]['physics_frame']>=30 and rows[-1]['minutes']>rows[0]['minutes'] and math.dist(rows[0]['player'],rows[-1]['player'])>5,'static world is not live timing')
    values=[r['interval_ms'] for r in rows]
    result={'median_ms':statistics.median(values),'p95_ms':percentile(values,.95),'p99_ms':percentile(values,.99),'max_ms':max(values),
            'sample_seconds':sum(values)/1000,'draw_calls_median':statistics.median(r['draw_calls'] for r in rows),
            'static_bytes_max':max(r['static_bytes'] for r in rows),'texture_bytes_max':max(r['texture_bytes'] for r in rows)}
    result['budget_60fps_candidate']='PASS' if result['p95_ms']<=18.5 and result['p99_ms']<=33.333 and result['max_ms']<=100 else 'FAIL'
    return result


def competing_jobs():
    """Observes other Godot jobs; never kills or edits another chat's process."""
    lines=subprocess.check_output(['ps','-axo','pid=,command='],text=True).splitlines()
    jobs=[line.strip() for line in lines if '/Godot ' in line or line.strip().split(' ',1)[-1].startswith('tools/Godot.app')]
    return jobs


def require_no_tests(jobs):
    """Blocks overlapping long test/capture jobs instead of presenting their interference as FPS."""
    blocked=['test_game.gd','reference_zoom_review.gd','reference_zoom_capture.gd','visual_baseline.gd','reference_zoom_live.gd']
    Z.require(not any(any(name in job for name in blocked) for job in jobs),'another test/capture/timing job is active')


def power_state():
    """Records actual power context without changing system preferences."""
    return subprocess.check_output(['pmset','-g','batt'],text=True).strip()


def verify(folder):
    """Validates complete provenance and all eighteen real runs before computing the zoom decision."""
    source=Z.read(folder/'source.json')
    Z.require(source.get('task')=='VCAMERA-006' and source.get('complete') is True and source.get('kind')=='zoom-live-timing','incomplete live provenance')
    Z.require(set(source.get('sources',{}))==set(SOURCES),'live source coverage')
    archived={str(p.relative_to(folder/'instrumentation')) for p in (folder/'instrumentation').rglob('*') if p.is_file()}
    Z.require(archived==set(SOURCES),'unexpected archived live source')
    for name,digest in source['sources'].items(): Z.require(Z.sha(folder/'instrumentation'/name)==digest,'live source hash: '+name)
    files={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    Z.require(files==set(source['artifacts']),'live artifact coverage')
    for name,digest in source['artifacts'].items(): Z.require(not Path(name).is_absolute() and '..' not in Path(name).parts and Z.sha(folder/name)==digest,'live artifact hash: '+name)
    profiles=[]; pids=[]; metrics={}; summary={}
    for case,size in Z.CASES.items():
        for mode,amount in Z.MODES.items():
            for repeat in range(REPEATS):
                name=f'{case}-{mode}-{repeat+1}'; path=folder/name; data=Z.read(path/'timing.json')
                metrics[name]=validate_run(data,size,amount); profiles.append(data['profile']); pids.append(data['pid'])
                env=Z.read(path/'environment.json')
                Z.require(env['exit_code']==0 and '--headless' not in env['command'] and 'ERROR:' not in (path/'engine.txt').read_text(),'live launch/engine error')
                require_no_tests(env['jobs_before']); require_no_tests(env['jobs_after'])
                Z.require(env['power_before'].splitlines()[0]==env['power_after'].splitlines()[0],'power source changed')
                if repeat==0:
                    with Image.open(path/'after-measurement.png') as image: Z.require(list(image.size)==size,'live post-sample GPU dimensions')
                else: Z.require(not (path/'after-measurement.png').exists(),'redundant repeat PNG should not inflate the evidence packet')
        control=[metrics[f'{case}-100-{r+1}']['p95_ms'] for r in range(REPEATS)]
        close=[metrics[f'{case}-120-{r+1}']['p95_ms'] for r in range(REPEATS)]
        a=statistics.median(control); b=statistics.median(close)
        summary[case]={'control_p95_median_ms':a,'close_p95_median_ms':b,'p95_ratio':b/a,'relative_guard':'PASS' if b<=a*1.15+.3 else 'FAIL',
            'rule':'median of 3 native p95; candidate <= control * 1.15 + 0.3 ms; independent from the unchanged absolute FPS budget'}
    Z.require(len(set(profiles))==18 and len(set(pids))==18,'eighteen independent native runs required')
    return {'runs':metrics,'comparison':summary,'absolute_budget':{'p95_ms':18.5,'p99_ms':33.333,'max_ms':100},'release_performance_accepted':False}


def capture(folder):
    """Runs matched native sessions serially, with no video/readback workload during measurements."""
    Z.verify(REPORT/'native')
    Z.require(not folder.exists(),'fresh live output required'); folder.mkdir(parents=True)
    source={'schema':1,'task':'VCAMERA-006','kind':'zoom-live-timing','complete':False,'performance_eligible':True,
        'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'video_provenance_sha256':Z.sha(REPORT/'native/source.json'),'sources':{p:Z.sha(ROOT/p) for p in SOURCES},'artifacts':{}}
    for p in SOURCES:
        target=folder/'instrumentation'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(ROOT/p,target)
    Z.manifest(folder,source)
    for case,size in Z.CASES.items():
        for repeat in range(REPEATS):
            modes=list(Z.MODES) if repeat%2==0 else list(reversed(Z.MODES))
            for mode in modes:
                name=f'{case}-{mode}-{repeat+1}'; print('LIVE '+name,flush=True); target=folder/name; target.mkdir()
                jobs_before=competing_jobs(); require_no_tests(jobs_before); power_before=power_state()
                for p,h in source['sources'].items(): Z.require(Z.sha(ROOT/p)==h,'source changed during live timing: '+p)
                launch=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
                    '--log-file',str(target/'engine.txt'),'--script','res://tools/reference_zoom_live.gd','--','--output='+str(target/'raw'),
                    '--profile=Codex-VCAMERA-006-Live-'+uuid.uuid4().hex,'--size=%dx%d'%tuple(size),'--zoom='+str(Z.MODES[mode])]
                with (target/'stdout.txt').open('w') as log: result=subprocess.run(launch,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=180)
                jobs_after=competing_jobs(); power_after=power_state()
                (target/'environment.json').write_text(json.dumps({'command':launch,'exit_code':result.returncode,'jobs_before':jobs_before,'jobs_after':jobs_after,'power_before':power_before,'power_after':power_after},indent=2)+'\n')
                if (target/'raw').exists():
                    for p in (target/'raw').iterdir(): shutil.move(str(p),str(target/p.name))
                    (target/'raw').rmdir()
                Z.manifest(folder,source)
                Z.require(result.returncode==0 and 'ERROR:' not in (target/'engine.txt').read_text(),'live launch/engine error: '+name)
                require_no_tests(jobs_after); Z.require(power_before.splitlines()[0]==power_after.splitlines()[0],'power source changed')
                validate_run(Z.read(target/'timing.json'),size,Z.MODES[mode])
                with Image.open(target/'after-measurement.png') as image: Z.require(list(image.size)==size,'post-sample GPU size')
                if repeat!=0: (target/'after-measurement.png').unlink()
                Z.manifest(folder,source)
    source['complete']=True; Z.manifest(folder,source)
    result=verify(folder); (folder.parent/'timing-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print('VALID_LIVE_ZOOM',flush=True)


def main():
    """Keeps collection and offline verification explicit and separate."""
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('command',choices=['capture','verify']); parser.add_argument('--output',type=Path,default=REPORT/'timing')
    args=parser.parse_args()
    try:
        if args.command=='capture': capture(args.output.resolve())
        else: print(json.dumps(verify(args.output.resolve()),indent=2))
    except (OSError,ValueError,KeyError,TypeError) as error: raise SystemExit(str(error)) from error


if __name__=='__main__': main()

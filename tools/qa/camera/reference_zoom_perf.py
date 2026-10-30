#!/usr/bin/env python3
"""Native live timing for VCAMERA-006; no fixed steps, screenshots or tests during samples."""
from __future__ import annotations
from tools.assets.contracts.source_paths import current_source, captured_paths, recorded_paths
import argparse
import json
import math
from pathlib import Path
import shutil
import statistics
import subprocess
from tools.common.git import git_environment
import uuid
from PIL import Image
from tools.qa.camera import reference_zoom as Z

ROOT=Z.ROOT
REPORT=Z.REPORT
SOURCES=Z.SOURCES+['tools/reference_zoom_live.gd','tools/reference_zoom_perf.py']
LEGACY_SOURCES=Z.LEGACY_SOURCES+['tools/reference_zoom_live.gd','tools/reference_zoom_perf.py']
REPEATS=3
_TIMING_PATHS = tuple(p for p in LEGACY_SOURCES if p.startswith('tools/') and p not in {'tools/visual_camera_points.gd', 'tools/encode_coordinate_video.swift'})


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
    """Blocks every observed competing Godot instance, without terminating another process."""
    Z.require(not jobs,'another test/capture/timing or Godot job is active')


def power_state():
    """Records actual power context without changing system preferences."""
    return subprocess.check_output(['pmset','-g','batt'],text=True).strip()


def provenance(folder, complete_required=True):
    """Checks frozen sources and every artifact even when collection was interrupted."""
    source=Z.read(folder/'source.json')
    Z.require(source.get('task')=='VCAMERA-006' and source.get('kind')=='zoom-live-timing' and source.get('performance_eligible') is True,'live provenance required')
    Z.require(isinstance(source.get('complete'),bool) and (not complete_required or source['complete']),'incomplete live provenance')
    schema=source.get('schema',1); Z.require(schema in [1,2],'unsupported live source schema')
    expected=LEGACY_SOURCES if schema==1 else SOURCES
    Z.require(set(source.get('sources',{}))==set(expected),'live source coverage')
    recorded_paths(_TIMING_PATHS, source.get('source_paths', {}))
    archived={str(p.relative_to(folder/'instrumentation')) for p in (folder/'instrumentation').rglob('*') if p.is_file()}
    Z.require(archived==set(expected),'unexpected archived live source')
    for name,digest in source['sources'].items(): Z.require(Z.sha(folder/'instrumentation'/name)==digest,'live source hash: '+name)
    files={str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
    Z.require(files==set(source['artifacts']),'live artifact coverage')
    for name,digest in source['artifacts'].items(): Z.require(not Path(name).is_absolute() and '..' not in Path(name).parts and Z.sha(folder/name)==digest,'live artifact hash: '+name)
    return source


def validate_environment(env, size, amount, profile, engine_log, source_paths=None):
    """Checks the real launch, isolation and power before admitting measured intervals."""
    paths = recorded_paths(_TIMING_PATHS, {} if source_paths is None else source_paths)
    script = 'res://' + paths.get('tools/reference_zoom_live.gd', 'tools/reference_zoom_live.gd')
    command=env.get('command',[])
    Z.require(env.get('exit_code')==0 and '--headless' not in command and 'ERROR:' not in engine_log,'live launch/engine error')
    Z.require(any(command[i:i+2]==['--script',script] for i in range(len(command)-1)),'live launch script differs')
    Z.require('--zoom='+str(amount) in command and '--size=%dx%d'%tuple(size) in command and '--profile='+profile in command,'live launch profile differs')
    require_no_tests(env['jobs_before']); require_no_tests(env['jobs_after'])
    before=env['power_before'].splitlines(); after=env['power_after'].splitlines()
    Z.require(before and after and before[0]==after[0],'power source changed')
    return before[0]


def validate_comparison_power(powers):
    """Prevents comparing individually stable AC and battery runs as one performance series."""
    Z.require(powers and len(set(powers))==1,'power source differs between compared runs')


def audit(folder):
    """Reports missing/rejected runs honestly; it never grants acceptance to a partial packet."""
    source=provenance(folder,False); runs={}; counts={'valid':0,'rejected':0,'missing':0}
    for case,size in Z.CASES.items():
        for mode,amount in Z.MODES.items():
            for repeat in range(REPEATS):
                name=f'{case}-{mode}-{repeat+1}'; path=folder/name
                if not (path/'timing.json').is_file():
                    runs[name]={'status':'missing'}; counts['missing']+=1; continue
                try:
                    data=Z.read(path/'timing.json'); metric=validate_run(data,size,amount)
                    power=validate_environment(Z.read(path/'environment.json'),size,amount,data['profile'],(path/'engine.txt').read_text(), source.get('source_paths', {}))
                    if repeat==0 or (path/'after-measurement.png').exists():
                        with Image.open(path/'after-measurement.png') as image:
                            Z.require(list(image.size)==size,'live post-sample GPU dimensions')
                except (OSError,ValueError,KeyError,TypeError,IndexError) as error:
                    runs[name]={'status':'rejected','reason':str(error)}; counts['rejected']+=1; continue
                runs[name]={'status':'valid','metrics':metric,'power_source':power}; counts['valid']+=1
    return {'task':'VCAMERA-006','source_complete':source['complete'],'acceptance_granted':False,
        'classification':'offline audit; not a completed timing acceptance','counts':counts,'runs':runs}


def verify(folder):
    """Validates complete provenance and all eighteen real runs before computing the zoom decision."""
    source=provenance(folder)
    profiles=[]; pids=[]; metrics={}; summary={}
    powers=[]
    for case,size in Z.CASES.items():
        for mode,amount in Z.MODES.items():
            for repeat in range(REPEATS):
                name=f'{case}-{mode}-{repeat+1}'; path=folder/name; data=Z.read(path/'timing.json')
                metrics[name]=validate_run(data,size,amount); profiles.append(data['profile']); pids.append(data['pid'])
                env=Z.read(path/'environment.json')
                powers.append(validate_environment(env,size,amount,data['profile'],(path/'engine.txt').read_text(), source.get('source_paths', {})))
                if repeat==0:
                    with Image.open(path/'after-measurement.png') as image: Z.require(list(image.size)==size,'live post-sample GPU dimensions')
                else: Z.require(not (path/'after-measurement.png').exists(),'redundant repeat PNG should not inflate the evidence packet')
        control=[metrics[f'{case}-100-{r+1}']['p95_ms'] for r in range(REPEATS)]
        close=[metrics[f'{case}-120-{r+1}']['p95_ms'] for r in range(REPEATS)]
        a=statistics.median(control); b=statistics.median(close)
        summary[case]={'control_p95_median_ms':a,'close_p95_median_ms':b,'p95_ratio':b/a,'relative_guard':'PASS' if b<=a*1.15+.3 else 'FAIL',
            'rule':'median of 3 native p95; candidate <= control * 1.15 + 0.3 ms; independent from the unchanged absolute FPS budget'}
    Z.require(len(set(profiles))==18 and len(set(pids))==18,'eighteen independent native runs required')
    validate_comparison_power(powers)
    return {'runs':metrics,'comparison':summary,'absolute_budget':{'p95_ms':18.5,'p99_ms':33.333,'max_ms':100},'release_performance_accepted':False}


def capture(folder):
    """Runs matched native sessions serially, with no video/readback workload during measurements."""
    Z.verify(REPORT/'native')
    Z.require(not folder.exists(),'fresh live output required'); folder.mkdir(parents=True)
    source={'schema':2,'task':'VCAMERA-006','kind':'zoom-live-timing','complete':False,'performance_eligible':True,
        'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True, env=git_environment()).strip(),
        'source_paths':captured_paths(_TIMING_PATHS),'video_provenance_sha256':Z.sha(REPORT/'native/source.json'),'sources':{p:Z.sha(current_source(ROOT, p)) for p in SOURCES},'artifacts':{}}
    for p in SOURCES:
        target=folder/'instrumentation'/p; target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(current_source(ROOT, p),target)
    Z.manifest(folder,source)
    for case,size in Z.CASES.items():
        for repeat in range(REPEATS):
            modes=list(Z.MODES) if repeat%2==0 else list(reversed(Z.MODES))
            for mode in modes:
                name=f'{case}-{mode}-{repeat+1}'; print('LIVE '+name,flush=True); target=folder/name; target.mkdir()
                jobs_before=competing_jobs(); require_no_tests(jobs_before); power_before=power_state()
                for p,h in source['sources'].items(): Z.require(Z.sha(current_source(ROOT, p))==h,'source changed during live timing: '+p)
                launch=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
                    '--log-file',str(target/'engine.txt'),'--script','res://tools/qa/camera/reference_zoom_live.gd','--','--output='+str(target/'raw'),
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
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('command',choices=['capture','verify','audit']); parser.add_argument('--output',type=Path,default=REPORT/'timing')
    args=parser.parse_args()
    try:
        if args.command=='capture': capture(args.output.resolve())
        else: print(json.dumps(audit(args.output.resolve()) if args.command=='audit' else verify(args.output.resolve()),indent=2))
    except (OSError,ValueError,KeyError,TypeError) as error: raise SystemExit(str(error)) from error


if __name__=='__main__': main()

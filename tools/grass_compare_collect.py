#!/usr/bin/env python3
"""Collect isolated VRENDER-002 quality frames or counter-ordered effect microbenchmarks."""
from __future__ import annotations
import argparse
import gzip
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time
import uuid
from perf_contract_collect import ROOT,context,command,jobs,native_pid,write,sha

FROZEN=['tools/grass_compare/mesh_data.gd','tools/grass_compare/field.gd','tools/grass_compare/wind.gdshader',
 'tools/grass_compare/capture.gd','tools/grass_compare/observer.gd','tools/grass_compare/review.gd',
 'tools/grass_compare_collect.py','tools/perf_contract_collect.py','tools/visual_camera_points.gd','tools/render_order_game.gd',
 'project.godot','main.tscn','scripts/systems/render_system.gd','scripts/systems/world_projection_system.gd',
 'docs/reports/visual-overhaul/vbase-002/profile.json','docs/reports/visual-overhaul/vart-008/modules.json',
 'docs/reports/visual-overhaul/vart-008/native/sprites/grass-low.png']


def schedule(mode):
    """Three repeats use different method/density order; no best-repeat selection or tail trimming."""
    if mode=='quality': return [{'name':str(width),'mode':'quality','method':'batch','count':256,'wide':width==1280} for width in [1152,1280]]
    if mode=='cpu-only': return [{'name':f'r{repeat}-{count}-cpu','mode':'bench','method':'cpu','count':count,'wide':False}
        for repeat in [1,2,3] for count in ([1024,256] if repeat==2 else [256,1024])]
    orders=[['cpu','items','batch','none'],['batch','none','cpu','items'],['items','cpu','none','batch']]
    return [{'name':f'r{repeat}-{count}-{method}','mode':'bench','method':method,'count':count,'wide':False}
        for repeat,order in enumerate(orders,1) for count in ([1024,256] if repeat==2 else [256,1024]) for method in order]


def collect(folder: Path, mode: str):
    """Archives exact inputs and all outputs, using only fresh profiles and serial native windows."""
    if folder.exists(): raise ValueError('fresh collection output required')
    if jobs(): raise ValueError('another Godot process active')
    if command(['git','diff','HEAD','--','scripts','assets/game','main.tscn']).strip(): raise ValueError('production differs from Git base')
    folder.mkdir(parents=True)
    source={'schema':1,'task':'VRENDER-002','mode':mode,'base_commit':command(['git','rev-parse','HEAD']),
        'complete':False,'schedule':schedule(mode),'sources':{name:sha(ROOT/name) for name in FROZEN},'artifacts':{}}
    for name in FROZEN:
        target=folder/'instrumentation'/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)
    write(folder/'source.json',source)
    for item in source['schedule']:
        if jobs(): raise ValueError('another Godot process appeared')
        if any(sha(ROOT/p)!=digest for p,digest in source['sources'].items()): raise ValueError('frozen inputs changed')
        target=folder/item['name']; target.mkdir(); profile='Codex-VRENDER-002-'+uuid.uuid4().hex
        args=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed','--audio-driver','Dummy',
            '--log-file',str(target/'engine.txt'),'--script','res://tools/grass_compare/capture.gd','--','--output='+str(target/'native'),
            '--profile='+profile,'--mode='+item['mode'],'--method='+item['method'],'--count='+str(item['count'])]
        if item['wide']: args.append('--wide')
        before=context(); samples=[]; pid=None; next_sample=0
        print('GRASS NATIVE '+item['name'],flush=True)
        with (target/'stdout.txt').open('w') as log:
            child=subprocess.Popen(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT); deadline=time.monotonic()+180
            while child.poll() is None:
                if time.monotonic()>deadline:
                    pid=pid or native_pid(profile)
                    if pid and '--profile='+profile in command(['ps','-o','command=','-p',str(pid)]): os.kill(pid,signal.SIGTERM)
                    child.terminate(); child.wait(timeout=10); raise ValueError('own isolated native launch timed out')
                if time.monotonic()>=next_sample:
                    pid=pid or native_pid(profile)
                    if pid:
                        samples.append({'utc':time.time(),'pid':pid,'raw':command(['ps','-o','pid=,rss=,time=,%cpu=','-p',str(pid)]),
                            'other_godot_pids':[line.split()[0] for line in jobs() if int(line.split()[0])!=pid],
                            'power_source':command(['pmset','-g','batt']).splitlines()[0]})
                    next_sample=time.monotonic()+5
                time.sleep(.25)
        write(target/'environment.json',{'command':args,'exit_code':child.returncode,'profile':profile,'pid':pid,
            'before':before,'after':context(),'jobs_after':jobs(),'rss_cpu_samples':samples})
        if (target/'native').exists():
            for p in (target/'native').iterdir(): shutil.move(str(p),target/p.name)
            (target/'native').rmdir()
        for pattern in ['*.csv','*-draws.json','states.json']:
            for path in target.glob(pattern):
                with gzip.GzipFile(str(path)+'.gz','wb',mtime=0) as out: out.write(path.read_bytes())
                path.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
        write(folder/'source.json',source)
        if child.returncode: raise ValueError('native launch failed: '+item['name'])
        if any(sha(ROOT/p)!=digest for p,digest in source['sources'].items()): raise ValueError('inputs changed during launch')
        if command(['git','diff','HEAD','--','scripts','assets/game','main.tscn']).strip(): raise ValueError('production changed during capture')
        print('RECORDED '+item['name'],flush=True)
    source['complete']=True; write(folder/'source.json',source)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--mode',choices=['quality','bench','cpu-only'],required=True); parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); collect(args.output.resolve(),args.mode)

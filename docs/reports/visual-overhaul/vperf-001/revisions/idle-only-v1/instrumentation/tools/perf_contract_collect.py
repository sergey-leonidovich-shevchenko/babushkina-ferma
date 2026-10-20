#!/usr/bin/env python3
"""Collect VPERF-001 native protocol runs, with external RSS/CPU boundary samples."""
from __future__ import annotations
import argparse
import gzip
import hashlib
import json
import os
import signal
import platform
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT=Path(__file__).resolve().parents[1]
FROZEN=['tools/perf_contract_capture.gd','tools/perf_contract_collect.py',
        'tools/visual_camera_points.gd','project.godot','main.tscn',
        'docs/reports/visual-overhaul/vbase-003/camera-points.json',
        'docs/reports/visual-overhaul/vbase-002/profile.json']


def sha(path):
    """Signs exact bytes, including the not-yet-committed collector overlay."""
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path,data):
    """Persists a recoverable per-run document; never overwrites another collection."""
    Path(path).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')


def command(args):
    """Unavailable OS information remains explicit and blocks admission later."""
    try: return subprocess.check_output(args,text=True,stderr=subprocess.STDOUT,timeout=15).strip()
    except (OSError,subprocess.SubprocessError) as e: return 'UNAVAILABLE: '+type(e).__name__


def context():
    """Reads power and thermal state without changing settings or retaining personal process arguments."""
    return {'utc':time.time(),'power':command(['pmset','-g','batt']),
            'power_settings':command(['pmset','-g','custom']),'thermal':command(['pmset','-g','therm']),
            'hardware':{'system':platform.system(),'os_version':platform.mac_ver()[0],'architecture':platform.machine(),
                'machine':{key:command(['sysctl','-n',key]) for key in ['hw.model','machdep.cpu.brand_string','hw.memsize','hw.ncpu']}}}


def jobs():
    """Rejects other Godot instances, but never terminates another task's process."""
    raw=command(['ps','-axo','pid=,comm='])
    if raw.startswith('UNAVAILABLE'): raise ValueError('process inventory unavailable')
    return [line.strip() for line in raw.splitlines() if line.rstrip().endswith('/Godot')]


def native_pid(profile):
    """Finds only this launch's unique isolated profile; arguments are not persisted."""
    raw=command(['ps','-axo','pid=,command='])
    for line in raw.splitlines():
        fields=line.strip().split(None,1)
        if len(fields)==2 and '/Godot ' in fields[1] and '--profile='+profile in fields[1]: return int(fields[0])
    return None


def collect(folder: Path, schedule):
    """Runs serial real-time sessions; PNG readbacks happen only outside the measured interval."""
    if folder.exists(): raise ValueError('fresh collection output required')
    if jobs(): raise ValueError('another Godot process is active')
    if command(['git','diff','HEAD','--','scripts','assets/game','main.tscn']).strip(): raise ValueError('runtime differs from Git base')
    folder.mkdir(parents=True)
    source={'schema':1,'task':'VPERF-001','base_commit':command(['git','rev-parse','HEAD']),
            'complete':False,'schedule':schedule,'sources':{p:sha(ROOT/p) for p in FROZEN},'artifacts':{}}
    for name in FROZEN:
        dest=folder/'instrumentation'/name; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,dest)
    write(folder/'source.json',source)
    for name,seconds,fault in schedule:
        if jobs(): raise ValueError('another Godot process appeared')
        if any(sha(ROOT/p)!=h for p,h in source['sources'].items()): raise ValueError('collector/configuration changed')
        target=folder/name; target.mkdir(); profile='Codex-VPERF-001-'+uuid.uuid4().hex
        launch=['open','-n','-W','-a',str(ROOT/'tools/Godot.app'),'--args','--path',str(ROOT),'--windowed',
                '--audio-driver','Dummy','--log-file',str(target/'engine.txt'),'--script','res://tools/perf_contract_capture.gd',
                '--','--output='+str(target/'native'),'--profile='+profile,'--seconds='+str(seconds)]
        if fault: launch.append('--fault='+fault)
        before=context(); rss=[]; next_read=0; pid=None
        print('NATIVE '+name,flush=True)
        with (target/'stdout.txt').open('w') as log:
            child=subprocess.Popen(launch,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT); deadline=time.monotonic()+seconds+150
            while child.poll() is None:
                if time.monotonic()>deadline:
                    if pid and '--profile='+profile in command(['ps','-o','command=','-p',str(pid)]): os.kill(pid,signal.SIGTERM)
                    child.terminate(); child.wait(timeout=10)
                    raise ValueError('own launch timeout; only the matching isolated process was stopped')
                if time.monotonic()>=next_read:
                    pid=pid or native_pid(profile)
                    if pid:
                        raw=command(['ps','-o','pid=,rss=,time=,%cpu=','-p',str(pid)])
                        other=[line.split()[0] for line in jobs() if int(line.split()[0])!=pid]
                        power=command(['pmset','-g','batt']).splitlines()[0]
                        rss.append({'utc':time.time(),'raw':raw,'pid':pid,'other_godot_pids':other,'power_source':power})
                    next_read=time.monotonic()+5
                time.sleep(.25)
        after=context()
        if any(sha(ROOT/p)!=h for p,h in source['sources'].items()): raise ValueError('collector/configuration changed during run')
        if command(['git','diff','HEAD','--','scripts','assets/game','main.tscn']).strip(): raise ValueError('runtime changed during run')
        write(target/'environment.json',{'command':launch,'exit_code':child.returncode,'profile':profile,'pid':pid,
            'before':before,'after':after,'jobs_after':jobs(),'rss_cpu_samples':rss,
            'sampling_note':'external ps every 5s; RSS bytes from KiB; cumulative CPU time is separate from frame/engine/GPU timers'})
        if (target/'native').exists():
            for p in (target/'native').iterdir(): shutil.move(str(p),str(target/p.name))
            (target/'native').rmdir()
        csv=target/'rows.csv'
        if csv.exists():
            with gzip.GzipFile(str(target/'rows.csv.gz'),'wb',mtime=0) as out: out.write(csv.read_bytes())
            csv.unlink()
        source['artifacts']={str(p.relative_to(folder)):sha(p) for p in folder.rglob('*') if p.is_file() and p.name!='source.json' and 'instrumentation' not in p.parts}
        write(folder/'source.json',source)
        if not fault and (child.returncode or not (target/'run.json').exists()): raise ValueError('native run failed: '+name)
        if not fault and json.loads((target/'run.json').read_text())['errors']: raise ValueError('native conditions failed: '+name)
        print('RECORDED '+name,flush=True)
    source['complete']=True; write(folder/'source.json',source)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--smoke',action='store_true'); parser.add_argument('--controls',action='store_true')
    args=parser.parse_args()
    schedule=[['smoke',30,'']] if args.smoke else ([['resize',30,'resize'],['pause',30,'pause']] if args.controls else [
        ['repeat-1',30,''],['repeat-2',30,''],['repeat-3',30,''],['long-cycle',600,'']])
    collect(args.output.resolve(),schedule)

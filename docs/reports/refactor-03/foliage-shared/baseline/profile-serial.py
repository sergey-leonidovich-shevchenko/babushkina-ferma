"""Run real historical readers/negative suites and every affected GD parser, before and after moves."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/foliage-shared'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment

p=argparse.ArgumentParser();p.add_argument('phase',choices=['before','after']);p.add_argument('--resume-unchanged-prefix',type=Path);args=p.parse_args()
inventory=json.loads((R/'baseline/inventory.json').read_text())
mapping={n:r['target'] for n,r in inventory['moves']['rows'].items()}
engine=os.environ['FARM_GODOT_BIN']
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def stored_log(name,raw):
    data=gzip.compress(raw,mtime=0);(R/name).write_bytes(data)
    return {'log':name,'raw_SHA256':sha(raw),'stored_SHA256':sha(data)}

names=['foliage_root','foliage_uv','foliage_wind','foliage_contact','foliage_speed',
    'foliage_recovery','foliage_pause','foliage_visibility']
commands=[('tools/'+name+'_verify.py',[]) for name in names]
commands += [('tools/grass_methods.py',['all']),('tools/plant_depth_verify.py',[]),('tools/shore_kit.py',[])]
commands += [('tools/test_'+name+'.py',[]) for name in names]
commands += [('tools/test_grass_methods.py',[]),('tools/test_plant_depth.py',[]),('tools/test_shore_kit.py',[])]
assert len(commands)==22
result={'phase':args.phase,'base':inventory['base'],'commands':[],'GD':[],
    'historical_readers':11,'old_negative_suites':11,'unit_cases':0,'native_frames':0,'FPS_admission':False,
    'foreign_cwd':True,'before_known_unsafe_Git_overrides_cleared':args.phase=='before',
    'after_foreign_Git_overrides':args.phase=='after'}
def save():
    (R/(args.phase+'-profile.json')).write_text(json.dumps(result,indent=2)+'\n')

if args.resume_unchanged_prefix:
    args.resume_unchanged_prefix=args.resume_unchanged_prefix.resolve()
    assert args.phase=='after'
    previous=json.loads(args.resume_unchanged_prefix.read_text())
    assert not previous['GD'] and len(previous['commands'])==22
    assert previous['commands'][-1]['exit']!=0 and all(row['exit']==0 for row in previous['commands'][:-1])
    for index,row in enumerate(previous['commands'][:-1]):
        assert row['logical']==commands[index][0]
        assert sha((Q/row['physical']).read_bytes())==row['source_SHA256']
        log=args.resume_unchanged_prefix.parent/row['log']
        assert sha(log.read_bytes())==row['stored_SHA256'] and sha(gzip.decompress(log.read_bytes()))==row['raw_SHA256']
        row['log']=str(log.relative_to(R))
        result['commands'].append(row)
        result['unit_cases']+=sum(int(n) for n in re.findall(rb'^Ran (\d+) tests? in ',gzip.decompress(log.read_bytes()),re.M))
    result['unchanged_successful_prefix_retained']=21
    result['prefix_evidence']=str(args.resume_unchanged_prefix.relative_to(R))
    result['no_success_inferred_for_failed_command']=True

with tempfile.TemporaryDirectory(prefix='remaining03 foreign Git ') as directory:
    foreign=Path(directory).resolve()/'unrelated';foreign.mkdir()
    clean=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1',PYTHONHASHSEED='0')
    subprocess.run(['git','init','-q',str(foreign)],env=clean,check=True)
    (foreign/'marker.txt').write_text('foreign repository\n')
    subprocess.run(['git','-C',str(foreign),'add','.'],env=clean,check=True)
    subprocess.run(['git','-C',str(foreign),'-c','user.name=Remaining QA','-c','user.email=qa@example.invalid',
        'commit','-qm','foreign'],env=clean,check=True)
    protected={n:(foreign/'.git'/n).read_bytes() for n in ['index','config']}
    env=dict(clean)
    if args.phase=='after':env.update(GIT_DIR=str(foreign/'.git'),GIT_WORK_TREE=str(foreign),
        GIT_INDEX_FILE=str(foreign/'.git/index'),GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true')
    for index,(logical,extra) in enumerate(commands):
        if index<len(result['commands']):continue
        physical=mapping.get(logical,logical) if args.phase=='after' else logical
        module=physical.removeprefix('tools/').removesuffix('.py').replace('/','.')
        command=[sys.executable,str(Q/'tools/run.py'),module,*extra]
        completed=subprocess.run(command,cwd=foreign,env=env,capture_output=True,timeout=600)
        raw=completed.stdout+completed.stderr
        row={'logical':logical,'physical':physical,'command':command,'exit':completed.returncode,
            'source_SHA256':sha((Q/physical).read_bytes()),'stdout_SHA256':sha(completed.stdout),
            **stored_log(args.phase+'-cli-'+str(index).zfill(2)+'.txt.gz',raw)}
        result['commands'].append(row)
        result['unit_cases']+=sum(int(n) for n in re.findall(rb'^Ran (\d+) tests? in ',raw,re.M))
        save();print(json.dumps({'phase':args.phase,'CLI':logical,'exit':completed.returncode}),flush=True)
        if completed.returncode:raise SystemExit(completed.returncode)
    for index,logical in enumerate(inventory['GD_before_logical']):
        physical=mapping.get(logical,logical) if args.phase=='after' else logical
        log=Path(directory)/('engine-'+str(index)+'.log')
        command=[engine,'--headless','--path',str(Q),'--log-file',str(log),'--check-only','--script','res://'+physical]
        completed=subprocess.run(command,cwd=foreign,env=env,capture_output=True,timeout=90)
        raw=completed.stdout+completed.stderr
        row={'logical':logical,'physical':physical,'source_SHA256':sha((Q/physical).read_bytes()),
            'exit':completed.returncode,**stored_log(args.phase+'-GD-'+str(index).zfill(3)+'.txt.gz',raw)}
        if log.exists():
            details=stored_log(args.phase+'-GD-'+str(index).zfill(3)+'.engine.gz',log.read_bytes())
            row.update(engine_log=details['log'],engine_raw_SHA256=details['raw_SHA256'],engine_stored_SHA256=details['stored_SHA256'])
        result['GD'].append(row);save()
        if completed.returncode or b'SCRIPT ERROR' in raw:raise SystemExit(completed.returncode or 1)
    assert all((foreign/'.git'/n).read_bytes()==data for n,data in protected.items())
    result['foreign_index_config_preserved']=True
if args.phase=='after':
    before=json.loads((R/'before-profile.json').read_text())
    assert [r['logical'] for r in before['commands']]==[r['logical'] for r in result['commands']]
    for old,new in zip(before['commands'][:11],result['commands'][:11]):assert old['stdout_SHA256']==new['stdout_SHA256'],new['logical']
    result['historical_stdout_byte_equal']=11
save()
print(json.dumps({'phase':args.phase,'CLI':len(result['commands']),'GD':len(result['GD']),'cases':result['unit_cases']}),flush=True)

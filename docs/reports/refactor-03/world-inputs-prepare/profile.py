"""Compare real World readers and old suites, plus a real Water writer restricted to an owned raw mirror."""
import argparse,hashlib,io,json,os,shutil,subprocess,sys,tempfile
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-inputs-prepare'
sys.path[:0]=[str(Q),str(Q/'tools')]
from tools.common.git import git_environment
p=argparse.ArgumentParser();p.add_argument('phase',choices=['before','after']);p.add_argument('--attempt',default='01');args=p.parse_args();phase=args.phase
prefix=phase if args.attempt=='01'else phase+'-attempt'+args.attempt
assert not(R/(phase+'-profile.json')).exists()
readers=['render_order','object_command_verify','village_bench_verify','village_street_verify','village_board_verify','village_trade_verify','pilot_static_audit','pilot_static_verify','pilot_pass_verify','post_motion_verify','transient_save_verify','shadow_inventory_verify','village_fence_verify','village_lamp_verify','shore_kit']
assets=['village_'+n+'_assets'for n in['bench','board','fence','lamp','street','trade']]
negatives=['test_'+n for n in['render_order','object_command','village_bench','village_street','village_board','village_trade','pilot_static','pilot_pass','post_motion','transient_save','shadow_inventory','village_fence','village_lamp','shore_kit','water_audit']]
rows=[]
with tempfile.TemporaryDirectory(prefix='world inputs '+phase+' foreign ')as directory:
    foreign=Path(directory).resolve();(foreign/'note.txt').write_text('foreign World input reader fixture\n')
    subprocess.run(['git','init','-q',str(foreign)],env=git_environment(),check=True)
    subprocess.run(['git','-C',str(foreign),'add','.'],env=git_environment(),check=True)
    state={n:(foreign/'.git'/n).read_bytes()for n in['index','config']}
    environment=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(foreign))
    if phase=='after':environment.update(GIT_DIR=str(foreign/'.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'.git/index'),GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true')
    for name in readers+assets+negatives:
        log=prefix+'-%02d.txt'%(len(rows)+1);argv=[sys.executable,str(Q/'tools'/(name+'.py'))]
        with(R/log).open('x')as stream:result=subprocess.run(argv,cwd=foreign,env=environment,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
        output=(R/log).read_text();row={'command':argv,'cwd':str(foreign),'exit':result.returncode,'log':log,'sha256':hashlib.sha256((R/log).read_bytes()).hexdigest()};rows.append(row)
        (R/(prefix+'-commands.json')).write_text(json.dumps(rows,indent=2)+'\n')
        assert result.returncode==0,(row,output[-3500:]);assert not any(x in output for x in['SCRIPT ERROR','Parse Error','\nERROR:'])
        print(json.dumps({'phase':phase,'command':len(rows),'exit':result.returncode}),flush=True)
    assert all((foreign/'.git'/n).read_bytes()==raw for n,raw in state.items())

import analyze_water_audit as water
raw_names=['before/native-1152.json','before/native-1920.json','before/native-3584.json','before-f10/native-1152.json']
original=Q/'docs/reports/water-2026-10';signatures={name:hashlib.sha256((original/name).read_bytes()).hexdigest()for name in raw_names}
with tempfile.TemporaryDirectory(prefix='owned Water writer '+phase+' ')as directory:
    owned=Path(directory).resolve()
    for name in raw_names:
        target=owned/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original/name,target)
    stdout=io.StringIO()
    with patch.object(water,'FOLDER',owned),redirect_stdout(stdout):water.main()
    assert stdout.getvalue().strip()=='WATER BASELINE: 48 verified diagnostic repeats; OPT/GPU acceptance: not claimed'
    (R/(prefix+'-water-writer.txt')).write_text(stdout.getvalue())
    analysis=json.loads((owned/'baseline-analysis.json').read_text());assert len(analysis)==4 and sum(len(r['measurements'])for r in analysis)==48
    outputs={}
    for name in['baseline-analysis.json','native-summary.md']:
        target=prefix+'-water-'+name;shutil.copyfile(owned/name,R/target);outputs[name]={'file':target,'sha256':hashlib.sha256((R/target).read_bytes()).hexdigest()}
assert all(hashlib.sha256((original/name).read_bytes()).hexdigest()==digest for name,digest in signatures.items())
writer={'real_module_main':True,'owned_raw_mirror':True,'raw_input_SHA256':signatures,'outputs':outputs,'diagnostic_old_repeats':48,'native_frames_new':0,'Game_new':False,'GPU_FPS_admission':False}
(R/(prefix+'-water-writer.json')).write_text(json.dumps(writer,indent=2)+'\n')
result={'phase':phase,'base':json.loads((R/'baseline/inventory.json').read_text())['base'],'commands':rows,'foreign_cwd':True,'foreign_Git_overrides':phase=='after','foreign_Git_index_config_unchanged':True,'historical_verifier_commands':15,'asset_verifier_commands':6,'old_negative_suites':15,'actual_owned_Water_writer':writer,'Game_new':False,'native_sessions':0,'GPU_FPS_admission':False,'input_reports_unmodified':True}
if phase=='after':
    before=json.loads((R/'before-profile.json').read_text());assert len(before['commands'])==len(rows)==36
    for left,right in zip(before['commands'],rows):
        assert left['command']==right['command']
        if not Path(left['command'][1]).name.startswith('test_'):assert(R/left['log']).read_bytes()==(R/right['log']).read_bytes(),left['command']
    for name in outputs:
        assert(R/before['actual_owned_Water_writer']['outputs'][name]['file']).read_bytes()==(R/outputs[name]['file']).read_bytes(),name
    result['historical_stdout_byte_equal']=21;result['owned_water_outputs_byte_equal']=2
(R/(phase+'-profile.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'phase':phase,'actual_commands':len(rows),'actual_owned_Water_writer':True,'native_sessions':0,'Game_new':False}))

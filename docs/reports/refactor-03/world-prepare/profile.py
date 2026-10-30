"""Actual before/after World readers, six asset verifiers and unchanged negative suites; never capture."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-prepare'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
p=argparse.ArgumentParser();p.add_argument('phase',choices=['before','after']);phase=p.parse_args().phase
assert not(R/(phase+'-profile.json')).exists()
readers=['render_order','object_command_verify','village_bench_verify','village_street_verify','village_board_verify','village_trade_verify','pilot_static_audit','pilot_static_verify','pilot_pass_verify','post_motion_verify','transient_save_verify','shadow_inventory_verify','village_fence_verify','village_lamp_verify','shore_kit']
assets=['village_'+n+'_assets'for n in ['bench','board','fence','lamp','street','trade']]
negatives=['test_'+n for n in ['render_order','object_command','village_bench','village_street','village_board','village_trade','pilot_static','pilot_pass','post_motion','transient_save','shadow_inventory','village_fence','village_lamp','shore_kit']]
rows=[]
with tempfile.TemporaryDirectory(prefix='world '+phase+' foreign ')as directory:
    foreign=Path(directory).resolve();(foreign/'note.txt').write_text('foreign World reader fixture\n')
    subprocess.run(['git','init','-q',str(foreign)],env=git_environment(),check=True)
    subprocess.run(['git','-C',str(foreign),'add','.'],env=git_environment(),check=True)
    before={n:(foreign/'.git'/n).read_bytes()for n in ['index','config']}
    environment=dict(git_environment(),PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(foreign))
    if phase=='after':environment.update(GIT_DIR=str(foreign/'.git'),GIT_WORK_TREE=str(foreign),GIT_INDEX_FILE=str(foreign/'.git/index'),GIT_CONFIG_COUNT='1',GIT_CONFIG_KEY_0='core.bare',GIT_CONFIG_VALUE_0='true')
    for name in readers+assets+negatives:
        log=phase+'-%02d.txt'%(len(rows)+1);argv=[sys.executable,str(Q/'tools'/(name+'.py'))]
        with(R/log).open('x')as stream:result=subprocess.run(argv,cwd=foreign,env=environment,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
        output=(R/log).read_text();row={'command':argv,'cwd':str(foreign),'exit':result.returncode,'log':log,'sha256':hashlib.sha256((R/log).read_bytes()).hexdigest()};rows.append(row)
        (R/(phase+'-commands.json')).write_text(json.dumps(rows,indent=2)+'\n')
        assert result.returncode==0,(row,output[-3500:]);assert not any(x in output for x in ['SCRIPT ERROR','Parse Error','\nERROR:'])
        print(json.dumps({'phase':phase,'command':len(rows),'exit':result.returncode}),flush=True)
    assert all((foreign/'.git'/n).read_bytes()==raw for n,raw in before.items())
result={'phase':phase,'base':json.loads((R/'baseline/inventory.json').read_text())['base'],'commands':rows,'foreign_cwd':True,'foreign_Git_overrides':phase=='after','foreign_Git_index_config_unchanged':True,'historical_verifier_commands':15,'asset_verifier_commands':6,'old_negative_suites':14,'Game_new':False,'native_sessions':0,'GPU_FPS_admission':False,'input_reports_unmodified':True}
if phase=='after':
    before=json.loads((R/'before-profile.json').read_text());assert len(before['commands'])==len(rows)==35
    for left,right in zip(before['commands'],rows):
        assert left['command']==right['command']
        if not Path(left['command'][1]).name.startswith('test_'):assert(R/left['log']).read_bytes()==(R/right['log']).read_bytes(),left['command']
    result['historical_stdout_byte_equal']=21
(R/(phase+'-profile.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'phase':phase,'actual_commands':len(rows),'native_sessions':0,'Game_new':False}))

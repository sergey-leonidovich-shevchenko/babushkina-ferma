"""Seal World input/history preparation only after full current gates and Wiki/browser checks."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-inputs-prepare'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
scope=json.loads((R/'scope.json').read_text());b=json.loads((R/'baseline/inventory.json').read_text());freeze=json.loads((R/'source-freeze.json').read_text());current={n:sha(Q/n)for n in scope['source_paths_after']}
assert current==freeze['source_SHA256']and freeze['version']=='0.0.376'
changed=set(filter(None,git('diff','--no-renames',scope['base'],'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in current or n.startswith(str(R.relative_to(Q))+'/')for n in changed)
tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
for row in b['author_UID_exact']:
    p=Q/row['path'];assert sha(p)==row['sha256']and p.stat().st_mode&0o777==row['mode'];assert row['path']not in tracked and git('check-ignore','--',row['path']).strip()
assert len(b['author_UID_exact'])==85 and sha(Q/b['anchor']['path'])==b['anchor']['sha256']
failed=json.loads((R/'gates-01/gate-exits.json').read_text());assert len(failed)==1 and failed[0]['gate']=='architecture'and failed[0]['exit']==1
gates=json.loads((R/'gates-02/gate-exits.json').read_text());assert[r['gate']for r in gates]==['architecture','game','wiki']and all(r['exit']==0 and r['version']=='0.0.376'for r in gates)
raw=(R/'gates-02/architecture.txt').read_text();cases=list(map(int,re.findall(r'Ran (\d+) tests? in',raw)));assert len(cases)==101 and sum(cases)==1337,(len(cases),sum(cases))
game=(R/'gates-02/game.txt').read_text();assert'TESTS: 53502 passed, 0 failed'in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=(R/'gates-02/wiki.txt').read_text();assert re.search(r'[ℹ#] pass 145\b',wiki)and re.search(r'[ℹ#] fail 0\b',wiki)
ci=json.loads((R/'baseline/ci375-final.json').read_text());assert ci['headRevision']==scope['base']and len(ci['checks'])==8 and all(r['conclusion']=='success'for r in ci['checks'])
reviews=json.loads((R/'baseline/reviews375.json').read_text());assert any(scope['base']in r['body']and'SOURCE PASS'in r['body']for r in reviews)
before=json.loads((R/'before-profile.json').read_text());after=json.loads((R/'after-profile.json').read_text());assert len(before['commands'])==len(after['commands'])==36 and after['historical_stdout_byte_equal']==21 and after['owned_water_outputs_byte_equal']==2
for profile in[before,after]:
    assert all(row['exit']==0 and sha(R/row['log'])==row['sha256']for row in profile['commands'])and profile['foreign_Git_index_config_unchanged']and profile['native_sessions']==0 and not profile['Game_new']and not profile['GPU_FPS_admission']
    writer=profile['actual_owned_Water_writer'];assert writer['owned_raw_mirror']and writer['diagnostic_old_repeats']==48 and not writer['Game_new']and not writer['GPU_FPS_admission']
    assert all(sha(R/row['file'])==row['sha256']for row in writer['outputs'].values())
reg=json.loads((R/'regression.json').read_text());assert reg['history_same_test_source']and reg['history_methods']==12 and reg['history_test_SHA256']==sha(Q/'tools/qa/world/test_world_source_history.py')and reg['producer_same_test_source']and reg['producer_methods']==13 and reg['producer_test_SHA256']==sha(Q/'tools/qa/world/test_world_producers.py')and reg['helper_new_API_methods']==16 and reg['old_context_methods']==19
assert'FAILED (failures=1, errors=10)'in(R/'history-red.txt').read_text()
for label,count in[('helper-green',16),('history-green',12),('producers-before',13),('producers-after',13),('context-after',19)]:
    data=json.loads((R/(label+'.json')).read_text());assert data['exit']==0 and data['methods']==count and sha(R/(label+'.txt'))==data['raw_sha256']
catalog=json.loads((R/'catalog.json').read_text());article=json.loads((R/'browser-article.json').read_text());assert article['current_world_inputs']and article['current_root245']and not article['stale_stop']and article['profile_href']==catalog['profile_href']
mobile=json.loads((R/'browser-mobile.json').read_text());assert mobile['dimensions']=={'width':390,'scrollWidth':390}
task=json.loads((R/'browser-task.json').read_text());assert task['in_progress']and task['current_world_inputs']and not task['stale_stop']
cleanup=json.loads((R/'browser-cleanup.json').read_text());assert cleanup['own_tab_closed']and cleanup['own_server_stop_confirmed']and cleanup['viewport_reset']
shutil.copyfile(__file__,R/'seal.py')
result={'task':'REFACTOR-03','phase':'World current/history input preparation','version':'0.0.376','base':scope['base'],'prior_source_review':5693715399,'prior_Team_intermediate_accepted':True,'prior_CI_success':8,'root_sources':245,'authoritative_gates':gates,'architecture_suites':101,'architecture_cases':1337,'game_passed':53502,'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,'regression':reg,'functions_address_only':scope['functions_preserved_with_address_only_normalization'],'current_input_sites':37,'historical_sites':14,'future_history_aliases':141,'current_source_map':133,'historical_fields_preserved':37,'author_UID_exact':85,'anchor_preserved':True,'actual_profile_CLI_each':36,'actual_owned_Water_writer_each':1,'historical_stdout_byte_equal':21,'owned_Water_outputs_byte_equal':2,'P3_fixed':True,'water_FOLDER_fixed':True,'native_Game_GPU_FPS_admission':False,'physical_moves':0,'UID_moves':0,'full_task03_accepted':False,'Task_Complete_added':False,'source_SHA256':current,'removed_source_paths':[],'report_files':[{'path':str(p.relative_to(R)),'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(R.rglob('*'))if p.is_file()and p.name!='checks.json'and '__pycache__'not in p.parts]}
(R/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'version':'0.0.376','source_paths':len(current),'report_files':len(result['report_files']),'full_gates':'101/1337,Game53502,redraw90x2,Wiki145'}))

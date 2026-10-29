"""Seal camera preparation only after complete new gates and browser checks."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(Q),*args],env=git_environment())
scope=json.loads((R/'scope.json').read_text());freeze=json.loads((R/'source-freeze.json').read_text());current={n:sha(Q/n)for n in scope['source_paths_after']}
assert current==freeze['source_SHA256']and freeze['version']=='0.0.373'
changed=set(filter(None,git('diff','--no-renames',scope['base'],'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in current or n.startswith(str(R.relative_to(Q))+'/')for n in changed)
uids=json.loads((R.parent/'baseline/local-uids.json').read_text());tracked=set(filter(None,git('ls-files','-z').decode().split('\0')))
for row in uids['local_only_UID']:
 paths=[Q/n for n in [row['old_path'],row['target']]if(Q/n).is_file()]
 assert len(paths)==1 and paths[0].read_text().strip()==row['value']
 name=str(paths[0].relative_to(Q));assert name not in tracked and git('check-ignore','--',name).strip()
assert len(uids['local_only_UID'])==85
anchor=uids['retained_anchor_local_UID'];assert sha(Q/anchor['path'])==anchor['sha256']
gates=json.loads((R/'gates-01/gate-exits.json').read_text());assert[r['gate']for r in gates]==['architecture','game','wiki']and all(r['exit']==0 and r['version']=='0.0.373'for r in gates)
raw=(R/'gates-01/architecture.txt').read_text();cases=list(map(int,re.findall(r'Ran (\d+) tests? in',raw)));assert len(cases)==96 and sum(cases)==1274,(len(cases),sum(cases))
game=(R/'gates-01/game.txt').read_text();assert'TESTS: 53502 passed, 0 failed'in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=(R/'gates-01/wiki.txt').read_text();assert re.search(r'[ℹ#] pass 145\b',wiki)and re.search(r'[ℹ#] fail 0\b',wiki)
ci_raw=json.loads((R/'baseline/ci372-final.json').read_text());ci=ci_raw.get('structuredContent')or json.loads(next(x['text']for x in ci_raw['content']if x['type']=='text'))
assert ci['headRevision']==scope['base']and len(ci['checks'])==8 and all(r['conclusion']=='success'for r in ci['checks'])
reviews=json.loads((R/'baseline/reviews372.json').read_text());assert any(scope['base']in r['body']and'INTERMEDIATE REVIEW PASS'in r['body']for r in reviews)
before=json.loads((R/'before-profile.json').read_text());after=json.loads((R/'after-profile.json').read_text());assert len(before['commands'])==len(after['commands'])==20 and after['historical_stdout_byte_equal']==11
for profile in [before,after]:
 assert all(row['exit']==0 and sha(R/row['log'])==row['sha256']for row in profile['commands'])and profile['foreign_Git_index_config_unchanged']and profile['native_sessions']==0 and not profile['Game_new']and not profile['GPU_FPS_admission']
reg=json.loads((R/'regression.json').read_text());assert reg['same_test_source']and reg['methods']==12 and reg['test_SHA256']==sha(Q/'tools/qa/camera/test_camera_context.py')
assert 'FAILED (failures=16)'in(R/'context-red.txt').read_text()and(R/'context-green.txt').read_text().rstrip().endswith('OK')
catalog=json.loads((R/'catalog.json').read_text());article=json.loads((R/'browser-article.json').read_text());assert article['current_camera_prepare']and article['current_root285']and not article['stale_stop']and article['profile_href']==catalog['profile_href']
mobile=json.loads((R/'browser-mobile.json').read_text());assert mobile['dimensions']=={'width':390,'scrollWidth':390}
task=json.loads((R/'browser-task.json').read_text());assert task['in_progress']and task['current_camera_prepare']and not task['stale_stop']
cleanup=json.loads((R/'browser-cleanup.json').read_text());assert cleanup['own_tab_closed']and cleanup['own_server_stop_confirmed']and cleanup['viewport_reset']
shutil.copyfile(__file__,R/'seal.py');result={'task':'REFACTOR-03','phase':'camera source-root and Git context preparation','version':'0.0.373','base':scope['base'],'prior_source_review':5692067678,'prior_Team_intermediate_accepted':True,'prior_CI_success':8,'root_sources':285,'authoritative_gates':gates,'architecture_suites':96,'architecture_cases':1274,'game_passed':53502,'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,'new_context_tests':12,'same_test_source_red_green':reg,'functions_address_only':70,'source_root_sites':6,'Git_read_sites':9,'historical_fields_preserved':37,'author_UID_preserved':85,'anchor_preserved':True,'actual_profile_commands_each':20,'historical_stdout_byte_equal':11,'native_Game_GPU_FPS_admission':False,'physical_moves':0,'UID_moves':0,'full_task03_accepted':False,'Task_Complete_added':False,'source_SHA256':current,'removed_source_paths':[],'report_files':[{'path':str(p.relative_to(R)),'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(R.rglob('*'))if p.is_file()and p.name!='checks.json'and '__pycache__'not in p.parts]}
(R/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'version':'0.0.373','source_paths':len(current),'report_files':len(result['report_files']),'full_gates':'96/1274,Game53502,redraw90x2,Wiki145'}))

"""Seal the exact P2 repair only after its new complete gates and local browser checks."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
ROOT=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=ROOT/'docs/reports/refactor-03/performance-review-1'
sys.path.insert(0,str(ROOT))
from tools.common.git import git_environment
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],env=git_environment())
scope=json.loads((R/'scope.json').read_text());freeze=json.loads((R/'source-freeze.json').read_text())
current={n:sha(ROOT/n)for n in scope['source_paths_after']};assert current==freeze['source_SHA256']and freeze['version']=='0.0.372'
changed=set(filter(None,git('diff','--no-renames',scope['base'],'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert all(n in current or n.startswith(str(R.relative_to(ROOT))+'/')for n in changed)
gates=json.loads((R/'gates-01/gate-exits.json').read_text());assert[r['gate']for r in gates]==['architecture','game','wiki']and all(r['exit']==0 and r['version']=='0.0.372'for r in gates)
text=(R/'gates-01/architecture.txt').read_text();cases=list(map(int,re.findall(r'Ran (\d+) tests? in',text)));assert len(cases)==95 and sum(cases)==1262,(len(cases),sum(cases))
game=(R/'gates-01/game.txt').read_text();assert'TESTS: 53502 passed, 0 failed'in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=(R/'gates-01/wiki.txt').read_text();assert re.search(r'[ℹ#] pass 145\b',wiki)and re.search(r'[ℹ#] fail 0\b',wiki)
raw=json.loads((R/'baseline/ci371-final.json').read_text());ci=raw.get('structuredContent')or json.loads(next(x['text']for x in raw['content']if x['type']=='text'))
assert ci['headRevision']==scope['base']and len(ci['checks'])==8 and all(x['conclusion']=='success'for x in ci['checks'])
reviews=json.loads((R/'baseline/reviews371.json').read_text());assert any(scope['base']in x['body']and'CHANGES REQUESTED'in x['body']for x in reviews)
profile=json.loads((R/'profile.json').read_text());assert len(profile['paired_actual_producers'])==4 and len(profile['commands'])==6 and all(x['exit']==0 for x in profile['commands'])
assert not profile['GPU_FPS_admission']and profile['real_native_sessions']==0 and not profile['Game_new']
for row in profile['commands']:assert sha(R/row['log'])==row['sha256']
reg=json.loads((R/'regression.json').read_text());assert reg['same_test_source']and reg['test_SHA256']==sha(ROOT/'tools/qa/performance/test_surface_producers.py')and reg['methods']==9
assert 'FAILED (failures=2, errors=9)'in(R/'producer-red.txt').read_text()
assert(R/'producer-green-01.txt').read_text().rstrip().endswith('OK')
catalog=json.loads((R/'catalog.json').read_text());browser=json.loads((R/'browser-article.json').read_text())
assert browser['current_P2_repair']and browser['current_root285']and not browser['stale_stop']and browser['profile_href']==catalog['profile_href']
mobile=json.loads((R/'browser-mobile.json').read_text());assert mobile['dimensions']=={'width':390,'scrollWidth':390}
task=json.loads((R/'browser-task.json').read_text());assert task['in_progress']and task['current_P2_repair']and not task['stale_stop']
cleanup=json.loads((R/'browser-cleanup.json').read_text());assert cleanup['own_tab_closed']and cleanup['own_server_stop_confirmed']and cleanup['viewport_reset']
shutil.copyfile(__file__,R/'seal.py')
result={'task':'REFACTOR-03','phase':'P2 surface producer repair','version':'0.0.372','base':scope['base'],
 'prior_review':5691592934,'prior_review_state':'CHANGES_REQUESTED','prior_CI_success':8,'root_sources':285,
 'authoritative_gates':gates,'architecture_suites':95,'architecture_cases':1262,'game_passed':53502,'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,
 'new_producer_tests':9,'same_test_source_red_green':reg,'producer_reader_functions_address_only':28,
 'known_map_original90_exact_plus_one':True,'known_map_entries':91,'historical_fields_preserved':37,'author_UID_preserved':85,'anchor_preserved':True,
 'real_prelaunch_archive_profiles':4,'foreign_CLI_profiles':6,'native_Game_GPU_FPS_admission':False,
 'physical_moves':0,'UID_moves':0,'full_task03_accepted':False,'Task_Complete_added':False,
 'source_SHA256':current,'removed_source_paths':[],
 'report_files':[{'path':str(p.relative_to(R)),'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(R.rglob('*'))if p.is_file()and p.name!='checks.json'and '__pycache__'not in p.parts]}
(R/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'version':'0.0.372','source_paths':len(current),'report_files':len(result['report_files']),'full_gates':'95/1262,Game53502,redraw90x2,Wiki145'}))

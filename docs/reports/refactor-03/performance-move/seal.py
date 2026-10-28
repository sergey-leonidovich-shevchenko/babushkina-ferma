"""Seal the actual371 source/evidence after all writers have finished; never approve the full task."""
import hashlib,json,re,shutil
from pathlib import Path
R=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm/docs/reports/refactor-03/performance-move')
ROOT=next(p for p in R.parents if(p/'project.godot').is_file())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
scope=json.loads((R/'scope.json').read_text());freeze=json.loads((R/'source-freeze.json').read_text())
import subprocess,sys
sys.path.insert(0,str(ROOT))
from tools.common.git import git_environment
def git(*args):return subprocess.check_output(['git','-C',str(ROOT),*args],env=git_environment())
allowed=set(scope['source_paths_after'])|set(scope['removed_source_paths'])
changed=set(filter(None,git('diff','--no-renames',scope['base'],'--name-only','-z').decode().split('\0')))|set(filter(None,git('ls-files','--others','--exclude-standard','-z').decode().split('\0')))
offending=[n for n in changed if n not in allowed and not n.startswith(str(R.relative_to(ROOT))+'/')]
assert not offending,offending
current={n:sha(ROOT/n)for n in scope['source_paths_after']}
assert current==freeze['source_SHA256']and freeze['version']=='0.0.371'
gates=json.loads((R/'gates-02/gate-exits.json').read_text())
assert [r['gate']for r in gates]==['architecture','game','wiki']and all(r['exit']==0 and r['version']=='0.0.371'for r in gates)
architecture=(R/'gates-02/architecture.txt').read_text();cases=list(map(int,re.findall(r'Ran (\d+) tests? in',architecture)))
assert len(cases)==94 and sum(cases)==1253,(len(cases),sum(cases))
assert 'ARCHITECTURE: boundaries and whitespace are valid'in architecture
game=(R/'gates-02/game.txt').read_text();assert 'TESTS: 53502 passed, 0 failed'in game and game.count('REDRAW: 90 passed, 0 failed')==2
wiki=(R/'gates-02/wiki.txt').read_text();assert re.search(r'[ℹ#] pass 145\b',wiki)and re.search(r'[ℹ#] fail 0\b',wiki)
raw=json.loads((R/'baseline/ci370-final.json').read_text());ci=raw.get('structuredContent')or json.loads(next(r['text']for r in raw['content']if r['type']=='text'))
assert ci['headRevision']==scope['base']and len(ci['checks'])==8 and all(r['conclusion']=='success'for r in ci['checks'])
reviews=json.loads((R/'baseline/reviews370.json').read_text());assert any(scope['base']in r['body']and 'SOURCE REVIEW PASS'in r['body']for r in reviews)
before=json.loads((R/'before-profile.json').read_text());after=json.loads((R/'after-profile.json').read_text());extra=json.loads((R/'extra-profile.json').read_text())
assert before['outputs']==after['outputs']and before['input_json_SHA256']==after['input_json_SHA256']and after['actual_before_after_equal']
assert len(before['commands'])==12 and len(after['commands'])==19 and after['attempt']==5
assert all(r['exit']==r['expected']for r in after['commands'])
assert len(extra['commands'])==73 and extra['direct_root_CLI_imports']==53 and extra['canonical_launcher_imports']==1 and extra['canonical_GD_parses']==18
for r in before['commands']+after['commands']+extra['commands']:
 assert sha(R/r['log'])==r['sha256'],r['log']
assert len(after['outputs']['actual_headless_crash_workers']['cases'])==14
assert not after['new_GPU_FPS_admission']and not after['window_opened']
assert 'ModuleNotFoundError: No module named \'performance_protocol\''in(R/'after-16.txt').read_text()
assert 'FAILED (errors=3)'in(R/'after-attempt02-16.txt').read_text()
assert 'Ran 34 tests'in(R/'nested-target-green.txt').read_text()and(R/'nested-target-green.txt').read_text().rstrip().endswith('OK')
proof=json.loads((R/'frozen-graph-proof.json').read_text())
assert proof['cases']==8 and [r['exit']for r in proof['records']]==[1,0]
assert proof['same_test_SHA256']==sha(ROOT/'tools/qa/performance/test_performance_layout.py')
assert 'Ran 6 tests'in(R/'frozen-redraw-green.txt').read_text()and(R/'frozen-redraw-green.txt').read_text().rstrip().endswith('OK')
assert json.loads((R/'gates-01/gate-exits.json').read_text())[0]['exit']==1
catalog=json.loads((R/'catalog.json').read_text());browser=json.loads((R/'browser-article.json').read_text())
assert browser['current_performance_move']and browser['current_root285']and not browser['stale_stop']and browser['profile_href']==catalog['profile_href']
mobile=json.loads((R/'browser-mobile.json').read_text());assert mobile['dimensions']=={'width':390,'scrollWidth':390}
task=json.loads((R/'browser-task.json').read_text());assert task['in_progress']and task['current_performance_move']and not task['stale_stop']
cleanup=json.loads((R/'browser-cleanup.json').read_text());assert cleanup['own_tab_closed']and cleanup['own_server_stop_confirmed']
shutil.copyfile(__file__,R/'seal.py')
result={'task':'REFACTOR-03','phase':'physical performance move','version':'0.0.371','base':scope['base'],
 'authoritative_gates':gates,'architecture_suites':94,'architecture_cases':1253,'game_passed':53502,'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,
 'root_sources':285,'physical_source_moves':33,'tracked_UID_moves':14,'ignored_UID_moves':4,'public_facades':4,'sampler_anchor_preserved':True,
 'old_test_methods_and_assertions_preserved':113,'new_layout_tests':8,'historical_fields_preserved':37,'all_author_UID_preserved':85,
 'actual_worker_checkpoints_each_profile':14,'actual_headless_smoke_frames_each_profile':180,'actual_after_commands':19,
 'actual_canonical_GD_parses':18,'actual_direct_root_imports':53,'actual_canonical_launcher_imports':1,
 'frozen_graph_same_source_red_green':proof,'additional_protocol_facade_requires_independent_acceptance':True,'prior370_source_review':5690964419,'prior370_CI_success':8,'full_task03_accepted':False,'Task_Complete_added':False,'GPU_FPS_admission':False,
 'source_SHA256':current,'removed_source_paths':scope['removed_source_paths'],
 'report_files':[{'path':str(p.relative_to(R)),'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(R.rglob('*'))if p.is_file()and p.name!='checks.json'and '__pycache__'not in p.parts]}
(R/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'version':'0.0.371','suites':94,'cases':1253,'root':285,'source_paths':len(current),'report_files':len(result['report_files'])}))

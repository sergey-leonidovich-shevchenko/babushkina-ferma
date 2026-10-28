"""Seal actual369 evidence without claiming full task approval or fresh rendering performance."""
import hashlib,json,re
from pathlib import Path
REPORT=Path(__file__).resolve().parent
ROOT=next(p for p in REPORT.parents if(p/'project.godot').is_file())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 scope=json.loads((REPORT/'scope.json').read_text());freeze=json.loads((REPORT/'source-freeze.json').read_text())
 current={n:sha(ROOT/n)for n in scope['source_paths_after']};assert freeze['source_SHA256']==current
 assert all(not(ROOT/n).exists()for n in freeze['removed_paths'])
 gates=json.loads((REPORT/'gates-02/gate-exits.json').read_text());assert[r['gate']for r in gates]==['architecture','game','wiki']
 assert all(r['exit']==0 and r['version']=='0.0.369'for r in gates)
 cases=list(map(int,re.findall(r'Ran (\d+) tests? in',(REPORT/'gates-02/architecture.txt').read_text())))
 assert len(cases)==92 and sum(cases)==1240,(len(cases),sum(cases))
 game=(REPORT/'gates-02/game.txt').read_text();assert'TESTS: 53502 passed, 0 failed'in game and game.count('REDRAW: 90 passed, 0 failed')==2
 refresh=json.loads((REPORT/'gates-04/gate-exits.json').read_text());assert[r['gate']for r in refresh]==['documentation','wiki']
 assert all(r['exit']==0 and r['version']=='0.0.369'for r in refresh)
 wiki=(REPORT/'gates-04/wiki.txt').read_text();assert re.search(r'[ℹ#] pass 145\b',wiki)and re.search(r'[ℹ#] fail 0\b',wiki)
 prior=json.loads((REPORT/'source-freeze-after-gates02.json').read_text())
 changed={n for n,h in current.items()if prior['source_SHA256'][n]!=h};assert changed=={'wiki/articles/project-refactoring.md'}
 delta=json.loads((REPORT/'docs-refresh.json').read_text());assert delta['changed_source_paths']==sorted(changed)and delta['all_runtime_tool_test_UID_version_paths_unchanged']is True
 assert sha(REPORT/'post-gates02-article.md.gz')==delta['before_article_gzip_SHA256']
 rejected=json.loads((REPORT/'gates-01/gate-exits.json').read_text());assert len(rejected)==1 and rejected[0]['exit']==1
 ci=json.loads((REPORT/'baseline/ci368-final.json').read_text());ci=json.loads(next(r['text']for r in ci['content']if r['type']=='text'))
 assert ci['headRevision']==scope['base']and len(ci['checks'])==8 and all(c['conclusion']=='success'for c in ci['checks'])
 before=json.loads((REPORT/'before-profile.json').read_text());after=json.loads((REPORT/'after-profile.json').read_text())
 assert before['outcomes']==after['outcomes']and after['actual_before_after_equal']and after['alchemy_expected_legacy_rejection']
 assert len(after['source_comparison'])==153
 catalog=json.loads((REPORT/'catalog.json').read_text());browser=json.loads((REPORT/'browser-article.json').read_text())
 assert browser['current_move']and browser['profile_href']==catalog['profile_href']
 assert browser['current_root314']and not browser['stale_root481']and not browser['stale_stop']
 assert json.loads((REPORT/'browser-mobile.json').read_text())['dimensions']=={'width':390,'scrollWidth':390}
 task=json.loads((REPORT/'browser-task.json').read_text());assert task['in_progress']and task['current_move']and not task['stale_stop']and task['task_scope_not_complete']
 cleanup=json.loads((REPORT/'browser-cleanup.json').read_text());assert cleanup['own_tab_closed']and cleanup['own_server_stop_confirmed']
 result={'task':'REFACTOR-03','phase':'compatibility physical move','version':'0.0.369','base':scope['base'],
  'full_gates_before_article_refresh':gates,'full_gates_source_freeze':'source-freeze-after-gates02.json','documentation_and_current_wiki_gates':refresh,'only_article_changed_after_full_gates':sorted(changed),'architecture_suites':len(cases),'architecture_cases':sum(cases),'game_passed':53502,'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,
  'root_sources':314,'physical_source_moves':89,'tracked_UID_moves':64,'ignored_UID_moves':23,'all_author_UID_preserved':85,'historical_fields_preserved':37,
  'actual_before_after_outcomes':after['outcomes'],'actual_after_commands':len(after['commands']),'new_real_CLI_cases':3,'source_review368':5689214200,'prior368_CI_success':8,
  'legacy_alchemy148_rejection_retained':True,'full_task03_accepted':False,'Task_Complete_added':False,'GPU_FPS_admission':False,
  'source_SHA256':current,'removed_source_paths':freeze['removed_paths'],
  'report_files':[{'path':p.relative_to(REPORT).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size}for p in sorted(REPORT.rglob('*'))if p.is_file()and p.name!='checks.json'and'__pycache__'not in p.parts]}
 (REPORT/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'version':'0.0.369','suites':len(cases),'cases':sum(cases),'root':314}))
if __name__=='__main__':main()

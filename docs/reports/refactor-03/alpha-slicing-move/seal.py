"""Связывает полный368-кандидат с неизменными источниками и не подменяет независимую приёмку."""
import hashlib
import json
from pathlib import Path
import re

REPORT = Path(__file__).resolve().parent
ROOT = next(p for p in REPORT.parents if (p / 'project.godot').is_file())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def payload(path):
    document = json.loads(path.read_text())
    return json.loads(next(c['text'] for c in document['content'] if c['type'] == 'text'))


def main():
    gates=json.loads((REPORT/'gates-01/gate-exits.json').read_text())
    assert [r['gate'] for r in gates]==['architecture','game','wiki']
    assert all(r['exit']==0 and r['version']=='0.0.368' for r in gates)
    cases=list(map(int,re.findall(r'Ran (\d+) tests? in',(REPORT/'gates-01/architecture.txt').read_text())))
    assert len(cases)==91 and sum(cases)==1237,(len(cases),sum(cases))
    game=(REPORT/'gates-01/game.txt').read_text()
    assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed')==2
    wiki=(REPORT/'gates-01/wiki.txt').read_text()
    assert re.search(r'[ℹ#] pass 145\b',wiki) and re.search(r'[ℹ#] fail 0\b',wiki)
    scope=json.loads((REPORT/'scope.json').read_text())
    freeze=json.loads((REPORT/'source-freeze.json').read_text())
    current={n:sha(ROOT/n) for n in scope['source_paths_after']}
    assert freeze['version']=='0.0.368' and freeze['source_SHA256']==current
    assert all(not(ROOT/n).exists() for n in freeze['removed_paths'])
    ci=payload(REPORT/'baseline/ci367-final.json')
    assert ci['headRevision']==scope['base'] and len(ci['checks'])==8
    assert all(c['conclusion']=='success' for c in ci['checks'])
    assert {123031457667,123020378125}<={c['id'] for c in ci['checks']}
    cancelled=payload(REPORT/'baseline/cancelled-linux-diagnostics.json')
    assert cancelled['job']['id']==123020343023 and cancelled['job']['conclusion']=='cancelled'
    assert cancelled['headRevision']==scope['base']
    catalog=json.loads((REPORT/'catalog.json').read_text())
    browser=json.loads((REPORT/'browser-article.json').read_text())
    assert browser['current_move'] and browser['profile_href']==catalog['profile_href']
    assert json.loads((REPORT/'browser-mobile.json').read_text())['dimensions']=={'width':390,'scrollWidth':390}
    assert json.loads((REPORT/'browser-task.json').read_text())['in_progress']
    cleanup=json.loads((REPORT/'browser-cleanup.json').read_text())
    assert cleanup['own_tab_closed'] and cleanup['own_server_stop_confirmed']
    profile=json.loads((REPORT/'profile.json').read_text())
    assert profile['all5603_frame_signatures_and_RGBA_PNG_equal_before']
    result={'task':'REFACTOR-03','phase':'alpha/slicing physical move with real consumer Git regression',
        'version':'0.0.368','base':scope['base'],'authoritative_gates':gates,
        'architecture_suites':len(cases),'architecture_cases':sum(cases),'game_passed':53502,
        'game_failed':0,'redraw_each_passed':90,'wiki_passed':145,'root_sources':403,
        'physical_source_moves':17,'JSON_moves':2,'ignored_UID_moves':6,'all_author_UID_preserved':85,
        'historical_fields_preserved':37,'new_real_consumer_cases':2,'actual_native_commands':len(profile['native']),
        'actual_foreign_CLI':len(profile['actual_foreign_CLI']),'frames_equal_before':5603,'control_files_equal_before':9,
        'prior367_source_review':5688074197,'prior367_CI_success':8,'cancelled_job_raw_preserved':123020343023,
        'user_queue_after_full03':['REFACTOR-07','REFACTOR-06','first overworld through VMAP-003'],
        'full_task03_accepted':False,'Task_Complete_added':False,'GPU_FPS_admission':False,
        'source_SHA256':current,'removed_source_paths':freeze['removed_paths'],
        'report_files':[{'path':str(p.relative_to(REPORT)),'sha256':sha(p),'bytes':p.stat().st_size}
            for p in sorted(REPORT.rglob('*')) if p.is_file() and p.name!='checks.json' and '__pycache__' not in p.parts]}
    (REPORT/'checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'version':'0.0.368','suites':len(cases),'cases':sum(cases),'root':403}))


if __name__=='__main__':main()

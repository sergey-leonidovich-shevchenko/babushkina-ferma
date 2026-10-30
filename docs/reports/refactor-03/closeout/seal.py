"""Seal the canonical closeout with explicit full-gates and later editorial-check scopes."""
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
from PIL import Image

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/closeout'
BASE='dd506fdd2cb98f1364c0e367c9f73c670064a6d0'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name):return json.loads((R/name).read_text())
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def raw(name):
    p=R/name
    return p.read_bytes() if p.exists() else gzip.decompress(Path(str(p)+'.gz').read_bytes())

assert git(Q,'rev-parse','HEAD').decode().strip()==BASE
assert git(Q,'branch','--show-current').decode().strip()=='codex/refactor-03-completion-record'
initial=load('source-freeze.json');final=load('final-source-freeze.json');sources=final['source_SHA256']
assert len(initial['source_SHA256'])==9 and len(sources)==10
assert all(sha((Q/n).read_bytes())==h for n,h in sources.items())
assert all(sources[n]==h for n,h in initial['source_SHA256'].items())
extra=load('editorial-summary-change.json')
assert set(sources)-set(initial['source_SHA256'])=={extra['file']}
assert extra['only_one_string_changed'] and not extra['card07_added']
before=json.loads((R/'baseline/sources-before-epic-summary.json').read_text())
after=json.loads((Q/extra['file']).read_text())
next(e for p in before['plans'] if p['id']=='refactoring' for e in p['epics'] if e['id']=='REFACTOR')['goal']=extra['after']
assert before==after
assert sha((R/'completion.json').read_bytes())==initial['report_content_inputs']['completion.json']
changed=set(filter(None,git(Q,'diff','--no-renames','--name-only','-z').decode().split('\0')))
untracked=set(filter(None,git(Q,'ls-files','--others','--exclude-standard','-z').decode().split('\0')))
assert changed==set(sources),(changed-set(sources),set(sources)-changed)
assert all(n.startswith(str(R.relative_to(Q))+'/') for n in untracked)
assert not git(Q,'diff','--name-only',BASE,'--','docs/reports').strip()
ledger=git(Q,'ls-tree','-r','-z',BASE,'--','docs/reports')
assert sha(ledger)==initial['existing_report_Git_ledger_SHA256']
preserve=load('preservation-before.json')
assert git(P,'branch','--show-current').decode().strip()==preserve['primary_branch']
for n,row in preserve['primary_foreign'].items():
    assert sha((P/n).read_bytes())==row['working_SHA256'] and sha(git(P,'show',':'+n))==row['index_SHA256'],n
for n,row in preserve['primary_ignored_probe'].items():
    assert sha((P/n).read_bytes())==row['SHA256'] and stat.S_IMODE((P/n).stat().st_mode)==row['mode'],n
uid={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
     for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert uid==preserve['QA_UID'] and len(uid)==304
completion=load('completion.json');approval=load('accepted-review.json');merge=load('accepted-merge.json');ci=load('accepted-CI.json')
assert completion['merged_commit']==BASE and merge['merged'] and merge['merge_commit_sha']==BASE
assert approval['body'].startswith('APPROVED') and completion['accepted_head'] in approval['body']
assert len(ci['checks'])==8 and all(c['conclusion']=='success' for c in ci['checks'])
assert git(Q,'rev-parse',BASE+'^{tree}')==git(Q,'rev-parse',completion['accepted_head']+'^{tree}')
assert completion['canonical_card_date']=='2026-10-30'
gates=load('gates-01/gate-exits.json')
assert [g['gate'] for g in gates]==['wiki','architecture','game']
assert all(g['exit']==0 and g['version']=='0.0.382' for g in gates)
counts=list(map(int,re.findall(r'^Ran (\d+) tests? in ',raw('gates-01/architecture.txt').decode(),re.M)))
assert (len(counts),sum(counts))==(107,1414),(len(counts),sum(counts))
game=raw('gates-01/game.txt').decode()
assert 'TESTS: 53502 passed, 0 failed' in game and game.count('REDRAW: 90 passed, 0 failed')==2
assert 'ℹ pass 145' in raw('gates-01/wiki.txt').decode() and 'ℹ fail 0' in raw('gates-01/wiki.txt').decode()
recheck=load('wiki-recheck.json')
assert recheck['exit']==0 and recheck['metadata_SHA256']==extra['after_SHA256']
assert 'ℹ pass 145' in raw('wiki-recheck/wiki.txt').decode() and 'ℹ fail 0' in raw('wiki-recheck/wiki.txt').decode()
catalog=load('catalog-final.json')
assert catalog['03_status']=='done' and catalog['03_date']=='2026-10-30' and catalog['06_status']=='blocked'
assert catalog['registry_cards']==7 and not catalog['07_card_added'] and catalog['source_public_dist_completion_equal']
browser=load('browser.json')
assert all(browser['task03'][k] for k in ['done','date','pr','acceptedMerge','historyLabel'])
assert browser['epicBefore']['stale'] and not browser['epic']['stale'] and browser['epic']['acceptedGoal']
assert all(browser['task06'][k] for k in ['blocked','dependencyDoneViaAX','next07','ownerConfirmationNotRequired','oldStopRemoved'])
assert load('browser-link-http.json')['exact_completion_bytes']
for label,width,height in [('desktop',1280,900),('mobile',390,844)]:
    assert browser[label]['width']==browser[label]['scrollWidth']==width
    image=Image.open(R/('browser-'+label+'.jpg'));assert image.format=='JPEG' and image.size==(width,height)
cleanup=load('browser-cleanup.json')
assert cleanup['own_server_exit']==143 and cleanup['own_tab_closed']=='29' and cleanup['viewport_reset'] and cleanup['planning_mutations_from_UI']==0
with (R/'README.md').open('a') as stream:
    stream.write('\nФактические проверки учёта382: gates-01 exit0 для architecture107 suites/1414 cases, Game53502/0, normal/F10 по90/0 и исходной Wiki145/0. Отдельный финальный Wiki recheck145/0 проверяет только позднюю редакционную строку goal поверх того же кода и девяти прежних frozen документов. Final-source-freeze содержит10 docs/meta; эти десять не выдаются за первоначальный epoch девятифайлового full gate. Source/public/dist completion.json точны, done03/дата30.10 и blocked06 подтверждены каталогом и браузером. Literal body-проба зависимости06 пропустила перенос строки; исходный false сохранён, видимая AX-ссылка «REFACTOR-03 Завершена» зафиксирована отдельно. Свои вкладка29 и сервер4193 закрыты, viewport reset. Own exact-head review/CI и решение Team Lead ещё обязательны до merge этого учёта.\n')
transcoded=[]
for path in sorted(R.rglob('*.txt')):
    data=path.read_bytes();packed=gzip.compress(data,mtime=0);target=Path(str(path)+'.gz')
    assert not target.exists();target.write_bytes(packed);path.unlink()
    transcoded.append({'raw_path':str(path.relative_to(R)),'stored_path':str(target.relative_to(R)),
        'raw_SHA256':sha(data),'stored_SHA256':sha(packed),'raw_bytes_changed':False})
(R/'raw-log-transcoding.json').write_text(json.dumps(transcoded,indent=2)+'\n')
for source,name in [(__file__,'seal.py'),('/private/tmp/refactor03-closeout-publish382.py','publish.py')]:shutil.copy2(source,R/name)
files=[{'path':str(p.relative_to(R)),'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size}
       for p in sorted(R.rglob('*')) if p.is_file() and p.name!='checks.json']
checks={'task':'REFACTOR-03','phase':'canonical closeout of accepted PR21','version':'0.0.382','base':BASE,
    'source_SHA256':sources,'source_code_changes':0,'UID_preserved':304,'existing_reports_preserved':initial['existing_report_entries'],
    'accepted_implementation_head':completion['accepted_head'],'accepted_implementation_merge':BASE,
    'accepted_implementation_review':5708056404,'accepted_implementation_CI':8,
    'authoritative_full_gates':'gates-01','full_gates_epoch':'initial9 docs/meta unchanged; one goal edited during architecture after initial Wiki; code unchanged throughout; final Wiki checked separately',
    'architecture_suites':107,'architecture_cases':1414,'Game_passed':53502,'Game_failed':0,
    'normal_F10_each':90,'Wiki_initial_passed':145,'final_editorial_Wiki_passed':145,'final_editorial_Wiki_recheck_exit':0,
    'later_editorial_file':'wiki/planning/sources.json (one goal only; registry still7)',
    'Task_Complete_for_already_accepted_source':'REFACTOR-03','done_status_proposed':'REFACTOR-03',
    '06_status':'blocked','07_implementation_started':False,'primary_foreign3_and_probe_preserved':True,
    'new_native_FPS_accepted':False,'VMAP_003_accepted':False,'closeout_merge':False,
    'current_head_review_CI':'own exact-head review/CI and Team Lead decision required','report_files':files}
(R/'checks.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'docs_meta':len(sources),'code_changes':0,'report_files':len(files)+1,
    'architecture':[107,1414],'Game':53502,'Wiki_each':145,'accepted_source':'merged PR21','closeout':'awaiting independent exact-head review/CI'}))

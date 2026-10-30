"""Record the accepted implementation separately from this proposed canonical closeout."""
import hashlib
import json
from pathlib import Path
import shutil
import stat
import subprocess
import sys

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
P=Path('/Users/sergeyshevchenko/my farm')
R=Q/'docs/reports/refactor-03/closeout'
BASE='dd506fdd2cb98f1364c0e367c9f73c670064a6d0'
HEAD='7976630ce372d3e7ac0c15b154ca7377d398450c'
REVIEW='https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5708056404'
sys.path.insert(0,str(Q))
from tools.common.git import git_environment

def sha(raw):return hashlib.sha256(raw).hexdigest()
def git(root,*args):return subprocess.check_output(['git','-C',str(root),*args],env=git_environment())
def load(name):return json.loads((R/name).read_text())
assert git(Q,'rev-parse','HEAD').decode().strip()==BASE
assert git(Q,'branch','--show-current').decode().strip()=='codex/refactor-03-completion-record'
assert (Q/'VERSION').read_text().strip()=='0.0.382'
assert git(Q,'show','-s','--format=%P',BASE).decode().strip()=='d609ab4fa6d82d6d013265183f018b8836abf7cc '+HEAD
tree=git(Q,'rev-parse',BASE+'^{tree}').decode().strip()
assert tree==git(Q,'rev-parse',HEAD+'^{tree}').decode().strip()
date=git(Q,'show','-s','--format=%cI',BASE).decode().strip()
assert date[:10]=='2026-10-30'
review=load('accepted-review.json');merge=load('accepted-merge.json');ci=load('accepted-CI.json')
assert review['body'].startswith('APPROVED') and HEAD in review['body']
assert merge['merged'] and merge['merge_commit_sha']==BASE and merge['head_sha']==HEAD
assert ci['headRevision']==HEAD and len(ci['checks'])==8 and all(c['conclusion']=='success' for c in ci['checks'])
foreign={n:{'working_SHA256':sha((P/n).read_bytes()),'index_SHA256':sha(git(P,'show',':'+n))}
    for n in ['docs/backlog/README.md','docs/epics/refactoring-2026-10/TASKS.md','wiki/planning/sources.json']}
local={n:{'SHA256':sha((P/n).read_bytes()),'mode':stat.S_IMODE((P/n).stat().st_mode)}
    for n in ['tools/foliage_coverage_probe.gd','tools/foliage_coverage_probe.gd.uid']}
uids={str(p.relative_to(Q)):{'SHA256':sha(p.read_bytes()),'mode':stat.S_IMODE(p.stat().st_mode)}
    for p in (Q/'tools').rglob('*.uid') if p.is_file()}
assert len(uids)==304
(R/'preservation-before.json').write_text(json.dumps({'base':BASE,'primary_branch':git(P,'branch','--show-current').decode().strip(),
    'primary_foreign':foreign,'primary_ignored_probe':local,'QA_UID':uids},indent=2)+'\n')
completion={'task':'REFACTOR-03','task_status':'done','implementation_PR':merge['url'],
    'accepted_head':HEAD,'accepted_base':merge['base_sha'],'merged_commit':BASE,'merged_tree':tree,
    'merged_at':merge['merged_at'],'git_committer_date':date,'canonical_card_date':date[:10],
    'date_source':'Calendar part of the accepted implementation merge Git %cI',
    'review':REVIEW,'review_graphql_id':review['id'],'review_submitted_at':review['submitted_at'],
    'reviewer_verdict':'APPROVED whole REFACTOR-03; independent reviewer shared-account COMMENT',
    'team_decision':'Team Lead explicitly accepted exact source head and CI8/8; delegated actual merge to Tech Lead, then canonical closeout to Developer through a separate reviewed PR',
    'accepted_CI':{'head':HEAD,'success':8,'total':8,'runs':[41000256126,41000246600],
        'test_jobs':[123882755333,123882724916],'architecture_each':[107,1414],'Game_each':[53520,0],
        'normal_F10_each':[90,0],'smoke_frames_each':180,'headless_CPU_series_each':6,
        'Wiki_each':[145,0],'source':'Accepted implementation CI and independent final review5708056404; not fresh closeout results'},
    'accepted_local':{'version':'0.0.381','architecture':[107,1414],'Game':[53502,0],'normal_F10_each':[90,0],'Wiki':[145,0],
        'source':'Immutable launch-boundary-review/gates-01; not fresh closeout results'},
    'accepted_scope':{'original_assignments':779,'generic_map':491,'root_sources':11,'root_budget':30,
        'canonical_UID_preserved':304,'contract_fields':37,'contract_modules':21,
        'exceptions':['PIL importer in assets/authoring','performance_protocol facade'],
        'new_native_FPS_accepted':False,'VMAP_003_accepted':False},
    'closeout_branch':'codex/refactor-03-completion-record','closeout_base':BASE,'closeout_version':'0.0.382',
    'closeout_acceptance':'Own checks, exact-head independent review/CI and Team Lead decision required before this accounting PR is merged',
    'changed_task_statuses':{'REFACTOR-03':['in_progress','done']},
    'REFACTOR_06':'blocked; stale owner-stop condition corrected to the currently authorized07→06 order; implementation not started',
    'next_queue':['REFACTOR-07 after accepted closeout03','REFACTOR-06','first overworld route to VMAP-003 with full dependencies'],
    'primary_parallel07_and_local_probe':'preserved separately; neither included in this branch'}
(R/'completion.json').write_text(json.dumps(completion,indent=2,ensure_ascii=False)+'\n')
summary='REFACTOR-03 принята через PR21: 779 назначений сверены, в корне tools 11 исходников при лимите 30. Следом REFACTOR-07, затем REFACTOR-06 и первая overworld до VMAP-003.'
accepted=f'Полная REFACTOR-03 принята через [PR №21](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21): head `{HEAD}`, [независимое ревью 5708056404]({REVIEW}), CI 8/8 и решение Team Lead. Фактический merge `{BASE}` от 30 октября 2026 имеет то же дерево, что проверенный head. Все 779 назначений учтены, в корне tools 11 исходников при лимите 30; сохранены 304 канонических UID и 37 логических полей 21 модуля.'

card_path=Q/'docs/epics/refactoring-2026-10/TASKS.md';card=card_path.read_text()
a,b=card.index('## REFACTOR-03 '),card.index('## REFACTOR-04 ')
section=card[a:b]
assert section.count('**Статус:** in_progress')==1
section=section.replace('**Статус:** in_progress','**Статус:** done',1)
pr='**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21\n'
section=section.replace(pr,pr+'\n**Дата завершения:** 2026-10-30\n',1)
section=section.replace('**Подтверждения / результат:**','**История промежуточного результата:**')
section+='**Подтверждения / результат:** '+accepted+' [Каноническая запись приёмки](../../reports/refactor-03/closeout/completion.json) отделяет принятый CI реализации от собственных проверок учёта. Профили 380/381 и все предыдущие отказы сохранены. Следом07→06→маршрут первой overworld; 04/05 и VMAP-003 не объявляются выполненными.\n\n'
card=card[:a]+section+card[b:]
old='**Условия запуска:** REFACTOR-03 принята и done, актуальная main и принятая карта путей; дополнительно нужна новая прямая команда пользователя. Указание28.10.2026 требует остановиться после текущей03, поэтому06 не запускается автоматически. VMAP-003 не является техническим блокером, но не отменяет пользовательскую остановку.'
new='**Условия запуска:** REFACTOR-03 принята и done; актуальная main и принятая карта путей. Последняя команда пользователя отменяет прежнюю остановку и задаёт порядок07→06:06 берётся после приёмки приоритетной REFACTOR-07. Дополнительное подтверждение владельца не требуется; VMAP-003 не является блокером этой технической очереди.'
assert old in card;card=card.replace(old,new,1)
old='**Подтверждения / результат:** Не начато. Пользовательская остановка28.10.2026: после завершения03 ждать новой прямой команды, не назначать06 автоматически. Эта запись не является реализацией06.'
new='**Подтверждения / результат:** Не начато. Прежнее условие остановки отменено последней прямой командой пользователя; перед06 выполняется REFACTOR-07. Статус06 остаётся blocked до соблюдения текущей очереди; эта запись не является реализацией06.'
assert old in card;card=card.replace(old,new,1);card_path.write_text(card)

for name,link in [('tools/README.md','../docs/reports/refactor-03/closeout/completion.json'),
                  ('wiki/articles/project-refactoring.md','../../docs/reports/refactor-03/closeout/completion.json'),
                  ('docs/epics/refactoring-2026-10/README.md','../../reports/refactor-03/closeout/completion.json')]:
    path=Q/name;old=path.read_text();title,rest=old.split('\n',1)
    history='\n## История промежуточных пакетов\n\nСледующие записи сохраняют состояния прежних кандидатов. Указания in_progress, draft, старые количества и ожидание приёмки в них относятся к своей версии; актуальный итог приведён выше.\n'
    current='\n\n'+accepted+'\n\n[Запись приёмки REFACTOR-03]('+link+'). Исторические отчёты и планы сохранены. Учёт проходит отдельный PR с собственными проверками и независимой приёмкой.\n\nТекущий порядок после принятия учёта03: **REFACTOR-07 → REFACTOR-06 → первая overworld до VMAP-003** по актуальным карточкам и полным зависимостям. Одновременно одна задача; решения, ревью и обычные approved merge выполняются агентами без дополнительных вопросов владельцу.\n'
    path.write_text(title+current+history+rest)
index=Q/'wiki/articles/index.json';text=index.read_text()
old='REFACTOR-02 и его учёт PR19 приняты. REFACTOR-03 в работе: тематические пакеты tools с сохранением команд, UID и исторических доказательств. Итоговый root-бюджет и REFACTOR-06 ещё не приняты.'
assert old in text;index.write_text(text.replace(old,summary,1))
testing=Q/'TESTING.md'
testing.write_text('Учёт REFACTOR-03, версия0.0.382: принятая реализация PR21/head7976630c/merge dd506fdd имеет собственные APPROVED и CI8/8. Для этого отдельного PR выполнить полные architecture, Game/normal/F10 и Wiki check на текущем freeze, затем проверить в браузере done/дату30.10/PR21 и точную JSON-запись приёмки. Прежние 107/1414, Game53502/0 локально и53520/0 в CI относятся к реализации381 и не заменяют проверки учёта. Runtime/tools code/tests/art/frozen evidence не меняются; только канонические документы, summary Wiki и version metadata. Исторические инструкции и прогоны ниже сохраняются как записи своих версий.\n\n'+testing.read_text())
(R/'README.md').write_text('# REFACTOR-03 — учёт принятого полного переноса\n\n'+accepted+'\n\n[completion.json](completion.json) содержит точные Git parents/tree/date, независимый APPROVED и все восемь исходных CI checks. Платформенные CI Game53520/0 и локальный Game53502/0 записаны раздельно. [accepted-review.json](accepted-review.json), [accepted-merge.json](accepted-merge.json) и [accepted-CI.json](accepted-CI.json) сохраняют ответы подключённого GitHub; это принятые проверки реализации, не новые результаты382.\n\nВ этой ветке предлагается каноническое done03 с датой30.10 по Git %cI принятого merge, текущие сводки README/Wiki и удаление устаревшего требования ждать новой команды владельца для06. Статус06 остаётся blocked: прежде выполняется07; сама07, её параллельная постановка и другие карточки не добавляются и не реализуются этим учётом. Старые записи помечены как история вместо переписывания отчётов. Task-Complete: REFACTOR-03 сохраняется только для уже принятой реализации.\n\nИгровой код, инструменты и тесты, графика, UID, исходные планы и все существующие отчёты остаются прежними. Primary находится на своей используемой feature-ветке; три чужих working/index файла07 и ignored probe с UID сохраняются по SHA/mode, не копируются и не staging. Используемая ветка реализации не удаляется.\n\nЭтот PR требует собственных полных TESTING, браузерной проверки, CI точного head, независимого Tech Lead review и решения Team Lead до merge. Ни следующий07, ни06, ни VMAP-003 здесь не закрываются.\n')
shutil.copy2(Q/'docs/reports/refactor-03/launch-boundary-review/run-gates.py',R/'run-gates.py')
shutil.copy2(__file__,R/'record.py')
print(json.dumps({'source_merge':BASE,'done_proposed':['REFACTOR-03'],'06_status':'blocked','primary_untouched':True,'version':'0.0.382'}))

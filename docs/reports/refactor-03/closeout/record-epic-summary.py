"""Correct the stale live epic description found by browser QA; preserve the initial gates epoch."""
import copy
import hashlib
import json
from pathlib import Path
import shutil

Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R=Q/'docs/reports/refactor-03/closeout'
path=Q/'wiki/planning/sources.json';before=path.read_bytes();data=json.loads(before)
source=next(s for s in data['plans'] if s['id']=='refactoring')
epic=next(e for e in source['epics'] if e['id']=='REFACTOR');old=epic['goal']
assert old.endswith('переносы пока не выполнены.')
new='Полная REFACTOR-03 принята через PR21: 779 назначений сверены, в корне tools 11 исходников при лимите30; команды, UID и исторические доказательства сохранены. Далее REFACTOR-07, затем REFACTOR-06 и первая overworld до VMAP-003 по актуальным зависимостям. Адресные04/05 остаются отдельными будущими задачами.'
(R/'baseline').mkdir(exist_ok=True)
(R/'baseline/sources-before-epic-summary.json').write_bytes(before)
text=before.decode();encoded_old=json.dumps(old,ensure_ascii=False);encoded_new=json.dumps(new,ensure_ascii=False)
assert text.count(encoded_old)==1
after=text.replace(encoded_old,encoded_new,1).encode();path.write_bytes(after)
changed=json.loads(after);expected=copy.deepcopy(data)
collection=expected['plans']
next(e for s in collection if s['id']=='refactoring' for e in s['epics'] if e['id']=='REFACTOR')['goal']=new
assert changed==expected
record={'file':'wiki/planning/sources.json','field':'refactoring.epics.REFACTOR.goal',
    'before_SHA256':hashlib.sha256(before).hexdigest(),'after_SHA256':hashlib.sha256(after).hexdigest(),
    'before':old,'after':new,'only_one_string_changed':True,'registry_card_count_still':7,
    'card07_added':False,'primary_parallel07_changed':False,
    'reason':'Browser epic page still claimed that all transfers were unimplemented',
    'full_gates_epoch':'Initial nine-file freeze; accepted implementation/tools/tests bytes unchanged throughout',
    'final_editorial_check':'Separate Wiki check and browser recheck required; this change is not represented as an earlier frozen full-gates input'}
(R/'editorial-summary-change.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n')
with (R/'README.md').open('a') as stream:
    stream.write('\nБраузер выявил отдельное старое описание эпика в Wiki registry: «переносы пока не выполнены». Исправлена только строка refactoring.epics.REFACTOR.goal; expected7 и остальные поля источников не меняются, карточка07 не добавляется. Начальная девятифайловая source-freeze и полный gates-01 сохраняются как свой epoch; код tools/runtime/tests одинаков до и после редакционной правки. Последняя строка registry требует отдельного финального Wiki/browser recheck и собственного exact-head CI; не выдаётся за вход первоначального полного прогона. Primary working/index sources.json с черновиком07 не менялся.\n')
shutil.copy2(__file__,R/'record-epic-summary.py')
print(json.dumps({'changed':'one Wiki epic goal','registry_cards':7,'full_gates_not_relabelled':True,'Wiki_recheck_required':True}))

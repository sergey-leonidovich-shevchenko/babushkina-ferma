"""Apply planned World current/history addressing after actual before profiles; do not move sources."""
import hashlib,json,re,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-inputs-prepare'
b=json.loads((R/'baseline/inventory.json').read_text());plan=json.loads((R/'baseline/adaptation-plan.json').read_text())
assert(R/'before-profile.json').is_file()and len(json.loads((R/'before-profile.json').read_text())['commands'])==36
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==b['base']
for name,row in b['sources'].items():assert hashlib.sha256((Q/name).read_bytes()).hexdigest()==row['sha256'],name
for name,row in plan['changes'].items():assert(Q/name).read_text()==row['before'];(Q/name).write_text(row['after'])
directory=Q/'tools/qa/world';assert directory.is_dir()
for source,target in [('source-inputs.py','source_inputs.py'),('test-world-source-history.py','test_world_source_history.py'),('test-source-inputs.py','test_source_inputs.py'),('test-world-producers.py','test_world_producers.py')]:
    out=directory/target;assert not out.exists();shutil.copyfile(R/'baseline'/source,out)
p=Q/'.gitignore';p.write_text(p.read_text()+'\n# REFACTOR-03 World current/history input preparation; physical files remain in place.\n!tools/qa/world/source_inputs.py\n!tools/qa/world/test_world_source_history.py\n!tools/qa/world/test_source_inputs.py\n!tools/qa/world/test_world_producers.py\n')
p=Q/'tools/quality/check_architecture.sh';s=p.read_text();marker='python3 tools/run.py qa.world.test_world_context\n';assert s.count(marker)==1
p.write_text(s.replace(marker,marker+'python3 tools/run.py qa.world.test_source_inputs\npython3 tools/run.py qa.world.test_world_source_history\npython3 tools/run.py qa.world.test_world_producers\n'))
paragraph=('Подготовка0.0.376 world-inputs отделяет37 current-input sites от14 Git-history sites в25 исходниках. '
 'Новый helper совмещает прежние art/current maps и141 известных исторических World alias из исходного принятого плана; '
 'это не объявляет физический перенос. Уникальный old/new alias выбирается только из того же полного Git commit, '
 'с проверкой своего checkout, типа/mode и symlink; нет live fallback. Source lists, архивные имена, численные пороги и прежние metadata сохранены. '
 'Audit evidence-каталоги сохраняют отдельное разрешение tree и точные git-show header bytes. '
 'Исправлены FOLDER водного анализатора и P3 повторного импорта из review5693715399. '
 '12 integration-тестов читают настоящие Git/capsule bytes в будущем canonical дереве: до1fail/10errors и1 позитивный контроль; '
 '16 API-контролей проверяют настоящий Git/alias/mode/worktree/replace/foreign context. '
 '13 actual producer используют настоящие Git/SHA/copy и явно fake-open17; process inventory/context являются source-only фикстурами, '
 'native кадров и новой Game/GPU/FPS приёмки нет. Прежние19 context cases и15 old negative suites сохраняются. '
 '36 before/after CLI плюс настоящий Water writer в собственной копии четырёх raw сравниваются отдельно; frozen WATER не перезаписывается. '
 'Физических/UID переносов нет, root245, current map133; shared sources пока прежние. '
 '375 exact e205c007 принят SOURCE PASS5693715399/Team и CI8/8;376 требует собственных полных TESTING/Wiki/browser/CI/review. '
 '03 остаётся in_progress/PR21draft, полного merge/Task-Complete нет.')
p=Q/'tools/README.md';s=p.read_text();marker='# Инструменты проекта\n';assert s.count(marker)==1;p.write_text(s.replace(marker,marker+'\n'+paragraph+'\n\n[Профиль подготовки World-входов376](../docs/reports/refactor-03/world-inputs-prepare/after-profile.json).\n',1))
p=Q/'wiki/articles/project-refactoring.md';s=p.read_text();marker='Подготовка0.0.375 world исправляет9';assert s.count(marker)==1;p.write_text(s.replace(marker,paragraph+'\n\n[Профиль подготовки World-входов376](../../docs/reports/refactor-03/world-inputs-prepare/after-profile.json).\n\n'+marker,1))
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a,c=s.index('## REFACTOR-03 '),s.index('## REFACTOR-04 ');p.write_text(s[:a]+s[a:c].rstrip()+' '+paragraph+' [Профиль376](../../reports/refactor-03/world-inputs-prepare/after-profile.json).\n\n'+s[c:])
p=Q/'docs/epics/refactoring-2026-10/README.md';s=p.read_text()
s,n=re.subn(r'(?m)^\*\*Остановка после текущей задачи:\*\*.*$', '**Текущая прямая команда пользователя:** прежняя остановка после03 отменена. Полностью завершаем и принимаем REFACTOR-03, затем REFACTOR-07, REFACTOR-06 и обычный маршрут первой overworld до VMAP-003 по актуальным зависимостям. Одновременно одна задача; отдельные PR, фактические проверки, независимое exact-head ревью, решение Team Lead, merge и учёт выполняются агентами без дополнительных подтверждений владельца. Новые механики/карты и обход ревью не разрешены.',s);assert n==1
old='Теперь03 в работе; после её полного завершения действует остановка пользователя28.10.2026.06 и обычный маршрут первой overworld не начинаются до новой прямой команды. Нынешние 420 корневых исходников ещё не проходят итоговый бюджет30; package marker меняет прогноз полного выпуска с9 на10.'
assert s.count(old)==1;s=s.replace(old,'Теперь03 в работе по последней прямой команде пользователя без прежней остановки; после полной приёмки03 следуют07,06 и актуальный маршрут первой overworld до VMAP-003. Текущий корень245 ещё не проходит итоговый бюджет30. Исторический package marker увеличивал прогноз9→10, а принятый protocol facade — до11; фактический итог проверяется в полном03 и06.')
s=s.replace('# REFACTOR — Понятная структура инструментов и модулей проекта\n','# REFACTOR — Понятная структура инструментов и модулей проекта\n\n'+paragraph+'\n',1);p.write_text(s)
for name in['TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md']:
    p=Q/name;p.write_text('REFACTOR-03 world-inputs0.0.376: `python3 tools/run.py qa.world.test_source_inputs`, `qa.world.test_world_source_history` и `qa.world.test_world_producers` проверяют16 real-Git API,12 source-history/FOLDER и13 actual producer случаев. Source-only fake-open/context/inventory не являются native/Game/GPU/FPS допуском; полные architecture/Game/normal/F10/Wiki и браузер обязательны. Профиль `docs/reports/refactor-03/world-inputs-prepare/` сохраняет36 old CLI и настоящий Water writer на собственной копии raw; frozen evidence/метрики/UID/source lists прежние. Root245,map133,physical moves0; P3 duplicate import исправлен.\n\n'+p.read_text())
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.376'],cwd=Q,check=True)
for source,target in[(str(Path(__file__)),'apply.py'),('/private/tmp/refactor03-world-profile376.py','profile.py')]:shutil.copyfile(source,R/target)
print(json.dumps({'source_files':25,'current_input_sites':37,'history_sites':14,'new_files':4,'P3_removed':True,'physical_moves':0,'root':245,'map':133}))

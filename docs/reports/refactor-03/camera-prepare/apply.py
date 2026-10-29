"""Apply address-only camera preparation after the actual before profile."""
import hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-prepare'
plan=json.loads((R/'baseline/adaptation-plan.json').read_text());b=json.loads((R/'baseline/inventory.json').read_text())
assert(R/'before-profile.json').is_file()
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==b['base']
for n,row in b['sources'].items():assert hashlib.sha256((Q/n).read_bytes()).hexdigest()==row['sha256'],n
for n,row in plan['changes'].items():assert(Q/n).read_text()==row['before'];(Q/n).write_text(row['after'])
directory=Q/'tools/qa/camera';assert not directory.exists();directory.mkdir()
(directory/'__init__.py').write_text('"""Проверки камеры, записей и контекста визуальных инструментов."""\n')
shutil.copyfile(R/'baseline/camera-context-test.py',directory/'test_camera_context.py')
p=Q/'.gitignore';p.write_text(p.read_text()+'\n# REFACTOR-03: camera context preparation; source implementations have not moved.\n!tools/qa/camera/\ntools/qa/camera/*\n!tools/qa/camera/__init__.py\n!tools/qa/camera/test_camera_context.py\n')
p=Q/'tools/quality/check_architecture.sh';s=p.read_text();marker='python3 tools/run.py qa.performance.test_surface_producers\n';assert s.count(marker)==1;p.write_text(s.replace(marker,marker+'python3 tools/run.py qa.camera.test_camera_context\n'))
paragraph=('Подготовка0.0.373 camera привязывает6 source-root и9 Git-read sites к исходнику/явному проекту. '
 'Двенадцать новых реальных context-сценариев: до правки16 failures с учётом subtests, после12/0 на том же source SHA. '
 'Проверены вложенные импорты шести настоящих модулей и восемь actual producer: семь запускают только явный fake-child, '
 'timing останавливается после source.json перед проверкой процессов. Git/SHA/copy/archive и прежние logical source keys настоящие; '
 'неполные пакеты отклоняются штатными readers. Это проверка source envelope, без native/GPU/FPS допуска. '
 'Двадцать прежних CLI/отрицательных suites сравниваются из чужой cwd/Git; старые evidence не переписываются. '
 'Физических переносов и UID-перемещений нет, root285. '
 '372 head57612b62 принят промежуточным review5692067678/Team и CI8/8; для373 обязательны собственные полные gates/CI/review. '
 '03 остаётся in_progress/PR21draft, полного merge/Task-Complete нет.')
p=Q/'tools/README.md';s=p.read_text();p.write_text(s.replace('# Инструменты проекта\n','# Инструменты проекта\n\n'+paragraph+'\n\n[Профиль подготовки камеры](../docs/reports/refactor-03/camera-prepare/after-profile.json).\n',1))
p=Q/'wiki/articles/project-refactoring.md';s=p.read_text();marker='Доработка P2 0.0.372';assert s.count(marker)==1;p.write_text(s.replace(marker,paragraph+'\n\n[Профиль подготовки камеры373](../../docs/reports/refactor-03/camera-prepare/after-profile.json).\n\n'+marker,1))
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a,c=s.index('## REFACTOR-03 '),s.index('## REFACTOR-04 ');section=s[a:c].rstrip()+' '+paragraph+' [Профиль373](../../reports/refactor-03/camera-prepare/after-profile.json).\n\n';p.write_text(s[:a]+section+s[c:])
for n in ['TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md']:
 p=Q/n;p.write_text('REFACTOR-03 camera0.0.373: `python3 tools/run.py qa.camera.test_camera_context` проверяет12 настоящих сценариев вложенного source-root/Git и новых source-envelope до нативного запуска. Семь дочерних fake-engine/open не рисуют кадры; timing останавливается перед нативным контекстом. Неполный вывод не принимается штатными verifiers. Системные команды сохраняют cwd/env, только Git получает явный проект и чистые overrides. Реальные before/after20 CLI и raw — в `docs/reports/refactor-03/camera-prepare/`. Без физических переносов/нового FPS допуска; обязательны полный architecture/Game/Wiki и браузер нового кандидата.\n\n'+p.read_text())
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.373'],cwd=Q,check=True)
shutil.copyfile(__file__,R/'apply.py');shutil.copyfile('/private/tmp/refactor03-camera-profile373.py',R/'profile.py')
print(json.dumps({'source_files':len(plan['changes']),'root_sites':6,'Git_sites':9,'new_tests':12,'physical_moves':0,'root_sources':285}))

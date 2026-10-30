"""Apply only World source-root/Git preparation after its real accepted baseline profile."""
import hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/world-prepare'
b=json.loads((R/'baseline/inventory.json').read_text());plan=json.loads((R/'baseline/adaptation-plan.json').read_text())
assert(R/'before-profile.json').is_file()and len(json.loads((R/'before-profile.json').read_text())['commands'])==35
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==b['base']
for name,row in b['sources'].items():assert hashlib.sha256((Q/name).read_bytes()).hexdigest()==row['sha256'],name
for name,row in plan['changes'].items():assert(Q/name).read_text()==row['before'];(Q/name).write_text(row['after'])
directory=Q/'tools/qa/world';assert not directory.exists();directory.mkdir()
(directory/'__init__.py').write_text('"""Проверки окружения, деревни и объектов первой локации."""\n')
shutil.copyfile(R/'baseline/world-context-test.py',directory/'test_world_context.py')
p=Q/'.gitignore';p.write_text(p.read_text()+'\n# REFACTOR-03 World context preparation; original implementations have not moved yet.\n!tools/qa/world/\ntools/qa/world/*\n!tools/qa/world/__init__.py\n!tools/qa/world/test_world_context.py\n')
p=Q/'tools/quality/check_architecture.sh';s=p.read_text();marker='python3 tools/run.py qa.camera.test_camera_layout\n';assert s.count(marker)==1;p.write_text(s.replace(marker,marker+'python3 tools/run.py qa.world.test_world_context\n'))
paragraph=('Подготовка0.0.375 world исправляет9 source-root и42 Git-read sites в24 исходниках. '
 'Девятнадцать новых real-context тестов воспроизводят red12fail/19error с учётом subtests; green фиксируется отдельным raw. '
 'Девять настоящих вложенных import, полные исторические provenance деревни/рендера/теней/пилота/сохранения и четыре actual writer/producer '
 'используют реальные Git, SHA и файлы. Два collector останавливаются после source.json перед native context, '
 'shadow writer — после настоящих JSON/CSV перед платформенными шрифтами/листами; это не native/GPU/FPS приёмка. '
 'До/после запускаются35 actual CLI:15 исторических readers,6 asset verifier и14 прежних отрицательных suites. '
 'Frozen source namespaces/архивы, алгоритмы, бюджеты, UID и shared points/encoder сохранены. '
 'Физических переносов пока нет, корень245.374 head6b13af8e принят промежуточным review5693093074/Team и CI8/8; '
 '375 требует собственных полных TESTING/Wiki/browser/CI и independent exact-head review. Полная03 остаётся in_progress/PR21draft.')
p=Q/'tools/README.md';s=p.read_text();marker='# Инструменты проекта\n';assert s.count(marker)==1;p.write_text(s.replace(marker,marker+'\n'+paragraph+'\n\n[Профиль подготовки мира375](../docs/reports/refactor-03/world-prepare/after-profile.json).\n',1))
p=Q/'wiki/articles/project-refactoring.md';s=p.read_text();marker='Пакет0.0.374 camera переносит40';assert s.count(marker)==1;p.write_text(s.replace(marker,paragraph+'\n\n[Профиль подготовки мира375](../../docs/reports/refactor-03/world-prepare/after-profile.json).\n\n'+marker,1))
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a,c=s.index('## REFACTOR-03 '),s.index('## REFACTOR-04 ');p.write_text(s[:a]+s[a:c].rstrip()+' '+paragraph+' [Профиль375](../../reports/refactor-03/world-prepare/after-profile.json).\n\n'+s[c:])
for name in ['TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md']:
    p=Q/name;p.write_text('REFACTOR-03 world0.0.375: `python3 tools/run.py qa.world.test_world_context` проверяет19 реальных nested/Git/archive/writer/producer сценариев.35 before/after CLI сохраняют15 historical readers,6 asset verifier и14 прежних отрицательных suites. Исторические источники/архивы и бюджеты прежние; physical moves нет,root245. Producer stop до native и font stop после JSON/CSV не дают нового native/Game/GPU/FPS допуска. Полные architecture/Game/normal/F10/Wiki и браузер обязательны; профиль — `docs/reports/refactor-03/world-prepare/after-profile.json`.\n\n'+p.read_text())
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.375'],cwd=Q,check=True)
for source,target in [(str(Path(__file__)),'apply.py'),('/private/tmp/refactor03-world-profile375.py','profile.py')]:shutil.copyfile(source,R/target)
print(json.dumps({'source_files':24,'source_root_sites':9,'Git_read_sites':42,'new_tests':19,'root_sources':245,'physical_moves':0}))

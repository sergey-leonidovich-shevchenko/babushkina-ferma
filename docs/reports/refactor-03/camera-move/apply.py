"""Apply bounded camera40 after actual before profiles, preserving all UID and two shared anchors."""
import hashlib,json,shutil,subprocess
from pathlib import Path
Q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm');R=Q/'docs/reports/refactor-03/camera-move'
plan=json.loads((R/'baseline/move-plan.json').read_text());b=json.loads((R/'baseline/inventory.json').read_text());profile=json.loads((R/'before-profile.json').read_text());assert len(profile['commands'])==40 and all(r['exit']==0 for r in profile['commands'])
assert subprocess.check_output(['git','-C',str(Q),'rev-parse','HEAD'],text=True).strip()==b['base']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for n,row in b['sources'].items():assert sha(Q/n)==row['sha256'],n
for row in plan['moves']:assert not(Q/row['target']).exists(),row['target']
for row in plan['local_UID']:assert sha(Q/row['old_path'])==row['sha256']and not(Q/row['target']).exists()
journal=[]
for row in [*plan['moves'],*plan['local_UID']]:
 old,target=Q/row['old_path'],Q/row['target'];target.parent.mkdir(parents=True,exist_ok=True);old.rename(target);journal.append({'old':row['old_path'],'new':row['target'],'sha256':sha(target)});(R/'apply-journal.json').write_text(json.dumps(journal,indent=2)+'\n')
mapping={r['old_path']:r['target']for r in plan['moves']}
for n,row in plan['changes'].items():
 p=Q/mapping.get(n,n);assert p.read_text()==row['before'],n;p.write_text(row['after'])
shutil.copyfile(R/'baseline/camera-layout-test.py',Q/'tools/qa/camera/test_camera_layout.py')
p=Q/'.gitignore';p.write_text(p.read_text()+'\n# REFACTOR-03: camera40; shared camera points/video encoder are deferred with their consumers.\n!tools/qa/camera/*.py\n!tools/qa/camera/*.gd\n!tools/qa/camera/*.swift\n'+''.join('!'+r['target']+'\n'for r in plan['moves']if r['target'].endswith('.uid')))
p=Q/'tools/quality/check_architecture.sh';text=p.read_text()
for old in mapping:
 if old.endswith('.py'):text=text.replace('python3 '+old,'python3 tools/run.py qa.camera.'+Path(old).stem)
marker='python3 tools/run.py qa.camera.test_camera_context\n';assert text.count(marker)==1;p.write_text(text.replace(marker,marker+'python3 tools/run.py qa.camera.test_camera_layout\n'))
# Live instructions change; frozen plans/reports and the original migration table remain byte-exact.
docs=['TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md','tools/README.md','wiki/articles/visual-motion.md','wiki/articles/visual-camera-motion.md','wiki/articles/visual-hardware.md','wiki/articles/visual-pose.md']
for n in docs:
 p=Q/n;text=p.read_text()
 for old,target in sorted(mapping.items(),key=lambda r:-len(r[0])):
  text=text.replace(old,'tools/run.py qa.camera.'+Path(old).stem if old.endswith('.py')else target)
 p.write_text(text)
paragraph=('Пакет0.0.374 camera переносит40 исходников и2 tracked UID в `tools/qa/camera`, сохраняя15 ignored UID: root285→245. '
 'Два общих источника `visual_camera_points.gd` и `encode_coordinate_video.swift` остаются на своих местах до связанных пакетов их потребителей; '
 'это отложенные строки исходной карты, а не отмена переноса или новый окончательный допуск. '
 'Живые imports/preload/CLI и физические input reads обновлены, логические SOURCES/архивные назначения прежние. '
 'Новая запись timing содержит полную known source_paths; reader связывает с ней точный старый/новый launch URI и отклоняет unknown/partial metadata. '
 'Три новых layout-сценария воспроизвели red6fail/1error, после переноса ожидаются3/0 тем же source. '
 'Прежние12 actual-producer context-тестов сохраняют ID/assertions с адресной адаптацией фикстур. '
 'До/после сравниваются настоящие22 CLI,17 compile-only Godot и офлайн-декодирование16 кадров из прежних MP4 плюс contact sheet. '
 'Это не новая native/Game/GPU/FPS-приёмка профиля. '
 '373 headd2ff4bde принят промежуточным review5692493268/Team, его CI завершился8/8. '
 'Для374 обязательны собственные полные TESTING/Wiki/CI и независимое ревью нового exact head.03 in_progress/PR21draft, полного merge/Task-Complete нет.')
p=Q/'tools/README.md';s=p.read_text();p.write_text(s.replace('# Инструменты проекта\n','# Инструменты проекта\n\n'+paragraph+'\n\n[Профиль переноса камеры374](../docs/reports/refactor-03/camera-move/after-profile.json).\n',1))
p=Q/'wiki/articles/project-refactoring.md';s=p.read_text();marker='Подготовка0.0.373 camera';assert s.count(marker)==1;old='В текущем кандидате корень tools составляет285 исходников';assert s.count(old)==1;s=s.replace(old,'В текущем кандидате корень tools составляет245 исходников');p.write_text(s.replace(marker,paragraph+'\n\n[Профиль переноса камеры374](../../docs/reports/refactor-03/camera-move/after-profile.json).\n\n'+marker,1))
p=Q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a,c=s.index('## REFACTOR-03 '),s.index('## REFACTOR-04 ');section=s[a:c].rstrip()+' '+paragraph+' [Профиль374](../../reports/refactor-03/camera-move/after-profile.json).\n\n';p.write_text(s[:a]+section+s[c:])
for name in ['TESTING.md','QA_CHECKLIST.md','docs/DEVELOPMENT.md']:
 p=Q/name;p.write_text('REFACTOR-03 camera40 0.0.374: `python3 tools/run.py qa.camera.test_camera_context` сохраняет12 real-producer контролей; `python3 tools/run.py qa.camera.test_camera_layout` добавляет3 случая canonical missing/closed metadata/точного launch URI. GDScript — `res://tools/qa/camera/`, Python — `python3 tools/run.py qa.camera.<модуль>`. Shared points/video encoder остаются до consumer-пакетов.40 source/2 tracked UID/15 ignored UID, root245; полный TESTING, Wiki/браузер и независимое ревью обязательны.\n\n'+p.read_text())
for n,row in b['deferred_shared_anchors'].items():assert sha(Q/n)==row['sha256']and(Q/n).stat().st_mode&0o777==row['mode']
subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.374'],cwd=Q,check=True)
shutil.copyfile(__file__,R/'apply.py');shutil.copyfile('/private/tmp/refactor03-camera-profile374.py',R/'profile.py')
(R/'migration.json').write_text(json.dumps({'base':b['base'],'root_before':285,'root_sources_after_moves':245,'moves':plan['moves'],'local_UID':plan['local_UID'],'deferred_shared_anchors':plan['deferred_shared_anchors'],'final_task_complete':False},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'source_moves':40,'tracked_UID':2,'ignored_UID':15,'root_after':245,'new_layout_tests':3,'deferred_sources':2}))

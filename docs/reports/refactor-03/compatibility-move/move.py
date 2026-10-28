"""Move the compatibility assignment exactly, changing only executable imports and live commands."""
import hashlib,json,shutil,subprocess
from pathlib import Path
REPORT=Path(__file__).resolve().parent
ROOT=next(p for p in REPORT.parents if(p/'project.godot').is_file())
def main():
 base=json.loads((REPORT/'baseline/inventory.json').read_text());assert(REPORT/'before-profile.json').is_file()
 mapping={n:r['target']for n,r in base['assignments'].items()}
 for old,new in mapping.items():
  assert hashlib.sha256((ROOT/old).read_bytes()).hexdigest()==base['sources'][old]['sha256'],old
  assert not(ROOT/new).exists(),new
 path=ROOT/'.gitignore';text=path.read_text()+'\n# REFACTOR-03: compatibility source; only previously tracked UID are included.\n!tools/qa/compatibility/\ntools/qa/compatibility/*\n!tools/qa/compatibility/*.py\n!tools/qa/compatibility/*.gd\n'
 text+=''.join('!'+new+'\n'for old,new in mapping.items()if old.endswith('.uid'));path.write_text(text)
 for old,new in mapping.items():
  (ROOT/new).parent.mkdir(parents=True,exist_ok=True);subprocess.run(['git','mv','--',old,new],cwd=ROOT,check=True)
 for row in base['local_UID']:
  p=ROOT/row['old_path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'];p.rename(ROOT/row['target'])
 for n in [*mapping.values(),'tools/assets/slicing/slice_review.gd','tools/water_fishing_review.gd','tools/water_navigation_review.gd','tools/water_topology_review.gd']:
  if not n.endswith('.gd'):continue
  path=ROOT/n;text=path.read_text()
  for old,new in mapping.items():text=text.replace('"res://'+old+'"','"res://'+new+'"')
  path.write_text(text)
 path=ROOT/mapping['tools/check_alchemy_reports.py'];text=path.read_text().replace('ROOT = Path(__file__).resolve().parents[1]', 'from tools.common.paths import project_root\n\nROOT = project_root(__file__)');path.write_text(text)
 (ROOT/'tools/qa/compatibility/__init__.py').write_text('"""Совместимость прежних игровых сценариев и инструментов проверки."""\n')
 shutil.copyfile('/private/tmp/refactor03-test-compatibility369.py',ROOT/'tools/qa/compatibility/test_compatibility_cli.py')
 path=ROOT/'tools/quality/check_architecture.sh';text=path.read_text();marker='python3 tools/run.py assets.alpha.test_street_consumer\n';assert marker in text;text=text.replace(marker,marker+'python3 tools/run.py qa.compatibility.test_compatibility_cli\n');path.write_text(text)
 for n in base['live_documents']:
  path=ROOT/n;text=path.read_text()
  for old,new in mapping.items():
   if old.endswith('.py'):text=text.replace('python3 '+old,'python3 tools/run.py '+new.removeprefix('tools/').removesuffix('.py').replace('/','.'))
   text=text.replace(old,new)
  path.write_text(text)
 path=ROOT/'TESTING.md';path.write_text('REFACTOR-03, compatibility0.0.369: `python3 tools/run.py qa.compatibility.test_compatibility_cli` проверяет3 реальных процесса с чужой cwd/Git. '
  '89 прежних source/64 tracked UID и23 ignored UID перенесены по принятой карте. Parse всех87 GD, реальные каталоги/граф циклов и четыре headless сценария сравниваются до/после; это не новая GPU/FPS-приёмка. Полные gates и независимое ревью точного head обязательны.\n\n'+path.read_text())
 path=ROOT/'tools/README.md';text=path.read_text().replace('# Инструменты проекта\n','# Инструменты проекта\n\nПакет0.0.369 переносит89 compatibility source и64 tracked UID, сохраняет23 ignored UID: root403→314. '
  'Godot-профили теперь в `res://tools/qa/compatibility/`; команды Python — `python3 tools/run.py qa.compatibility.farm_cycles <catalog> <output>` и `python3 tools/run.py qa.compatibility.check_alchemy_reports`. '
  '[Сравнение](../docs/reports/refactor-03/compatibility-move/after-profile.json) сохраняет реальные before/after результаты. 368 принят промежуточным source review5689214200/Team и CI8/8. Полная03 остаётся in_progress до root≤30 и финальной приёмки.\n');path.write_text(text)
 paragraph=('Пакет0.0.369 переносит89 compatibility source и64 tracked UID, сохраняя23 ignored UID: root403→314. '
  '[Профиль после переноса369](../../docs/reports/refactor-03/compatibility-move/after-profile.json) сравнивает настоящие команды, каталоги и граф циклов до/после. '
  'Проверяются87 GD и три публичных CLI-сценария. 368 принят промежуточным source review5689214200/Team и CI8/8. '
  'Для369 нужны собственные gates/CI и независимое ревью нового head;03 in_progress, финального merge нет.\n\n')
 path=ROOT/'wiki/articles/project-refactoring.md';text=path.read_text();assert 'Пакет0.0.368 переносит17' in text;text=text.replace('Пакет0.0.368 переносит17',paragraph+'Пакет0.0.368 переносит17',1)
 text=text.replace('В текущем кандидате корень tools составляет481 исходник','В текущем кандидате корень tools составляет314 исходников')
 text=text.replace('По актуальному указанию28.10.2026 после полного завершения03 останавливаемся;06 требует новой прямой команды.', 'По последней прямой команде пользователя после полной приёмки03 продолжаем07 →06 → обычный маршрут первой overworld до VMAP-003 без дополнительных подтверждений владельца.')
 path.write_text(text)
 path=ROOT/'docs/epics/refactoring-2026-10/TASKS.md';text=path.read_text();a,b=text.index('## REFACTOR-03 '),text.index('## REFACTOR-04 ');section=text[a:b].rstrip()+' '+paragraph.replace('../../docs/reports/','../../reports/')+'\n';path.write_text(text[:a]+section+text[b:])
 subprocess.run(['python3','tools/run.py','planning.bump_version','--set','0.0.369'],cwd=ROOT,check=True)
 print(json.dumps({'moves':len(mapping),'root_after':314,'ignored_UID':len(base['local_UID'])}))
if __name__=='__main__':main()

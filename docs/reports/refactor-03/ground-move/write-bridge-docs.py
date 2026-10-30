"""Record the real gate failure and narrowly audited source-hash relocation repair."""
from pathlib import Path
import json
import hashlib

q=Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
r=q/'docs/reports/refactor-03/ground-move'
sha=lambda raw:hashlib.sha256(raw).hexdigest()
patch=json.loads((r/'source-bridge-patch.json').read_text())
for row in patch.values():
    row['before_SHA256']=sha(row['before'].encode())
    row['after_SHA256']=sha(row['after'].encode())
(r/'source-bridge-patch.json').write_text(json.dumps(patch,indent=2)+'\n')
p=Path('/private/tmp/refactor03-ground-audit379.py'); s=p.read_text()
s=s.replace("mapping = {r['old_path']: r['target'] for r in plan['moves']}","mapping = {r['old_path']: r['target'] for r in plan['moves']}\nbridge = json.loads((R / 'source-bridge-patch.json').read_text())")
s=s.replace("expected = plan['changes'].get(name, {}).get('after_SHA256', row['sha256'])","expected = bridge.get(target, {}).get('after_SHA256', plan['changes'].get(name, {}).get('after_SHA256', row['sha256']))")
s=s.replace("assert UID_after == UID_expected and len(UID_after) == 302","new_UID = {n: UID_after[n] for n in ['tools/qa/ground/compiled_sources.gd.uid', 'tools/qa/ground/compiled_sources_review.gd.uid']}\nassert UID_after == dict(UID_expected, **new_UID) and len(UID_after) == 304")
s=s.replace("    assert sha(actual.encode()) == row['after_SHA256'], target", "    if target in bridge:\n        repair = bridge[target]\n        assert actual == repair['after'] and sha(actual.encode()) == repair['after_SHA256'], target\n        assert sha(repair['before'].encode()) == row['after_SHA256'], target\n        actual = repair['before']\n    assert sha(actual.encode()) == row['after_SHA256'], target")
s=s.replace("'mapping_exactly_original113_rows': True, 'UID_bytes_mode_equal': 302", "'mapping_exactly_original113_rows': True, 'UID_bytes_mode_equal': 302,\n    'new_UID': new_UID, 'source_bridge_changes_audited_separately': sorted(bridge)")
s=s.replace("scope = json.loads((R / 'scope-initial.json').read_text())", "scope = json.loads((R / 'scope.json').read_text())")
s=s.replace("'UID': 302, 'frozen_fields': 37", "'UID_preserved': 302, 'UID_new': 2, 'frozen_fields': 37")
p.write_text(s)
scope=json.loads((r/'scope.json').read_text())
newfiles=['tools/qa/ground/compiled_sources.gd','tools/qa/ground/compiled_sources.gd.uid','tools/qa/ground/compiled_sources_review.gd','tools/qa/ground/compiled_sources_review.gd.uid','tools/qa/ground/test_compiled_sources.py']
scope['source_paths_after']=sorted(set(scope['source_paths_after']+newfiles))
scope['source_bridge_repair']='source-bridge-patch.json'
scope['new_UID']=newfiles[1:4:2]
(r/'scope.json').write_text(json.dumps(scope,indent=2,ensure_ascii=False)+'\n')
plan=json.loads((r/'PLAN.json').read_text())
plan.update(all_tools_UID_preserved=302,all_tools_UID=304,new_QA_UID=2,
    bridge_tests={'Python':2,'provenance':101,'fresh':36,'fresh_masks':9},
    gate01_failure='25 source-hash assertions after relocation; raw retained')
(r/'PLAN.json').write_text(json.dumps(plan,indent=2,ensure_ascii=False)+'\n')
for name in ['TESTING.md','QA_CHECKLIST.md','tools/README.md','wiki/articles/project-refactoring.md']:
    p=q/name;s=p.read_text();prefix='Перенос Ground 0.0.379:'
    a=s.index(prefix) if prefix in s else 0
    b=s.index('\n\n',a) if prefix in s else 0
    first=s[a:b].replace('34 Python','35 Python').replace('14 тестов','15 тестов')
    note=' Для frozen масок добавлен QA-only bridge семи путей: прежние SHA принимаются только при точном обратном преобразовании quoted preload URI; любые другие изменения байтов и отсутствующий canonical источник отклоняются. Четыре fresh compiler записывают реальные текущие SHA, сохраняя логические ключи. Два интеграционных теста проверяют 101 provenance-контроль и 36 проверок девяти новых масок, с неизменными geometry/UV/colour bytes. Игровые .res не пересоздаются. Первый полный Game дал 25 ошибок старых source paths; отказ сохранён, исправление проверяется новой полной серией gates-02. Сохранены 302 прежних UID, добавлены два QA-only UID.'
    p.write_text(s[:a]+first+note+s[b:] if b else 'REFACTOR-03 Ground379.'+note+'\n\n'+s)
p=r/'README.md';s=p.read_text().replace('все 34 новых','все 35 новых').replace('14 тестовых','15 тестовых')
s=s.replace('Итоговые raw появятся в `gates-01`','Первый полный Game в `gates-01` дал 25 source-path ошибок; отказ сохранён. Итоговые raw после исправления появятся в `gates-02`')
s+='\n## Проверка frozen и новых масок\n\nПервый полный Game: 53477 passed / 25 failed. Старые логические ключи source_sha256 указывали на переехавшие builder/field. Готовые runtime .res и frozen отчёты оставлены побайтно прежними. QA-only compiled_sources принимает актуальные байты либо их SHA после точного обратного преобразования семи quoted preload URI; прочие изменения, missing canonical/stale root, неизвестные ключи, пустые и частичные хеши отклоняются. Компиляторы новых масок используют SHA текущих файлов с прежними логическими ключами.\n\n[Точная поправка восьми потребителей](source-bridge-patch.json) отделена от URI-only аудита переноса. [Прогон двух тестов](source-bridge-test-attempt02.txt): 101 provenance и 36 fresh checks; четыре настоящих компилятора построили девять масок в временных каталогах. Их geometry/UV/colour bytes и mask_spec равны frozen ресурсам. Первый запуск нового review имел ошибку вывода типа String; [raw](source-bridge-test-attempt01.txt) сохранён. Новые два UID относятся только к QA helper/review; прежние 302 UID сохранены. [Freeze до исправления](before-source-bridge/source-freeze.json) не перезаписан.\n'
p.write_text(s)
p=q/'docs/epics/refactoring-2026-10/TASKS.md';s=p.read_text();a=s.index('## REFACTOR-03 ');b=s.index('## REFACTOR-04 ')
section=s[a:b]+'- Ground379: первый Game выявил25 source-hash ошибок после переноса; QA-only bridge сохраняет frozen .res и различает точный preload move от изменения содержимого. Свежие compiler hashes и девять byte-equal масок проверены отдельно; обязательна новая полная gates-02.\n\n'
p.write_text(s[:a]+section+s[b:])
print('bridge source/docs/audit scope updated; no gate result fabricated')

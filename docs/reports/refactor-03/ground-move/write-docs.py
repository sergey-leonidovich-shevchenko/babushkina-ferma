"""Update live Ground commands and one03 card only after actual before/after profiles pass."""
import hashlib
import json
from pathlib import Path
import re
import shutil

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/ground-move'
plan = json.loads((R / 'baseline/move-plan.json').read_text())
after = json.loads((R / 'after-profile.json').read_text())
assert after['historical_stdout_byte_equal'] == 10 and len(after['commands']) == 22 and len(after['GD']) == 55
assert (R / 'layout-green-attempt02.txt').read_text().rstrip().endswith('OK')
assert 'Ran 22 tests' in (R / 'layout-green-attempt02.txt').read_text()
mapping = {r['old_path']: r['target'] for r in plan['moves']}
files = [Q / n for n in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md', 'tools/README.md']]
files += [p for p in (Q / 'wiki/articles').glob('*.md') if p.name != 'tools-migration-map.md']
changed = []
for p in files:
    text = before = p.read_text()
    for old, target in sorted(mapping.items(), key=lambda pair: -len(pair[0])):
        if old.endswith('.py'):
            module = target.removeprefix('tools/').removesuffix('.py').replace('/', '.')
            text = text.replace('python3 ' + old, 'python3 tools/run.py ' + module)
        text = re.sub(re.escape(old) + r'(?![\w./-])', lambda _: target, text)
    text = text.replace('В текущем кандидате корень tools составляет153 исходников',
        'В текущем кандидате корень tools составляет82 исходника')
    if text != before:
        p.write_text(text)
        changed.append(str(p.relative_to(Q)))

(R / 'README.md').write_text('''# REFACTOR-03: перенос Ground, 0.0.379

Инструменты травы, дорог, грядок и сезонов перемещены в `tools/qa/ground`. Вместе перенесены 29 Python, 42 GDScript и 42 отслеживаемых UID. В корне tools осталось 82 исходника вместо 153. Текущая закрытая карта содержит ровно 380 назначений: к прежним 267 добавлены 113 строк оригинального принятого плана. Общие camera points, encoder, render_order_game, water anchor, performance facades/sampler и shore-kit остаются до связанных следующих шагов той же REFACTOR-03.

Родитель `c1cdd9f5842eaf2286be38bd8f95d18767d03c11` принят по независимому review5704521872, CI 8/8 и решению Team Lead. Новому head нужны свои CI и независимое ревью. Вся REFACTOR-03 остаётся in_progress в draft PR21: 82 ещё выше бюджета 30, вся исходная карта пока не завершена. main не меняется, Task-Complete отсутствует.

Обновлены импорты, десять native launch URI, ссылки в 13 игровых тестовых наборах, 19 current-input sites и 18 исторических Git-read sites. Ground-layers помечает собственные QA-исходники NEW, поэтому его прежний выбор исторического performance helper сохранён. Логические SOURCES/OVERLAY и назначения внутри архивов остались прежними. Проверены [37 полей в 21 модуле](source-contract-audit.json), [код и адреса](code-audit.json), все 302 UID bytes/mode с учётом 42 новых физических адресов. Runtime scripts, art и измеряемое игровое поведение этим переносом не меняются.

[До](before-profile.json) и [после](after-profile.json) выполнены по 22 actual CLI из foreign cwd/Git: десять исторических readers, десять прежних negative suites, Ground context и общий surface producer. Все проходят; десять reader stdout побайтно равны. Ещё по 55 настоящих Godot compile-only checks проверяют 42 перемещённых GD и 13 потребителей. stdout и engine logs сохранены lossless gzip с raw/stored SHA. [Свежий headless editor import](fresh-editor.json) успешен после сохранения только собственного QA-кеша; primary cache не тронут. Это компиляция и чтение старых доказательств, без новой native/GPU/FPS приёмки.

Новый [layout suite](new-layout-test-audit.json) содержит 22 real Git/hash/copy/index случая. На родителе — 4 failed subtests, 19 errors и один положительный контроль; после — 22/0. Старые ключи архива читаются из canonical Git tree; ambiguity и missing canonical/stale legacy отклоняются. Десять actual producer запускают только явно fake-open17 и проверяют реальные argv/cwd, текущие источники, архивные bytes и partial rejection. Исходные кадры и Git не заменяются; полная native-проверка отказывается принимать input-only capsule.

Первый after-layout прогон дал 9 failures: guard фикстуры ошибочно считал архивные input PNG игровыми кадрами. [Отказ](layout-green-attempt01.txt) и [адресная поправка](native-guard-fixture-repair.json) сохранены; guard теперь исключает только inputs, все source PNG/hash assertions остались. Авторитетный повтор — [attempt02](layout-green-attempt02.txt). SHA before/after теста различаются: package imports, unused subprocess и один fixture guard. Равенство проверено с явной нормализацией этой поправки, удалённых тестовых методов нет.

P3 родителя исправлен: удалён Path в test_ground_context. Расширенный [аудит импортов](unused-import-audit.json) охватывает все 34 новых/изменённых/перемещённых tools Python, включая 14 тестовых модулей. Он также нашёл и удалил sys в изменённом surface producer test и subprocess в новом layout test; лишние импорты git_environment девяти collectors удалены после маршрутизации через общий helper. Отдельных unit-тестов удаления импортов нет. Frozen reports, историческая карта и другие карточки не переписываются.

Неуспешные прототипы сохранены отдельно: descriptor старой карты ожидал отсутствующее old_path; затем full verifier фикстуры получил явный folder. Первый compile-only процесс не смог открыть стандартный user://logs и завершился -6. [Диагностика](before-GD-attempt01.json) и raw сохранены; повтор использует owned --log-file, только 55 GD были повторены, 22 успешных CLI не запускались заново.

[План](PLAN.json), [исходная карта и байты](baseline/move-plan.json), [исходный red](baseline/layout-red.json), [scope](scope-initial.json). Полные architecture/Game/normal/F10/Wiki, каталог/браузер, exact-head CI и независимое решение обязательны; будущие результаты не подменяются профилями. Итоговые raw появятся в `gates-01`, контрольный пакет — `checks.json`.
''')
paragraph = ('Перенос Ground 0.0.379: 71 исходник и 42 tracked UID находятся в `tools/qa/ground`; '
    'корень tools сокращён со 153 до 82 исходников. Карта расширена ровно на 113 принятых строк до 380. '
    'Все 37 логических полей в 21 модуле и 302 UID bytes/mode сохранены. До/после прошли по 22 CLI и 55 '
    'compile-only checks, десять исторических stdout равны. Новые 22 real-layout случая проходят; '
    'fake-open17 проверяет source/argv и не является native/FPS приёмкой. P3 Path и дополнительные unused '
    'импорты в тестах исправлены; аудит теперь включает все 34 Python-модуля и 14 тестовых. '
    'Родитель378 принят review5704521872 и CI 8/8. Вся03 остаётся draft/in_progress, root82 >30; '
    'новому head нужны полные TESTING, независимое review/CI и решение Team Lead.')
for name, href in [('tools/README.md', '../docs/reports/refactor-03/ground-move/after-profile.json'),
                  ('wiki/articles/project-refactoring.md', '../../docs/reports/refactor-03/ground-move/after-profile.json')]:
    p = Q / name
    text = p.read_text()
    index = text.index('\n') + 1
    p.write_text(text[:index] + '\n' + paragraph + '\n\n[Профиль переноса Ground379](' + href + ').\n' + text[index:])
    changed.append(name)
p = Q / 'TESTING.md'
p.write_text('REFACTOR-03 Ground379: `python3 tools/run.py qa.ground.<модуль>` и Godot `res://tools/qa/ground/`. '
    '71 source/42 UID, root153→82, карта267→380; прежние 37 полей/21 модуль и 302 UID bytes/mode сохраняются. '
    '`python3 tools/run.py qa.ground.test_ground_layout` — 22 real Git/copy/history/argv/index случая; '
    'frame fixture repair и все отказы сохранены. Десять actual producer используют только fake-open17: '
    'native0, полная проверка отвергает input-only proof. До/после по22 CLI и55 GD checks, десять reader stdout '
    'побайтно равны. Expanded unused audit включает34 Python и14 tools-тестов, отдельного unit удаления '
    'импортов нет. [План и границы](docs/reports/refactor-03/ground-move/README.md). Полные architecture, '
    'Game/normal/F10, Wiki/browser и независимые exact-head review/CI обязательны; вся03 не завершена.\n\n' + p.read_text())
changed.append('TESTING.md')
p = Q / 'docs/epics/refactoring-2026-10/TASKS.md'
text = p.read_text()
a, b = text.index('## REFACTOR-03 '), text.index('## REFACTOR-04 ')
section = text[a:b] + ('**Промежуточный перенос Ground 0.0.379:** родитель378 принят '
    '[review5704521872](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5704521872), '
    'CI 8/8 и Team Lead. 71 исходник/42 UID перемещены в qa/ground, root153→82, карта267→380. '
    'Сохранены 37 полей/21 модуль и 302 UID bytes/mode. Новые22 layout, прежние22 CLI/55 GD и fresh import '
    'прошли; данные и отказы в [отчёте](../../reports/refactor-03/ground-move/README.md). P3 Path и дополнительные '
    'unused в tools-тестах исправлены, аудит34 Python включает14 тестовых модулей. Вся03 остаётся '
    'in_progress/draft PR21, нужны полные TESTING и независимые exact-head CI/review; без merge/Task-Complete.\n\n')
p.write_text(text[:a] + section + text[b:])
changed.append(str(p.relative_to(Q)))

bad = []
current_targets = []
for p in files:
    for line, text in enumerate(p.read_text().splitlines(), 1):
        for old, target in mapping.items():
            if re.search(re.escape(old) + r'(?![\w./-])', text):
                bad.append({'path': str(p.relative_to(Q)), 'line': line, 'old': old})
            if target in text:
                assert (Q / target).is_file(), target
                current_targets.append({'document': str(p.relative_to(Q)), 'line': line, 'target': target})
assert not bad, bad
(R / 'live-command-audit.json').write_text(json.dumps({'old_live_Ground_addresses': bad,
    'current_targets': current_targets, 'frozen_reports_and_historical_map_excluded': True}, indent=2) + '\n')
scope = json.loads((R / 'scope-initial.json').read_text())
scope['source_paths_after'] = sorted(set(scope['source_paths_after']) | set(changed))
scope['docs_not_yet_finalized'] = False
(R / 'scope.json').write_text(json.dumps(scope, indent=2, ensure_ascii=False) + '\n')
shutil.copy2(__file__, R / 'write-docs.py')
print(json.dumps({'live_documents_updated': sorted(set(changed)), 'current_targets': len(current_targets),
    'source_paths_final': len(scope['source_paths_after'])}))

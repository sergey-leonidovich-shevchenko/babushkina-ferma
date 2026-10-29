"""Write factual World-core report and freeze current sources only after all profile/regression checks pass."""
import hashlib
import json
from pathlib import Path
import re
import shutil

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
REPORT = ROOT / 'docs/reports/refactor-03/world-core-move'
scope = json.loads((REPORT / 'scope.json').read_text())
before = json.loads((REPORT / 'before-profile.json').read_text())
after = json.loads((REPORT / 'after-profile.json').read_text())
regression = json.loads((REPORT / 'regression.json').read_text())
assert len(before['commands']) == len(after['commands']) == 38
assert len(before['GD_parse']) == len(after['GD_parse']) == 46
assert all(row['exit'] == 0 for row in before['commands'] + after['commands'] + before['GD_parse'] + after['GD_parse'])
assert after['historical_stdout_byte_equal'] == 22 and after['owned_water_outputs_byte_equal'] == 2
assert [row['methods'] for row in regression['commands']] == [16, 14, 13, 19]
assert all(row['exit'] == 0 for row in regression['commands'])
assert 'FAILED (errors=1)' in (REPORT / 'history-red.txt').read_text()
assert 'FAILED (errors=1)' in (REPORT / 'history-green.txt').read_text()
assert 'test_water_folder_follows_nested_source_project' in (REPORT / 'history-green.txt').read_text()
assert regression['commands'][2]['label'] == 'history-green-attempt02'
for profile in [before, after]:
    counts = []
    for row in profile['commands']:
        raw = (REPORT / row['log']).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == row['sha256']
        counts.extend(map(int, re.findall(r'Ran (\d+) tests? in', raw.decode())))
    assert len(counts) == 16 and sum(counts) == 213
assert scope['root_sources'] == 153 and scope['normalized_address_sites'] == 38
text = '''# REFACTOR-03: World-core 0.0.377

Перенесены 92 исходника, 42 отслеживаемых UID и два локальных UID. Корень `tools` уменьшен с 245 до 153 исходников. Новые Python-команды запускаются через `python3 tools/run.py qa.world.<модуль>`, GDScript — из `res://tools/qa/world/`. Статус всей REFACTOR-03 остаётся `in_progress`, PR21 — draft, без полного merge и `Task-Complete`.

Принятый родитель — `7a2d7a5917bede86b3ffa850b1d5c83e9e8cc0bd`: SOURCE PASS5695222063, решение Team Lead и CI8/8. Это допуск продолжить ту же03, а не приёмка нового кандидата. P3 по четырём неиспользуемым импортам исправлен без специальных unit-тестов на удаление импортов.

Карта содержит ровно 134 новых назначения из исходного принятого плана: 48 Python, 44 GDScript и 42 UID. Общая текущая карта — 267. Отдельная art-карта и таблица 141 исторического World alias не менялись. Пять исходников shore-kit остаются для отдельного шага совместимости прежней художественной витрины; общий `render_order_game` с UID — до обновления ground/foliage consumers. Они остаются частью полного объёма03. Общие camera points, encoder, water anchor и performance facades/sampler сохранены.

## Фактические проверки

- [Исходный профиль](before-profile.json) и [повторный профиль](after-profile.json): по 38 настоящих CLI из чужой cwd, после — также с чужими Git overrides. Все 16 исторических readers, 6 asset verifier и 16 прежних negative suites /213 cases проходят. Вывод 22 historical/asset команд побайтно совпадает. Для перенесённых модулей сравниваются старый physical CLI и новый canonical CLI с тем же логическим назначением.
- По 46 настоящих `Godot --check-only`: 44 перенесённых GD и два внешних plant-depth consumer. Свежий headless editor import сохранён отдельно. Это compile-only проверки, без кадров Game и без GPU/FPS допуска.
- Реальный Water writer исполнен только на собственной копии четырёх raw. Все 48 старых diagnostic repeats сохранены, оба JSON/MD результата побайтно равны. Четыре точные raw-копии находятся рядом с MD для его относительных ссылок; исходный frozen Water не перезаписывался.
- [Регрессии](regression.json): 16 прежних API, 14 actual producer, 13 source-history и 19 прежних context cases. У сборщиков реальные Git/hash/copy/argv/cwd, а `open` явно подставной и завершается с17. Штатные readers отвергают partial output, повторный output запрещён; native кадров нет.
- Внешний `plant_depth` наследует World source lists. Его текущие входы и Git reader обновлены вместе с зависимостью. Расширенный history source на родителе даёт 12 успешных случаев и одну настоящую ошибку foreign Git; после исправления все13 проходят. Расширенный producer source проходит14/0 до и после. Между before/after сохраняются все методы и утверждения; различаются только package imports и один адрес текущего входа водной фикстуры.
- [Аудит](scope.json): проверены 569 функций, включая явно добавленные тестовые ветви, 671 import statements и 38 адресных замен. Полный AST после узкой нормализации совпадает; 37 прежних полей в21 модуле сохранены. Проверены байты/mode всех85 локальных UID, все отложенные anchors и остальные шесть карточек. Параллельный план07 в primary не включён. Исторические планы и доказательства не переписываются.

Первый after-regression сохранён в `history-green.txt`:12 случаев прошли, водная nested-source фикстура ещё копировала анализатор из старого root-пути. [Адресная правка](water-fixture-address-repair.json) меняет один current input и сохраняет все утверждения. Старые test/plan/audit/scope bytes и raw отказа сохранены в baseline. Авторитетный повтор — `history-green-attempt02.txt`; уже успешные16 API/14 producer не повторялись, их SHA и raw проверены заново. Прежние19 context cases выполнены после него. Продуктовые алгоритмы из-за этой правки не менялись.

Частный планировщик первоначально неэффективно извлекал текст каждого AST-узла. Он остановлен до любой мутации продукта; его источник сохранён, извлечение ограничено import-узлами. Порядок нового import внешнего CLI уточнён до мутации: он находится после существующего bootstrap. Эти черновики не являются принятыми runtime-проверками.

## Обязательная приёмка кандидата

167 source SHA заморожены перед полными gates. Требуются новые `tools/check_architecture.sh`, `./run_tests.sh`, normal/F10, `pnpm --dir wiki check`, проверка каталога/браузера и независимое exact-head review с решением Team Lead. Плановое количество архитектурных проверок —101 suites/1339 cases. До фактических результатов полный набор и CI нового SHA не заявляются. Root153 всё ещё выше конечного бюджета30.
'''
(REPORT / 'README.md').write_text(text)
assert not (REPORT / 'source-freeze.json').exists()
sources = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in scope['source_paths_after']}
assert len(sources) == 167
(REPORT / 'source-freeze.json').write_text(json.dumps({'base': scope['base'], 'version': '0.0.377',
    'source_SHA256': sources, 'physical_moves': 92, 'root_sources': 153,
    'before_full_gates': True}, indent=2) + '\n')
shutil.copyfile(__file__, REPORT / 'report.py')
print(json.dumps({'source_frozen': 167, 'old_negative_suites': 16, 'old_negative_cases': 213,
                  'actual_CLI_each': 38, 'actual_GD_each': 46, 'historical_stdout_equal': 22,
                  'architecture_expected': '101/1339', 'ready_for_full_gates': True}))

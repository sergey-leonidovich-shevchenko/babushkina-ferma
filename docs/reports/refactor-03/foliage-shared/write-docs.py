"""Update live usage and the03 section only; historical reports and other task cards remain frozen."""
import json
from pathlib import Path
import re
import shutil

Q = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
R = Q / 'docs/reports/refactor-03/foliage-shared'
plan = json.loads((R / 'move-plan.json').read_text())
mapping = plan['mapping']
after = json.loads((R / 'after-profile.json').read_text())
assert len(after['commands']) == 22 and len(after['GD']) == 114 and after['unit_cases'] == 243
assert after['historical_stdout_byte_equal'] == 11
assert all(row['exit'] == 0 for row in after['commands'] + after['GD'])
coverage = json.loads((R / 'full-plan-coverage.json').read_text())
assert coverage['original_rows_accounted_for'] == 779 and len(coverage['root_sources']) == 11
unused = json.loads((R / 'unused-import-audit.json').read_text())
assert not unused['unused_candidates']

files = [Q / n for n in ['TESTING.md', 'QA_CHECKLIST.md', 'docs/DEVELOPMENT.md', 'tools/README.md']]
files += [p for p in (Q / 'wiki/articles').glob('*.md') if p.name != 'tools-migration-map.md']
changed = set()
for path in files:
    before = text = path.read_text()
    for old, target in sorted(mapping.items(), key=lambda pair: -len(pair[0])):
        if old.endswith('.py'):
            module = target.removeprefix('tools/').removesuffix('.py').replace('/', '.')
            text = text.replace('python3 ' + old, 'python3 tools/run.py ' + module)
        text = re.sub(re.escape(old) + r'(?![\w./-])', lambda _: target, text)
    text = text.replace('В текущем кандидате корень tools составляет82 исходника при конечном лимите30',
        'В текущем кандидате корень tools составляет11 исходников при конечном лимите30')
    text = text.replace('исторический прогноз10 с обязательным protocol facade увеличен до11, полного переноса ещё нет',
        'исторический прогноз10 с обязательным protocol facade увеличен до11; полная карта сверена, приёмка03 ещё ожидается')
    if text != before:
        path.write_text(text)
        changed.add(str(path.relative_to(Q)))

paragraph = ('Финальный перенос REFACTOR-03, кандидат0.0.380: 77 исходников (включая шесть nested grass_compare) '
    'и34 tracked UID распределены по qa/foliage, qa/world и qa/camera; четыре ignored UID сохраняются локально. '
    'Корень tools82→11 при лимите30. Все779 назначений исходного плана сверены отдельно от generic map491; '
    'два прежних исключения — PIL importer в authoring и protocol facade — сохранены. Все304 UID bytes/mode '
    'и37 полей21 source-contract модуля прежние. До/после:22 actual CLI,243 прежних теста и114 Godot compile-only; '
    '11 исторических stdout побайтно равны. Новые11 context,10 provenance и10 actual-producer случаев '
    'проверяют свои Git/cwd/index/config, canonical input/copy/hash и точный launch URI; fake-open17 не рисует '
    'кадры и не даёт native/FPS-приёмки. Старые отчёты не переписаны. Родитель379 принят review5706289303, '
    'CI8/8 и Team Lead. Полная03 остаётся in_progress в PR21 до обязательных gates, независимого ревью '
    'текущего head, CI и решения Team Lead; merge/Task-Complete пока нет.')
for name, href in [('tools/README.md', '../docs/reports/refactor-03/foliage-shared/README.md'),
                   ('wiki/articles/project-refactoring.md', '../../docs/reports/refactor-03/foliage-shared/README.md')]:
    path = Q / name
    text = path.read_text()
    index = text.index('\n') + 1
    path.write_text(text[:index] + '\n' + paragraph + '\n\n[Полная карта и проверки380](' + href + ').\n' + text[index:])
    changed.add(name)

path = Q / 'tools/README.md'
text = path.read_text()
text = text.replace('Остальные принятые корневые входы `smoke_test.sh`, `performance_gate.sh`, `performance_gate.py` и защищённые `performance_sampler.gd`/`water_audit.gd` сохраняются для следующего этапа.',
    'Полный текущий корневой набор приведён ниже; каждый адрес имеет публичного потребителя или отдельную причину сохранения.')
text += '''
## Все 11 исходников, оставшихся в корне

| Адрес | Потребитель и причина |
| --- | --- |
| `tools/run.py` | Общий Python CLI для документации, quality gate и произвольной cwd; передаёт argv в пакет |
| `tools/__init__.py` | Закрепляет собственный пакет tools при запуске из чужой cwd/PYTHONPATH |
| `tools/check_architecture.sh` | Hooks и Actions; делегирует `quality/check_architecture.sh` |
| `tools/bump_version.py` | Pre-commit/CLI/import API; делегирует planning с сохранением законного alternate index |
| `tools/task_batch.py` | Post-commit/status/import API; publish остаётся историческим и не обходит PR |
| `tools/smoke_test.sh` | `.github/workflows/ci.yml`; делегирует qa/performance с прежними argv/exit |
| `tools/performance_gate.sh` | `.github/workflows/ci.yml`; делегирует qa/performance с прежними argv/exit |
| `tools/performance_gate.py` | Frozen redraw/causal executable reports; один модуль, API и mutable SAMPLER |
| `tools/performance_protocol.py` | Три frozen executable consumer, включая protocol-before-gate import; единственная реализация qa/performance |
| `tools/performance_sampler.gd` | `qa/performance/performance_gate.py`; защищённый engine --script anchor исходного плана |
| `tools/water_audit.gd` | Защищённый anchor исторического WATER/shore протокола исходного плана |

Все779 исходных назначений, actual target и сохранённые facade/anchors: [проверенная полная карта](../docs/reports/refactor-03/foliage-shared/full-plan-coverage.json).
Историческая карта не менялась. Generic491 — отдельная текущая таблица адресов, не замена полной779.
Закреплённый `tools/Godot.app` остаётся на месте и не входит в число исходников.
'''
path.write_text(text)

path = Q / 'TESTING.md'
path.write_text('REFACTOR-03, кандидат380: перед публикацией выполнить `python3 tools/run.py qa.foliage.test_foliage_context`, '
    '`qa.foliage.test_relocation_provenance`, `qa.foliage.test_foliage_producers` через тот же launcher; '
    'прежние11 negative suites и11 historical readers сохраняются. Полные `tools/check_architecture.sh`, '
    '`./run_tests.sh` (Game/normal/F10) и `pnpm --dir wiki check`, browser1280/390 и независимое exact-head '
    'review/CI обязательны. Корень11≤30, исходная карта779 сверена, UID304 и37 frozen полей прежние. '
    'Профили до/после22CLI/243cases/114GD и31 новых source-only случаев не заменяют полные gates или '
    'нативную/FPS-приёмку. [Отчёт и отказы](docs/reports/refactor-03/foliage-shared/README.md).\n\n' + path.read_text())
changed.add('TESTING.md')

path = Q / 'docs/epics/refactoring-2026-10/TASKS.md'
text = path.read_text()
a, b = text.index('## REFACTOR-03 '), text.index('## REFACTOR-04 ')
section = text[a:b] + '**Финальный кандидат0.0.380:** ' + paragraph + '\n\n' + (
    'Подробные назначения/исключения и все raw: [foliage/shared](../../reports/refactor-03/foliage-shared/README.md). '
    'P3 родительского ревью: живые counters379 исправлены на35 Python/15 tools-тестов; frozen отчёт379 не переписан.\n\n')
path.write_text(text[:a] + section + text[b:])
changed.add('docs/epics/refactoring-2026-10/TASKS.md')

(R / 'README.md').write_text('''# REFACTOR-03: оставшиеся Foliage и shared, кандидат0.0.380

Все исходные назначения tools физически завершены; принятие всей03 ещё ожидает обязательные gates, независимое exact-head review/CI и решение Team Lead. [PR21](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21) остаётся draft, карточка in_progress. main и Task-Complete не меняются.

Перенесены77 source:38 Python,37 GDScript,1shader и1Swift. Из них71 находился в корне, ещё6 — в nested grass_compare. Семейства: foliage102 строки, world7, camera2 с учётом34 trackedUID. Четыре ignoredUID следуют за исходниками локально, без добавления в Git. Все304 tools UID сохраняют bytes/mode. Корень82→11≤30. [Полная карта779](full-plan-coverage.json) отдельно учитывает более ранние пакеты и уже принятые исключения PIL importer/ protocol facade; generic map380→491 содержит ровно111 новых строк исходного плана, а не все779.

Родитель108ad126d00eb141658928aa3d68588c5af34db7 принят независимым review5706289303, CI8/8 и решением Team Lead как промежуточный379. [Исходный census](PLAN.json) создан до этого решения и сохраняет историческую фразу review pending; [baseline](baseline/inventory.json) содержит уже подтверждённый статус. P3 счётчиков35/15 исправлен только в живых TESTING/карточке03, отчёт379 сохранён.

Новые команды: `python3 tools/run.py qa.foliage.<модуль>`, `qa.world.shore_kit`; Godot URI — `res://tools/qa/foliage/` и `res://tools/qa/world/shore_kit_*.gd`. Shared render_order_game и camera points/Swift encoder перенесены вместе с потребителями. Семь public facades, run/package marker и два защищённых anchor перечислены с потребителями в tools/README. Установленный Godot, runtime scripts, art, .res и исторические raw не изменены.

[Механический аудит](code-audit.json) сравнивает AST и точные GD bytes после закрытой нормализации только адресов:4 source-root,29 current-input,9 historical read,24 Git-env,10 Python launch URI,129 GD URI. Импорты проверяются отдельно на использование и реальными CLI. Логические SOURCES/FROZEN/OVERLAY и назначения архива прежние: [37 полей21 модуля](source-contract-audit.json). Алгоритмы, бюджеты и прежние assertions не сокращены.

Grass source.json добавляет только полную известную source_paths одного capture. Reader сохраняет legacy без поля и требует точный URI после единственного --script; поддельный URI в payload не принимается. Shore reader читает только canonical source: legacy SHA разрешает исключительно обратные quoted URI двух известных Shore GD, current SHA требует actual bytes. Полные legacy/current key schemes принимаются, mixed/unknown отклоняются. Эти изменения provenance отделены от механического аудита и проверены реальными byte/hash/metadata контролями; новые native/GPU/FPS результаты не заявляются.

До/после выполнены [22 actual CLI](after-profile.json):11 старых reader и11 прежних отрицательных suites,243 cases. Все11 reader stdout побайтно равны; ещё по114 Godot compile-only проверяют переехавшие скрипты и потребителей. Логи сохранены lossless gzip с raw/storedSHA. [Первый after отказ](after-attempt01/after-profile.json): один прежний test_visibility запускал дочерний файл напрямую и терял package imports. [Адресная поправка](visibility-child-repair.json) сохраняет тот же testcase, env и assertions, используя общий tools/run.py; отказ и полный повтор сохранены.

Вторая попытка сохранила21 успешный CLI, но Shore fixture читала прежний tools-путь. [Поправка](shore-fixture-repair.json) меняет только copy source/target для tools; исторические относительные пути изображений с ../ остаются прежними. Её первый чрезмерно общий вариант отклонил эти пути: [attempt03](after-attempt03/after-profile.json) сохранён. Финальный профиль повторяет провалившийся suite10/0, сохраняя21 успешный результат только после проверки actual source SHA и lossless raw. Компиляция сначала завершила21 GD последовательно, затем оставшиеся93 выполнены максимум тремя независимыми процессами: [журнал](compile-concurrency.json). Остановлен только собственный последовательный driver и его check-only child, незавершённый результат не принят; native/FPS не измерялись. Сравнение foreign index/config в прерванном CLI-контексте не успело выполниться; финальный completion-context и отдельные реальные context/producer suites проверяют свои index/config явно.

Профиль завершён до import-only cleanup: [удалены13 неиспользуемых импортов](unused-import-cleanup.json), каждый non-import AST и все методы/assertions прежние. Полные gates запускаются уже на конечном source freeze. Расширенный [unused audit](unused-import-audit.json) включает все изменённые, перемещённые и новые tools Python, в том числе тесты; отдельного unit удаления импортов нет.

Три новых suite:11 real source-root/Git/archive context,10 relocation/provenance и10 actual producer. Context red:4 failed subtests/8 errors/2 positive controls; relocation red:1 failure/9 errors с учётом subtests,2 positive controls. Parent raw сохранены в baseline. Context prototype сначала имел ошибку native-folder, а первый installed green — неявную зависимость дочернего import от PYTHONPATH: [fixture repair](context-child-fixture-repair.json) явно передаёт свой source root; методы и assertions не удалены. Полный11-case прогон входит в обязательный architecture. Producer first attempt имел два KeyError: явный fake capture не содержал complete; исправлена только synthetic fixture, добавлено complete:false. Десять producer после этого проходят. Git/SHA/copy/index/config и argv/cwd настоящие; только open заменён явным child17, PNG кадров отсутствуют. Это проверка partial-source envelope, не успешный запуск игры.

Полные architecture, Game/normal/F10, Wiki/catalog/browser и fresh editor обязательны для текущего кандидата; итоговые данные — checks.json и gates-01. Внешний лимит ожидания полного architecture увеличен2400→3600с из-за трёх новых реальных suite и предыдущего прогона38м50с; команда gate, пороги тестов и CI-бюджеты не меняются. Ошибки и частичные raw не удаляются.
''')

bad, targets = [], []
for path in files:
    for line, text in enumerate(path.read_text().splitlines(), 1):
        for old, target in mapping.items():
            if re.search(re.escape(old) + r'(?![\w./-])', text):
                bad.append({'document': str(path.relative_to(Q)), 'line': line, 'old': old})
            if target in text:
                targets.append({'document': str(path.relative_to(Q)), 'line': line, 'target': target})
assert not bad, bad
(R / 'live-command-audit.json').write_text(json.dumps({'old_live_addresses': bad,
    'current_targets': targets, 'frozen_reports_and_historical_map_excluded': True}, indent=2) + '\n')
(R / 'live-documents.json').write_text(json.dumps({'changed': sorted(changed)}, indent=2) + '\n')
shutil.copy2(__file__, R / 'write-docs.py')
print(json.dumps({'updated': sorted(changed), 'current_links': len(targets)}))

# REFACTOR-01 — итоговая карта после принятия PR #12

Основание — принятая main `da9fa07e2f4c7f1fe05d9e89eebc454afc79d4ff`, версия `0.0.342`. Кандидат `0.0.343` объединяет проверенный аудит `7c23f6efb107728afb30929e058f4de123cbfd27` и это служебное закрытие обычным merge. **Переносов tools и новой игровой реализации нет.** REFACTOR-01 остаётся in_progress до независимого ревью точного head и решения Team Lead.

[Карточка](../../../epics/refactoring-2026-10/TASKS.md) · [Wiki](../../../../wiki/articles/project-refactoring.md) · [полная карта в Wiki](../../../../wiki/articles/tools-migration-map.md) · [таблица](snapshot/tool-map.md) · [CSV](snapshot/tool-map.csv) · [JSON](snapshot/tool-map.json) · [проверки](checks.json).

## Основание и сохранённая история

Первый проход 206918ab и полный проходad60faf4 сохранены отдельно. На коммите `7c23f6ef` успешно выполнены architecture82 набора/1135 случаев, Game53502/0, normal/F10 по 90/0, Wiki135/0, 29 контролей аудита, два полных replay и реальные disposable probes. [Первый отчёт и данные](../README.md) не переписаны под новую базу. Его source SHA и снимки 342 относятся к тому checkpoint, а не к текущему head.

Принятый [PR #12](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/12) закрыл редакционную подготовку 25 октября, добавил статью/отчёт и один Wiki-аудитор. В tools/scripts/tests/assets/hooks/workflows различий с ad60faf4 нет. Новая main и свои правки объединены без force/rebase, обе истории сохранены. [Проверка оснований](baseline-verification.json).

Повторный снимок включает **24 070 blobs, 6 720 009 394 байт**; SHA256 каждого — в [манифесте](snapshot/baseline-files.jsonl.gz). Все 17 309 прежних файлов docs/reports сохраняются. Отдельный [scope](scope-audit.json) сверяет все принятые файлы с рабочим деревом, новые публикуемые пути, чужие карточки, порядок Wiki index и все три planning-реестра.

## Полная карта и текущие числа

В tools по-прежнему 767 непосредственных файлов и 779 рекурсивно. Корень содержит 553 исполняемых исходника, **без shader**; во всём дереве 558 исполняемых +1 вложенный shader. Tracked UID216; у 86 других Godot-исходников sidecar только локальный/ignored. В [наблюдении](local-uid-observation.json) эти локальные данные отделены от Git-базы.

[Явная политика](migration-plan.json) назначает целевой путь всем 779 файлам.17 тематических семейств и зависимости сохраняются; в Wiki563 строки исходников/данных, UID у соответствующего исходника. JSON/CSV включают UID отдельными строками. Путь, назначение, CLI/env, исходный SHA, UID и индексы точных/потенциальных потребителей доступны для каждого файла.

Плановый корень — **9 исходников при бюджете 30**, а не уже достигнутый результат:

- Шесть фасадов: check_architecture.sh, bump_version.py, task_batch.py, smoke_test.sh, performance_gate.sh и performance_gate.py.
- Два полных неизменяемых anchor: performance_sampler.gd и water_audit.gd.
- Один только предложенный tools/run.py для запуска квалифицированных Python-модулей из разных cwd.

Причины конкретны. Frozen test_causal читает старый sampler; frozen отчёт WATER содержит настоящую физическую Markdown-ссылку на water_audit. Frozen redraw_compare импортирует performance_gate и присваивает gate.SAMPLER: import-фасад обязан сохранить module identity и mutable globals, обычный import-star не подходит. Сотни прежних имён не превращаются в сотни wrappers.

## Потребители, UID и исторические ограничения

[Ledger](snapshot/references.jsonl.gz) перечисляет consumer/строку/вид/scope/target; поля reference_ids связывают его с каждой строкой карты. Это нормализованные индексы, не число выполненных запусков. Статическая цепочка не доказывает исполнения ветви, а совпадение шаблона остаётся кандидатом. `show` раскрывает конкретные строки без ручного поиска по всему репозиторию.

[Адреса рисков](snapshot/hazards.json), [межсемейные imports](snapshot/cross-family-imports.json), [физические ссылки](snapshot/markdown-links.json) и [ручные решения](reference-decisions.json) сохранены отдельно. Семь архивов/28 tools-members индексируются без извлечения и перепаковки. Старые source keys, планы, капсулы, raw и source SHA не переподписываются под новую структуру; link/provenance checkers не отключаются.

Для 52 совпадений общих SOURCES/OVERLAY и старых prefix-фильтров будущие 02/03 должны отделить историческое пространство имён от новых путей collector. UID переносятся совместно с исходником; для 86 отсутствующих в Git sidecars нужен адресный preflight. Новые ignore-правила разрешают только нужные тематические папки, не весь установленный Godot и временные файлы.

Два [disposable опыта](experiments/root-depth.json) и [hook-окружение](experiments/git-hook-environment.json) проверяют реальные функции принятой базы. Наивное вложение byte-identical checker ломает parent.parent; наследование GIT_* направляет вложенный init в disposable parent. Очищенная граница проходит; настоящие config/index не меняются. Сам test_shore_kit здесь не исправляется: это первый адресный шаг 02.

## Остальные каталоги

[Полные имена и потребители](snapshot/other-catalogs.json) не разрешают массовые перемещения:

| Семейство | Предложение после выпуска tools |
| --- | --- |
| systems/storage6 и furnace3 | Адресные пакеты 05 с прежними save/поведением |
| presentation/storage4 и foliage7 GDScript +2 shader | Пакеты 05, UID и bindings вместе |
| suites/foliage8 и storage4 | Пакеты 04 с сохранением nested run и прямых QA-потребителей |
| helpers3 | Оставить: уже отдельные короткие сценарии |
| reports17 309 | Оставить frozen; улучшать указатели и Wiki |
| wiki/scripts21 | Оставить: отдельные catalog/store/API/export/редакционные аудиторы, наибольший prepare332 физических строки |
| preview386 PNG/import пар | Оставить стабильную адресацию по ID |

Остальные systems/presentation/suites не включаются по одному размеру каталога. [Граф suites](snapshot/suite-registry.json):174 набора, 37 верхних запусков, без недостижимых/повторных статических путей и циклов; suite_base отдельно. Фактический Game записывается независимо.

Очередь: **02 →03 →06**, затем обычный маршрут первой локации. 04/05 — только адресное решение Team Lead. [Небольшие пакеты, условия и git revert](../migration-batches.md) сохраняют общий смысл; исторические числа первого прохода не выдаются за текущие. Редакционные аудиторы PR #8/#12 относятся к своим принятым lifecycle-статусам и не требуют возвращать нынешнюю 01 из in_progress в ready.

## Воспроизведение и приёмка

```sh
python3 -m unittest discover -s docs/reports/refactor-01/instrumentation -p 'test_*.py' -v
python3 docs/reports/refactor-01/instrumentation/audit.py check --plan docs/reports/refactor-01/integration-1/migration-plan.json --snapshot docs/reports/refactor-01/integration-1/snapshot
python3 docs/reports/refactor-01/instrumentation/audit.py show --snapshot docs/reports/refactor-01/integration-1/snapshot --path tools/performance_gate.py
python3 docs/reports/refactor-01/integration-1/verify_scope.py
```

При интеграции исправлена только команда в метаданных самого аудитора: план теперь задаёт свой verification_command, поэтому проверка каждой строки ведёт к текущему scoped snapshot, а не к первому пакету. Регрессия включена в полный fixture-replay из другой cwd. Старый код первого прохода доступен в checkpoint7c23f6ef; прежние source SHA не переписаны.

Полный replay повторно хеширует все Git blobs и побайтно сравнивает весь пакет. Проверяется корень и другая cwd с пробелами;29 контролей включают настоящий disposable linked worktree. Scope проверяет именно текущий кандидат, не заменяет guard размещения будущей 06. Лишний собственный временный исходник должен дать настоящий отказ.

Свежие architecture, полный Game, redraw normal/F10, Wiki, профильные проверки и их SHA — в [checks.json](checks.json); прежние raw не используются как PASS нового head. Wiki показывает актуальную карту/статус/ссылки; source/public/dist CSV/JSON сверяются побайтно. Отказ automation download-event или не применившийся viewport не считаются успешной проверкой соответствующего UI-действия.

Графика, новые механики, native GPU/FPS и VMAP-003 не принимаются этой задачей. Для merge нужны exact-head CI, независимое ревью и решение Team Lead. Task-Complete пока отсутствует; main этим кандидатом не обновляется.

# Рефакторинг: инструменты по назначению

Учёт [PR №19](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/19) принят и влит в main `d609ab4f`: независимое ревью5663052246 точного head6dd6c3bb и CI8/8. В версии0.0.356 Git-вызовы scope reader изолированы от чужого worktree/index/config, а checkout выбирается по исходнику. [Результат P2 и реальные red/green](../../docs/reports/refactor-02/closeout/review-1/result.json) сохраняют12 сценариев на Python3.11/3.9 и прежние доказательства. Теперь REFACTOR-03 в работе: тематические переносы начинают с адресации генераторов графики. Это ещё не приёмка03, итогового бюджета tools или этапа06.

**REFACTOR-02 принят:** [PR №18](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/18) влит merge `58eda69f` после независимого [ревью 5661046362](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/18#pullrequestreview-5661046362) точного head `a1444f1c` и CI8/8. [Запись приёмки](../../docs/reports/refactor-02/closeout/completion.json) и отдельный учёт отделены от неизменных данных реализации. Подготовка и [14 quality/planning переносов](../../docs/reports/refactor-02/move/migration.json) сохраняют три публичных входа и прежние проверки. REFACTOR-01 и WIKI-003 уже приняты; [историческая полная карта](tools-migration-map.md), [JSON](../../docs/reports/refactor-01/integration-1/snapshot/tool-map.json) и [CSV](../../docs/reports/refactor-01/integration-1/snapshot/tool-map.csv) не переписаны. Корень tools сейчас544; полный выпуск с прогнозом10 при лимите30 принимает 03→06. Учёт02 принят через PR19, REFACTOR-03 в работе; после его приёмки —06 и первая overworld. VMAP-001…003 остаются открытыми.

Постановка принята через [PR #9](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9), учёт VFOLIAGE-010 — через [PR #10](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/10), учёт REFACTOR-00 — через [PR #11](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/11), merge `206918ab`. [Запись приёмки постановки](../../docs/reports/refactor-00/closeout/completion.json) остаётся исторической.

[Эпик и карточки](#/development/epics/refactoring--REFACTOR) · [Постановка в PR #9](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9) · [Исходная ведомость](../../docs/reports/refactor-00/inventory.json).

Исходная ведомость закрепляет два снимка: в принятой на момент постановки main `2fa58d3` у корня tools 750 файлов; в тогда открытом PR №7 `8ef7feae` — 762. Это исторические измерения, а не счётчик нынешней main. PR №7 позже принят и влит merge-коммитом `7dde012f`; актуальную карту составляет REFACTOR-01. Там смешаны QA, работа с ассетами, сборка, общие проверки и ручные стенды. Первый полезный выпуск группирует их по ответственности и оставляет в корне не более 30 исходников публичных команд с объяснёнными исключениями. Python и Godot одной подсистемы остаются рядом.

Порядок: аудит ссылок и входов → общие пути/репозиторные команды → QA/asset/build/dev-пакеты → README и guard. Каждый этап имеет отдельную ветку/PR и собственную приёмку. Тесты не теряются в новых папках; новые внутренние инструменты больше не попадают автоматически в корень.

Аудит проверил scripts/systems, scripts/presentation, tests/suites, helpers, reports, wiki/scripts и preview. Адресные предложения 04/05: systems/storage — 6 и furnace — 3; presentation/storage — 4 и foliage — 9 исходников; suites/foliage — 8 и storage — 4 набора. Остальные модули не включены в перенос автоматически. Helpers, reports, wiki/scripts и preview оставляем: дополнительная вложенность не оправдывает риск. [Полные имена и обоснования](../../docs/reports/refactor-01/integration-1/snapshot/other-catalogs.json).

Главный риск — сломать импорт, preload, CI, Wiki или прежнее доказательство. Сохранённые планы, капсулы, source SHA, raw и неудачные попытки остаются неизменными; исторические readers читают свой Git base/капсулу. Старые сотни имён не превращаются в сотни пустых wrappers. Механический перенос отделяется от изменения поведения.

Это техническая очередь по новому прямому поручению. Она не разрешает новые механики/карты и не закрывает общий FPS или VMAP-003. После первого выпуска tools возвращается обычный маршрут первой локации; оставшиеся адресные переносы согласуются Team Lead по ведомости.

## Исторический план REFACTOR-01

На исторической базе `da9fa07e`: 767 непосредственных файлов tools, 779 рекурсивно; в корне553 исполняемых исходника; рекурсивно558 исходников +1shader и216 trackedUID. Аудит предложил17 семейств: quality/planning, assets по назначению, build/dev, QA art/camera/foliage/ground/world/performance/compatibility. Его прогноз —9 исходников при бюджете30. После принятого02 фактический корень544, а новый package marker увеличивает прогноз полного выпуска до10; достижение бюджета проверяют03→06.

Исторический план сохранял шесть публичных фасадов: check_architecture, bump_version, task_batch, smoke_test, performance_gate.sh и импортируемый performance_gate.py. Frozen redraw_compare присваивает gate.SAMPLER: facade должен сохранять идентичность модуля и mutable globals, обычный import-star не подходит. Полные performance_sampler.gd и water_audit.gd сохраняют старые места из-за физических потребителей прежних отчётов. Принятый02 уже подключил общий tools/run.py, quality/planning и первые три публичных фасада; оставшаяся часть плана относится к03→06.

## Исторические риски, проверенные в аудите на копиях

Byte-identical checker из базы проходил в tools и отказывал после наивного вложения в quality: `.parent.parent` искал неправильный корень. Настоящий метод test_shore_kit с унаследованными GIT_* менял disposable parent config и падал; очистка окружения сохраняла config/index. Реальный репозиторий в опыте не изменён. Принятый02 устранил эти два риска общим source-root и адресной Git-изоляцией; прежние отказы аудита сохранены, а реальные отрицательные и положительные случаи повторены в13 инфраструктурных проверках.

У 86 Godot-исходников UID нет в Git, хотя локально sidecars существуют и ignored. Их нельзя потерять при переезде или случайно добавить вместе с установленным движком. Tracked 216 UID перемещаются с исходниками без генерации новых значений. [Локальное наблюдение](../../docs/reports/refactor-01/integration-1/local-uid-observation.json).

Исторические source descriptors нельзя переписывать под новые пути: выявлены 52 imports общих SOURCES/OVERLAY, а также старые prefix-фильтры. Старый reader читает закреплённые base/capsule, новый collector пишет собственную серию. Все 24070 blobs базы, семь архивов и 28 tools-members проиндексированы; link/provenance checkers остаются включены.

## Как проверить и что дальше

36 контролей проверяют карту, UID, повреждённый пакет, настоящий Git, worktree с пробелами и другую cwd. После независимого ревью новые root-входы требуют безопасного нормализованного пути непосредственно в tools, расширения исходника и непустой причины; дубликаты запрещены. Production-план779/9 не меняется. Полное воспроизведение читает все6,26 GiB базы и побайтно сравнивает весь пакет, не только summary:

```sh
python3 -m unittest discover -s docs/reports/refactor-01/instrumentation -p 'test_*.py' -v
python3 docs/reports/refactor-01/review-1/replay.py
python3 docs/reports/refactor-01/instrumentation/audit.py show --snapshot docs/reports/refactor-01/integration-1/snapshot --path tools/performance_sampler.gd
```

[Исходные проверки](../../docs/reports/refactor-01/integration-1/checks.json) отделены от [журналов принятой базы](../../docs/reports/refactor-01/integration-1/baseline-verification.json). [Доработка P2 в PR14](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14) сохраняет весь прежний пакет: обновляются только SHA двух файлов генератора и производные metadata в отдельном комплекте. Текущий replay приведён выше, старый snapshot воспроизводится генератором c9cea3ae. Статический граф174 suites содержит37 верхних запусков, без потери/дубля; это не замена Game. Нативная графика/GPU-FPS не переснимаются и не принимаются этим аудитом.

[Воспроизведение ложного PASS](../../docs/reports/refactor-01/review-1/red-reproduction.json) · [Отказ повреждённых production-планов](../../docs/reports/refactor-01/review-1/green-production-plan.json) · [Новый inventory](../../docs/reports/refactor-01/review-1/reproduction/inventory.json) · [Новый packet](../../docs/reports/refactor-01/review-1/reproduction/packet.json) · [Сравнение всех данных](../../docs/reports/refactor-01/review-1/collection-comparison.json).

После принятия 01: **02 — пути/Git-изоляция/quality/planning →03 — тематические инструменты →06 — README/guard**. Внутри 03 сначала учитываются взаимные imports assets/build и camera/performance, затем world/ground/foliage и совместимость. 04/05 остаются отдельными будущими работами Team Lead. Все старые raw, планы, капсулы и source SHA сохраняются; откат опубликованного пакета — git revert с теми же проверками.

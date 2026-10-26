# Рефакторинг: инструменты по назначению

**REFACTOR-01 в работе:** подготовлена полная карта принятой main `ad60faf4` после PR #8, 0.0.341. Все 779 файлов tools получили тематический путь либо объяснённое исключение. Переносов нет; аудит ожидает проверок и независимого exact-head ревью. [Карточка](#/development/tasks/refactoring--REFACTOR-01) · [полная карта прямо в Wiki](tools-migration-map.md) · [JSON с consumers и UID](../../docs/reports/refactor-01/snapshot/tool-map.json) · [CSV](../../docs/reports/refactor-01/snapshot/tool-map.csv).

Постановка принята через [PR #9](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9), учёт VFOLIAGE-010 — через [PR #10](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/10), учёт REFACTOR-00 — через [PR #11](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/11), merge `206918ab`. [Запись приёмки постановки](../../docs/reports/refactor-00/closeout/completion.json) остаётся исторической.

[Эпик и карточки](#/development/epics/refactoring--REFACTOR) · [Постановка в PR #9](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9) · [Исходная ведомость](../../docs/reports/refactor-00/inventory.json).

Исходная ведомость закрепляет два снимка: в принятой на момент постановки main `2fa58d3` у корня tools 750 файлов; в тогда открытом PR №7 `8ef7feae` — 762. Это исторические измерения, а не счётчик нынешней main. PR №7 позже принят и влит merge-коммитом `7dde012f`; актуальную карту составляет REFACTOR-01. Там смешаны QA, работа с ассетами, сборка, общие проверки и ручные стенды. Первый полезный выпуск группирует их по ответственности и оставляет в корне не более 30 исходников публичных команд с объяснёнными исключениями. Python и Godot одной подсистемы остаются рядом.

Порядок: аудит ссылок и входов → общие пути/репозиторные команды → QA/asset/build/dev-пакеты → README и guard. Каждый этап имеет отдельную ветку/PR и собственную приёмку. Тесты не теряются в новых папках; новые внутренние инструменты больше не попадают автоматически в корень.

Аудит проверил scripts/systems, scripts/presentation, tests/suites, helpers, reports, wiki/scripts и preview. Адресные предложения 04/05: systems/storage — 6 и furnace — 3; presentation/storage — 4 и foliage — 9 исходников; suites/foliage — 8 и storage — 4 набора. Остальные модули не включены в перенос автоматически. Helpers, reports, wiki/scripts и preview оставляем: дополнительная вложенность не оправдывает риск. [Полные имена и обоснования](../../docs/reports/refactor-01/snapshot/other-catalogs.json).

Главный риск — сломать импорт, preload, CI, Wiki или прежнее доказательство. Сохранённые планы, капсулы, source SHA, raw и неудачные попытки остаются неизменными; исторические readers читают свой Git base/капсулу. Старые сотни имён не превращаются в сотни пустых wrappers. Механический перенос отделяется от изменения поведения.

Это техническая очередь по новому прямому поручению. Она не разрешает новые механики/карты и не закрывает общий FPS или VMAP-003. После первого выпуска tools возвращается обычный маршрут первой локации; оставшиеся адресные переносы согласуются Team Lead по ведомости.

## Что именно предложено

Нынешний tools: 767 непосредственных файлов, 779 рекурсивно; в корне 553 исполняемых исходника; рекурсивно 558 исходников +1 shader и 216 tracked UID. Предлагаются 17 семейств: quality/planning, assets по назначению, build/dev, QA art/camera/foliage/ground/world/performance/compatibility. После будущих переносов в корне останется **9 исходников при бюджете 30**, а не сотни wrappers.

Шесть фасадов сохраняют публичные check_architecture, bump_version, task_batch, smoke_test, performance_gate.sh и импортируемый performance_gate.py. Frozen redraw_compare присваивает gate.SAMPLER: этот facade обязан сохранять идентичность модуля и mutable globals, обычный import-star не подходит. Полные performance_sampler.gd и water_audit.gd остаются на старых местах: первый читает действующий frozen causal test, на второй ссылается физическая ссылка старого отчёта WATER. Один новый tools/run.py — общий launcher, пока только предложение. Ни один новый путь сейчас не объявлен работающим.

## Риски, которые проверили на копиях

Byte-identical checker из базы проходит в tools и отказывает после наивного вложения в quality: `.parent.parent` ищет неправильный корень. Настоящий метод test_shore_kit с унаследованными GIT_* меняет disposable parent config и падает; очистка окружения проходит и сохраняет config/index. Реальный репозиторий в опыте не изменён. Эти условия нужно устранить первыми в 02; исправления здесь не выполнены.

У 86 Godot-исходников UID нет в Git, хотя локально sidecars существуют и ignored. Их нельзя потерять при переезде или случайно добавить вместе с установленным движком. Tracked 216 UID перемещаются с исходниками без генерации новых значений. [Локальное наблюдение](../../docs/reports/refactor-01/local-uid-observation.json).

Исторические source descriptors нельзя переписывать под новые пути: выявлены 52 imports общих SOURCES/OVERLAY, а также старые prefix-фильтры. Старый reader читает закреплённые base/capsule, новый collector пишет собственную серию. Все 24056 blobs базы, семь архивов и 28 tools-members проиндексированы; link/provenance checkers остаются включены.

## Как проверить и что дальше

29 контролей проверяют карту, UID, повреждённый пакет, настоящий Git, worktree с пробелами и другую cwd. Полное воспроизведение читает все 6,26 GiB базы и побайтно сравнивает весь пакет, не только summary:

```sh
python3 -m unittest discover -s docs/reports/refactor-01/instrumentation -p 'test_*.py' -v
python3 docs/reports/refactor-01/instrumentation/audit.py check --snapshot docs/reports/refactor-01/snapshot
python3 docs/reports/refactor-01/instrumentation/audit.py show --snapshot docs/reports/refactor-01/snapshot --path tools/performance_sampler.gd
```

[Свежие проверки](../../docs/reports/refactor-01/checks.json) отделены от [журналов принятой базы](../../docs/reports/refactor-01/baseline-verification.json). Статический граф 174 suites содержит 37 верхних запусков, без потери/дубля; это не замена фактическому Game. Нативная графика/GPU-FPS не переснимаются и не принимаются этим аудитом.

После принятия 01: **02 — пути/Git-изоляция/quality/planning →03 — тематические инструменты →06 — README/guard**. Внутри 03 сначала учитываются взаимные imports assets/build и camera/performance, затем world/ground/foliage и совместимость. 04/05 остаются отдельными будущими работами Team Lead. Все старые raw, планы, капсулы и source SHA сохраняются; откат опубликованного пакета — git revert с теми же проверками.

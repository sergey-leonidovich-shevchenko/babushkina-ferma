# REFACTOR — карточки технического рефакторинга

[Контракт и порядок](README.md) · [Wiki](../../../wiki/articles/project-refactoring.md).

Семь карточек: подготовка 00 и шесть этапов 01…06. Developer не прерывает VFOLIAGE-010. После её полного принятия следующей становится 01; новые механики не добавляются.

## REFACTOR-00 — Сохранить эпик, исходную ведомость и приоритет пользователя

**Статус:** done · **Приоритет:** P1 · **Объём:** S · **Тип:** design.

**Ветка:** codex/refactor-00-maintainable-layout

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9

**Результат и объём:** Этот документ, шесть предметных этапов, регистрация технологии в Wiki и очереди Team Lead. Переносов кода нет.

**Внутренние блокеры:** нет; самостоятельная постановка.

**Условия запуска:** Редакционная подготовка по прямому поручению пользователя; разработчика не переключать.

**Приёмка:**

- Эпик доступен через Wiki и указатель; сохранены существующие ID, статусы и группы.
- Следующая работа Developer после полного завершения VFOLIAGE-010 — REFACTOR-01; текущая задача не прервана.
- Разделены принятая main и открытый PR7; числа взяты из точных Git-снимков.

**Проверка:** Редакционные проверки, сохранность реестров, Wiki, TESTING.md. Публикация в отдельном PR; независимое ревью поручает Team Lead.

**Подтверждения / результат:** Постановка принята и влита через PR #9: exact head `7667c7e0ea04a9b61b458b825afcc552dd9d7fb9`, независимое [ревью Team Lead 5644081658](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/9#pullrequestreview-5644081658), фактический merge `9e6474808da59a28a177f2d9a2c068917da2f16b`. CI — 8/8 success: architecture 82 набора/1135 сценариев, CI Game 53520/0, redraw по 90/0, Wiki 135/0; локальный Game 53502/0 записан отдельно. [Запись приёмки](../../reports/refactor-00/closeout/completion.json) сохраняет прежний результат и исходные доказательства. Реализация переносов этим не объявляется; учётный PR требует своего exact-head CI и независимого ревью Team Lead.

## REFACTOR-01 — Составить полную карту переносов tools и подтвердить остальные узкие места

**Статус:** done · **Приоритет:** P1 · **Объём:** M · **Тип:** investigation.

**Ветка:** codex/refactor-01-maintainable-layout

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14

**Результат и объём:** Назначение каждого файла tools, пары UID, импорты/публичные входы/исторические ссылки и целевая таблица путей. Отдельно оценить systems, presentation, suites, helpers и reports.

**Внутренние блокеры:** REFACTOR-00, VFOLIAGE-010.

**Условия запуска:** REFACTOR-00 и VFOLIAGE-010 приняты и done; актуальная main. Карта путей является результатом этого аудита, заранее она не требуется. VMAP-003 не является блокером заказанного технического первого выпуска.

**Приёмка:**

- У каждого исходника tools есть новый тематический путь либо обоснованное публичное исключение; будущий корень содержит не более 30 исходников.
- Для каждого входа перечислены реальные потребители CI/hooks/Python/Godot/Wiki и воспроизводимая проверка. Живые ссылки документации отделены от исторических: старые доказательства доступны по закреплённому Git base/капсуле, проверка ссылок не отключается целиком.
- Для других каталогов записано конкретное семейство и польза переноса либо мотивированное «оставить»; никаких массовых перемещений по одному счётчику.
- Базовые проверки и все неизменяемые доказательства перечислены с SHA; намечены маленькие тематические коммиты и откат. Отдельно учтена изоляция вложенных Git-команд: известный test_shore_kit не должен наследовать Git-окружение hook и менять конфигурацию родительского репозитория.

**Проверка:** Read-only аудит принятой актуальной main, действующие профильные gates и проверка ведомости человеком. Реализация последующих переносов не требуется для приёмки аудита.

**Подтверждения / результат:** Аудит принят через [PR #14](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14): точный head `567b05c7d032d40f243df750ea25070e86f6d678`, независимое [ревью Tech Lead 5655708005](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/14#pullrequestreview-5655708005), CI 8/8 и фактический merge `d43c455046bf333e145f7cd097768ec4f60dabac` от 26 октября 2026. [Учёт и прежний результат](../../reports/refactor-01/closeout/completion.json) сохраняют базу `da9fa07e`, карту 779 tools blobs /17 семейств /9 будущих корневых исходников, историю P2/P3,36 профильных контролей, полный replay и прежние доказательства. Локально: architecture82/1135, Game53502/0, normal/F10 по90/0, Wiki135/0; отдельно CI Game53520/0, smoke180 и шесть CPU-серий в каждом полном test-job. Переносов tools ещё нет. Учётный PR имеет собственные проверки и независимое ревью. REFACTOR-02 готов по зависимости; его запуск следует после приёмки существующего PR #15 WIKI-003, затем 02→03→06.

## REFACTOR-02 — Разделить общую инфраструктуру и репозиторные команды tools

**Статус:** done · **Приоритет:** P1 · **Объём:** M · **Тип:** refactor.

**Ветка:** codex/refactor-02-maintainable-layout

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/18

**Дата завершения:** 2026-10-27

**Результат и объём:** Пилотный перенос common/quality/planning по принятой ведомости; общее определение корня и сохранение публичных команд. Алгоритмы проверок не менять.

**Внутренние блокеры:** REFACTOR-01.

**Условия запуска:** Зависимости приняты и done; актуальная main и принятая карта путей. VMAP-003 не является блокером заказанного технического первого выпуска.

**Приёмка:**

- Команды пилотного пакета работают из корня, другой cwd, worktree с пробелами и чистого CI; импорты не зависят от старого parents[1].
- Hooks/Actions/run_tests/документация вызывают принятые пути; разрешённые wrappers перечислены и не дублируют реализацию.
- Число реально запущенных проверок и отрицательные сценарии сохранены; новое расположение читается рекурсивными сканерами.
- Старые планы/капсулы/SHA и runtime побайтно прежние; механические перемещения отделены от логических изменений.

**Проверка:** Пилотные команды и проверки отказов импорта/пути, затем TESTING.md и CI текущего SHA. Не требовать ещё не перенесённые QA-группы.

**Подтверждения / результат:** Пилот принят и влит через [PR №18](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/18): точный head `a1444f1c36207f7a1057cca3a70dde7763d82434`, base `d603de591082f19b1a9964eefd8f1d0671d38839`, независимое [ревью 5661046362](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/18#pullrequestreview-5661046362), CI 8/8 и фактический merge `58eda69fd86f6784aa5fbdcfbec4a526b212b0f4` от 27 октября 2026. Подготовка `f6180e7c` и 14 переносов `a1444f1c` разделены; три публичных входа, их mode/import identity, алгоритмы и прежние отрицательные проверки сохранены. [Точная карта](../../reports/refactor-02/move/migration.json), [отчёт реализации](../../reports/refactor-02/move/README.md) и [запись приёмки](../../reports/refactor-02/closeout/completion.json) сохраняют все прежние результаты и отказы. Локальные проверки реализации: architecture83/1148, Game53502/0, normal/F10 по90/0, Wiki145/0; отдельно CI Game53520/0, smoke180 и шесть CPU-серий в каждом полном test-job. Корень tools — 544 исходника; прогноз полного выпуска10 при лимите30 ещё принимается в 03→06. Учётный PR требует своих проверок и независимой приёмки; до неё REFACTOR-03 не начинается. Нового допуска FPS или VMAP-003 нет.

## REFACTOR-03 — Разнести QA, обработку ассетов, сборку и ручные стенды tools по подсистемам

**Статус:** done · **Приоритет:** P1 · **Объём:** L · **Тип:** refactor.

**Ветка:** codex/refactor-03-maintainable-layout

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21

**Дата завершения:** 2026-10-30

**Результат и объём:** Завершить карту tools небольшими пакетами: qa/<подсистема>, assets, build, dev. Связанные Python/GDScript/контроли и UID переносить совместно.

**Внутренние блокеры:** REFACTOR-02.

**Условия запуска:** Зависимости приняты и done; актуальная main и принятая карта путей. VMAP-003 не является блокером заказанного технического первого выпуска.

**Приёмка:**

- В корне tools не более 30 исполняемых исходников; у каждого исключения есть публичный потребитель и причина в tools/README.md.
- Карта прежний→новый путь полна; живые imports/preload/скрипты/команды обновлены, старые упоминания в frozen raw не переписаны.
- Все исторические readers проходят из новой структуры по своему Git base/капсуле; подмена капсулы/сырья отклоняется и после переноса.
- Свежий импорт Godot, QA-профили/output и профильные отрицательные контроли работают; UID сохраняются, установленный движок не перенесён.
- Ни один пакет не ослабляет бюджет или функциональную проверку; большие перемещения разделены по подсистемам и отдельным коммитам.

**Проверка:** По каждой группе выполнить её прежние профильные и отрицательные проверки, полный TESTING.md и Wiki check; реальные новые измерения нужны только при изменении измеряемого поведения.

**История промежуточного результата:** В работе в [draft PR21](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21) на базе `d609ab4f`. Подготовка `0352c5f2` и первый authoring-перенос `f02481b2` разделены:31 исходник/5 tracked UID/9 ignored UID, root544→513. Доработка P2 head `5ba619a3` принята независимым [ревью5672404997](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5672404997) и Team Lead; [локальные gates359](../../reports/refactor-03/authoring-docs/checks.json) —84/1163, Game53502/0, normal/F10 по90/0, Wiki145/0. Это промежуточная приёмка исправления, не merge всей03. Пакет0.0.360 (4 аудио-инструмента, root509) принят промежуточным ревью5673231328 head `d27f688f` и Team Lead; его локальные gates —84/1163, Game53502/0, normal/F10 по90/0, Wiki145/0. Пакет0.0.361 переносит5 исходников image/review и1 tracked UID; [карта](../../reports/refactor-03/image-review-move/migration.json) и [профиль](../../reports/refactor-03/image-review-move/profile.json) сохраняют PIL/CLI/Node/Godot, root504. Пакет361 принят промежуточным ревью5673984294 head `832964d4` и Team Lead. Кандидат0.0.362 готовит8 source-root и4 исторических reader /5 main source pins без перемещений; [профиль](../../reports/refactor-03/art-history-prepare/profile.json) и21 новый Git/worktree контроль проверяют границу. Root504, новый кандидат требует собственных полных gates/review. Кандидат0.0.363 переносит23 art-standard source/3 tracked UID, сохраняет4 ignored UID и текущие collectors через source_paths; [профиль](../../reports/refactor-03/art-standard-move/profile.json),root481. Пакет363 head `8579b883` принят промежуточным [ревью5675903250](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5675903250) и Team Lead. Кандидат0.0.364 готовит15 source-root/9 Git-read и legacy/current scanner без перемещений; [профиль](../../reports/refactor-03/assets-history-prepare/profile.json) сохраняет16 AST/12 CLI/12 новых контролей, root481. Собственные полные gates/review364 ещё обязательны. Подготовка364 head6af72 принята review5676273527/Team Lead, CI8/8. Кандидат0.0.365 перемещает61 source/8 tracked UID/2 JSON и18 ignored UID; root420. [Профиль](../../reports/refactor-03/assets-build-move/profile-02.json) сохраняет35 AST/28 GD, реальный старый/новый fixed-input экспорт и negative metadata; собственные полные gates/review нового head ещё обязательны. Последняя команда пользователя28.10.2026 отменяет остановку: полное закрытие03 →07 →06 → обычный маршрут первой overworld до VMAP-003; одновременно одна задача, отдельные PR, независимое exact-head ревью, решение Team Lead, merge и учёт без дополнительных подтверждений владельца. Остальные семейства, полный бюджет≤30 и окончательное ревью ещё впереди;03 in_progress,06 blocked, Task-Complete не добавляется. Доработка P2 0.0.366 после review5676955759 возвращает legacy namespace настоящего внешнего create; [профиль366](../../reports/refactor-03/assets-build-review-1/profile.json) и три реальных producer-контроля сохраняют probe/project/draft, пять фаз и отказы. Head365 не принят, новый366 требует собственного полного gate/CI/review. P2 на482ed19c принят review5683524122/Team и CI8/8. Подготовка0.0.367 alpha/slicing добавляет5 точных source pins/8 layout-history случаев и8 ROOT/GIT-context адаптаций; [реальный before-профиль](../../reports/refactor-03/alpha-slicing-prepare/profile.json) сохраняет5603 frame signatures и alpha fixtures. Физических переносов нет,root420, собственные gates/review нового head обязательны. Подготовка367 head7dbd5b2c принята промежуточным source review5688074197/Team; CI367 завершён8/8 success, включая назначенный reviewer retry Linux. Пакет0.0.368 переносит17 source/2 JSON и6 ignored UID alpha/slicing, root403. [After-профиль](../../reports/refactor-03/alpha-slicing-move/profile.json) сравнивает реальные5603 кадра/9 controls и публичные сценарии; собственные gates/CI/review нового head обязательны.03 in_progress, финального merge нет. Первый реальный after-прогон выявил foreign-Git дефект потребителя street:3 Git-вызова исправлены, [регрессия](../../reports/refactor-03/alpha-slicing-move/street-regression.json) дала red1/2→green2/0 одним source. Повторный профиль прошёл12 native/14 CLI; все5603 сигнатуры/RGBA/PNG и9 controls равны367. Пакет0.0.369 переносит89 compatibility source и64 tracked UID, сохраняя23 ignored UID: root403→314. [Профиль после переноса369](../../reports/refactor-03/compatibility-move/after-profile.json) сравнивает настоящие команды, каталоги и граф циклов до/после. Проверяются87 GD и три публичных CLI-сценария. 368 принят промежуточным source review5689214200/Team и CI8/8. Для369 нужны собственные gates/CI и независимое ревью нового head;03 in_progress, финального merge нет. Подготовка0.0.370 performance исправляет8 source-root sites,9 Git-read sites и2 публичных shell-root. Пять настоящих context-тестов проверяют чужие cwd/GIT/index/config: до правки4fail/1error, после требуется5/0 на неизменном test source. Shell smoke в этих тестах использует только fake-engine свидетель argv/cwd. Физических переносов/UID-перемещений нет, root314. [Профиль подготовки370](../../reports/refactor-03/performance-prepare/after-profile.json) сохраняет реальные before/after CLI,14 isolated save workers и smoke180. Исторические показатели и бюджеты не ослабляются; новый FPS-допуск не заявлен. 369 headc6f323d8 принят независимым review5690215352/Team и CI8/8. 370 требует собственных gates/CI/review;03in_progress, финального merge нет. Пакет0.0.371 переносит33 performance source,14 tracked UID и4 ignored UID в `tools/qa/performance`; четыре публичных фасада и защищённый sampler остаются: root314→285. Обновлены54 живых Python-потребителя, включая запуск прежних root CLI из чужой cwd/Git. Старые FROZEN-ключи/архивы сохраняются; новый collector читает canonical входы, записывает прежний namespace и явный closed layout `qa-performance-v1`. Восемь новых layout-контролей защищают реальный producer/archive/child argv и mutable SAMPLER; fake-open свидетель не является нативной/FPS-приёмкой. [Профиль переноса371](../../reports/refactor-03/performance-move/after-profile.json) сопоставляет настоящие CLI,14 SIGKILL save workers и headless smoke180;18 GD проходят свежий parse. 370 head9a2ad81f принят промежуточным review5690964419/Team; его итоговый CI учитывается отдельно. Для371 обязательны собственные полные gates/CI и независимое ревью точного head.03 остаётся in_progress, финального merge нет. Общий gates-01 выявил frozen import `performance_protocol` до импорта gate; дополнительный четвёртый фасад сохраняет эти исполняемые отчёты. Исходная карта/архивы не переписаны, исключение ожидает независимого ревью. Один source8-case теста воспроизвёл1fail/1error→8/0. Доработка P2 0.0.372 исправляет настоящие grass/ground producer после CHANGES REQUESTED review5691592934 headf134dd9b. Источник helper читается/хешируется/перепроверяется по canonical пути; копия архива и FROZEN/SOURCES сохраняют прежний ключ `tools/perf_contract_collect.py`. Ground и grass reader выбирают единственный old/new helper из того же Git commit с чистым Git-окружением; известная карта расширена ровно на один helper до91. Девять новых real-producer сценариев дают red2fail/9errors (включая subtests)→green9/0: реальные Git/SHA/copy/reader, новая папка, чужая cwd/Git, повреждение, missing canonical и ambiguous aliases. Fake-open проверяет только child argv/I/O; реальные native/GPU/FPS сессии не запускались. [Профиль исправления372](../../reports/refactor-03/performance-review-1/profile.json) сопоставляет исходные collect-body из Git9a2 с текущими по7 input-resolution заменам, четыре реальные prelaunch-архива и6 foreign CLI. Старые подписанные пакеты/доказательства не переписаны. 371 получил CI8/8 и отдельную положительную оценку четвёртого facade, однако весь head с P2 не принят. 372 требует собственных полных gates/CI и повторного независимого ревью точного SHA. Root285,03in_progress/PR21draft, полного merge/Task-Complete нет. Подготовка0.0.373 camera привязывает6 source-root и9 Git-read sites к исходнику/явному проекту. Двенадцать новых реальных context-сценариев: до правки16 failures с учётом subtests, после12/0 на том же source SHA. Проверены вложенные импорты шести настоящих модулей и восемь actual producer: семь запускают только явный fake-child, timing останавливается после source.json перед проверкой процессов. Git/SHA/copy/archive и прежние logical source keys настоящие; неполные пакеты отклоняются штатными readers. Это проверка source envelope, без native/GPU/FPS допуска. Двадцать прежних CLI/отрицательных suites сравниваются из чужой cwd/Git; старые evidence не переписываются. Физических переносов и UID-перемещений нет, root285. 372 head57612b62 принят промежуточным review5692067678/Team и CI8/8; для373 обязательны собственные полные gates/CI/review. 03 остаётся in_progress/PR21draft, полного merge/Task-Complete нет. [Профиль373](../../reports/refactor-03/camera-prepare/after-profile.json). Пакет0.0.374 camera переносит40 исходников и2 tracked UID в `tools/qa/camera`, сохраняя15 ignored UID: root285→245. Два общих источника `visual_camera_points.gd` и `encode_coordinate_video.swift` остаются на своих местах до связанных пакетов их потребителей; это отложенные строки исходной карты, а не отмена переноса или новый окончательный допуск. Живые imports/preload/CLI и физические input reads обновлены, логические SOURCES/архивные назначения прежние. Новая запись timing содержит полную known source_paths; reader связывает с ней точный старый/новый launch URI и отклоняет unknown/partial metadata. Три новых layout-сценария воспроизвели red6fail/1error, после переноса3/0 тем же source. Прежние12 actual-producer context-тестов сохраняют ID/assertions с адресной адаптацией фикстур. До/после сравниваются настоящие22 CLI,17 compile-only Godot и офлайн-декодирование16 кадров из прежних MP4 плюс contact sheet. Это не новая native/Game/GPU/FPS-приёмка профиля. 373 headd2ff4bde принят промежуточным review5692493268/Team, его CI завершился8/8. Для374 обязательны собственные полные TESTING/Wiki/CI и независимое ревью нового exact head.03 in_progress/PR21draft, полного merge/Task-Complete нет. [Профиль374](../../reports/refactor-03/camera-move/after-profile.json). Подготовка0.0.375 world исправляет9 source-root и42 Git-read sites в24 исходниках. Девятнадцать новых real-context тестов воспроизводят red12fail/19error с учётом subtests; после19/0 на том же source SHA;21 stdout побайтно равны. Девять настоящих вложенных import, полные исторические provenance деревни/рендера/теней/пилота/сохранения и четыре actual writer/producer используют реальные Git, SHA и файлы. Два collector останавливаются после source.json перед native context, shadow writer — после настоящих JSON/CSV перед платформенными шрифтами/листами; это не native/GPU/FPS приёмка. До/после запускаются35 actual CLI:15 исторических readers,6 asset verifier и14 прежних отрицательных suites. Frozen source namespaces/архивы, алгоритмы, бюджеты, UID и shared points/encoder сохранены. Физических переносов пока нет, корень245.374 head6b13af8e принят промежуточным review5693093074/Team и CI8/8; 375 требует собственных полных TESTING/Wiki/browser/CI и independent exact-head review. Полная03 остаётся in_progress/PR21draft. [Профиль375](../../reports/refactor-03/world-prepare/after-profile.json). Подготовка0.0.376 world-inputs отделяет37 current-input sites от14 Git-history sites в25 исходниках. Новый helper совмещает прежние art/current maps и141 известных исторических World alias из исходного принятого плана; это не объявляет физический перенос. Уникальный old/new alias выбирается только из того же полного Git commit, с проверкой своего checkout, типа/mode и symlink; нет live fallback. Source lists, архивные имена, численные пороги и прежние metadata сохранены. Audit evidence-каталоги сохраняют отдельное разрешение tree и точные git-show header bytes. Исправлены FOLDER водного анализатора и P3 повторного импорта из review5693715399. 12 integration-тестов читают настоящие Git/capsule bytes в будущем canonical дереве: до1fail/10errors и1 позитивный контроль, после12/0 тем же source; 16 API-контролей проверяют настоящий Git/alias/mode/worktree/replace/foreign context. 13 actual producer используют настоящие Git/SHA/copy и явно fake-open17; process inventory/context являются source-only фикстурами, native кадров и новой Game/GPU/FPS приёмки нет. Прежние19 context cases и15 old negative suites сохраняются. 36 before/after CLI плюс настоящий Water writer в собственной копии четырёх raw сравниваются отдельно; frozen WATER не перезаписывается. Физических/UID переносов нет, root245, current map133; shared sources пока прежние. 375 exact e205c007 принят SOURCE PASS5693715399/Team и CI8/8;376 требует собственных полных TESTING/Wiki/browser/CI/review. 03 остаётся in_progress/PR21draft, полного merge/Task-Complete нет. [Профиль376](../../reports/refactor-03/world-inputs-prepare/after-profile.json). Перенос World-core 0.0.377: 92 исходника и 42 отслеживаемых UID находятся в `tools/qa/world`; два локальных UID сохраняют байты и права доступа. В корне tools остаётся 153 исходника вместо 245. Текущая карта расширена ровно 134 принятыми назначениями до 267; отдельная карта art и 141 исторический World alias прежние. Обновлены импорты, пути запуска и загрузки Godot, адреса текущих фикстур. Логические списки источников и архивные имена сохранены. Внешний сборщик глубины растений читает унаследованные входы World по актуальным адресам и из истории своего Git. Его создание отчёта и чтение архива проверяются отдельно; эти фикстуры не дают новой игровой, native или FPS приёмки. Пять исходников shore-kit и общий render_order_game с UID остаются до следующих зависимых шагов той же REFACTOR-03. Общие camera points, encoder и water anchor сохранены. P3 из review 5695222063 исправлен удалением четырёх неиспользуемых импортов. Пакет 376 принят с CI 8/8; для 377 обязательны новые полные TESTING, Wiki, браузер, CI и независимое ревью точного SHA. REFACTOR-03 остаётся in_progress в draft PR21; полного merge и Task-Complete нет. [Профиль377](../../reports/refactor-03/world-core-move/after-profile.json).

**Промежуточная подготовка Ground 0.0.378:** принятый родитель c47b78…/review5697669336/CI8/8 сохранён.28 прямых Git-вызовов18 модулей изолированы от чужих cwd/index/config;10 настоящих архивных сценариев дали parent9 ошибок → текущие10/0.37 полей21 модуля и frozen reports прежние. Неиспользуемый импорт plant_depth и живые World/Water команды исправлены. [План и проверки](../../reports/refactor-03/ground-context-prepare/README.md). Физических переносов0, корень153, текущая карта267. Полная03 не завершена; PR21 остаётся draft/in_progress, новый head требует независимого ревью и CI.

**Промежуточный перенос Ground 0.0.379:** родитель378 принят [review5704521872](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5704521872), CI 8/8 и Team Lead. 71 исходник/42 UID перемещены в qa/ground, root153→82, карта267→380. Сохранены 37 полей/21 модуль и 302 UID bytes/mode. Новые22 layout, прежние22 CLI/55 GD и fresh import прошли; данные и отказы в [отчёте](../../reports/refactor-03/ground-move/README.md). P3 Path и дополнительные unused в tools-тестах исправлены, аудит35 Python включает15 тестовых модулей. Вся03 остаётся in_progress/draft PR21, нужны полные TESTING и независимые exact-head CI/review; без merge/Task-Complete.

- Ground379: первый Game выявил25 source-hash ошибок после переноса; QA-only bridge сохраняет frozen .res и различает точный preload move от изменения содержимого. Свежие compiler hashes и девять byte-equal масок проверены отдельно; обязательна новая полная gates-03 (gates-02: ps запрещён sandbox; точный permitted replay1/0).

**Финальный кандидат0.0.380:** Финальный перенос REFACTOR-03, кандидат0.0.380: 77 исходников (включая шесть nested grass_compare) и34 tracked UID распределены по qa/foliage, qa/world и qa/camera; четыре ignored UID сохраняются локально. Корень tools82→11 при лимите30. Все779 назначений исходного плана сверены отдельно от generic map491; два прежних исключения — PIL importer в authoring и protocol facade — сохранены. Все304 UID bytes/mode и37 полей21 source-contract модуля прежние. До/после:22 actual CLI,243 прежних теста и114 Godot compile-only; 11 исторических stdout побайтно равны. Новые11 context,10 provenance и10 actual-producer случаев проверяют свои Git/cwd/index/config, canonical input/copy/hash и точный launch URI; fake-open17 не рисует кадры и не даёт native/FPS-приёмки. Старые отчёты не переписаны. Родитель379 принят review5706289303, CI8/8 и Team Lead. Полная03 остаётся in_progress в PR21 до обязательных gates, независимого ревью текущего head, CI и решения Team Lead; merge/Task-Complete пока нет.

Подробные назначения/исключения и все raw: [foliage/shared](../../reports/refactor-03/foliage-shared/README.md). P3 родительского ревью: живые counters379 исправлены на35 Python/15 tools-тестов; frozen отчёт379 не переписан.

**Доработка P2 0.0.381:** P2 REFACTOR-03, кандидат0.0.381: `qa.foliage.test_relocation_provenance` проверяет20 случаев, включая10 новых тестов/54 подслучая границы engine/user argv. Parent2c856d7d дал32 failed subtests/4 errors, текущий reader20/0 на том же test SHA. Поиск script завершается на первом --/++; open --args и прямой Godot разделены, дубли/конфликтующие формы отклоняются, payload-флаги не влияют на engine. Все10 прежних test-методов и остальные функции reader сохранены;18 старых Grass controls и исторический stdout проходят без изменений. Parent380 не принят из-за P2;03 остаётся in_progress/PR21draft до новых полных TESTING, exact-head review/CI и решения Team Lead. Frozen evidence и runtime не переписаны. [Доказательства](../../reports/refactor-03/launch-boundary-review/README.md).

**Подтверждения / результат:** Полная REFACTOR-03 принята через [PR №21](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21): head `7976630ce372d3e7ac0c15b154ca7377d398450c`, [независимое ревью 5708056404](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/21#pullrequestreview-5708056404), CI 8/8 и решение Team Lead. Фактический merge `dd506fdd2cb98f1364c0e367c9f73c670064a6d0` от 30 октября 2026 имеет то же дерево, что проверенный head. Все 779 назначений учтены, в корне tools 11 исходников при лимите 30; сохранены 304 канонических UID и 37 логических полей 21 модуля. [Каноническая запись приёмки](../../reports/refactor-03/closeout/completion.json) отделяет принятый CI реализации от собственных проверок учёта. Профили 380/381 и все предыдущие отказы сохранены. Следом07→06→маршрут первой overworld; 04/05 и VMAP-003 не объявляются выполненными.

## REFACTOR-04 — Сгруппировать профильные suites и helpers без потери запуска

**Статус:** blocked · **Приоритет:** P2 · **Объём:** M · **Тип:** refactor.

**Ветка:** codex/refactor-04-maintainable-layout

**Результат и объём:** Тематические папки tests/suites и helpers из принятой ведомости. Runner остаётся агрегатором; вместе перемещаются preload-потребители и UID.

**Внутренние блокеры:** REFACTOR-01, REFACTOR-06.

**Условия запуска:** Зависимости приняты и done; актуальная main и принятая карта путей. VMAP-003 не является блокером заказанного технического первого выпуска.

**Приёмка:**

- Каждый прежний suite подключён ровно один раз; сравнение до/после различает потерю и дубль набора, а не только общий зелёный счётчик.
- Сканеры методов/русских комментариев/лимитов и отдельные QA-профили находят вложенные тесты.
- Профильные negative controls и полный Game дают прежние условия/отказы; существующие сценарии не заменены тестами одних новых путей.
- Изменения production, ассетов и исторических доказательств отсутствуют.

**Проверка:** Ведомость подключения до/после, адресные запуски перенесённых suites, полный TESTING.md и exact-head CI. Статусы чужих задач не менять.

**Подтверждения / результат:** Не начато. Отдельный этап после полезного выпуска tools; порядок с маршрутом overworld подтверждает Team Lead.

## REFACTOR-05 — Упорядочить подтверждённые семейства systems и presentation

**Статус:** blocked · **Приоритет:** P2 · **Объём:** L · **Тип:** refactor.

**Ветка:** codex/refactor-05-maintainable-layout

**Результат и объём:** Только перечисленные в аудите связные домены scripts/systems и scripts/presentation, по одному тематическому пакету. Не создавать новые системы и не менять игровые правила ради структуры.

**Внутренние блокеры:** REFACTOR-01, REFACTOR-04.

**Условия запуска:** Зависимости приняты и done; актуальная main и принятая карта путей. VMAP-003 не является блокером заказанного технического первого выпуска.

**Приёмка:**

- У каждого переносимого семейства есть владелец, граница и все preload/сериализованные пути; непроверенные каталоги не включены.
- UID и ресурсные ссылки сохраняются; main и сохранения загружаются в чистом импорте и после обычного обновления.
- Сравнение подтверждает механический перенос без изменения алгоритмов, RNG, игрового времени, FPS-политики и данных.
- Исторические проверки продолжают использовать свои исходники; внешние entry points и документация согласованы.

**Проверка:** Один небольшой домен на ревью, его поведенческие регрессии, старый save/штатный запуск/переходы и TESTING.md. Если аудит не подтвердил пользу, сохранить аргументированный отказ от конкретного переноса и пересогласовать объём через Team Lead.

**Подтверждения / результат:** Не начато. Сам по себе размер папки не разрешает массовое переписывание production.

## REFACTOR-06 — Закрепить навигацию и правило добавления новых инструментов

**Статус:** done · **Приоритет:** P1 · **Объём:** M · **Тип:** validation.

**Ветка:** codex/refactor-06-maintainable-layout

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/31

**Учётный Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/32

**Дата завершения:** 2026-10-31

**Результат и объём:** README tools, правила размещения/владельцев и адресный guard против повторного засорения корня. Итоговая ведомость остальных каталогов, отдельные статусы будущих 04/05.

**Внутренние блокеры:** REFACTOR-03, REFACTOR-07.

**Условия запуска:** REFACTOR-03 принята и done; актуальная main и принятая карта путей. Последняя команда пользователя отменяет прежнюю остановку и задаёт порядок07→06:06 берётся после приёмки приоритетной REFACTOR-07. Дополнительное подтверждение владельца не требуется; VMAP-003 не является блокером этой технической очереди.

**Приёмка:**

- Человек находит общий gate, QA травы и обработку атласа по README и успешно запускает команды из двух cwd.
- Проверка реального списка файлов отклоняет новый внутренний инструмент в корне и допускает документированные публичные исключения; не фиксирует навечно весь снимок репозитория.
- Порог корня и принадлежность проверяются для исходников и UID честно; новые вложенные файлы не выпадают из существующих gates.
- Итоговый отчёт содержит исходные/новые числа, полную карту путей и реальные проверки; старые raw/SHA прежние. Невыполненные 04/05 не объявлены завершёнными.

**Проверка:** Чистый checkout, штатный локальный и CI-запуск, отрицательная копия с новым ошибочно размещённым инструментом; Wiki check и независимое exact-head ревью.

**Подтверждения / результат:** [PR31](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/31) принят на exact head `81142f385603668792377964a1d4f2bd50afb8a6`: после CHANGES_REQUESTED review5724024281 fail-closed дефект недоступного каталога закрыт адресным parent-red/current-green, независимое [review5724142227](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/31#pullrequestreview-5724142227) дало APPROVED. Два exact-head workflow run `41224322959` и `41224327750` завершили 8/8 jobs success; Team Lead принял результат. Merge `bcf9b1031ba80a0d0840d10e615f5c7d00d31cf0` от `2026-10-31T17:50:59Z` имеет родителей `b560e1f4485d02dd7d3c8ede808847996e8111e8` и reviewed head, дерево `33fed2983acd12c30e2850969f7a5d07cf44a35e`. Закрыт только первый выпуск структуры tools: REFACTOR-04/05 остаются `blocked`, весь эпик не объявлен завершённым, следующая очередь — первая overworld до VMAP-003. [Запись приёмки](../../reports/refactor-06/closeout/completion.json).

Task-Complete: REFACTOR-06

## REFACTOR-07 — Линтеры, форматирование и самопроверка реальных сценариев перед ревью

**Статус:** done · **Приоритет:** P1 · **Объём:** M · **Тип:** refactor.

**Ветка:** codex/refactor-07-quality-gates

**Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/28

**Учётный Pull Request:** https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/29

**Дата завершения:** 2026-10-31

**Результат и объём:** Воспроизводимый барьер качества изменяемого GDScript/Python и самопроверка настоящих публичных сценариев до независимого ревью. Постановка пользователя28.10.2026; последующей прямой командой передана Developer в очередь после03.

**Внутренние блокеры:** REFACTOR-03.

**Условия запуска:** Полная03 принята и учтена: PR21/PR26, merge464328853c2fbbed1410ac0312de75c3fee7cfa2, done30.10.2026. Порядок последней прямой команды пользователя:03→07→06→первая overworld до VMAP-003. Зависимости07 от06 нет. Прежняя остановка после07 отменена; дополнительное подтверждение владельца не требуется.

**Проблема:** Возвраты выявили устаревшие живые команды, чтение чужого Git и тесты, собиравшие fixture самостоятельно вместо вызова настоящего create. Линтер не заменяет проверку этих контрактов.

**Первый выпуск / этапы:**

1. Снять базу принятых Godot/Python/CI, предупреждений, публичных входов и стоимости проверок. Малой пробой на одном GDScript и одном Python-инструменте проверить совместимость и закрепить версии/установку.
2. GDScript: gdformat для формата, gdlint для стиля/сложности и настоящий анализатор Godot после свежего импорта для семантики. Постепенно включать полезные предупреждения типов/небезопасных операций как ошибки. gdlint не считать полным аналогом PHPStan.
3. Python: Ruff lint/format и один type checker — mypy либо Pyright по результату пробы. Проверить поддерживаемые версии Python и launcher/imports; не подключать конкурирующие форматтеры.
4. Один быстрый локальный check и те же правила в CI; отдельная явная fix-команда. CI молча не исправляет. Начать с целых изменяемых файлов, прозрачного baseline старых нарушений и узких мотивированных исключений. Новые вложенные файлы не пропускать.
5. Самопроверка в CODE_REVIEW.md/TESTING.md: прочитать diff, перечислить изменённые контракты и действующих потребителей; вызвать настоящую публичную точку входа на пустом внешнем временном каталоге с реальными файловыми/Git I/O. Проверить артефакты, URI/JSON, коды выхода, запрет перезаписи и отказы. Тест не обходит producer собственной сборкой fixture. По риску путей/imports/Git проверить чужой cwd, пробелы, hostile PYTHONPATH/GIT_* и настоящий linked worktree. Проверять живые команды безопасно; --help не доказывает работу create/export.
6. Существенные дефекты ревью превращать в адресные регрессии: одинаковый сценарий старого кода даёт отказ, исправленный проходит; ограничения честно объяснять. Reviewer получает точный SHA, фактические команды/результаты, сохранённые отказы и непроверенные условия. Независимое ревью сохраняется.

**Приёмка:**

- Локальный и CI check используют одинаковые закреплённые версии/правила. Реальные отрицательные примеры формата, lint и типов отклоняются профильными инструментами; исправленные проходят. Godot обнаруживает реальную ошибку GDScript.
- Baseline/исключения не скрывают новые нарушения; новый вложенный исходник проверяется. Нет массового форматирования старого кода, изменения алгоритмов/механик или autofix исторических доказательств.
- Настоящий producer создаёт внешний проект; регрессии устаревшей команды, namespace fixture и чужой Git-истории обнаруживаются до ревью. Исходный проект, окружение и чужой index/config прежние, temp очищены.
- Быстрый gate и профильные сценарии документированы, время измерено; полные gates TESTING.md и прежние отрицательные проверки не ослаблены. Reviewer воспроизводит малую пробу на чистом checkout.
- Frozen raw/provenance/исторические SHA сохранены. Синтаксическая/headless проверка не выдаётся за игровой или аппаратный допуск.

**Проверка:** Отрицательные примеры каждого инструмента; реальный сценарий и отказ в disposable checkout; TESTING.md по объёму и Wiki check при её правках. Снять baseline классов возвратов; после нескольких сопоставимых PR сравнить повторные ошибки и стоимость проверок. Нулевое число замечаний не обещать и не добиваться сокрытием дефектов.

**Польза / аудитория / риск:** Developer и reviewer; польза5/5, удобство4/5, соответствие5/5, стоимость3/5, риск3/5 — гипотезы. Риски: несовместимый парсер Godot, шум старого кода, ложная уверенность от линтера и обход сценария тестовым двойником. Внедрение малыми проверяемыми этапами.

**Источники:** [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit), [предупреждения Godot](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html). Точные версии и Python type checker выбрать малой пробой при запуске.

**Подтверждения / результат:** Реализация0.0.383/source060787d9 опубликована в PR28. Закреплены Ruff/mypy/gdtoolkit и реальный Godot, целые изменяемые файлы и явный fix; исходный legacy не форматировался. Полные локальные gates: architecture108/1424, Game53502/0, normal/F10по90, smoke180, performance6/6, Wiki145; последние guard/русские комментарии отдельно прошли11 quality cases, static8, реальный mirror и14 producer-команд. Browser1280/390 и8 карточек проверены. [Результаты и точные границы freeze](../../reports/refactor-07/local-validation.json). Отказ первого loader-контроля явно не считается red; корректный повтор подтвердил запуск теста на прежнем/новом helper. Версия0.0.384 добавляет URL PR и фактический статус без изменения quality-кода.03done/дата, канонические UID/старые reports прежние;06blocked. Независимое ревью вернуло P2: live working check мог скрыть ошибочные staged bytes, включая legacy baseline. Доработка0.0.385 вводит read-only --staged до bump и11 реальных Git/hook/alternate-index случаев, включая legacy до baseline. Финальный полный прогон без родительского bytecode-флага: architecture109/1436, Game53502/0, normal/F10, smoke, performance и Wiki145/0; source1230, прежние reports22411, tracked UID800 и index/чужие данные сохранены. Прерванные96/1259 не считаются полной приёмкой. [Финальные проверки P2](../../reports/refactor-07/review-p2-index/final-validation.json).

**Итоговая приёмка:** [PR №28](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/28) принят на exact head `c5c2a2d68bc5c79cb61f2bf1c27fe8fa0ccf3703`: независимое [ревью 5718136092](https://github.com/sergey-leonidovich-shevchenko/babushkina-ferma/pull/28#pullrequestreview-5718136092) закрыло P2 и не нашло новых замечаний, CI завершился 8/8 success, Team Lead подтвердил merge. Merge `7d8c62be8a98edcd34cf1ede3919625295c5076e` от `2026-10-30T20:16:31Z` (`2026-10-31 01:16:31`, Asia/Almaty) имеет дерево `ee3a17e5bc8463eba6eb3918137367a5409005d6`, совпадающее с reviewed head. В CI оба основных job дали architecture109/1436, Game53520/0, normal/F10, smoke и performance6/6; это отдельно от локального Game53502/0, оба факта сохранены без подмены. [Запись приёмки](../../reports/refactor-07/closeout/completion.json) отделяет реализацию от учётного PR. Следующая задача — REFACTOR-06; новые механики, VMAP и аппаратная графическая приёмка этой записью не закрываются.

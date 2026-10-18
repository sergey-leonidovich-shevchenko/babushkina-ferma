# VPIPELINE · Подготовка ассетов и импорт

[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)

<a id="vpipeline-001"></a>

## VPIPELINE-001 — Разделить мастер и runtime

Статус: `done` · P0 · этап `foundation` · `engineering`

Концепты, послойные исходники, превью и игровые файлы имеют отдельные пути и .gdignore там, где импорт не нужен

Ветка: `codex/vpipeline-001-visual-task`.

Зависимости: VART-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-001/`.

Критерии:

- Концепты, послойные исходники, превью и игровые файлы имеют отдельные пути и .gdignore там, где импорт не нужен
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-001/README.md, docs/reports/visual-overhaul/vpipeline-001/baseline.json, docs/reports/visual-overhaul/vpipeline-001/import-comparison.json, docs/reports/visual-overhaul/vpipeline-001/native-comparison.json, docs/reports/visual-overhaul/vpipeline-001/browser.json, docs/reports/visual-overhaul/vpipeline-001/verification.json, tools/visual_pipeline.py, tools/test_visual_pipeline.py, tests/suites/asset_boundary_suite.gd, wiki/articles/visual-pipeline.md, wiki/articles/IDEA-001.md, docs/reports/visual-overhaul/vpipeline-001/additional-local-preview-audit.json, docs/reports/visual-overhaul/vpipeline-001/local-tile-preview-relocation.json, docs/reports/visual-overhaul/vpipeline-001/editor-textures-after.json.

<a id="vpipeline-002"></a>

## VPIPELINE-002 — Описать метаданные нового ресурса

Статус: `done` · P0 · этап `foundation` · `engineering`

ID, source rect, pivot, физический размер, ракурсы, фильтр и варианты качества сохраняются независимо от имени PNG

Ветка: `codex/vpipeline-002-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-002/`.

Критерии:

- ID, source rect, pivot, физический размер, ракурсы, фильтр и варианты качества сохраняются независимо от имени PNG
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-002/README.md, docs/reports/visual-overhaul/vpipeline-002/native-comparison.json, docs/reports/visual-overhaul/vpipeline-002/verification.json, docs/reports/visual-overhaul/vpipeline-002/browser.json, assets/game/visual_resources.json, scripts/systems/visual_resource_catalog.gd, tools/visual_resources.py, tools/test_visual_resources.py, tests/suites/visual_resource_suite.gd, docs/VISUAL_RESOURCE_FORMAT.md, wiki/articles/visual-resources.md.

<a id="vpipeline-003"></a>

## VPIPELINE-003 — Настроить фильтрацию по семействам

Статус: `done` · P0 · этап `foundation` · `engineering`

Linear и nearest сравниваются адресно; изменение общего флага не размывает старые шрифты и атласы

Ветка: `codex/vpipeline-003-visual-task`.

Зависимости: VPIPELINE-001, VPIPELINE-002.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-003/`.

Критерии:

- Linear и nearest сравниваются адресно; изменение общего флага не размывает старые шрифты и атласы
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-003/README.md, docs/reports/visual-overhaul/vpipeline-003/native-comparison.json, docs/reports/visual-overhaul/vpipeline-003/native/after/capture.json, docs/reports/visual-overhaul/vpipeline-003/browser.json, docs/reports/visual-overhaul/vpipeline-003/verification.json, assets/game/visual_sampling.json, scripts/presentation/visual_sampling_system.gd, tools/visual_sampling.py, tools/test_visual_sampling.py, tests/suites/visual_sampling_suite.gd, wiki/articles/visual-sampling.md.

<a id="vpipeline-004"></a>

## VPIPELINE-004 — Подготовить padding атласов

Статус: `done` · P0 · этап `foundation` · `engineering`

Экструзия края и запас учитывают фильтр и mip; на уменьшении не видны соседние кадры

Ветка: `codex/vpipeline-004-visual-task`.

Зависимости: VPIPELINE-001, VPIPELINE-003.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-004/`.

Критерии:

- Экструзия края и запас учитывают фильтр и mip; на уменьшении не видны соседние кадры
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-004/README.md, docs/reports/visual-overhaul/vpipeline-004/native-comparison.json, docs/reports/visual-overhaul/vpipeline-004/native/capture.json, docs/reports/visual-overhaul/vpipeline-004/browser.json, docs/reports/visual-overhaul/vpipeline-004/verification.json, assets/game/items/ui/padded/catalog.json, scripts/presentation/padded_atlas_system.gd, tools/padded_atlases.py, tools/test_padded_atlases.py, tests/suites/padded_atlas_suite.gd, wiki/articles/padded-atlases.md.

<a id="vpipeline-005"></a>

## VPIPELINE-005 — Проверить цветовые и data текстуры

Статус: `done` · P0 · этап `foundation` · `engineering`

Маски глубины и гибкости не проходят цветовую коррекцию; RGBA значения после импорта проверены численно

Ветка: `codex/vpipeline-005-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-005/`.

Критерии:

- Маски глубины и гибкости не проходят цветовую коррекцию; RGBA значения после импорта проверены численно
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-005/README.md, docs/reports/visual-overhaul/vpipeline-005/numeric-proof.json, docs/reports/visual-overhaul/vpipeline-005/room-comparison.json, docs/reports/visual-overhaul/vpipeline-005/browser.json, docs/reports/visual-overhaul/vpipeline-005/verification.json, assets/game/visual_texture_intents.json, scripts/presentation/texture_intent_system.gd, tools/texture_intents.py, tools/test_texture_intents.py, tests/suites/texture_intent_suite.gd, wiki/articles/data-textures.md.

<a id="vpipeline-006"></a>

## VPIPELINE-006 — Закрепить два размера иконок

Статус: `done` · P0 · этап `foundation` · `engineering`

64 для сетки и 160 для выбранного превью; opening шкафа не декодирует все крупные мастера

Ветка: `codex/vpipeline-006-visual-task`.

Зависимости: VPIPELINE-002, VART-010.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-006/`.

Критерии:

- 64 для сетки и 160 для выбранного превью; opening шкафа не декодирует все крупные мастера
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-006/README.md, docs/reports/visual-overhaul/vpipeline-006/proof.json, docs/reports/visual-overhaul/vpipeline-006/after/capture.json, docs/reports/visual-overhaul/vpipeline-006/browser.json, docs/reports/visual-overhaul/vpipeline-006/verification.json, scripts/presentation/prepared_item_icon_system.gd, tools/item_ui_fitter.gd, tools/item_sizes.py, tools/test_item_sizes.py, tests/suites/item_sizes_suite.gd, wiki/articles/item-icon-sizes.md.

<a id="vpipeline-007"></a>

## VPIPELINE-007 — Сделать проверку альфа-краёв

Статус: `done` · P0 · этап `foundation` · `engineering`

Белый и пурпурный matte обнаруживается отчётом и контрольным фоном; инструмент не удаляет белые детали предмета

Ветка: `codex/vpipeline-007-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-007/`.

Критерии:

- Белый и пурпурный matte обнаруживается отчётом и контрольным фоном; инструмент не удаляет белые детали предмета
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-007/README.md, docs/reports/visual-overhaul/vpipeline-007/legacy-baseline.json, docs/reports/visual-overhaul/vpipeline-007/proof.json, docs/reports/visual-overhaul/vpipeline-007/native/capture.json, tools/alpha_audit.py, tools/alpha_metrics.py, tools/test_alpha_audit.py, tools/test_alpha_proof.py, wiki/articles/alpha-edges.md, wiki/articles/alpha-candidates.md.

<a id="vpipeline-008"></a>

## VPIPELINE-008 — Проверить целостность нарезки

Статус: `done` · P0 · этап `foundation` · `engineering`

Каждый source rect в пределах изображения, имеет запас и pivot; край подсолнуха и оружия не обрезан

Ветка: `codex/vpipeline-008-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-008/`.

Критерии:

- Каждый source rect в пределах изображения, имеет запас и pivot; край подсолнуха и оружия не обрезан
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-008/README.md, docs/reports/visual-overhaul/vpipeline-008/proof.json, docs/reports/visual-overhaul/vpipeline-008/legacy-slices.json, docs/reports/visual-overhaul/vpipeline-008/after/inventory.json, docs/reports/visual-overhaul/vpipeline-008/after/measurements.json, docs/reports/visual-overhaul/vpipeline-008/before-native/capture.json, docs/reports/visual-overhaul/vpipeline-008/after-native/capture.json, docs/reports/visual-overhaul/vpipeline-008/legacy-native/capture.json, docs/reports/visual-overhaul/vpipeline-008/browser.json, docs/reports/visual-overhaul/vpipeline-008/verification.json, tools/slice_audit.py, tools/slice_metrics.py, tools/slice_export.gd, tools/slice_catalogs.gd, tools/slice_policy.json, tools/slice_proof.py, tools/test_slice_audit.py, tools/test_slice_proof.py, tests/suites/atlas_source_geometry_suite.gd, wiki/articles/sprite-slices.md, wiki/articles/slice-risks.md.

<a id="vpipeline-009"></a>

## VPIPELINE-009 — Составить безопасную миграцию файлов

Статус: `done` · P0 · этап `foundation` · `engineering`

Замена сохраняет стабильные ID и ссылки Wiki/F12; удаление старого ассета только после проверки всех потребителей

Ветка: `codex/vpipeline-009-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-009/`.

Критерии:

- Замена сохраняет стабильные ID и ссылки Wiki/F12; удаление старого ассета только после проверки всех потребителей
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vpipeline-009/README.md, docs/reports/visual-overhaul/vpipeline-009/plan.json, docs/reports/visual-overhaul/vpipeline-009/inventory.json, docs/reports/visual-overhaul/vpipeline-009/proof.json, docs/reports/visual-overhaul/vpipeline-009/fixture-sources.json, docs/reports/visual-overhaul/vpipeline-009/production-unchanged.json, docs/reports/visual-overhaul/vpipeline-009/wiki-contract.json, docs/reports/visual-overhaul/vpipeline-009/browser.json, docs/reports/visual-overhaul/vpipeline-009/verification.json, docs/reports/visual-overhaul/vpipeline-009/historical-replay.json, tools/asset_migration.py, tools/migration_inventory.py, tools/migration_fixture.py, tools/migration_capture.gd, tools/migration_proof.py, tools/test_asset_migration.py, tools/test_migration_proof.py, wiki/articles/asset-migration.md.

<a id="vpipeline-010"></a>

## VPIPELINE-010 — Собрать лицензионный и размерный отчёт

Статус: `done` · P0 · этап `foundation` · `engineering`

Каждый production файл имеет происхождение, размеры и оценку памяти; архивы макетов исключены из игрового экспорта

Ветка: `codex/vpipeline-010-visual-task`.

Зависимости: VPIPELINE-001.

Единый владелец пересечения: **OPT-03**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/visual_asset_system.gd](../../../../scripts/systems/visual_asset_system.gd)
- [scripts/presentation/prepared_item_icon_system.gd](../../../../scripts/presentation/prepared_item_icon_system.gd)
- [assets/game/world_sprite_manifest.json](../../../../assets/game/world_sprite_manifest.json)

Результаты: `docs/reports/visual-overhaul/vpipeline-010/`.

Критерии:

- Каждый production файл имеет происхождение, размеры и оценку памяти; архивы макетов исключены из игрового экспорта
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить source rect, alpha, размеры, профили импорта и ссылки; испортить тестовую копию ассета и убедиться в явной ошибке.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: 18 октября 2026: docs/reports/visual-overhaul/vpipeline-010/README.md; снимок commit 6ade4a2c, 2839 production-файлов, 1190 растров/встроенных текстур, SHA, размеры, альфа, импорт, адресные источники и номинальная RGBA8-оценка. 400 прямых медиа с неустановленным происхождением и 31 вычисляемый источник превью остаются долгом перед VRELEASE; отчёт не выдаёт разрешение на выпуск., Настоящий export-pack: 3874 записи / 1595 ресурсов; исходники и архивы макетов исключены, JSON/TXT включены. Нативные 1190 текстур и восемь GPU-кадров 1152x648: реальные деревня/дом при одной камере и состоянии, 0 разных пикселей. Пакет запущен из пустой физической папки; испорченная копия выявила утечку архива и потерянный ctex. Production-пиксели, ссылки и сохранения не изменены., 17 сценариев стоимости/источников/ZIP + 8 порчи доказательств; architecture gate, полный игровой набор 44082/0, Wiki build/TypeScript и 41 Node-тест. Wiki: asset-costs, CSV/JSON; скачанный в браузере CSV имеет 2839 строк с SHA источника; 921 игровая статья не изменилась. Версия 0.0.247..

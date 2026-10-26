# Полная карта tools — REFACTOR-01

Предложение по принятой базе `da9fa07e2f4c7f1fe05d9e89eebc454afc79d4ff` (0.0.342). **Все 779 файлов учтены; переносов ещё нет.** UID отдельно доступны в CSV/JSON; здесь они показаны у исходника. Текущая карточка in_progress до принятия PR.

[Обзор и риски](project-refactoring.md) · [карточка REFACTOR-01](#/development/tasks/refactoring--REFACTOR-01) · [полная JSON-карта с consumers](../../docs/reports/refactor-01/integration-1/snapshot/tool-map.json) · [CSV](../../docs/reports/refactor-01/integration-1/snapshot/tool-map.csv) · [счётчики](../../docs/reports/refactor-01/integration-1/snapshot/inventory.json) · [граф suites](../../docs/reports/refactor-01/integration-1/snapshot/suite-registry.json) · [другие каталоги](../../docs/reports/refactor-01/integration-1/snapshot/other-catalogs.json).

Плановый корень — девять исходников при бюджете 30: шесть публичных CLI/import-фасадов, два полных исторических anchor и один новый launcher. Нынешний корень содержит 553 исполняемых исходника; во всём tools — 558 таких исходников и 1 вложенный shader. Числа в таблицах — статические ссылки ledger, включая историю, **не число запусков**. Наличие ссылки не доказывает исполнение, её отсутствие не разрешает удаление. Точные consumer/строки раскрываются JSON-картой и командой `audit.py show`, приведённой в обзоре.

Таблица ниже побайтно взята из `docs/reports/refactor-01/integration-1/snapshot/tool-map.md` после его вводной части. Исходный SHA и отдельные пары UID закреплены в JSON. Разделы соответствуют 17 семействам; поиск Wiki находит конкретное имя инструмента.

Авторские docstrings в назначении извлечены из принятой базы; это исторические описания, а не замена нынешнему процессу PR. В частности task_batch publish не является рабочим маршрутом публикации.

## Проверки репозитория

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/check_architecture.sh` | `tools/quality/check_architecture.sh` | Проверки репозитория: вход или вспомогательный модуль семейства | 186 |
| `tools/check_documentation.py` | `tools/quality/check_documentation.py` | Проверки репозитория: вход или вспомогательный модуль семейства. Проверяет обязательные документы и локальные ссылки Markdown. | 20 |
| `tools/test_documentation.py` | `tools/quality/test_documentation.py` | Проверки репозитория: профильные и отрицательные Python-контроли. Проверяет границы обхода документации после добавления веб-зависимостей. | 13 |

## Бэклоги и служебный учёт

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/build_art_backlog.py` | `tools/planning/build_art_backlog.py` | Бэклоги и служебный учёт: подготовка ресурсов или эталонов. Распределяет весь измеренный реестр по точным художественным партиям без пропусков. | 4 |
| `tools/build_optimization_matrix.py` | `tools/planning/build_optimization_matrix.py` | Бэклоги и служебный учёт: подготовка ресурсов или эталонов. Собирает воспроизводимый план из 320 отдельных сценариев; план не равен выполненным проверкам. | 6 |
| `tools/bump_version.py` | `tools/planning/bump_version.py` | Бэклоги и служебный учёт: вход или вспомогательный модуль семейства. Повышает SemVer приложения и синхронизирует Godot и macOS metadata. | 19 |
| `tools/pilot_rollout.py` | `tools/planning/pilot_rollout.py` | Бэклоги и служебный учёт: вход или вспомогательный модуль семейства. Проверяет ограниченную очередь пилота; состояния задач берёт только из общего бэклога. | 13 |
| `tools/project_backlog.py` | `tools/planning/project_backlog.py` | Бэклоги и служебный учёт: вход или вспомогательный модуль семейства. Офлайн-проверка и читаемое представление плана разработки в репозитории. | 16 |
| `tools/task_batch.py` | `tools/planning/task_batch.py` | Бэклоги и служебный учёт: вход или вспомогательный модуль семейства. Считает завершённые задачи в main и публикует пакет из десяти задач. | 13 |
| `tools/test_pilot_rollout.py` | `tools/planning/test_pilot_rollout.py` | Бэклоги и служебный учёт: профильные и отрицательные Python-контроли. Отрицательные сценарии первой очереди, полного графа и границ неподтверждённой реализации. | 5 |
| `tools/test_project_backlog.py` | `tools/planning/test_project_backlog.py` | Бэклоги и служебный учёт: профильные и отрицательные Python-контроли. Проверки плана, блокирующих связей, статусов и читаемых карточек. | 6 |
| `tools/test_task_batch.py` | `tools/planning/test_task_batch.py` | Бэклоги и служебный учёт: профильные и отрицательные Python-контроли. Проверяет публикацию задач на изолированных репозиториях без сети. | 7 |
| `tools/test_visual_backlog.py` | `tools/planning/test_visual_backlog.py` | Бэклоги и служебный учёт: профильные и отрицательные Python-контроли. Негативные проверки плана: структура не должна ложно обещать готовность или покрытие. | 16 |
| `tools/visual_backlog.py` | `tools/planning/visual_backlog.py` | Бэклоги и служебный учёт: вход или вспомогательный модуль семейства. Проверяет отдельный визуальный план и собирает его читаемые карточки без изменения статусов. | 28 |

## Подготовка графических ресурсов

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/build_bridge_sprites.py` | `tools/assets/authoring/build_bridge_sprites.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Детерминированно извлекает законченные мосты из лицензионного монтажного листа. | 33 |
| `tools/build_building_sprites.py` | `tools/assets/authoring/build_building_sprites.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Извлекает восемь фасадов из дробного исходного листа без повторного масштабирования. | 21 |
| `tools/build_clean_interior_atlas.gd` | `tools/assets/authoring/build_clean_interior_atlas.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 6 |
| `tools/build_editor_transition_tiles.py` | `tools/assets/authoring/build_editor_transition_tiles.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Собирает сезонную траву и диагональные переходы редактора из утверждённых тайлов 24×24. | 67 |
| `tools/build_environment_sprites.py` | `tools/assets/authoring/build_environment_sprites.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Собирает модульные сезонные, лунные и биомные спрайты из старых дробных листов. | 213 |
| `tools/build_fence_atlas.py` | `tools/assets/authoring/build_fence_atlas.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Нормализует художественный лист заборов в строгую сетку 8×5 по 64 px. | 289 |
| `tools/build_forest_tree_atlas.py` | `tools/assets/authoring/build_forest_tree_atlas.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Собирает строгие RGBA-атласы стадий лесных и плодовых деревьев. | 5 |
| `tools/build_house_furniture.gd` | `tools/assets/authoring/build_house_furniture.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: отслеживается | 90 |
| `tools/build_item_ui_textures.gd` | `tools/assets/authoring/build_item_ui_textures.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: отслеживается | 795 |
| `tools/build_level_editor_tiles.py` | `tools/assets/authoring/build_level_editor_tiles.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Нарезает утверждённые мастера местности на отдельные игровые тайлы 24×24. | 118 |
| `tools/build_painted_item_icons.gd` | `tools/assets/authoring/build_painted_item_icons.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: отслеживается | 179 |
| `tools/build_prepared_pixels.gd` | `tools/assets/authoring/build_prepared_pixels.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: отслеживается | 24 |
| `tools/build_ui_kit.py` | `tools/assets/authoring/build_ui_kit.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Нарезает художественный мастер UI на независимые PNG без соседнего bleed. | 35 |
| `tools/build_village_materials.gd` | `tools/assets/authoring/build_village_materials.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 43 |
| `tools/build_village_prop_atlas.py` | `tools/assets/authoring/build_village_prop_atlas.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Нормализует дробный деревенский лист 4×2 в строгий RGBA-атлас. | 5 |
| `tools/build_village_props.gd` | `tools/assets/authoring/build_village_props.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 41 |
| `tools/extract_artisan_assets.py` | `tools/assets/authoring/extract_artisan_assets.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Создаёт только метаданные нарезки; исходные RGBA-пиксели остаются неизменными. | 322 |
| `tools/extract_basement_atlases.py` | `tools/assets/authoring/extract_basement_atlases.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Copies unchanged approved pixels; records measured AtlasTexture regions. | 161 |
| `tools/extract_farm_icons.gd` | `tools/assets/authoring/extract_farm_icons.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 288 |
| `tools/extract_farmyard_sprites.gd` | `tools/assets/authoring/extract_farmyard_sprites.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 65 |
| `tools/extract_hero_combat_sprites.gd` | `tools/assets/authoring/extract_hero_combat_sprites.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: отслеживается | 115 |
| `tools/extract_kitchen_atlases.py` | `tools/assets/authoring/extract_kitchen_atlases.py` | Подготовка графических ресурсов: подготовка ресурсов или эталонов. Воспроизводит измеренные AtlasTexture без изменения пикселей утверждённых атласов. | 55 |
| `tools/measure_character_walk.py` | `tools/assets/authoring/measure_character_walk.py` | Подготовка графических ресурсов: вход или вспомогательный модуль семейства. Measure existing complete figures without changing any source pixel. | 22 |
| `tools/measure_hero_actions.py` | `tools/assets/authoring/measure_hero_actions.py` | Подготовка графических ресурсов: вход или вспомогательный модуль семейства. Read-only pixel measurements; source images are never modified here. | 3 |
| `tools/measure_skeleton_regions.py` | `tools/assets/authoring/measure_skeleton_regions.py` | Подготовка графических ресурсов: вход или вспомогательный модуль семейства. Измеряет целые прозрачные фигуры без изменения пикселей исходников. | 3 |
| `tools/prepare_celestial_dial.gd` | `tools/assets/authoring/prepare_celestial_dial.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 13 |
| `tools/prepare_character_walk.gd` | `tools/assets/authoring/prepare_character_walk.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 350 |
| `tools/prepare_hero_actions.gd` | `tools/assets/authoring/prepare_hero_actions.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 197 |
| `tools/prepare_skeleton_v2.gd` | `tools/assets/authoring/prepare_skeleton_v2.gd` | Подготовка графических ресурсов: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 8 |
| `tools/slice_item_icons.py` | `tools/assets/authoring/slice_item_icons.py` | Подготовка графических ресурсов: вход или вспомогательный модуль семейства. Нарезает предметные атласы на очищенные PNG с единым прозрачным холстом. | 307 |
| `tools/update_ui_visual_manifest.py` | `tools/assets/authoring/update_ui_visual_manifest.py` | Подготовка графических ресурсов: вход или вспомогательный модуль семейства. Обновляет геометрию, SHA-256 и устойчивые perceptual-отпечатки UI-эталонов. | 9 |

## Альфа и края изображений

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/alpha_audit.py` | `tools/assets/alpha/alpha_audit.py` | Альфа и края изображений: вход или вспомогательный модуль семейства. Проверяет возможные белые/пурпурные края; не содержит исправления игровых пикселей. | 22 |
| `tools/alpha_capture.gd` | `tools/assets/alpha/alpha_capture.gd` | Альфа и края изображений: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 17 |
| `tools/alpha_fixtures.py` | `tools/assets/alpha/alpha_fixtures.py` | Альфа и края изображений: вход или вспомогательный модуль семейства. Создаёт числовые отрицательные контроли только в новом диагностическом каталоге. | 6 |
| `tools/alpha_metrics.py` | `tools/assets/alpha/alpha_metrics.py` | Альфа и края изображений: вход или вспомогательный модуль семейства. Числовая диагностика возможного matte; исходные изображения не изменяет. | 15 |
| `tools/alpha_policy.json` | `tools/assets/alpha/alpha_policy.json` | Альфа и края изображений: политика или паспорт данных | 7 |
| `tools/alpha_proof.py` | `tools/assets/alpha/alpha_proof.py` | Альфа и края изображений: вход или вспомогательный модуль семейства. Повторно проверяет числовые контроли и неизменность белых деталей в нативных кадрах. | 5 |
| `tools/test_alpha_audit.py` | `tools/assets/alpha/test_alpha_audit.py` | Альфа и края изображений: профильные и отрицательные Python-контроли. Проверяет цветовые контроли, защиту белых деталей и запрет автоматического принятия нового matte. | 10 |
| `tools/test_alpha_proof.py` | `tools/assets/alpha/test_alpha_proof.py` | Альфа и края изображений: профильные и отрицательные Python-контроли. Проверяет сохранённую GPU-матрицу и адресные отказы при порче её копий. | 10 |

## Нарезка атласов

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/slice_audit.py` | `tools/assets/slicing/slice_audit.py` | Нарезка атласов: вход или вспомогательный модуль семейства. Выгружает реальные игровые кадры и проверяет их геометрию до публикации. | 23 |
| `tools/slice_capture.gd` | `tools/assets/slicing/slice_capture.gd` | Нарезка атласов: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 6 |
| `tools/slice_catalogs.gd` | `tools/assets/slicing/slice_catalogs.gd` | Нарезка атласов: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 9 |
| `tools/slice_export.gd` | `tools/assets/slicing/slice_export.gd` | Нарезка атласов: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 11 |
| `tools/slice_legacy_capture.gd` | `tools/assets/slicing/slice_legacy_capture.gd` | Нарезка атласов: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 6 |
| `tools/slice_metrics.py` | `tools/assets/slicing/slice_metrics.py` | Нарезка атласов: вход или вспомогательный модуль семейства. Проверяет геометрию кадров и измеряет запас, не изменяя изображения. | 10 |
| `tools/slice_policy.json` | `tools/assets/slicing/slice_policy.json` | Нарезка атласов: политика или паспорт данных | 11 |
| `tools/slice_proof.py` | `tools/assets/slicing/slice_proof.py` | Нарезка атласов: вход или вспомогательный модуль семейства. Проверяет исторические GPU-пары, исправленные границы и адресные отрицательные контроли. | 9 |
| `tools/slice_review.gd` | `tools/assets/slicing/slice_review.gd` | Нарезка атласов: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/test_slice_audit.py` | `tools/assets/slicing/test_slice_audit.py` | Нарезка атласов: профильные и отрицательные Python-контроли. Портит только отдельные копии кадров и метаданных, не затрагивая игру. | 19 |
| `tools/test_slice_proof.py` | `tools/assets/slicing/test_slice_proof.py` | Нарезка атласов: профильные и отрицательные Python-контроли. Проверяет нативные доказательства на отдельных испорченных копиях. | 10 |

## Происхождение и миграция ресурсов

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/asset_migration.py` | `tools/assets/migration/asset_migration.py` | Происхождение и миграция ресурсов: вход или вспомогательный модуль семейства. VPIPELINE-009: проверяемый план перехода; команды массового переименования/удаления нет. | 15 |
| `tools/migration_capture.gd` | `tools/assets/migration/migration_capture.gd` | Происхождение и миграция ресурсов: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 11 |
| `tools/migration_fixture.py` | `tools/assets/migration/migration_fixture.py` | Происхождение и миграция ресурсов: вход или вспомогательный модуль семейства. Создаёт отдельный Godot-проект для проверки rename-only без изменений рабочей игры. | 7 |
| `tools/migration_inventory.py` | `tools/assets/migration/migration_inventory.py` | Происхождение и миграция ресурсов: вход или вспомогательный модуль семейства. Снимает потенциальных потребителей графики; отсутствие ссылки не разрешает удаление. | 17 |
| `tools/migration_proof.py` | `tools/assets/migration/migration_proof.py` | Происхождение и миграция ресурсов: вход или вспомогательный модуль семейства. Проверяет настоящий rename-only стенд, откат, UID, F12 и отрицательные контроли. | 9 |
| `tools/test_asset_migration.py` | `tools/assets/migration/test_asset_migration.py` | Происхождение и миграция ресурсов: профильные и отрицательные Python-контроли. Проверяет граф и правила миграции на копиях; рабочая графика не меняется. | 8 |
| `tools/test_migration_proof.py` | `tools/assets/migration/test_migration_proof.py` | Происхождение и миграция ресурсов: профильные и отрицательные Python-контроли. Портит отдельные копии GPU-пакета, не трогая игру или принятые кадры. | 9 |

## Контракты текстур и размеров UI

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/asset_costs.py` | `tools/assets/contracts/asset_costs.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Измеряет файлы и связывает происхождение с доказательствами, не выдавая догадки за лицензию. | 6 |
| `tools/asset_game_probe.gd` | `tools/assets/contracts/asset_game_probe.gd` | Контракты текстур и размеров UI: диагностический наблюдатель; UID: нет в Git; отдельный preflight | 4 |
| `tools/asset_provenance.json` | `tools/assets/contracts/asset_provenance.json` | Контракты текстур и размеров UI: политика или паспорт данных | 7 |
| `tools/asset_report.py` | `tools/assets/contracts/asset_report.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. VPIPELINE-010: воспроизводимый аудит стоимости/происхождения и состава настоящего экспорта. | 12 |
| `tools/check_sprite_cleanup.py` | `tools/assets/contracts/check_sprite_cleanup.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет выбранную партию удаления; отсутствие текстовой ссылки само по себе не разрешает удаление. | 7 |
| `tools/check_world_sprite_manifest.py` | `tools/assets/contracts/check_world_sprite_manifest.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Автоматически проверяет реестр, runtime-ссылки и владельцев мировых спрайтов. | 805 |
| `tools/item_export_contract.gd` | `tools/assets/contracts/item_export_contract.gd` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства; UID: отслеживается | 4 |
| `tools/item_export_contract.py` | `tools/assets/contracts/item_export_contract.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Сверяет рассмотренный конечный реестр экспортов с реальными капсулами и игровыми файлами. | 8 |
| `tools/item_export_contract_review.gd` | `tools/assets/contracts/item_export_contract_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/item_fingerprint_capture.gd` | `tools/assets/contracts/item_fingerprint_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: отслеживается | 8 |
| `tools/item_icon_contract_review.gd` | `tools/assets/contracts/item_icon_contract_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: отслеживается | 6 |
| `tools/item_sizes.py` | `tools/assets/contracts/item_sizes.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет два размера UI и воспроизводимую нативную загрузку шкафа. | 799 |
| `tools/item_sizes_capture.gd` | `tools/assets/contracts/item_sizes_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 785 |
| `tools/item_sizes_review.gd` | `tools/assets/contracts/item_sizes_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 7 |
| `tools/item_ui_fitter.gd` | `tools/assets/contracts/item_ui_fitter.gd` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 25 |
| `tools/padded_atlas_capture.gd` | `tools/assets/contracts/padded_atlas_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 14 |
| `tools/padded_atlas_review.gd` | `tools/assets/contracts/padded_atlas_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/padded_atlases.py` | `tools/assets/contracts/padded_atlases.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Детерминированно пакует отдельные уровни миниатюр с экструзией полного RGBA-края. | 27 |
| `tools/preview_portability.py` | `tools/assets/contracts/preview_portability.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет фиксированные RGBA/PNG и собирает одинаковый диагностический стенд двух ОС. | 10 |
| `tools/preview_portability_capture.gd` | `tools/assets/contracts/preview_portability_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/sprite_usage_review.gd` | `tools/assets/contracts/sprite_usage_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/test_asset_report.py` | `tools/assets/contracts/test_asset_report.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Отрицательные сценарии стоимости, неизвестного происхождения и реально экспортированного payload. | 5 |
| `tools/test_item_export_contract.py` | `tools/assets/contracts/test_item_export_contract.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Портит копии предложения и реальных PNG, не подключая контракт к старому игровому suite. | 7 |
| `tools/test_item_sizes.py` | `tools/assets/contracts/test_item_sizes.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Повреждает отдельные копии двух размеров и нативного доказательства шкафа. | 11 |
| `tools/test_padded_atlases.py` | `tools/assets/contracts/test_padded_atlases.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет поля и независимые уровни на отдельных настоящих PNG и намеренно испорченных копиях. | 10 |
| `tools/test_preview_portability.py` | `tools/assets/contracts/test_preview_portability.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Портит копии фиксированных входов и настоящего минимального вывода Godot, не игровые PNG. | 6 |
| `tools/test_sprite_cleanup.py` | `tools/assets/contracts/test_sprite_cleanup.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет защиту динамических ресурсов на изолированной партии, без игровых слотов. | 6 |
| `tools/test_texture_intents.py` | `tools/assets/contracts/test_texture_intents.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Намеренно повреждает отдельные копии политики, импорта и числовых доказательств. | 12 |
| `tools/test_visual_icons.py` | `tools/assets/contracts/test_visual_icons.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Отрицательные сценарии VART-010 без изменения игровых PNG. | 11 |
| `tools/test_visual_pipeline.py` | `tools/assets/contracts/test_visual_pipeline.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет отказ на повреждённом изображении и нарушенных границах без порчи ресурсов игры. | 136 |
| `tools/test_visual_resources.py` | `tools/assets/contracts/test_visual_resources.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет паспорт на отдельных настоящих PNG, не повреждая игровые ресурсы. | 11 |
| `tools/test_visual_sampling.py` | `tools/assets/contracts/test_visual_sampling.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет ошибки фильтрации и доказательств только на собственных копиях файлов. | 10 |
| `tools/test_world_sprite_manifest.py` | `tools/assets/contracts/test_world_sprite_manifest.py` | Контракты текстур и размеров UI: профильные и отрицательные Python-контроли. Проверяет динамический world-аудитор на изолированной файловой фикстуре. | 3 |
| `tools/texture_data_probe.gd` | `tools/assets/contracts/texture_data_probe.gd` | Контракты текстур и размеров UI: диагностический наблюдатель; UID: нет в Git; отдельный preflight | 9 |
| `tools/texture_data_room_capture.gd` | `tools/assets/contracts/texture_data_room_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 7 |
| `tools/texture_intent_review.gd` | `tools/assets/contracts/texture_intent_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/texture_intents.py` | `tools/assets/contracts/texture_intents.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет назначения, точные данные импорта и сохранённую GPU-матрицу VPIPELINE-005. | 18 |
| `tools/ui_portability_capture.gd` | `tools/assets/contracts/ui_portability_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/ui_portability_observer.gd` | `tools/assets/contracts/ui_portability_observer.gd` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства; UID: отслеживается | 8 |
| `tools/visual_asset_policy.json` | `tools/assets/contracts/visual_asset_policy.json` | Контракты текстур и размеров UI: политика или паспорт данных | 18 |
| `tools/visual_icons.py` | `tools/assets/contracts/visual_icons.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. VART-010: происхождение, два экранных размера и честная отдельная художественная приёмка. | 12 |
| `tools/visual_icons_capture.gd` | `tools/assets/contracts/visual_icons_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 783 |
| `tools/visual_pipeline.py` | `tools/assets/contracts/visual_pipeline.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет границу авторских файлов и импортируемых ресурсов, не удаляя ассеты. | 143 |
| `tools/visual_pipeline_capture.gd` | `tools/assets/contracts/visual_pipeline_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 4 |
| `tools/visual_pipeline_review.gd` | `tools/assets/contracts/visual_pipeline_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 7 |
| `tools/visual_resource_capture.gd` | `tools/assets/contracts/visual_resource_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 7 |
| `tools/visual_resources.py` | `tools/assets/contracts/visual_resources.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет единый паспорт графики и реальные PNG до загрузки игрой. | 24 |
| `tools/visual_resources_review.gd` | `tools/assets/contracts/visual_resources_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 10 |
| `tools/visual_sampling.py` | `tools/assets/contracts/visual_sampling.py` | Контракты текстур и размеров UI: вход или вспомогательный модуль семейства. Проверяет адресные профили фильтрации и сохранённое нативное сравнение. | 12 |
| `tools/visual_sampling_capture.gd` | `tools/assets/contracts/visual_sampling_capture.gd` | Контракты текстур и размеров UI: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 11 |
| `tools/visual_sampling_review.gd` | `tools/assets/contracts/visual_sampling_review.gd` | Контракты текстур и размеров UI: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |

## Подготовка и аудит аудио

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/audio_composer.py` | `tools/assets/audio/audio_composer.py` | Подготовка и аудит аудио: вход или вспомогательный модуль семейства. Оригинальная партитура фермы: нейлоновые струны, мягкое фортепиано, флейта и камерный фон. | 77 |
| `tools/audio_sound_effects.py` | `tools/assets/audio/audio_sound_effects.py` | Подготовка и аудит аудио: вход или вспомогательный модуль семейства. Мягкие предметные эффекты: дерево, земля, воздух и короткие музыкальные подтверждения. | 41 |
| `tools/audit_audio_assets.py` | `tools/assets/audio/audit_audio_assets.py` | Подготовка и аудит аудио: вход или вспомогательный модуль семейства. Проверяет экспортированные WAV: реальные отсчёты, запас пиков, RMS, DC, границы петли и спектр. | 6 |
| `tools/generate_audio_assets.py` | `tools/assets/audio/generate_audio_assets.py` | Подготовка и аудит аудио: подготовка ресурсов или эталонов. Воспроизводимо создаёт оригинальные камерные темы и мягкие эффекты фермы; требуется NumPy. | 40 |
| `tools/import_pixabay_assets.py` | `tools/assets/audio/import_pixabay_assets.py` | Подготовка и аудит аудио: вход или вспомогательный модуль семейства. Преобразует загруженные листы Pixabay в компактные прозрачные игровые спрайты. | 2 |

## Пакеты ресурсов и передача художнику

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/artist_packet.py` | `tools/build/artist_packet.py` | Пакеты ресурсов и передача художнику: вход или вспомогательный модуль семейства. Проверяет воспроизводимый художественный комплект, не принимая новую графику игры. | 6 |
| `tools/asset_pack.py` | `tools/build/asset_pack.py` | Пакеты ресурсов и передача художнику: вход или вспомогательный модуль семейства. Создаёт отдельную копию для настоящего export-pack и проверяет её содержимое без запуска игры. | 8 |
| `tools/asset_pack_probe.gd` | `tools/build/asset_pack_probe.gd` | Пакеты ресурсов и передача художнику: диагностический наблюдатель; UID: нет в Git; отдельный preflight | 7 |
| `tools/test_artist_packet.py` | `tools/build/test_artist_packet.py` | Пакеты ресурсов и передача художнику: профильные и отрицательные Python-контроли. Проверяет целостность передачи художнику на отдельных временных копиях. | 5 |
| `tools/test_asset_pack_proof.py` | `tools/build/test_asset_pack_proof.py` | Пакеты ресурсов и передача художнику: профильные и отрицательные Python-контроли. Портит только копии нативного пакета и пересчитывает хеш, проверяя содержимое доказательств. | 6 |

## Ручной просмотр и редакционные экспорты

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/art_review_export.gd` | `tools/dev/art_review/art_review_export.gd` | Ручной просмотр и редакционные экспорты: вход или вспомогательный модуль семейства; UID: отслеживается | 4 |
| `tools/art_review_serve.mjs` | `tools/dev/art_review/art_review_serve.mjs` | Ручной просмотр и редакционные экспорты: вход или вспомогательный модуль семейства | 5 |
| `tools/check_art_review.py` | `tools/dev/art_review/check_art_review.py` | Ручной просмотр и редакционные экспорты: профильные Godot-проверки. Проверяет полный снимок рисунков и точное покрытие художественных партий. | 5 |
| `tools/test_art_review.py` | `tools/dev/art_review/test_art_review.py` | Ручной просмотр и редакционные экспорты: профильные и отрицательные Python-контроли. Проверяет контроль полноты и целостности художественной ревизии на повреждённых копиях. | 4 |

## Проверки художественного стандарта

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/test_visual_density.py` | `tools/qa/art/test_visual_density.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Негативные сценарии сопоставимости и честного масштаба VART-006. | 11 |
| `tools/test_visual_edges.py` | `tools/qa/art/test_visual_edges.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Отрицательные сценарии происхождения, масштаба и прозрачного края VART-005. | 11 |
| `tools/test_visual_light.py` | `tools/qa/art/test_visual_light.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Отрицательные сценарии паспорта VART-007. | 11 |
| `tools/test_visual_modules.py` | `tools/qa/art/test_visual_modules.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Сценарии потери художественного контракта VART-008. | 11 |
| `tools/test_visual_palette.py` | `tools/qa/art/test_visual_palette.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Проверяет ошибки контракта палитры, не заменяя художественный выбор автотестом. | 7 |
| `tools/test_visual_perspective.py` | `tools/qa/art/test_visual_perspective.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Проверяет геометрию стандарта, не выдавая старую графику за принятую новую партию. | 7 |
| `tools/test_visual_reuse.py` | `tools/qa/art/test_visual_reuse.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Регрессии полноты и границ аудита VART-009. | 12 |
| `tools/test_visual_scale.py` | `tools/qa/art/test_visual_scale.py` | Проверки художественного стандарта: профильные и отрицательные Python-контроли. Отказы при подмене сравнения масштаба и его нативных доказательств. | 7 |
| `tools/visual_density.py` | `tools/qa/art/visual_density.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Паспорт плотности VART-006: сравнимость мастеров, а не автоматическая оценка красоты. | 13 |
| `tools/visual_density_capture.gd` | `tools/qa/art/visual_density_capture.gd` | Проверки художественного стандарта: сценарий захвата артефактов; UID: отслеживается | 12 |
| `tools/visual_edges.py` | `tools/qa/art/visual_edges.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Проверяет происхождение и сравнимость макетов VART-005, не принимает графику автоматически. | 13 |
| `tools/visual_light.py` | `tools/qa/art/visual_light.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Проверяет паспорт света и настоящий нативный вывод, не оценивает красоту. | 12 |
| `tools/visual_light_capture.gd` | `tools/qa/art/visual_light_capture.gd` | Проверки художественного стандарта: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 10 |
| `tools/visual_modules.py` | `tools/qa/art/visual_modules.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Проверяет реальные мастера и нарезку VART-008; не принимает художественный вкус за пользователя. | 12 |
| `tools/visual_modules_capture.gd` | `tools/qa/art/visual_modules_capture.gd` | Проверки художественного стандарта: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 19 |
| `tools/visual_palette.py` | `tools/qa/art/visual_palette.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Сверяет палитры, измеренные области и неизменный мастер стенда VART-003. | 10 |
| `tools/visual_perspective.py` | `tools/qa/art/visual_perspective.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Проверяет стандарт трёх ракурсов и его связь с настоящими ресурсами Godot. | 10 |
| `tools/visual_perspective_export.gd` | `tools/qa/art/visual_perspective_export.gd` | Проверки художественного стандарта: вход или вспомогательный модуль семейства; UID: отслеживается | 9 |
| `tools/visual_reuse.py` | `tools/qa/art/visual_reuse.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. VART-009: полнота решений, происхождение файлов и доказательства нативного сравнения. | 14 |
| `tools/visual_reuse_capture.gd` | `tools/qa/art/visual_reuse_capture.gd` | Проверки художественного стандарта: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 11 |
| `tools/visual_reuse_sources.gd` | `tools/qa/art/visual_reuse_sources.gd` | Проверки художественного стандарта: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 18 |
| `tools/visual_scale.py` | `tools/qa/art/visual_scale.py` | Проверки художественного стандарта: вход или вспомогательный модуль семейства. Нативное сравнение размера героя и двух полей обзора без изменения игровой физики. | 11 |
| `tools/visual_scale_capture.gd` | `tools/qa/art/visual_scale_capture.gd` | Проверки художественного стандарта: сценарий захвата артефактов; UID: отслеживается | 8 |

## Камера, presentation и нативный baseline

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/analyze_visual_baseline.py` | `tools/qa/camera/analyze_visual_baseline.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Проверяет пригодность VBASE, отдельно от соблюдения бюджета плавности. Выбросы не удаляются. | 31 |
| `tools/camera_quantization.py` | `tools/qa/camera/camera_quantization.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. VCAMERA-002: native paired camera comparison, signed evidence and offline rejection. | 37 |
| `tools/camera_quantization_capture.gd` | `tools/qa/camera/camera_quantization_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 58 |
| `tools/camera_quantization_review.gd` | `tools/qa/camera/camera_quantization_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/check_native_frame_reports.py` | `tools/qa/camera/check_native_frame_reports.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Validate full native scenarios using frame_post_draw, not idle process loops. | 6 |
| `tools/encode_coordinate_video.swift` | `tools/qa/camera/encode_coordinate_video.swift` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства | 293 |
| `tools/pose_video_frames.swift` | `tools/qa/camera/pose_video_frames.swift` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства | 4 |
| `tools/pose_video_strip.py` | `tools/qa/camera/pose_video_strip.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Builds a scientific contact sheet from decoded native video pixels, without scaling. | 3 |
| `tools/presentation_pose.py` | `tools/qa/camera/presentation_pose.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. VCAMERA-003: paired native presentation phases and root shader contact, never FPS. | 58 |
| `tools/presentation_pose_capture.gd` | `tools/qa/camera/presentation_pose_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 65 |
| `tools/presentation_pose_live.gd` | `tools/qa/camera/presentation_pose_live.gd` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 2 |
| `tools/presentation_pose_review.gd` | `tools/qa/camera/presentation_pose_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/reference_zoom.py` | `tools/qa/camera/reference_zoom.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. VCAMERA-006: identical world trajectories at 100/120%, separate from live timing. | 32 |
| `tools/reference_zoom_capture.gd` | `tools/qa/camera/reference_zoom_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 39 |
| `tools/reference_zoom_live.gd` | `tools/qa/camera/reference_zoom_live.gd` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 58 |
| `tools/reference_zoom_perf.py` | `tools/qa/camera/reference_zoom_perf.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Native live timing for VCAMERA-006; no fixed steps, screenshots or tests during samples. | 17 |
| `tools/reference_zoom_review.gd` | `tools/qa/camera/reference_zoom_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 4 |
| `tools/run_visual_baseline.py` | `tools/qa/camera/run_visual_baseline.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Запускает независимые нативные повторы VBASE с паспортом машины и открытыми исходными замерами. | 29 |
| `tools/test_camera_quantization.py` | `tools/qa/camera/test_camera_quantization.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Offline unit envelopes of the camera validator; synthetic metadata never proves native acceptance. | 6 |
| `tools/test_presentation_pose.py` | `tools/qa/camera/test_presentation_pose.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. VCAMERA-003 rejection tests use captured evidence and disposable copies only. | 5 |
| `tools/test_reference_zoom.py` | `tools/qa/camera/test_reference_zoom.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. VCAMERA-006 rejects real evidence defects using memory or temporary copies only. | 5 |
| `tools/test_visual_baseline.py` | `tools/qa/camera/test_visual_baseline.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Поведенческие проверки протокола VBASE: валидность измерения не равна хорошей производительности. | 11 |
| `tools/test_visual_camera.py` | `tools/qa/camera/test_visual_camera.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Проверяет отказы стенда на повреждённых копиях настоящего нативного паспорта. | 10 |
| `tools/test_visual_coordinates.py` | `tools/qa/camera/test_visual_coordinates.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Проверяет реальные паспорта координат и отказы при подмене измерений. | 6 |
| `tools/test_visual_hardware.py` | `tools/qa/camera/test_visual_hardware.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Проверяет аппаратный допуск VBASE-002 на временных трассах, без запуска игры и смены питания. | 8 |
| `tools/test_visual_motion.py` | `tools/qa/camera/test_visual_motion.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Отрицательные проверки маршрута VBASE-005 на копиях настоящих нативных данных. | 6 |
| `tools/test_visual_static.py` | `tools/qa/camera/test_visual_static.py` | Камера, presentation и нативный baseline: профильные и отрицательные Python-контроли. Отрицательные сценарии статического эталона на настоящей нативной серии. | 11 |
| `tools/visual_baseline.gd` | `tools/qa/camera/visual_baseline.gd` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 25 |
| `tools/visual_camera.py` | `tools/qa/camera/visual_camera.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Снимает и проверяет точки камеры; статические кадры не допускаются в замер производительности. | 18 |
| `tools/visual_camera_capture.gd` | `tools/qa/camera/visual_camera_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 9 |
| `tools/visual_camera_points.gd` | `tools/qa/camera/visual_camera_points.gd` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 518 |
| `tools/visual_camera_review.gd` | `tools/qa/camera/visual_camera_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/visual_coordinates.py` | `tools/qa/camera/visual_coordinates.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Снимает нативный контракт координат и проверяет реальные кадры, ввод и матрицы. | 12 |
| `tools/visual_coordinates_capture.gd` | `tools/qa/camera/visual_coordinates_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: отслеживается | 6 |
| `tools/visual_coordinates_review.gd` | `tools/qa/camera/visual_coordinates_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/visual_hardware.py` | `tools/qa/camera/visual_hardware.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. VBASE-002: паспорт доступной машины и допуск сопоставимых нативных повторов, отдельно от FPS. | 19 |
| `tools/visual_motion.py` | `tools/qa/camera/visual_motion.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. VBASE-005: воспроизводимый маршрут игровым вводом, два нативных видео и независимый допуск QA. | 18 |
| `tools/visual_motion_capture.gd` | `tools/qa/camera/visual_motion_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 22 |
| `tools/visual_motion_review.gd` | `tools/qa/camera/visual_motion_review.gd` | Камера, presentation и нативный baseline: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/visual_motion_route.gd` | `tools/qa/camera/visual_motion_route.gd` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 13 |
| `tools/visual_static.py` | `tools/qa/camera/visual_static.py` | Камера, presentation и нативный baseline: вход или вспомогательный модуль семейства. Воспроизводимый нативный эталон деревни; Pillow нужен только для сравнения PNG. | 14 |
| `tools/visual_static_capture.gd` | `tools/qa/camera/visual_static_capture.gd` | Камера, presentation и нативный baseline: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 11 |

## Ветер и контакт растительности

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/foliage_contact_capture.gd` | `tools/qa/foliage/foliage_contact_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 27 |
| `tools/foliage_contact_collect.py` | `tools/qa/foliage/foliage_contact_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Freeze exact production sources and collect two fresh native wind windows. | 4 |
| `tools/foliage_contact_review.gd` | `tools/qa/foliage/foliage_contact_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/foliage_contact_verify.py` | `tools/qa/foliage/foliage_contact_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Verify rooted hero reaction using native pixels, independent math and immutable inputs. | 6 |
| `tools/foliage_pause_capture.gd` | `tools/qa/foliage/foliage_pause_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 33 |
| `tools/foliage_pause_collect.py` | `tools/qa/foliage/foliage_pause_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Collect only the predeclared VFOLIAGE-009 native windows, preserving every partial run. | 17 |
| `tools/foliage_pause_game.gd` | `tools/qa/foliage/foliage_pause_game.gd` | Ветер и контакт растительности: QA-надстройка над настоящей игрой; UID: отслеживается | 18 |
| `tools/foliage_pause_review.gd` | `tools/qa/foliage/foliage_pause_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 20 |
| `tools/foliage_pause_verify.py` | `tools/qa/foliage/foliage_pause_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Independently verify the fixed native VFOLIAGE-009 pause campaign. | 10 |
| `tools/foliage_recovery_capture.gd` | `tools/qa/foliage/foliage_recovery_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 16 |
| `tools/foliage_recovery_collect.py` | `tools/qa/foliage/foliage_recovery_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Freeze exact production sources and collect two fresh native wind windows. | 9 |
| `tools/foliage_recovery_review.gd` | `tools/qa/foliage/foliage_recovery_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/foliage_recovery_verify.py` | `tools/qa/foliage/foliage_recovery_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Recompute the complete recovery trace and bind native GPU/pixel proof to immutable sources. | 5 |
| `tools/foliage_root_board.gd` | `tools/qa/foliage/foliage_root_board.gd` | Ветер и контакт растительности: контрольный визуальный стенд; UID: отслеживается | 7 |
| `tools/foliage_root_capture.gd` | `tools/qa/foliage/foliage_root_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/foliage_root_collect.py` | `tools/qa/foliage/foliage_root_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Capture native root passports and actual gameplay/query pairs without user saves. | 5 |
| `tools/foliage_root_observer.gd` | `tools/qa/foliage/foliage_root_observer.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 7 |
| `tools/foliage_root_review.gd` | `tools/qa/foliage/foliage_root_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/foliage_root_verify.py` | `tools/qa/foliage/foliage_root_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Check native roots, every mask texel, complete state and immutable source bindings. | 53 |
| `tools/foliage_speed_capture.gd` | `tools/qa/foliage/foliage_speed_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 10 |
| `tools/foliage_speed_collect.py` | `tools/qa/foliage/foliage_speed_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Freeze exact production sources and collect two fresh native wind windows. | 5 |
| `tools/foliage_speed_review.gd` | `tools/qa/foliage/foliage_speed_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/foliage_speed_verify.py` | `tools/qa/foliage/foliage_speed_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Verify real physical speed, native GPU fields and lossless motion against immutable sources. | 4 |
| `tools/foliage_uv_board.gd` | `tools/qa/foliage/foliage_uv_board.gd` | Ветер и контакт растительности: контрольный визуальный стенд; UID: отслеживается | 7 |
| `tools/foliage_uv_capture.gd` | `tools/qa/foliage/foliage_uv_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/foliage_uv_collect.py` | `tools/qa/foliage/foliage_uv_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Capture native root passports and actual gameplay/query pairs without user saves. | 5 |
| `tools/foliage_uv_quad.gd` | `tools/qa/foliage/foliage_uv_quad.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 7 |
| `tools/foliage_uv_review.gd` | `tools/qa/foliage/foliage_uv_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/foliage_uv_verify.py` | `tools/qa/foliage/foliage_uv_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Verify actual GPU atlas isolation, independent reflection and fixed lower geometry. | 5 |
| `tools/foliage_visibility_budget.gd` | `tools/qa/foliage/foliage_visibility_budget.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 7 |
| `tools/foliage_visibility_capture.gd` | `tools/qa/foliage/foliage_visibility_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/foliage_visibility_collect.py` | `tools/qa/foliage/foliage_visibility_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Fresh, bounded VFOLIAGE-010 collection; every failed/partial launch remains intact. | 8 |
| `tools/foliage_visibility_coverage.py` | `tools/qa/foliage/foliage_visibility_coverage.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Независимый пересчёт coverage и проверка пиксельных culling-пар VFOLIAGE-010. | 5 |
| `tools/foliage_visibility_evidence.py` | `tools/qa/foliage/foliage_visibility_evidence.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Чтение VFOLIAGE-010: целостность файлов и декодирование первичных RGBA. | 11 |
| `tools/foliage_visibility_game.gd` | `tools/qa/foliage/foliage_visibility_game.gd` | Ветер и контакт растительности: QA-надстройка над настоящей игрой; UID: отслеживается | 7 |
| `tools/foliage_visibility_pack.py` | `tools/qa/foliage/foliage_visibility_pack.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Losslessly archive every native RGBA frame before removing only declared successful staging PNGs. | 7 |
| `tools/foliage_visibility_provenance.py` | `tools/qa/foliage/foliage_visibility_provenance.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Историческое происхождение VFOLIAGE-010 и отдельная проверка текущего кандидата. | 11 |
| `tools/foliage_visibility_review.gd` | `tools/qa/foliage/foliage_visibility_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 9 |
| `tools/foliage_visibility_test_fixture.py` | `tools/qa/foliage/foliage_visibility_test_fixture.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Изолированные файловые fixture исторического кандидата для регрессий VFOLIAGE-010. | 5 |
| `tools/foliage_visibility_verify.py` | `tools/qa/foliage/foliage_visibility_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Проверка исторической серии VFOLIAGE-010; текущий кандидат проверяется отдельным флагом. | 19 |
| `tools/foliage_visibility_window.py` | `tools/qa/foliage/foliage_visibility_window.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Дешёвые проверки нативного окна, движения, состояния и счётчиков VFOLIAGE-010. | 6 |
| `tools/foliage_wind_baseline.gd` | `tools/qa/foliage/foliage_wind_baseline.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 2 |
| `tools/foliage_wind_capture.gd` | `tools/qa/foliage/foliage_wind_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 31 |
| `tools/foliage_wind_collect.py` | `tools/qa/foliage/foliage_wind_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Freeze exact production sources and collect two fresh native wind windows. | 4 |
| `tools/foliage_wind_review.gd` | `tools/qa/foliage/foliage_wind_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/foliage_wind_verify.py` | `tools/qa/foliage/foliage_wind_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Verify native wind against CPU geometry, immutable sources and complete save snapshots. | 6 |
| `tools/grass_compare/capture.gd` | `tools/qa/foliage/grass_compare/capture.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 45 |
| `tools/grass_compare/field.gd` | `tools/qa/foliage/grass_compare/field.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 16 |
| `tools/grass_compare/mesh_data.gd` | `tools/qa/foliage/grass_compare/mesh_data.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 23 |
| `tools/grass_compare/observer.gd` | `tools/qa/foliage/grass_compare/observer.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 12 |
| `tools/grass_compare/review.gd` | `tools/qa/foliage/grass_compare/review.gd` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 9 |
| `tools/grass_compare/wind.gdshader` | `tools/qa/foliage/grass_compare/wind.gdshader` | Ветер и контакт растительности: вход или вспомогательный модуль семейства; UID: отслеживается | 13 |
| `tools/grass_compare_collect.py` | `tools/qa/foliage/grass_compare_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Collect isolated VRENDER-002 quality frames or counter-ordered effect microbenchmarks. | 13 |
| `tools/grass_methods.py` | `tools/qa/foliage/grass_methods.py` | Ветер и контакт растительности: вход или вспомогательный модуль семейства. Read-only VRENDER-002 evidence analysis. Frozen visual microbenchmarks never accept live gameplay FPS. | 11 |
| `tools/plant_depth_capture.gd` | `tools/qa/foliage/plant_depth_capture.gd` | Ветер и контакт растительности: сценарий захвата артефактов; UID: отслеживается | 13 |
| `tools/plant_depth_collect.py` | `tools/qa/foliage/plant_depth_collect.py` | Ветер и контакт растительности: драйвер сбора серии. Collect source-bound before/after native vegetation depth captures without touching ordinary Godot. | 6 |
| `tools/plant_depth_game.gd` | `tools/qa/foliage/plant_depth_game.gd` | Ветер и контакт растительности: QA-надстройка над настоящей игрой; UID: отслеживается | 9 |
| `tools/plant_depth_review.gd` | `tools/qa/foliage/plant_depth_review.gd` | Ветер и контакт растительности: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/plant_depth_verify.py` | `tools/qa/foliage/plant_depth_verify.py` | Ветер и контакт растительности: проверка сохранённых доказательств. Verify real plant/hero depth dispatch, complete gameplay, rollback and bounded changed pixels. | 5 |
| `tools/test_foliage_contact.py` | `tools/qa/foliage/test_foliage_contact.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Mutate only copies of actual evidence; enforce native contact and failure detection. | 3 |
| `tools/test_foliage_pause.py` | `tools/qa/foliage/test_foliage_pause.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Reject corrupted copies of retained native pause data; never admit unfocused runs. | 9 |
| `tools/test_foliage_recovery.py` | `tools/qa/foliage/test_foliage_recovery.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Reject corrupted copies of real recovery evidence, leaving the accepted archive untouched. | 5 |
| `tools/test_foliage_root.py` | `tools/qa/foliage/test_foliage_root.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Negative controls corrupt temporary native evidence, never accepted originals. | 6 |
| `tools/test_foliage_speed.py` | `tools/qa/foliage/test_foliage_speed.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Corrupt copies of real native evidence; never change the accepted archive. | 4 |
| `tools/test_foliage_uv.py` | `tools/qa/foliage/test_foliage_uv.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Corrupt copies of actual GPU evidence; accepted native files remain untouched. | 5 |
| `tools/test_foliage_visibility.py` | `tools/qa/foliage/test_foliage_visibility.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Контроли на временных копиях VFOLIAGE-010: повреждение данных, происхождение и будущие кандидаты. | 17 |
| `tools/test_foliage_wind.py` | `tools/qa/foliage/test_foliage_wind.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Negative controls for real native wind evidence; never modify accepted files. | 4 |
| `tools/test_grass_methods.py` | `tools/qa/foliage/test_grass_methods.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. VRENDER-002 admission tests mutate owned temporary copies, never native sources or user saves. | 6 |
| `tools/test_plant_depth.py` | `tools/qa/foliage/test_plant_depth.py` | Ветер и контакт растительности: профильные и отрицательные Python-контроли. Reject damaged copies of actual plant-depth evidence without changing native archives. | 5 |

## Грунт, дороги и грядки

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/axial_road_board.gd` | `tools/qa/ground/axial_road_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 8 |
| `tools/axial_road_builder.gd` | `tools/qa/ground/axial_road_builder.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 43 |
| `tools/axial_road_capture.gd` | `tools/qa/ground/axial_road_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 10 |
| `tools/axial_road_collect.py` | `tools/qa/ground/axial_road_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-004 native images. No FPS claims. | 8 |
| `tools/axial_road_compile.gd` | `tools/qa/ground/axial_road_compile.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 12 |
| `tools/axial_road_field.gd` | `tools/qa/ground/axial_road_field.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 65 |
| `tools/axial_road_review.gd` | `tools/qa/ground/axial_road_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/axial_road_verify.py` | `tools/qa/ground/axial_road_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-004 evidence, exact source archives and real draw snapshots. | 6 |
| `tools/decoration_capture.gd` | `tools/qa/ground/decoration_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/decoration_collect.py` | `tools/qa/ground/decoration_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-008 native images. No FPS claims. | 9 |
| `tools/decoration_overlay.gd` | `tools/qa/ground/decoration_overlay.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 11 |
| `tools/decoration_review.gd` | `tools/qa/ground/decoration_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 10 |
| `tools/decoration_verify.py` | `tools/qa/ground/decoration_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Validate bounded decoration policy and source-bound native controls, never FPS. | 7 |
| `tools/garden_board.gd` | `tools/qa/ground/garden_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 9 |
| `tools/garden_capture.gd` | `tools/qa/ground/garden_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/garden_collect.py` | `tools/qa/ground/garden_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-007 native images. No FPS claims. | 8 |
| `tools/garden_import.gd` | `tools/qa/ground/garden_import.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 9 |
| `tools/garden_review.gd` | `tools/qa/ground/garden_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/garden_verify.py` | `tools/qa/ground/garden_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-007 evidence, exact source archives and real draw snapshots. | 5 |
| `tools/ground_edge_board.gd` | `tools/qa/ground/ground_edge_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 8 |
| `tools/ground_edge_builder.gd` | `tools/qa/ground/ground_edge_builder.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 23 |
| `tools/ground_edge_capture.gd` | `tools/qa/ground/ground_edge_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 10 |
| `tools/ground_edge_collect.py` | `tools/qa/ground/ground_edge_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-003 native images. No FPS claims. | 8 |
| `tools/ground_edge_compile.gd` | `tools/qa/ground/ground_edge_compile.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 8 |
| `tools/ground_edge_field.gd` | `tools/qa/ground/ground_edge_field.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 97 |
| `tools/ground_edge_review.gd` | `tools/qa/ground/ground_edge_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/ground_edge_verify.py` | `tools/qa/ground/ground_edge_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-003 evidence, exact source archives and real draw snapshots. | 6 |
| `tools/ground_layers.py` | `tools/qa/ground/ground_layers.py` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства. VRENDER-003: native static/live separation evidence, independent of physical FPS acceptance. | 18 |
| `tools/ground_layers_capture.gd` | `tools/qa/ground/ground_layers_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 12 |
| `tools/ground_layers_review.gd` | `tools/qa/ground/ground_layers_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 10 |
| `tools/ground_seasons_capture.gd` | `tools/qa/ground/ground_seasons_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/ground_seasons_collect.py` | `tools/qa/ground/ground_seasons_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-010 native images. No FPS claims. | 8 |
| `tools/ground_seasons_fixture.gd` | `tools/qa/ground/ground_seasons_fixture.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 81 |
| `tools/ground_seasons_review.gd` | `tools/qa/ground/ground_seasons_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 9 |
| `tools/ground_seasons_verify.py` | `tools/qa/ground/ground_seasons_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify five natural calendar ground profiles on one immutable first-map geometry. | 5 |
| `tools/meadow_board.gd` | `tools/qa/ground/meadow_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 10 |
| `tools/meadow_capture.gd` | `tools/qa/ground/meadow_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 12 |
| `tools/meadow_collect.py` | `tools/qa/ground/meadow_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-001 native images. No FPS claims. | 9 |
| `tools/meadow_import.gd` | `tools/qa/ground/meadow_import.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 10 |
| `tools/meadow_review.gd` | `tools/qa/ground/meadow_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/meadow_verify.py` | `tools/qa/ground/meadow_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-001 evidence, exact source archives and real draw snapshots. | 6 |
| `tools/plaza_board.gd` | `tools/qa/ground/plaza_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 7 |
| `tools/plaza_builder.gd` | `tools/qa/ground/plaza_builder.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 9 |
| `tools/plaza_capture.gd` | `tools/qa/ground/plaza_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/plaza_collect.py` | `tools/qa/ground/plaza_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-006 native images. No FPS claims. | 8 |
| `tools/plaza_compile.gd` | `tools/qa/ground/plaza_compile.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 8 |
| `tools/plaza_field.gd` | `tools/qa/ground/plaza_field.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 10 |
| `tools/plaza_import.gd` | `tools/qa/ground/plaza_import.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 7 |
| `tools/plaza_review.gd` | `tools/qa/ground/plaza_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/plaza_verify.py` | `tools/qa/ground/plaza_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-006 evidence, exact source archives and real draw snapshots. | 5 |
| `tools/road_network_board.gd` | `tools/qa/ground/road_network_board.gd` | Грунт, дороги и грядки: контрольный визуальный стенд; UID: отслеживается | 7 |
| `tools/road_network_builder.gd` | `tools/qa/ground/road_network_builder.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 11 |
| `tools/road_network_capture.gd` | `tools/qa/ground/road_network_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/road_network_collect.py` | `tools/qa/ground/road_network_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-005 native images. No FPS claims. | 7 |
| `tools/road_network_compile.gd` | `tools/qa/ground/road_network_compile.gd` | Грунт, дороги и грядки: вход или вспомогательный модуль семейства; UID: отслеживается | 8 |
| `tools/road_network_review.gd` | `tools/qa/ground/road_network_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/road_network_verify.py` | `tools/qa/ground/road_network_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify historical VGROUND-005 evidence, exact source archives and real draw snapshots. | 5 |
| `tools/terrain_revision_capture.gd` | `tools/qa/ground/terrain_revision_capture.gd` | Грунт, дороги и грядки: сценарий захвата артефактов; UID: отслеживается | 11 |
| `tools/terrain_revision_collect.py` | `tools/qa/ground/terrain_revision_collect.py` | Грунт, дороги и грядки: драйвер сбора серии. Collect isolated, source-bound VGROUND-009 native images. No FPS claims. | 9 |
| `tools/terrain_revision_review.gd` | `tools/qa/ground/terrain_revision_review.gd` | Грунт, дороги и грядки: профильные Godot-проверки; UID: отслеживается | 9 |
| `tools/terrain_revision_verify.py` | `tools/qa/ground/terrain_revision_verify.py` | Грунт, дороги и грядки: проверка сохранённых доказательств. Verify local writes to the retained GPU target, full controls and unchanged gameplay. | 8 |
| `tools/test_axial_road.py` | `tools/qa/ground/test_axial_road.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Regression tests for rejection of invalid meadow evidence, using synthetic documents only. | 5 |
| `tools/test_decoration_rules.py` | `tools/qa/ground/test_decoration_rules.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Positive and negative evidence checks; mutate only temporary copies. | 4 |
| `tools/test_garden_soil.py` | `tools/qa/ground/test_garden_soil.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Negative controls for VGROUND-007 evidence; synthetic fixtures are not native acceptance. | 5 |
| `tools/test_ground_edge.py` | `tools/qa/ground/test_ground_edge.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Regression tests for rejection of invalid meadow evidence, using synthetic documents only. | 5 |
| `tools/test_ground_layers.py` | `tools/qa/ground/test_ground_layers.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. VRENDER-003 negative admission checks operate on copies, not player slots or signed native sources. | 5 |
| `tools/test_ground_seasons.py` | `tools/qa/ground/test_ground_seasons.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Reject incomplete or misleading seasonal acceptance records using temporary copies. | 4 |
| `tools/test_meadow_ground.py` | `tools/qa/ground/test_meadow_ground.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Regression tests for rejection of invalid meadow evidence, using synthetic documents only. | 5 |
| `tools/test_plaza_ground.py` | `tools/qa/ground/test_plaza_ground.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Negative controls for VGROUND-006 evidence; synthetic fixtures are not native acceptance. | 5 |
| `tools/test_road_network.py` | `tools/qa/ground/test_road_network.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Negative controls for VGROUND-005 evidence; synthetic fixtures are not native acceptance. | 5 |
| `tools/test_terrain_revision.py` | `tools/qa/ground/test_terrain_revision.py` | Грунт, дороги и грядки: профильные и отрицательные Python-контроли. Reject false local-revision evidence; modifications stay in temporary copies. | 4 |

## Слои и объекты первой карты

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/analyze_water_audit.py` | `tools/qa/world/analyze_water_audit.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Проверка исходных водных трасс; квантили общие с эпиком OPT. | 4 |
| `tools/object_command_canvas.gd` | `tools/qa/world/object_command_canvas.gd` | Слои и объекты первой карты: вход или вспомогательный модуль семейства; UID: отслеживается | 106 |
| `tools/object_command_capture.gd` | `tools/qa/world/object_command_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 88 |
| `tools/object_command_collect.py` | `tools/qa/world/object_command_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect isolated, source-bound VRENDER-004 native images. No FPS claims. | 66 |
| `tools/object_command_review.gd` | `tools/qa/world/object_command_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 67 |
| `tools/object_command_verify.py` | `tools/qa/world/object_command_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify the VRENDER-004 descriptor, isolated replay and unchanged production fallback. | 5 |
| `tools/pilot_pass_capture.gd` | `tools/qa/world/pilot_pass_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 25 |
| `tools/pilot_pass_collect.py` | `tools/qa/world/pilot_pass_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 15 |
| `tools/pilot_pass_game.gd` | `tools/qa/world/pilot_pass_game.gd` | Слои и объекты первой карты: QA-надстройка над настоящей игрой; UID: отслеживается | 21 |
| `tools/pilot_pass_review.gd` | `tools/qa/world/pilot_pass_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/pilot_pass_verify.py` | `tools/qa/world/pilot_pass_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify actual scoped production dispatch, exact legacy RGBA and atomic fallbacks. | 5 |
| `tools/pilot_static_audit.py` | `tools/qa/world/pilot_static_audit.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Bind acceptance to the canonical queue at its real Git base; this is an audit, not a status registry. | 6 |
| `tools/pilot_static_capture.gd` | `tools/qa/world/pilot_static_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 8 |
| `tools/pilot_static_collect.py` | `tools/qa/world/pilot_static_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 5 |
| `tools/pilot_static_scene.gd` | `tools/qa/world/pilot_static_scene.gd` | Слои и объекты первой карты: вход или вспомогательный модуль семейства; UID: отслеживается | 6 |
| `tools/pilot_static_verify.py` | `tools/qa/world/pilot_static_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Admit a bounded static modular study and separate real-game compatibility controls. | 5 |
| `tools/post_motion_capture.gd` | `tools/qa/world/post_motion_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 22 |
| `tools/post_motion_collect.py` | `tools/qa/world/post_motion_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 11 |
| `tools/post_motion_game.gd` | `tools/qa/world/post_motion_game.gd` | Слои и объекты первой карты: QA-надстройка над настоящей игрой; UID: отслеживается | 18 |
| `tools/post_motion_review.gd` | `tools/qa/world/post_motion_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/post_motion_verify.py` | `tools/qa/world/post_motion_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify the source-bound post-motion service, real windows, shader inputs and complete saves. | 5 |
| `tools/render_order.py` | `tools/qa/world/render_order.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. VRENDER-001: source-bound command inventory and native draw-purity evidence, never an FPS gate. | 48 |
| `tools/render_order_capture.gd` | `tools/qa/world/render_order_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 22 |
| `tools/render_order_game.gd` | `tools/qa/world/render_order_game.gd` | Слои и объекты первой карты: QA-надстройка над настоящей игрой; UID: отслеживается | 304 |
| `tools/shadow_inventory.py` | `tools/qa/world/shadow_inventory.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Build the reviewed VSHADOW-001 inventory; this never modifies game artwork. | 3 |
| `tools/shadow_inventory_canvas.gd` | `tools/qa/world/shadow_inventory_canvas.gd` | Слои и объекты первой карты: вход или вспомогательный модуль семейства; UID: отслеживается | 8 |
| `tools/shadow_inventory_capture.gd` | `tools/qa/world/shadow_inventory_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 9 |
| `tools/shadow_inventory_collect.py` | `tools/qa/world/shadow_inventory_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect visible static shadow-ownership controls; never claim a solar or FPS pass. | 5 |
| `tools/shadow_inventory_verify.py` | `tools/qa/world/shadow_inventory_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify immutable raster ownership and native on/off contact controls. | 5 |
| `tools/shore_kit.py` | `tools/qa/world/shore_kit.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Проверяет отдельный художественный комплект берега и сохранённую нативную витрину. | 7 |
| `tools/shore_kit_canvas.gd` | `tools/qa/world/shore_kit_canvas.gd` | Слои и объекты первой карты: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 6 |
| `tools/shore_kit_capture.gd` | `tools/qa/world/shore_kit_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 4 |
| `tools/shore_kit_review.gd` | `tools/qa/world/shore_kit_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 7 |
| `tools/test_object_command.py` | `tools/qa/world/test_object_command.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Check explicit schema fixtures and the separately recorded native replay evidence. | 6 |
| `tools/test_pilot_pass.py` | `tools/qa/world/test_pilot_pass.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Corrupt only copies of actual VRENDER-005 native data; never weaken historical proof. | 5 |
| `tools/test_pilot_static.py` | `tools/qa/world/test_pilot_static.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Reject corrupted copies of actual static-pilot evidence, without altering the retained archive. | 5 |
| `tools/test_post_motion.py` | `tools/qa/world/test_post_motion.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Corrupt copies of real native evidence; never mutate historical captures or gameplay. | 5 |
| `tools/test_render_order.py` | `tools/qa/world/test_render_order.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. VRENDER-001: negative copies must fail even if their artifact hash is recomputed. | 5 |
| `tools/test_shadow_inventory.py` | `tools/qa/world/test_shadow_inventory.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Reject incomplete/tampered shadow evidence in temporary copies only. | 5 |
| `tools/test_shore_kit.py` | `tools/qa/world/test_shore_kit.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Негативные проверки берегового комплекта не меняют игровые ресурсы и исходные доказательства. | 7 |
| `tools/test_transient_save.py` | `tools/qa/world/test_transient_save.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Corrupt isolated native metadata/source copies; never replace accepted evidence. | 5 |
| `tools/test_village_bench.py` | `tools/qa/world/test_village_bench.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Reject damaged copies of actual bench captures and authoring geometry. | 6 |
| `tools/test_village_board.py` | `tools/qa/world/test_village_board.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Negative controls operate on copies of genuine native fence evidence. | 5 |
| `tools/test_village_fence.py` | `tools/qa/world/test_village_fence.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Negative controls operate on copies of genuine native fence evidence. | 5 |
| `tools/test_village_lamp.py` | `tools/qa/world/test_village_lamp.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Reject damaged copies of actual lamp captures and authoring geometry. | 6 |
| `tools/test_village_street.py` | `tools/qa/world/test_village_street.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Reject damaged copies of actual street-prop captures and authoring geometry. | 6 |
| `tools/test_village_trade.py` | `tools/qa/world/test_village_trade.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Negative controls operate on copies of genuine native fence evidence. | 5 |
| `tools/test_water_audit.py` | `tools/qa/world/test_water_audit.py` | Слои и объекты первой карты: профильные и отрицательные Python-контроли. Отрицательные проверки протокола WATER-01 без запуска графики. | 4 |
| `tools/transient_save_capture.gd` | `tools/qa/world/transient_save_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 13 |
| `tools/transient_save_collect.py` | `tools/qa/world/transient_save_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect two real-window save-boundary controls with immutable Git-bound assets. | 6 |
| `tools/transient_save_probe.gd` | `tools/qa/world/transient_save_probe.gd` | Слои и объекты первой карты: диагностический наблюдатель; UID: отслеживается | 9 |
| `tools/transient_save_review.gd` | `tools/qa/world/transient_save_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/transient_save_verify.py` | `tools/qa/world/transient_save_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify native file preservation, unchanged gameplay/rendering and exact reviewed save code. | 5 |
| `tools/village_bench_assets.py` | `tools/qa/world/village_bench_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Build or verify three uniformly rendered bench views from immutable transparent masters. | 10 |
| `tools/village_bench_capture.gd` | `tools/qa/world/village_bench_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 64 |
| `tools/village_bench_collect.py` | `tools/qa/world/village_bench_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native bench captures without touching ordinary Godot. | 41 |
| `tools/village_bench_gallery.gd` | `tools/qa/world/village_bench_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 80 |
| `tools/village_bench_leg_capture.gd` | `tools/qa/world/village_bench_leg_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/village_bench_review.gd` | `tools/qa/world/village_bench_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/village_bench_verify.py` | `tools/qa/world/village_bench_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify actual bench substitutions, immutable gameplay and four-contact native galleries. | 7 |
| `tools/village_board_assets.py` | `tools/qa/world/village_board_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Derive six cardinal street props without repainting alpha or stretching axes. | 6 |
| `tools/village_board_capture.gd` | `tools/qa/world/village_board_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 40 |
| `tools/village_board_collect.py` | `tools/qa/world/village_board_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 25 |
| `tools/village_board_gallery.gd` | `tools/qa/world/village_board_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 36 |
| `tools/village_board_review.gd` | `tools/qa/world/village_board_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/village_board_verify.py` | `tools/qa/world/village_board_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify five first-map notice/sign placements and six-locale native evidence. | 5 |
| `tools/village_clearance_review.gd` | `tools/qa/world/village_clearance_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 3 |
| `tools/village_fence_assets.py` | `tools/qa/world/village_fence_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Derive modular oak fence sprites mechanically, without stretching or repainting. | 5 |
| `tools/village_fence_capture.gd` | `tools/qa/world/village_fence_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 46 |
| `tools/village_fence_collect.py` | `tools/qa/world/village_fence_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 29 |
| `tools/village_fence_gallery.gd` | `tools/qa/world/village_fence_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 42 |
| `tools/village_fence_review.gd` | `tools/qa/world/village_fence_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/village_fence_verify.py` | `tools/qa/world/village_fence_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify exact native fence changes, source coverage and unchanged gameplay/HUD. | 5 |
| `tools/village_lamp_assets.py` | `tools/qa/world/village_lamp_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Derive unlit lamp bodies; emission remains independent procedural profile data. | 6 |
| `tools/village_lamp_capture.gd` | `tools/qa/world/village_lamp_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 52 |
| `tools/village_lamp_collect.py` | `tools/qa/world/village_lamp_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 33 |
| `tools/village_lamp_gallery.gd` | `tools/qa/world/village_lamp_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 48 |
| `tools/village_lamp_review.gd` | `tools/qa/world/village_lamp_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/village_lamp_verify.py` | `tools/qa/world/village_lamp_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify actual lamp substitutions, immutable gameplay and cardinal native galleries. | 5 |
| `tools/village_map_review.gd` | `tools/qa/world/village_map_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/village_regions_capture.gd` | `tools/qa/world/village_regions_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/village_regions_review.gd` | `tools/qa/world/village_regions_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/village_street_assets.py` | `tools/qa/world/village_street_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Derive six cardinal street props without repainting alpha or stretching axes. | 6 |
| `tools/village_street_capture.gd` | `tools/qa/world/village_street_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 58 |
| `tools/village_street_collect.py` | `tools/qa/world/village_street_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native bench captures without touching ordinary Godot. | 37 |
| `tools/village_street_gallery.gd` | `tools/qa/world/village_street_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 54 |
| `tools/village_street_review.gd` | `tools/qa/world/village_street_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/village_street_verify.py` | `tools/qa/world/village_street_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify actual street substitutions, immutable gameplay and cardinal native galleries. | 5 |
| `tools/village_trade_assets.py` | `tools/qa/world/village_trade_assets.py` | Слои и объекты первой карты: вход или вспомогательный модуль семейства. Derive a small cardinal trading kit with preserved RGBA and uniform scale. | 6 |
| `tools/village_trade_capture.gd` | `tools/qa/world/village_trade_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 34 |
| `tools/village_trade_collect.py` | `tools/qa/world/village_trade_collect.py` | Слои и объекты первой карты: драйвер сбора серии. Collect source-bound before/after native lamp/body and light captures without touching ordinary Godot. | 22 |
| `tools/village_trade_gallery.gd` | `tools/qa/world/village_trade_gallery.gd` | Слои и объекты первой карты: галерея вариантов; UID: отслеживается | 30 |
| `tools/village_trade_review.gd` | `tools/qa/world/village_trade_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/village_trade_verify.py` | `tools/qa/world/village_trade_verify.py` | Слои и объекты первой карты: проверка сохранённых доказательств. Verify source-bound static market/sack captures, without claiming focus/input or performance. | 5 |
| `tools/water_audit.gd` | `tools/water_audit.gd` | Слои и объекты первой карты: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 91 |
| `tools/water_fishing_capture.gd` | `tools/qa/world/water_fishing_capture.gd` | Слои и объекты первой карты: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/water_fishing_review.gd` | `tools/qa/world/water_fishing_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/water_navigation_review.gd` | `tools/qa/world/water_navigation_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/water_topology_review.gd` | `tools/qa/world/water_topology_review.gd` | Слои и объекты первой карты: профильные Godot-проверки; UID: отслеживается | 5 |

## CPU, память и диагностические бюджеты

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/analyze_optimization_audit.py` | `tools/qa/performance/analyze_optimization_audit.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Читает сырые нативные кадры; никогда не принимает средний headless FPS за доказательство плавности. | 8 |
| `tools/analyze_storage_perf.py` | `tools/qa/performance/analyze_storage_perf.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Пересчитывает реальные интервалы хранилищ и отделяет короткие пробы от приёмки эпика. | 4 |
| `tools/audit_save_crashes.py` | `tools/qa/performance/audit_save_crashes.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Прерывает собственные дочерние Godot на границах записи в отдельном tmp. | 6 |
| `tools/boss_cpu_review.gd` | `tools/qa/performance/boss_cpu_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/cave_boss_frame_review.gd` | `tools/qa/performance/cave_boss_frame_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 6 |
| `tools/cpu_profile_game.gd` | `tools/qa/performance/cpu_profile_game.gd` | CPU, память и диагностические бюджеты: QA-надстройка над настоящей игрой; UID: нет в Git; отдельный preflight | 5 |
| `tools/geometry_benchmark.gd` | `tools/qa/performance/geometry_benchmark.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 6 |
| `tools/inspector_benchmark.gd` | `tools/qa/performance/inspector_benchmark.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: нет в Git; отдельный preflight | 5 |
| `tools/lazy_item_storage_perf.gd` | `tools/qa/performance/lazy_item_storage_perf.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/optimization_asset_audit.py` | `tools/qa/performance/optimization_asset_audit.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Статический аудит достижимых preload-ресурсов, без загрузки или редактирования изображений. | 5 |
| `tools/optimization_audit_boss.gd` | `tools/qa/performance/optimization_audit_boss.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/optimization_audit_route.gd` | `tools/qa/performance/optimization_audit_route.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/optimization_audit_sweep.gd` | `tools/qa/performance/optimization_audit_sweep.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 5 |
| `tools/perf_contract.py` | `tools/qa/performance/perf_contract.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Validate VPERF-001 protocol evidence without turning an observation into a release FPS gate. | 9 |
| `tools/perf_contract_capture.gd` | `tools/qa/performance/perf_contract_capture.gd` | CPU, память и диагностические бюджеты: сценарий захвата артефактов; UID: отслеживается | 46 |
| `tools/perf_contract_collect.py` | `tools/qa/performance/perf_contract_collect.py` | CPU, память и диагностические бюджеты: драйвер сбора серии. Collect VPERF-001 native protocol runs, with external RSS/CPU boundary samples. | 85 |
| `tools/performance_gate.py` | `tools/qa/performance/performance_gate.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Собирает настоящую игру в фиксированном окне; каждый normal/F10 повтор обязан пройти прежний бюджет50. | 7 |
| `tools/performance_gate.sh` | `tools/qa/performance/performance_gate.sh` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства | 14 |
| `tools/performance_protocol.py` | `tools/qa/performance/performance_protocol.py` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства. Независимо пересчитывает фиксированное окно по реальным callback timestamp; пропуски не превращает в0 FPS. | 13 |
| `tools/performance_sampler.gd` | `tools/performance_sampler.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 27 |
| `tools/redraw_frame_review.gd` | `tools/qa/performance/redraw_frame_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 12 |
| `tools/runtime_cleanup_review.gd` | `tools/qa/performance/runtime_cleanup_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 6 |
| `tools/runtime_cleanup_soak.gd` | `tools/qa/performance/runtime_cleanup_soak.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 6 |
| `tools/runtime_frame_review.gd` | `tools/qa/performance/runtime_frame_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 8 |
| `tools/save_crash_worker.gd` | `tools/qa/performance/save_crash_worker.gd` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/smoke_test.sh` | `tools/qa/performance/smoke_test.sh` | CPU, память и диагностические бюджеты: вход или вспомогательный модуль семейства | 10 |
| `tools/storage_perf_game.gd` | `tools/qa/performance/storage_perf_game.gd` | CPU, память и диагностические бюджеты: QA-надстройка над настоящей игрой; UID: отслеживается | 3 |
| `tools/storage_perf_review.gd` | `tools/qa/performance/storage_perf_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/test_optimization_audit.py` | `tools/qa/performance/test_optimization_audit.py` | CPU, память и диагностические бюджеты: профильные и отрицательные Python-контроли. Поведенческие проверки измерителя, генератора матрицы и статического графа ресурсов. | 5 |
| `tools/test_perf_contract.py` | `tools/qa/performance/test_perf_contract.py` | CPU, память и диагностические бюджеты: профильные и отрицательные Python-контроли. Protocol mutation tests use synthetic inputs; native acceptance remains a separate gate. | 8 |
| `tools/test_performance_gate.py` | `tools/qa/performance/test_performance_gate.py` | CPU, память и диагностические бюджеты: профильные и отрицательные Python-контроли. Повреждает копии настоящего trace; missing/invalid/process и настоящая малая скорость различаются. | 7 |
| `tools/test_redraw_output.py` | `tools/qa/performance/test_redraw_output.py` | CPU, память и диагностические бюджеты: профильные и отрицательные Python-контроли. Exercise the real shell wrapper with a fake engine; never launch Godot in these tests. | 3 |
| `tools/test_storage_perf.py` | `tools/qa/performance/test_storage_perf.py` | CPU, память и диагностические бюджеты: профильные и отрицательные Python-контроли. Не допускает ложной приёмки короткой, неполной, фоновой или зависшей трассы хранилища. | 4 |
| `tools/wildlife_query_review.gd` | `tools/qa/performance/wildlife_query_review.gd` | CPU, память и диагностические бюджеты: профильные Godot-проверки; UID: отслеживается | 15 |

## Регрессии существующих игровых систем

| Прежний путь | Предложенный путь | Назначение / UID | Ссылки в ledger |
| --- | --- | --- | ---: |
| `tools/action_lifecycle_native.gd` | `tools/qa/compatibility/action_lifecycle_native.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 7 |
| `tools/alchemy_capture.gd` | `tools/qa/compatibility/alchemy_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/alchemy_catalog_export.gd` | `tools/qa/compatibility/alchemy_catalog_export.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/alchemy_review.gd` | `tools/qa/compatibility/alchemy_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/apiary_capture.gd` | `tools/qa/compatibility/apiary_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/apiary_review.gd` | `tools/qa/compatibility/apiary_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/artisan_capture.gd` | `tools/qa/compatibility/artisan_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/artisan_review.gd` | `tools/qa/compatibility/artisan_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/basement_capture.gd` | `tools/qa/compatibility/basement_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/basement_review.gd` | `tools/qa/compatibility/basement_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/basement_ui_review.gd` | `tools/qa/compatibility/basement_ui_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 2 |
| `tools/boss_balance_review.gd` | `tools/qa/compatibility/boss_balance_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 4 |
| `tools/character_polish_capture.gd` | `tools/qa/compatibility/character_polish_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 2 |
| `tools/check_alchemy_reports.py` | `tools/qa/compatibility/check_alchemy_reports.py` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства. Проверяет выгруженный каталог и настоящие интервалы отрисовки после добавления алхимии. | 3 |
| `tools/compact_dialogue_capture.gd` | `tools/qa/compatibility/compact_dialogue_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 2 |
| `tools/compact_dialogue_preview.gd` | `tools/qa/compatibility/compact_dialogue_preview.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/compact_dialogue_review.gd` | `tools/qa/compatibility/compact_dialogue_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/compact_hud_review.gd` | `tools/qa/compatibility/compact_hud_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/content_reference_audit.gd` | `tools/qa/compatibility/content_reference_audit.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 6 |
| `tools/cooking_capture.gd` | `tools/qa/compatibility/cooking_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 3 |
| `tools/cooking_review.gd` | `tools/qa/compatibility/cooking_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 2 |
| `tools/depth_guardian_capture.gd` | `tools/qa/compatibility/depth_guardian_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 5 |
| `tools/depth_guardian_review.gd` | `tools/qa/compatibility/depth_guardian_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/design_audit_capture.gd` | `tools/qa/compatibility/design_audit_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 5 |
| `tools/design_audit_gallery.gd` | `tools/qa/compatibility/design_audit_gallery.gd` | Регрессии существующих игровых систем: галерея вариантов; UID: отслеживается | 7 |
| `tools/design_audit_review.gd` | `tools/qa/compatibility/design_audit_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/dev_cabinet_capture.gd` | `tools/qa/compatibility/dev_cabinet_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/dev_cabinet_review.gd` | `tools/qa/compatibility/dev_cabinet_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 16 |
| `tools/dropped_loot_capture.gd` | `tools/qa/compatibility/dropped_loot_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/dropped_loot_review.gd` | `tools/qa/compatibility/dropped_loot_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/end_to_end_capture.gd` | `tools/qa/compatibility/end_to_end_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 5 |
| `tools/end_to_end_review.gd` | `tools/qa/compatibility/end_to_end_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/farm_bounds_capture.gd` | `tools/qa/compatibility/farm_bounds_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 3 |
| `tools/farm_bounds_review.gd` | `tools/qa/compatibility/farm_bounds_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/farm_cursor_review.gd` | `tools/qa/compatibility/farm_cursor_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/farm_cycles.py` | `tools/qa/compatibility/farm_cycles.py` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства. Выгружает кандидаты замкнутых цепочек из фактического каталога FARM. | 3 |
| `tools/farm_native.gd` | `tools/qa/compatibility/farm_native.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/farm_review.gd` | `tools/qa/compatibility/farm_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/focus_pause_native.gd` | `tools/qa/compatibility/focus_pause_native.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 4 |
| `tools/front_facing_capture.gd` | `tools/qa/compatibility/front_facing_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/front_facing_review.gd` | `tools/qa/compatibility/front_facing_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/furnace_capture.gd` | `tools/qa/compatibility/furnace_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/furnace_review.gd` | `tools/qa/compatibility/furnace_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/generate_adaptive_hud_previews.gd` | `tools/qa/compatibility/generate_adaptive_hud_previews.gd` | Регрессии существующих игровых систем: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 7 |
| `tools/generate_hero_pose_preview.gd` | `tools/qa/compatibility/generate_hero_pose_preview.gd` | Регрессии существующих игровых систем: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 3 |
| `tools/generate_ui_layout_audit.gd` | `tools/qa/compatibility/generate_ui_layout_audit.gd` | Регрессии существующих игровых систем: подготовка ресурсов или эталонов; UID: нет в Git; отдельный preflight | 6 |
| `tools/grandmother_animation_review.gd` | `tools/qa/compatibility/grandmother_animation_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/held_weapon_capture.gd` | `tools/qa/compatibility/held_weapon_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/held_weapon_review.gd` | `tools/qa/compatibility/held_weapon_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/hero_actions_capture.gd` | `tools/qa/compatibility/hero_actions_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 2 |
| `tools/hero_actions_review.gd` | `tools/qa/compatibility/hero_actions_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 2 |
| `tools/house_furniture_capture.gd` | `tools/qa/compatibility/house_furniture_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 2 |
| `tools/house_furniture_review.gd` | `tools/qa/compatibility/house_furniture_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/kitchen_capture.gd` | `tools/qa/compatibility/kitchen_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/kitchen_review.gd` | `tools/qa/compatibility/kitchen_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/lazy_item_icons_review.gd` | `tools/qa/compatibility/lazy_item_icons_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/livestock_review.gd` | `tools/qa/compatibility/livestock_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 11 |
| `tools/paper_theme_capture.gd` | `tools/qa/compatibility/paper_theme_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 8 |
| `tools/paper_theme_reference_capture.gd` | `tools/qa/compatibility/paper_theme_reference_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/paper_theme_review.gd` | `tools/qa/compatibility/paper_theme_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 7 |
| `tools/player_contact_capture.gd` | `tools/qa/compatibility/player_contact_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 2 |
| `tools/player_contact_review.gd` | `tools/qa/compatibility/player_contact_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 2 |
| `tools/prepared_pixels_review.gd` | `tools/qa/compatibility/prepared_pixels_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/prop_edges_capture.gd` | `tools/qa/compatibility/prop_edges_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 2 |
| `tools/qa_teleport_capture.gd` | `tools/qa/compatibility/qa_teleport_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/qa_teleport_review.gd` | `tools/qa/compatibility/qa_teleport_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/ranged_combat_capture.gd` | `tools/qa/compatibility/ranged_combat_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: нет в Git; отдельный preflight | 4 |
| `tools/ranged_combat_review.gd` | `tools/qa/compatibility/ranged_combat_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/recovery_capture.gd` | `tools/qa/compatibility/recovery_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 5 |
| `tools/recovery_review.gd` | `tools/qa/compatibility/recovery_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/research_capture.gd` | `tools/qa/compatibility/research_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/research_catalog_export.gd` | `tools/qa/compatibility/research_catalog_export.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 4 |
| `tools/research_review.gd` | `tools/qa/compatibility/research_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/resident_review.gd` | `tools/qa/compatibility/resident_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 2 |
| `tools/runtime_comfort_review.gd` | `tools/qa/compatibility/runtime_comfort_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/runtime_maintenance_tests.gd` | `tools/qa/compatibility/runtime_maintenance_tests.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 5 |
| `tools/safe_review.gd` | `tools/qa/compatibility/safe_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 6 |
| `tools/skeleton_aim_capture.gd` | `tools/qa/compatibility/skeleton_aim_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 4 |
| `tools/startup_review.gd` | `tools/qa/compatibility/startup_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 5 |
| `tools/storage_actions_capture.gd` | `tools/qa/compatibility/storage_actions_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/storage_window_capture.gd` | `tools/qa/compatibility/storage_window_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 5 |
| `tools/terrain_cache_review.gd` | `tools/qa/compatibility/terrain_cache_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 5 |
| `tools/tree_occlusion_review.gd` | `tools/qa/compatibility/tree_occlusion_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: нет в Git; отдельный preflight | 4 |
| `tools/workshops_capture.gd` | `tools/qa/compatibility/workshops_capture.gd` | Регрессии существующих игровых систем: сценарий захвата артефактов; UID: отслеживается | 3 |
| `tools/workshops_catalog_export.gd` | `tools/qa/compatibility/workshops_catalog_export.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/workshops_review.gd` | `tools/qa/compatibility/workshops_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 4 |
| `tools/world_native.gd` | `tools/qa/compatibility/world_native.gd` | Регрессии существующих игровых систем: вход или вспомогательный модуль семейства; UID: отслеживается | 3 |
| `tools/world_review.gd` | `tools/qa/compatibility/world_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 3 |
| `tools/world_workbench_review.gd` | `tools/qa/compatibility/world_workbench_review.gd` | Регрессии существующих игровых систем: профильные Godot-проверки; UID: отслеживается | 6 |


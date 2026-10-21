# VRENDER · Слои существующего custom draw

[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)

<a id="vrender-001"></a>

## VRENDER-001 — Описать порядок команд кадра

Статус: `done` · P0 · этап `foundation` · `engineering`

От земли до HUD перечислены реальные вызовы, материал и система координат; зависимости переднего плана сохранены

Ветка: `codex/vrender-001-render-order`.

Зависимости: VBASE-001.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результаты: `docs/reports/visual-overhaul/vrender-001/`.

Критерии:

- От земли до HUD перечислены реальные вызовы, материал и система координат; зависимости переднего плана сохранены
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vrender-001/README.md, docs/reports/visual-overhaul/vrender-001/contract.json, docs/reports/visual-overhaul/vrender-001/summary.json, docs/reports/visual-overhaul/vrender-001/native/source.json, docs/reports/visual-overhaul/vrender-001/browser-review.json.

<a id="vrender-002"></a>

## VRENDER-002 — Сравнить три способа эффекта травы

Статус: `done` · P0 · этап `foundation` · `engineering`

Один участок сравнивает CPU mesh, отдельный CanvasItem и пакетную геометрию; ADR содержит стоимость и отклонённые варианты

Ветка: `codex/vrender-002-grass-methods`.

Зависимости: VRENDER-001.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результаты: `docs/reports/visual-overhaul/vrender-002/`.

Критерии:

- Один участок сравнивает CPU mesh, отдельный CanvasItem и пакетную геометрию; ADR содержит стоимость и отклонённые варианты
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vrender-002/README.md, docs/reports/visual-overhaul/vrender-002/ADR.md, docs/reports/visual-overhaul/vrender-002/summary.json, docs/reports/visual-overhaul/vrender-002/bench/source.json, docs/reports/visual-overhaul/vrender-002/cpu-only/source.json, docs/reports/visual-overhaul/vrender-002/quality/source.json, docs/reports/visual-overhaul/vrender-002/browser-review.json, docs/reports/visual-overhaul/vrender-002/checks.json.

<a id="vrender-003"></a>

## VRENDER-003 — Разделить статичное и живое покрытие

Статус: `done` · P0 · этап `foundation` · `engineering`

Вода и движущаяся растительность не запекаются в UPDATE_ONCE; неподвижная земля не пересобирается каждый кадр

Ветка: `codex/vrender-003-static-live-ground`.

Зависимости: VRENDER-002.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результаты: `docs/reports/visual-overhaul/vrender-003/`.

Критерии:

- Вода и движущаяся растительность не запекаются в UPDATE_ONCE; неподвижная земля не пересобирается каждый кадр
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vrender-003/README.md, docs/reports/visual-overhaul/vrender-003/summary.json, docs/reports/visual-overhaul/vrender-003/native/source.json, docs/reports/visual-overhaul/vrender-003/native/1152/hot-loop.json, docs/reports/visual-overhaul/vrender-003/native/1152/cold.json, docs/reports/visual-overhaul/vrender-003/review.txt, docs/reports/visual-overhaul/vrender-003/browser-review.json.

<a id="vrender-004"></a>

## VRENDER-004 — Определить контракт команды объекта

Статус: `done` · P0 · этап `foundation` · `engineering`

Пакет содержит опору, bounds, материал, локальный UV и слой; прежний draw путь остаётся рабочим fallback

Ветка: `codex/vrender-004-object-command`.

Зависимости: VRENDER-002.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результаты: `docs/reports/visual-overhaul/vrender-004/`.

Критерии:

- Пакет содержит опору, bounds, материал, локальный UV и слой; прежний draw путь остаётся рабочим fallback
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vrender-004/README.md, docs/reports/visual-overhaul/vrender-004/contract.json, docs/reports/visual-overhaul/vrender-004/review.txt, docs/reports/visual-overhaul/vrender-004/python-check.txt, docs/reports/visual-overhaul/vrender-004/sampling-notes.json, docs/reports/visual-overhaul/vrender-004/progress-check.json, docs/reports/visual-overhaul/vrender-004/quality-check.txt, docs/reports/visual-overhaul/vrender-004/browser-review.json, docs/reports/visual-overhaul/vrender-004/summary.json, docs/reports/visual-overhaul/vrender-004/native/source.json, docs/reports/visual-overhaul/vrender-004/completion.json, docs/reports/visual-overhaul/vrender-004/final-quality-check.txt, docs/reports/visual-overhaul/vrender-004/wiki-check.txt.

<a id="vrender-005"></a>

## VRENDER-005 — Включить один выбранный проход

Статус: `ready` · P0 · этап `foundation` · `engineering`

Feature flag переключает только эталонный участок; остальные карты и HUD дают прежнее поведение

Ветка: `codex/vrender-005-visual-task`.

Зависимости: VRENDER-003, VRENDER-004.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-005/`.

Критерии:

- Feature flag переключает только эталонный участок; остальные карты и HUD дают прежнее поведение
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vrender-006"></a>

## VRENDER-006 — Свести сортировку героя и растений

Статус: `backlog` · P0 · этап `foundation` · `engineering`

Передний и задний проход не создают непрозрачный дубль; переход через равный ground_y имеет стабильный порядок

Ветка: `codex/vrender-006-visual-task`.

Зависимости: VRENDER-005.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-006/`.

Критерии:

- Передний и задний проход не создают непрозрачный дубль; переход через равный ground_y имеет стабильный порядок
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vrender-007"></a>

## VRENDER-007 — Разделить настил и перила моста

Статус: `backlog` · P0 · этап `foundation` · `engineering`

Ноги над настилом, ближние перила перед телом; вода под настилом не становится проходимой вне реального моста

Ветка: `codex/vrender-007-visual-task`.

Зависимости: VRENDER-005.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-007/`.

Критерии:

- Ноги над настилом, ближние перила перед телом; вода под настилом не становится проходимой вне реального моста
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vrender-008"></a>

## VRENDER-008 — Передавать время после движения

Статус: `ready` · P0 · этап `foundation` · `engineering`

Сервис получает фактическую позицию после столкновений и перехода карты; уткнувшийся в стену герой не продавливает дальнюю траву

Ветка: `codex/vrender-008-visual-task`.

Зависимости: VRENDER-004.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-008/`.

Критерии:

- Сервис получает фактическую позицию после столкновений и перехода карты; уткнувшийся в стену герой не продавливает дальнюю траву
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vrender-009"></a>

## VRENDER-009 — Изолировать параметры нескольких viewport

Статус: `backlog` · P0 · этап `foundation` · `engineering`

Редактор, мини-превью и игра не перезаписывают позиции и время друг друга; выбран один владелец на мир

Ветка: `codex/vrender-009-visual-task`.

Зависимости: VRENDER-008.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-009/`.

Критерии:

- Редактор, мини-превью и игра не перезаписывают позиции и время друг друга; выбран один владелец на мир
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vrender-010"></a>

## VRENDER-010 — Проверить освобождение визуального мира

Статус: `backlog` · P0 · этап `foundation` · `engineering`

После 50 смен карт нет зависших материалов и активного влияния прежнего героя; ошибка ресурса включает fallback

Ветка: `codex/vrender-010-visual-task`.

Зависимости: VRENDER-009.

Единый владелец пересечения: **OPT-04**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/render_system.gd](../../../../scripts/systems/render_system.gd)
- [scripts/world_background.gd](../../../../scripts/world_background.gd)
- [scripts/presentation/village_terrain_canvas.gd](../../../../scripts/presentation/village_terrain_canvas.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vrender-010/`.

Критерии:

- После 50 смен карт нет зависших материалов и активного влияния прежнего героя; ошибка ресурса включает fallback
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить герой/куст/перила/передний план и HUD, manual pause, два viewport, вход-выход из карты; сравнить snapshots состояния до/после draw.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

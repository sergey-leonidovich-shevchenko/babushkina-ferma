# VFOLIAGE · Ветер и отклик растительности

[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)

<a id="vfoliage-001"></a>

## VFOLIAGE-001 — Определить корни внутри атласа

Статус: `done` · P0 · этап `pilot` · `engineering`

Каждая используемая область 362×362 имеет реальный anchor и маску гибкости; прозрачный низ не считается корнем

Ветка: `codex/vfoliage-001-atlas-roots`.

Зависимости: VART-008, VRENDER-002.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-001/`.

Критерии:

- Каждая используемая область 362×362 имеет реальный anchor и маску гибкости; прозрачный низ не считается корнем
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-001/README.md, docs/reports/visual-overhaul/vfoliage-001/dependency-audit.json, docs/reports/visual-overhaul/vfoliage-001/changes.json, docs/reports/visual-overhaul/vfoliage-001/runtime.patch, docs/reports/visual-overhaul/vfoliage-001/native-admission.json, docs/reports/visual-overhaul/vfoliage-001/profiles.json, docs/reports/visual-overhaul/vfoliage-001/summary.json, docs/reports/visual-overhaul/vfoliage-001/native/source.json, docs/reports/visual-overhaul/vfoliage-001/review.txt, docs/reports/visual-overhaul/vfoliage-001/python-check.txt, docs/reports/visual-overhaul/vfoliage-001/completion.json, docs/reports/visual-overhaul/vfoliage-001/quality-check.txt, docs/reports/visual-overhaul/vfoliage-001/wiki-check.txt, docs/reports/visual-overhaul/vfoliage-001/browser-review.json.

<a id="vfoliage-002"></a>

## VFOLIAGE-002 — Подготовить локальные UV растения

Статус: `done` · P0 · этап `pilot` · `engineering`

Соседняя ячейка не попадает в выборку при деформации и linear; flip не переворачивает закреплённый низ

Ветка: `codex/vfoliage-002-local-uv`.

Зависимости: VFOLIAGE-001.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-002/`.

Критерии:

- Соседняя ячейка не попадает в выборку при деформации и linear; flip не переворачивает закреплённый низ
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-002/README.md, docs/reports/visual-overhaul/vfoliage-002/dependency-audit.json, docs/reports/visual-overhaul/vfoliage-002/changes.json, docs/reports/visual-overhaul/vfoliage-002/native-admission.json, docs/reports/visual-overhaul/vfoliage-002/summary.json, docs/reports/visual-overhaul/vfoliage-002/native/source.json, docs/reports/visual-overhaul/vfoliage-002/review.txt, docs/reports/visual-overhaul/vfoliage-002/python-check.txt, docs/reports/visual-overhaul/vfoliage-002/completion.json, docs/reports/visual-overhaul/vfoliage-002/quality-check.txt, docs/reports/visual-overhaul/vfoliage-002/wiki-check.txt, docs/reports/visual-overhaul/vfoliage-002/browser-review.json.

<a id="vfoliage-003"></a>

## VFOLIAGE-003 — Сделать слабый фоновый ветер

Статус: `done` · P0 · этап `pilot` · `engineering`

Корни неподвижны, фазы пространственно различаются; вся картинка больше не ездит целиком

Ветка: `codex/vfoliage-003-background-wind`.

Зависимости: VFOLIAGE-002, VRENDER-005, VRENDER-008.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-003/`.

Критерии:

- Корни неподвижны, фазы пространственно различаются; вся картинка больше не ездит целиком
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-003/README.md, docs/reports/visual-overhaul/vfoliage-003/summary.json, docs/reports/visual-overhaul/vfoliage-003/completion.json, docs/reports/visual-overhaul/vfoliage-003/native/source.json, wiki/articles/foliage-wind.md.

<a id="vfoliage-004"></a>

## VFOLIAGE-004 — Добавить отклонение от героя

Статус: `done` · P0 · этап `pilot` · `engineering`

Подход с четырёх сторон и остановка точно в корне не дают NaN, резкого перелома и чрезмерного изгиба

Ветка: `codex/vfoliage-004-hero-contact`.

Зависимости: VFOLIAGE-003.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-004/`.

Критерии:

- Подход с четырёх сторон и остановка точно в корне не дают NaN, резкого перелома и чрезмерного изгиба
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-004/README.md, docs/reports/visual-overhaul/vfoliage-004/summary.json, docs/reports/visual-overhaul/vfoliage-004/completion.json, docs/reports/visual-overhaul/vfoliage-004/native/source.json, wiki/articles/foliage-contact.md.

<a id="vfoliage-005"></a>

## VFOLIAGE-005 — Учитывать реальную скорость прохода

Статус: `done` · P0 · этап `pilot` · `engineering`

Медленный шаг и бег имеют разные импульсы; ввод в стену без движения не создаёт сильного эффекта

Ветка: `codex/vfoliage-005-actual-speed`.

Зависимости: VFOLIAGE-004.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-005/`.

Критерии:

- Медленный шаг и бег имеют разные импульсы; ввод в стену без движения не создаёт сильного эффекта
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-005/README.md, docs/reports/visual-overhaul/vfoliage-005/summary.json, docs/reports/visual-overhaul/vfoliage-005/completion.json, docs/reports/visual-overhaul/vfoliage-005/native/source.json, wiki/articles/foliage-speed.md.

<a id="vfoliage-006"></a>

## VFOLIAGE-006 — Добавить мягкое восстановление

Статус: `done` · P0 · этап `pilot` · `engineering`

После выхода состояние возвращается без скачка; активный набор имеет предел и удаляет затухшие записи

Ветка: `codex/vfoliage-006-soft-recovery`.

Зависимости: VFOLIAGE-005.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результаты: `docs/reports/visual-overhaul/vfoliage-006/`.

Критерии:

- После выхода состояние возвращается без скачка; активный набор имеет предел и удаляет затухшие записи
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vfoliage-006/README.md, docs/reports/visual-overhaul/vfoliage-006/summary.json, docs/reports/visual-overhaul/vfoliage-006/completion.json, docs/reports/visual-overhaul/vfoliage-006/native/source.json, wiki/articles/foliage-recovery.md, docs/reports/visual-overhaul/vfoliage-006/review-1/README.md, docs/reports/visual-overhaul/vfoliage-006/review-1/summary.json, docs/reports/visual-overhaul/vfoliage-006/review-1/completion.json, docs/reports/visual-overhaul/vfoliage-006/review-1/native/source.json, docs/reports/visual-overhaul/vfoliage-006/ci-portability/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-portability/completion.json, docs/reports/visual-overhaul/vfoliage-006/ci-godot-env/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-godot-env/completion.json, docs/reports/visual-overhaul/vfoliage-006/ci-migration-source/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-migration-source/completion.json, docs/reports/visual-overhaul/vfoliage-006/ci-platform/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-platform/completion.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-repro/completion.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac/sources.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac/preview/report.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac/catalogue/report.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac/ui/report.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/ci-artifacts.json, docs/reports/visual-overhaul/vfoliage-006/ci-repro/proposed-game-gate.patch, docs/reports/visual-overhaul/vfoliage-006/ci-repro/mac-gl-cachefix/context.json, docs/reports/visual-overhaul/vfoliage-006/ci-integration/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-performance/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-performance/production/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-performance/p3/README.md, docs/reports/visual-overhaul/vfoliage-006/ci-error-detection/README.md, docs/reports/visual-overhaul/vfoliage-006/causal-investigation/README.md, docs/reports/visual-overhaul/vfoliage-006/redraw-scheduling/README.md, docs/reports/visual-overhaul/vfoliage-006/redraw-output-ownership/README.md, docs/reports/visual-overhaul/vfoliage-006/closeout/completion.json.

<a id="vfoliage-007"></a>

## VFOLIAGE-007 — Разделить жёсткость растений

Статус: `ready` · P0 · этап `pilot` · `engineering`

Трава, камыш, цветок и куст имеют разные параметры; цветы не превращаются в резиновый веер

Ветка: `codex/vfoliage-007-visual-task`.

Зависимости: VFOLIAGE-001.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vfoliage-007/`.

Критерии:

- Трава, камыш, цветок и куст имеют разные параметры; цветы не превращаются в резиновый веер
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vfoliage-008"></a>

## VFOLIAGE-008 — Ограничить влияние NPC и животных

Статус: `backlog` · P0 · этап `pilot` · `engineering`

Только ближайшие выбранные акторы влияют на видимые пучки; число источников ограничено и измеряется

Ветка: `codex/vfoliage-008-visual-task`.

Зависимости: VFOLIAGE-006.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vfoliage-008/`.

Критерии:

- Только ближайшие выбранные акторы влияют на видимые пучки; число источников ограничено и измеряется
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vfoliage-009"></a>

## VFOLIAGE-009 — Заморозить эффекты на игровой паузе

Статус: `ready` · P0 · этап `pilot` · `engineering`

Рюкзак, шкаф, меню, фокус и редактор останавливают visual clock согласно политике; возврат не даёт скачка

Ветка: `codex/vfoliage-009-visual-task`.

Зависимости: VFOLIAGE-004, VRENDER-008.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vfoliage-009/`.

Критерии:

- Рюкзак, шкаф, меню, фокус и редактор останавливают visual clock согласно политике; возврат не даёт скачка
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vfoliage-010"></a>

## VFOLIAGE-010 — Принять видимость и бюджет травы

Статус: `backlog` · P0 · этап `pilot` · `engineering`

Видео у краёв экрана, через куст и чанк; максимальные bounds учитывают изгиб, draw calls и overdraw записаны

Ветка: `codex/vfoliage-010-visual-task`.

Зависимости: VFOLIAGE-006, VFOLIAGE-009, VRENDER-006.

Исходники:

- [scripts/systems/village_ambient_renderer.gd](../../../../scripts/systems/village_ambient_renderer.gd)
- [scripts/systems/world_visual_profile_system.gd](../../../../scripts/systems/world_visual_profile_system.gd)
- [scripts/core/game_loop.gd](../../../../scripts/core/game_loop.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vfoliage-010/`.

Критерии:

- Видео у краёв экрана, через куст и чанк; максимальные bounds учитывают изгиб, draw calls и overdraw записаны
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Четыре подхода к корню, бег/стоп/стена, телепорт, пауза, offscreen, low quality; счётчики активных пучков возвращаются к исходным.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

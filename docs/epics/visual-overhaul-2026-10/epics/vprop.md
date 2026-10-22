# VPROP · Общий набор предметов окружения

[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)

<a id="vprop-001"></a>

## VPROP-001 — Подготовить простой дубовый набор

Статус: `ready` · P1 · этап `pilot` · `engineering`

Стол, стул, шкаф и сундук представлены отдельными мастерами в трёх сторонах без растяжения

Ветка: `codex/vprop-001-visual-task`.

Зависимости: VART-004.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)
- [docs/reports/visual-overhaul/vart-004/README.md](../../../../docs/reports/visual-overhaul/vart-004/README.md)
- [docs/reports/visual-overhaul/vart-006/README.md](../../../../docs/reports/visual-overhaul/vart-006/README.md)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vprop-001/`.

Критерии:

- Стол, стул, шкаф и сундук представлены отдельными мастерами в трёх сторонах без растяжения
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.
- У сторон согласованы исходная плотность, высота ножек/корпуса и видимая рабочая грань; учтены отклонения VART-004.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vprop-002"></a>

## VPROP-002 — Перерисовать деревенские лавки

Статус: `done` · P1 · этап `pilot` · `engineering`

Лево, право и вниз читаются с игровой камеры; основание и тень одинаковы у трёх видов

Ветка: `codex/vprop-002-village-benches`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-002/`.

Критерии:

- Лево, право и вниз читаются с игровой камеры; основание и тень одинаковы у трёх видов
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-002/README.md, docs/reports/visual-overhaul/vprop-002/source.json, docs/reports/visual-overhaul/vprop-002/prompts.json, docs/reports/visual-overhaul/vprop-002/summary.json, docs/reports/visual-overhaul/vprop-002/native/before/source.json, docs/reports/visual-overhaul/vprop-002/native/after/source.json, docs/reports/visual-overhaul/vprop-002/review.txt, docs/reports/visual-overhaul/vprop-002/python-check.txt, docs/reports/visual-overhaul/vprop-002/completion.json, docs/reports/visual-overhaul/vprop-002/quality-check.txt, docs/reports/visual-overhaul/vprop-002/wiki-check.txt, docs/reports/visual-overhaul/vprop-002/browser-review.json, docs/reports/visual-overhaul/vprop-002-four-legs/README.md, docs/reports/visual-overhaul/vprop-002-four-legs/source.json, docs/reports/visual-overhaul/vprop-002-four-legs/prompts.json, docs/reports/visual-overhaul/vprop-002-four-legs/native.json, docs/reports/visual-overhaul/vprop-002-four-legs/completion.json, docs/reports/visual-overhaul/vprop-002-four-legs/quality-check.txt, docs/reports/visual-overhaul/vprop-002-four-legs/wiki-check.txt, docs/reports/visual-overhaul/vprop-002-four-legs/browser-review.json.

<a id="vprop-003"></a>

## VPROP-003 — Перерисовать колодец и телегу

Статус: `done` · P1 · этап `pilot` · `engineering`

Убраны белые края и диагональная телега; колодец имеет видимый объём и понятный подход

Ветка: `codex/vprop-003-well-cart`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-003/`.

Критерии:

- Убраны белые края и диагональная телега; колодец имеет видимый объём и понятный подход
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-003/README.md, docs/reports/visual-overhaul/vprop-003/alpha-review.json, docs/reports/visual-overhaul/vprop-003/source.json, docs/reports/visual-overhaul/vprop-003/prompts.json, docs/reports/visual-overhaul/vprop-003/summary.json, docs/reports/visual-overhaul/vprop-003/native/before/source.json, docs/reports/visual-overhaul/vprop-003/native/after/source.json, docs/reports/visual-overhaul/vprop-003/review.txt, docs/reports/visual-overhaul/vprop-003/python-check.txt, docs/reports/visual-overhaul/vprop-003/sampling-notes.json, docs/reports/visual-overhaul/vprop-003/completion.json, docs/reports/visual-overhaul/vprop-003/quality-check.txt, docs/reports/visual-overhaul/vprop-003/wiki-check.txt, docs/reports/visual-overhaul/vprop-003/browser-review.json.

<a id="vprop-004"></a>

## VPROP-004 — Разделить светильник и свечение

Статус: `done` · P1 · этап `pilot` · `engineering`

Сухой рисунок фонаря пригоден днём; свет подключается отдельным профилем вечером

Ветка: `codex/vprop-004-lamp-glow`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-004/`.

Критерии:

- Сухой рисунок фонаря пригоден днём; свет подключается отдельным профилем вечером
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-004/README.md, docs/reports/visual-overhaul/vprop-004/source.json, docs/reports/visual-overhaul/vprop-004/prompts.json, docs/reports/visual-overhaul/vprop-004/summary.json, docs/reports/visual-overhaul/vprop-004/native/before/source.json, docs/reports/visual-overhaul/vprop-004/native/after/source.json, docs/reports/visual-overhaul/vprop-004/review.txt, docs/reports/visual-overhaul/vprop-004/python-check.txt, docs/reports/visual-overhaul/vprop-004/completion.json, docs/reports/visual-overhaul/vprop-004/quality-check.txt, docs/reports/visual-overhaul/vprop-004/wiki-check.txt, docs/reports/visual-overhaul/vprop-004/browser-review.json.

<a id="vprop-005"></a>

## VPROP-005 — Подготовить ограждения и ворота

Статус: `done` · P1 · этап `pilot` · `engineering`

Прямые секции, углы и проходы привязаны к сетке; визуальный забор совпадает с блокировкой

Ветка: `codex/vprop-005-fence-grid`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-005/`.

Критерии:

- Прямые секции, углы и проходы привязаны к сетке; визуальный забор совпадает с блокировкой
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-005/README.md, docs/reports/visual-overhaul/vprop-005/source.json, docs/reports/visual-overhaul/vprop-005/prompts.json, docs/reports/visual-overhaul/vprop-005/summary.json, docs/reports/visual-overhaul/vprop-005/native/before/source.json, docs/reports/visual-overhaul/vprop-005/native/after/source.json, docs/reports/visual-overhaul/vprop-005/review.txt, docs/reports/visual-overhaul/vprop-005/python-check.txt, docs/reports/visual-overhaul/vprop-005/completion.json, docs/reports/visual-overhaul/vprop-005/quality-check.txt, docs/reports/visual-overhaul/vprop-005/wiki-check.txt, docs/reports/visual-overhaul/vprop-005/browser-review.json.

<a id="vprop-006"></a>

## VPROP-006 — Согласовать указатели и доски

Статус: `done` · P1 · этап `pilot` · `engineering`

Читаемые силуэты, общий масштаб и три стороны; подпись не встроена в текстуру для шести локалей

Ветка: `codex/vprop-006-wayfinding`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-006/`.

Критерии:

- Читаемые силуэты, общий масштаб и три стороны; подпись не встроена в текстуру для шести локалей
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-006/README.md, docs/reports/visual-overhaul/vprop-006/source.json, docs/reports/visual-overhaul/vprop-006/prompts.json, docs/reports/visual-overhaul/vprop-006/summary.json, docs/reports/visual-overhaul/vprop-006/native/before/source.json, docs/reports/visual-overhaul/vprop-006/native/after/source.json, docs/reports/visual-overhaul/vprop-006/review.txt, docs/reports/visual-overhaul/vprop-006/python-check.txt, docs/reports/visual-overhaul/vprop-006/completion.json, docs/reports/visual-overhaul/vprop-006/quality-check.txt, docs/reports/visual-overhaul/vprop-006/wiki-check.txt, docs/reports/visual-overhaul/vprop-006/browser-review.json.

<a id="vprop-007"></a>

## VPROP-007 — Подготовить торговый декор

Статус: `done` · P1 · этап `pilot` · `engineering`

Ящики, мешки, бочки и прилавки не закрывают доступ к услугам; на воду не попадают

Ветка: `codex/vprop-007-trade-decor`.

Зависимости: VART-004, VART-008.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результаты: `docs/reports/visual-overhaul/vprop-007/`.

Критерии:

- Ящики, мешки, бочки и прилавки не закрывают доступ к услугам; на воду не попадают
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vprop-007/README.md, docs/reports/visual-overhaul/vprop-007/source.json, docs/reports/visual-overhaul/vprop-007/prompts.json, docs/reports/visual-overhaul/vprop-007/summary.json, docs/reports/visual-overhaul/vprop-007/native/before/source.json, docs/reports/visual-overhaul/vprop-007/native/after/source.json, docs/reports/visual-overhaul/vprop-007/review.txt, docs/reports/visual-overhaul/vprop-007/python-check.txt, docs/reports/visual-overhaul/vprop-007/completion.json, docs/reports/visual-overhaul/vprop-007/quality-check.txt, docs/reports/visual-overhaul/vprop-007/wiki-check.txt, docs/reports/visual-overhaul/vprop-007/browser-review.json.

<a id="vprop-008"></a>

## VPROP-008 — Подготовить интерьерный декор

Статус: `backlog` · P1 · этап `pilot` · `engineering`

Ковёр, посуда и настенные детали добавляют уют без случайной диагональной перспективы мебели

Ветка: `codex/vprop-008-visual-task`.

Зависимости: VPROP-001.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vprop-008/`.

Критерии:

- Ковёр, посуда и настенные детали добавляют уют без случайной диагональной перспективы мебели
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vprop-009"></a>

## VPROP-009 — Подготовить пещерные опоры

Статус: `backlog` · P1 · этап `pilot` · `engineering`

Балка, рельс, обломки и факел имеют единый материал и глубину; декор не выдаётся за добываемую жилу

Ветка: `codex/vprop-009-visual-task`.

Зависимости: VPROP-001.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vprop-009/`.

Критерии:

- Балка, рельс, обломки и факел имеют единый материал и глубину; декор не выдаётся за добываемую жилу
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vprop-010"></a>

## VPROP-010 — Принять общий набор в сцене

Статус: `backlog` · P1 · этап `pilot` · `engineering`

Все предметы показаны рядом с героем при штатном масштабе и на сетке; макеты утверждены до runtime замены

Ветка: `codex/vprop-010-visual-task`.

Зависимости: VPROP-001, VPROP-002, VPROP-003, VPROP-004, VPROP-005, VPROP-006, VPROP-007, VPROP-008, VPROP-009.

Единый владелец пересечения: **UX-05**. Эта карточка уточняет работу владельца, не закрывает его автоматически.

Исходники:

- [scripts/systems/village_layout_system.gd](../../../../scripts/systems/village_layout_system.gd)
- [scripts/presentation/house_furniture_visual_system.gd](../../../../scripts/presentation/house_furniture_visual_system.gd)
- [scripts/systems/furniture_facing_system.gd](../../../../scripts/systems/furniture_facing_system.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vprop-010/`.

Критерии:

- Все предметы показаны рядом с героем при штатном масштабе и на сетке; макеты утверждены до runtime замены
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Лево/право/вниз, сетка и единственный подход; светлый/тёмный фон, боковое перекрытие героем и отсутствие растяжения.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

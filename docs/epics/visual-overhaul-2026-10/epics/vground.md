# VGROUND · Земля и дороги

[Все эпики](../TASKS.md) · [Аудит](../AUDIT.md)

<a id="vground-001"></a>

## VGROUND-001 — Собрать бесшовную базу травы

Статус: `done` · P0 · этап `pilot` · `engineering`

Показать повтор 5×5 при игровом масштабе; крупных узнаваемых одинаковых пятен нет

Ветка: `codex/vground-001-seamless-grass`.

Зависимости: VART-008, VRENDER-003.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результаты: `docs/reports/visual-overhaul/vground-001/`.

Критерии:

- Показать повтор 5×5 при игровом масштабе; крупных узнаваемых одинаковых пятен нет
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vground-001/README.md, docs/reports/visual-overhaul/vground-001/art-source.json, docs/reports/visual-overhaul/vground-001/summary.json, docs/reports/visual-overhaul/vground-001/completion.json, docs/reports/visual-overhaul/vground-001/native/source.json, docs/reports/visual-overhaul/vground-001/review.txt, docs/reports/visual-overhaul/vground-001/browser-review.json.

<a id="vground-002"></a>

## VGROUND-002 — Добавить крупные цветовые пятна

Статус: `ready` · P0 · этап `pilot` · `engineering`

Распределение детерминированно и меняется по биому; цветовые пятна не требуют отдельного процесса на клетку

Ветка: `codex/vground-002-visual-task`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-002/`.

Критерии:

- Распределение детерминированно и меняется по биому; цветовые пятна не требуют отдельного процесса на клетку
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vground-003"></a>

## VGROUND-003 — Нарисовать края травы и земли

Статус: `done` · P0 · этап `pilot` · `engineering`

Прямые, выпуклые и вогнутые углы соединяются без ступеней альфа-канала; маски отделены от цвета

Ветка: `codex/vground-003-soft-ground-edges`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результаты: `docs/reports/visual-overhaul/vground-003/`.

Критерии:

- Прямые, выпуклые и вогнутые углы соединяются без ступеней альфа-канала; маски отделены от цвета
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vground-003/README.md, docs/reports/visual-overhaul/vground-003/completion.json, docs/reports/visual-overhaul/vground-003/summary.json, docs/reports/visual-overhaul/vground-003/native/source.json, docs/reports/visual-overhaul/vground-003/review.txt, docs/reports/visual-overhaul/vground-003/compile.txt, docs/reports/visual-overhaul/vground-003/browser-review.json.

<a id="vground-004"></a>

## VGROUND-004 — Убрать капсульную форму дорог

Статус: `done` · P0 · этап `pilot` · `engineering`

Оси путей остаются ортогональными; художественные потёртости края не создают диагональные сокращения маршрута

Ветка: `codex/vground-004-axial-road-shape`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результаты: `docs/reports/visual-overhaul/vground-004/`.

Критерии:

- Оси путей остаются ортогональными; художественные потёртости края не создают диагональные сокращения маршрута
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vground-004/README.md, docs/reports/visual-overhaul/vground-004/completion.json, docs/reports/visual-overhaul/vground-004/summary.json, docs/reports/visual-overhaul/vground-004/native/source.json, docs/reports/visual-overhaul/vground-004/review.txt, docs/reports/visual-overhaul/vground-004/compile.txt, docs/reports/visual-overhaul/vground-004/browser-review.json.

<a id="vground-005"></a>

## VGROUND-005 — Собрать соединения дорожной сети

Статус: `done` · P0 · этап `pilot` · `engineering`

Т-стык, крест, тупик и поворот имеют одну толщину и общие UV; нет двойной тёмной линии

Ветка: `codex/vground-005-road-junctions`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результаты: `docs/reports/visual-overhaul/vground-005/`.

Критерии:

- Т-стык, крест, тупик и поворот имеют одну толщину и общие UV; нет двойной тёмной линии
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: docs/reports/visual-overhaul/vground-005/README.md, docs/reports/visual-overhaul/vground-005/completion.json, docs/reports/visual-overhaul/vground-005/summary.json, docs/reports/visual-overhaul/vground-005/review.txt, docs/reports/visual-overhaul/vground-005/native/source.json, docs/reports/visual-overhaul/vground-005/browser-review.json.

<a id="vground-006"></a>

## VGROUND-006 — Согласовать площадь и грунт

Статус: `ready` · P0 · этап `pilot` · `engineering`

Переход камня в землю имеет обломки и контакт; узор площади не доминирует над героями и лутом

Ветка: `codex/vground-006-visual-task`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-006/`.

Критерии:

- Переход камня в землю имеет обломки и контакт; узор площади не доминирует над героями и лутом
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vground-007"></a>

## VGROUND-007 — Отделить огород от декоративной земли

Статус: `ready` · P0 · этап `pilot` · `engineering`

Новая текстура не меняет разрешённые клетки вспашки; влажное и сухое состояние различимы без большой капли

Ветка: `codex/vground-007-visual-task`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-007/`.

Критерии:

- Новая текстура не меняет разрешённые клетки вспашки; влажное и сухое состояние различимы без большой капли
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vground-008"></a>

## VGROUND-008 — Ограничить процедурный декор

Статус: `ready` · P0 · этап `pilot` · `engineering`

Двери, служебные подходы, грядки, вода и мосты исключены из посева; ручные элементы не перетираются

Ветка: `codex/vground-008-visual-task`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-008/`.

Критерии:

- Двери, служебные подходы, грядки, вода и мосты исключены из посева; ручные элементы не перетираются
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vground-009"></a>

## VGROUND-009 — Ввести локальную ревизию покрытия

Статус: `ready` · P0 · этап `pilot` · `engineering`

Изменение одной грядки или секции обновляет нужный участок, а не текстуры всей карты

Ветка: `codex/vground-009-visual-task`.

Зависимости: VGROUND-001.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-009/`.

Критерии:

- Изменение одной грядки или секции обновляет нужный участок, а не текстуры всей карты
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

<a id="vground-010"></a>

## VGROUND-010 — Принять сезонные переходы земли

Статус: `backlog` · P0 · этап `pilot` · `engineering`

Весна, лето, осень, зима и мокрый вариант проверены на одной геометрии; коллизии и маршруты идентичны

Ветка: `codex/vground-010-visual-task`.

Зависимости: VGROUND-003, VGROUND-005, VGROUND-006, VGROUND-007, VGROUND-008, VGROUND-009.

Исходники:

- [scripts/systems/village_terrain_renderer.gd](../../../../scripts/systems/village_terrain_renderer.gd)
- [scripts/presentation/village_region_terrain.gd](../../../../scripts/presentation/village_region_terrain.gd)
- [scripts/systems/village_map_data.gd](../../../../scripts/systems/village_map_data.gd)

Результат / новые пути (пока не существуют): `docs/reports/visual-overhaul/vground-010/`.

Критерии:

- Весна, лето, осень, зима и мокрый вариант проверены на одной геометрии; коллизии и маршруты идентичны
- Сравнение выполнено при одинаковой камере; подтверждение связано с commit и конфигурацией, не только с зелёным автотестом.

Проверка:

- Проверить прямой край, Т-стык, поворот, тупик, угол и сезон; сравнить проходимость и вспашку с исходным состоянием.
- Перед commit/push выполнить TESTING.md; для runtime дополнительно нативный кадр/видео и профильные тесты.

Риск: Несогласованные масштаб, порядок слоёв или стоимость могут ухудшить соседние объекты; оценивать в игровой сцене.

Откат: Отдельный commit; предыдущий ресурс/профиль сохранить до приёмки, откатить ссылку или выключить флаг эффекта без изменения сохранений.

Оценка: [1, 3] рабочих дней, уверенность low. Рабочая гипотеза на одну карточку; уточнить по пилоту. Не календарное обещание.

Доказательства: пока отсутствуют; задача не выполнена.

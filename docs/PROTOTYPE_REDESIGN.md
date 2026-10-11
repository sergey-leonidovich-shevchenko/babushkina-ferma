# Пересборка игрового прототипа — 0.0.88

Дата: 8 сентября 2026. Работа выполнена локально; публикация в GitHub в этот этап не входит.

## Что изменено

| Проблема | Решение | Проверка |
| --- | --- | --- |
| Нарисованная дорога не соответствовала коллизии | Первая локация собирается из тайлов, зданий и отдельных пропов; `VillageMapData` задаёт дороги, воду, зоны и точки входа | Непрерывные физические маршруты, оба моста, выход из дома, автоматический вход в пещеру |
| Животное меняло рост и превращалось в другой силуэт | Отдельные явные кадры, стабильные опоры и масштаб; новые лиса, летучая мышь и ящерица, отобранные рабочие кадры оленя и кабана | Контактные листы четырёх ракурсов и фаз, проверка источников и поведения |
| Герой копал не в ту сторону | Новый герой с четырьмя ракурсами; 16 нарисованных фаз мотыги, фиксированное направление действия и отдельная опора стоп | `HeroActionSuite`, `HeroVisualSuite`, нативный лист анимации |
| После удара персонаж выглядел застрявшим или попадал в объект | Убрано смещение рисунка героя внутрь препятствий, физическое отбрасывание проверяет коллизии и пересечения с другими актёрами | Регрессии боя, ухода зверей, разъединения тел |
| Резкая дверь и утомляющие короткие мелодии | Оригинальные более длинные темы, мягкий скрип двери, спокойные переходы и ограничение частого переключения боевой музыки | Анализ 33 WAV и сценарии музыкальных переходов |
| Новые PNG дёргали игру при первом показе | Очистка цветной каймы и подготовка кадров выполняются заранее и кешируются | Нативный маршрут с измерением реального времени кадров |

Первая карта теперь состоит из прогулочных петель: двор и ферма → мост → площадь, магазин и гильдия → берег → вторая переправа → сад. Лесная кромка отделена от безопасного двора. Старый цельный мастер остаётся референсом, а не скрытой коллизией под новыми объектами.

## Проверки

- Полный итоговый `./run_tests.sh`: **5710 проверок, 0 ошибок**. Архитектурный gate и аудит 24 семейств мировых ассетов прошли. Это число поведенческих утверждений, не процент покрытия строк GDScript; построчное покрытие не измерено.
- Новый реальный маршрут ввода/физики: **27 проверок, 0 ошибок**, 741 физический кадр — дом, стартовая дорога, оба моста, площадь, обратный путь, пещера, рюкзак и скольжение у стены. Три пользовательских сохранения не изменены.
- Музыка и эффекты: **33 WAV, 201 измерение, 0 ошибок**; отдельные 155 проверок Godot. Действия героя: **69 проверок** ракурсов, таймеров, успешного копания с выключенным звуком и отсутствия побочных игровых изменений.
- Итоговый нативный контроль: **по 1400 кадров только деревни**, normal и F10 последовательно, те же seed, маршрут и полноэкранное окно 3584×2240. Normal: среднее **16,672 мс (около 60 FPS)**, p95 18,284 мс, максимум 36,009 мс. F10: среднее **30,858 мс (около 32,4 FPS)**, p95 51,091 мс. Маршруты пройдены, сохранения не изменены. F10 ускорен, но не доведён до плавных 60 FPS: это открытый `TD-PERF-007`, не закрытый пункт.
- Первые пробы обнаружили остановку 1,224 с: миникарта строилась внутри рисования после вступления. Подготовка перенесена до управления. Дополнительно введены ограниченный кеш метрик шрифтов, один debug-пакет на render-кадр, отсутствие проверок движения в покое и пространственный индекс постоянных коллизий. Около 3000 точек восьми локаций совпадают с исходным точным обходом; средняя стоимость отдельной навигационной пробы уменьшилась примерно вдвое.
- Пересняты настоящие окна рюкзака, дерева способностей и контекстного HUD; физические HUD-эталоны и общий manifest обновлены. Не заявляется повторная нативная съёмка каждого старого экрана на всех устройствах.

Точные метрики, условия и все выбросы — в [PERFORMANCE.md](../PERFORMANCE.md), исходные и промежуточные JSON сохранены отдельно. F10 остаётся первым пунктом производительного техдолга. Прогретый второй запуск сам по себе не считается исправлением; финальные пробы выполнялись без временных таймеров в игровых модулях.

## Границы этого этапа

Это ещё прототип, а не законченная игра. Старые NPC и напарники сохраняют свои восьминаправленные наборы; не все враги и старые локации перерисованы. Новый герой пока один для всех уровней: четыре прежних несовместимых возрастных скина отключены, характеристики и уровни не убраны. Полная нарисованная анимация тела сделана для ходьбы и мотыги; остальные инструменты используют направленные преобразования отдельных спрайтов. Это не четыре новых полноценных атласа боя.

Источники вдохновения — настроение ремесленной деревни и понятные бытовые занятия, а не копирование карт, персонажей или музыки: [Stardew Valley](https://www.stardewvalley.net/), [Graveyard Keeper](https://www.graveyardkeeper.com/home).

## Материалы и воспроизведение

- [Детали музыки и звуков](AUDIO_REDESIGN.md).
- [Животные, физика и их новые ассеты](WILDLIFE_COMFORT.md).
- [Художественные правила, четыре направления и опоры](ART_GUIDE.md).
- [Физический проверочный маршрут](reports/runtime_comfort_review.json).
- [Реальный рендер новых поз героя](../assets/generated/level_drafts/hero_four_direction_review.png).
- [Новая карта: двор](../assets/generated/level_drafts/village_modular_home.png).
- [Новая карта: площадь](../assets/generated/level_drafts/village_modular_plaza.png).

Запуск тестов: `./run_tests.sh`. Дополнительные проверки: `./tools/check_architecture.sh`. Нативные проверки запускаются по очереди, без параллельного Godot, чтобы не искажать время кадров.

## Генерация героя

Режим: встроенная генерация изображений (skill `imagegen`), затем проверка фактического RGBA и нативного вывода Godot. Рисование и изменения изображений выполнены встроенным генератором. Из нерегулярных мастеров игра берёт явно описанные целочисленные области; общего деления на четыре недостаточно. Ни один кадр не растягивается под индивидуальный силуэт.

Подключённые финальные файлы:

- `assets/game/characters/hero_v3/walk_master.png` — 1254×1254, RGBA, четыре ракурса × четыре фазы.
- `assets/game/characters/hero_v3/hoe_master.png` — 1281×1228, RGBA, четыре ракурса × четыре фазы.

Ниже сохранён полный набор промптов, включая корректировки прозрачности и неверно ориентированной мотыги. Не все промежуточные результаты использованы в игре.

### hero_v3_walk_prompt

```text
Use case: stylized-concept. Asset type: production-ready pixel-art player character sprite sheet for a cozy, slightly mysterious farming RPG. Image 1 is a character identity and palette reference only, NOT the layout. Redesign her into a more grounded, readable village farmer-adventurer: young adult woman, warm brown hair in a compact bun with blue ribbon, indigo scarf, practical blue tunic over cream sleeves, small tan work apron, dark trousers, sturdy brown boots, leather belt. Charming face but smaller eyes/head than the reference, roughly 3 heads tall. Rich hand-pixelled 32-bit-era RPG look, crisp controlled pixel clusters, earthy restrained colors, dark brown/blue outline, no magenta fringes. EXACT square sprite sheet containing 4 columns by 4 rows, sixteen separate full-body poses on truly transparent alpha. Every cell is the same size and every figure has the exact SAME scale, fixed feet baseline and centered ground pivot. Row 1: front view facing DOWN toward viewer. Row 2: true side view facing LEFT. Row 3: true side view facing RIGHT. Row 4: back view facing UP away from viewer, no face visible. In each row the four columns are a loopable walk cycle: left-foot contact, passing neutral, right-foot contact, passing neutral; clearly changing leg and opposing arm poses, tiny vertical movement only, consistent body anatomy and height. EMPTY HANDS, no weapons, no tools. Full figures with ample transparent padding inside each cell, none crossing a cell boundary. No floor/shadows, no background, no cell borders, no labels, no text, no extra sprites. Uniform overhead-left lighting. Important: exactly FOUR rows, not eight, and four columns; never mix viewing directions in one row.
```

### hero_walk_alpha_prompt

```text
Use case: background-extraction. Image 1 is the exact edit target. Remove the entire white-and-grey checkerboard background from this sprite sheet and replace it with genuinely TRANSPARENT ALPHA pixels, not a drawn checkerboard. Preserve all sixteen character poses pixel-for-pixel as much as possible: same four rows, four columns, locations, scale, silhouettes, palette, crisp pixel-art edges. No new content. No opaque background anywhere. Export a PNG with actual transparency around and between sprites, not RGB. Do not change the characters or their arrangement.
```

### hero_hoe_prompt

```text
Use case: stylized-concept. Asset type: four-direction farming action animation sprite sheet, production game asset. Image 1 is the EXACT character identity reference: retain this same adult brown-haired woman with bun and blue ribbon, indigo scarf, practical blue tunic and cream sleeves, tan work apron, dark trousers and brown boots. Create exactly FOUR rows by FOUR columns, sixteen full-body sprites. Truly TRANSPARENT ALPHA background; no checkerboard painted into image, no solid background, no colored fringe. Same rich crisp pixel-art style and EXACT same body proportions and scale as reference in all cells. Each row is one sequence of USING A HOE. ROW1 faces DOWN toward viewer. ROW2 faces LEFT, true side. ROW3 faces RIGHT, true side. ROW4 faces UP away from viewer with back visible. COL1: two hands holding wooden farming hoe forward, ready. COL2: hands raise hoe overhead with clearly bent elbows, anticipation. COL3: torso bends at waist and both hands bring hoe down, metal blade strikes soil in front of boots in that direction. COL4: recovering upright, bringing hoe back to ready. Hoe is a long slim wooden handle with a small steel farming blade perpendicular to shaft (not a shovel, not a scythe). Both hands grip the same handle naturally. Legs planted; SAME feet/ground pivot in all frames, body bends not scales. Feet never float. Tool stays in the appropriate direction; for up-facing row tool is correctly behind the body except raised head visible overhead. Generous padding around every figure including raised tool; all poses entirely contained in their own equal cells, no overlap. Consistent overhead-left lighting, dark warm outline, no neon edges. No ground patch, no dirt cloud, no UI, no shadows, no captions, no labels, no gridlines, no border, no watermark.
```

### hero_hoe_final_prompt

```text
Use case: precise-object-edit and background-extraction. Image 1 is the edit target. Keep the existing sixteen sprites, four rows, four columns, character identity, body scale, style and positions. Fix ONLY the bottom row third column: this is the farmer hoeing while FACING UP, away from viewer. Show her back, bent slightly FORWARD AWAY from viewer, not toward the viewer. Her hands and hoe handle are on the FAR side of her body and partially occluded by her torso. The hoe's steel blade strikes ground NORTH of her boots, visually ABOVE the boot baseline, never below or toward the viewer. Remove the current wrong diagonally-downward pointing hoe in that cell. All other fifteen poses must stay unchanged. ALSO remove every white/grey checkerboard background pixel across the entire sheet and replace with genuinely transparent ALPHA, not a painted checkerboard. Preserve crisp warm dark pixel outlines. No red, magenta, green or yellow extraction fringe, no captions, no grid, no opaque backdrop. Deliver transparent RGBA PNG with all sixteen figures isolated.
```

### hero_hoe_alpha_prompt

```text
Use case: background-extraction. Image 1 is the exact edit target. Remove ALL white-and-grey checkerboard background around and between these sixteen pixel-art farmer poses, replacing it with genuinely transparent alpha pixels. This is only background removal. Keep all sixteen farmer+hoe sprites unchanged, their original positions, scale, pixel outlines and every pose. Do not draw a new checkerboard. Output RGBA PNG with real transparency, not RGB. No colored matte fringe, no backdrop, no shadows, no text or new elements.
```

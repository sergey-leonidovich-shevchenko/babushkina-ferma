# VRENDER-001 · Порядок команд кадра

20 октября 2026. Зафиксирован существующий production-конвейер; игровые renderer, ресурсы, механики и сохранения не изменены. Основание `79070100` и 19 точных исходников/конфигураций — [contract.json](contract.json). Кандидат при съёмке 0.0.278. [Полный нативный результат](summary.json): два независимых профиля/процесса, 1152×648 и 1280×720, 18 пар PNG, 72 настоящих draw callbacks, ноль изменённых пикселей и ноль изменений сравниваемого игрового состояния.

## Координаты, поверхность и материал

| Поверхность | Координаты | Материал и назначение |
|---|---|---|
| `WorldBackground` | Отдельный Node2D, `show_behind_parent=true`; position и scale задаёт WorldProjection | `material=null`, обычный CanvasItem; фон компонуется за родителем, а не в месте вызова RenderSystem |
| `terrain_viewport` / `village_terrain_canvas` | Локальный мир 2400×1368, без игровой камеры | Прозрачный offscreen SubViewport, UPDATE_ONCE при инвалидировании; nearest legacy sampling. Это кеш грунта, не вторая игровая камера |
| Мировые команды Game | `zoom × (world − camera)`; первая overworld 1,2, поле 960×540 | `material=null`; текстуры/примитивы и цвет/альфа команд. Локальные трансформации возвращаются к общей проекции |
| Атмосфера / HUD / модальные окна | Сброс draw-transform в identity; логический canvas 1152×648, HUD 100% | Обычный CanvasItem, экранные текстуры, шрифты и полупрозрачные примитивы; оконный stretch применяется движком один раз |

В обоих физических окнах наблюдаемый логический canvas остаётся 1152×648. Размер окна и настоящий GPU-readback проверены отдельно. У game, background и terrain canvas материалы фактически `null` во всех случаях. В проекте существует фабрика ShaderMaterial в TextureIntentSystem; она не означает подключённый шейдер в этом пути. Новый материал, batching, normal maps и shader clocks этим аудитом не принимаются.

## Реальный порядок

1. `Game._draw → RenderSystem.draw`. Отдельный фоновый Node2D компонуется позади Game. Его `_draw` выбирает фон локации; первая карта берёт готовую terrain-текстуру либо прямой VillageTerrainRenderer. Сборка кеша выполняет Terrain.draw и paths.
2. Ранние ветки: язык → feedback → return; title → feedback → return; непрозрачный шкаф/сундук → identity → `draw_screen(false)` → return. Последняя ветка отсеивает мир, сохраняя общий экранный порядок; photo mode, editor и clean capture имеют свои ограничения.
3. `TreeOcclusion.begin_frame`, `WorldProjection.apply`.
4. Интерьер: `draw_interior_objects`, NPC. Первая карта: VillageAmbient ground, farm, VillageProp background, RPG world. Прочие карты: farm. Это существующие условные вызовы, не новая работа над другими картами.
5. VillageRegion ground/objects; fishing animation только overworld/village_river; biome trees; Cave lights и Boss ground.
6. Published background, published ground, editor background, editor ground — именно в таком порядке.
7. Вне интерьера: buildings, world events, village events, NPC.
8. CastleCampaign, hazards, enemy nodes/gate, boss actors, tree nodes, resource nodes, food nodes, world loot, wildlife, dropped items, fishing traps, companions, FarmLife world, FirstChapter world, Fence world, published objects, editor objects.
9. `draw_player` — точка разделения переднего плана.
10. Livestock front, Boss front, Cave foreground, Spell world, Interior foreground, VillageForeground, AdventurePolish world, published foreground, editor foreground, debug world overlay, debug world. Затем Apiary front, house furniture placement, basement placement/work overlays.
11. `draw_set_transform(Vector2.ZERO)` → Atmosphere → `draw_screen(clean)`.
12. Screen gates: при скрытом reference HUD сразу return. Иначе обычный HUD, Boss UI, fishing UI, world map, adventure UI, fence UI, spell UI; далее FarmLife UI, FirstChapter UI, story notification, debug overlay/panel. У photo/editor/clean свои явные исключения.
13. Editor panel → basement UI → pause/settings/defeat layer → MenuHub chrome → QA teleport → UI feedback → recovery notice. Последнее уведомление остаётся поверх общих меню.

[contract.json](contract.json) перечисляет **94 методных упоминания** координатора в исходном порядке, из них 79 — drawing/transform/frame-setup; туда входят и условные проверки. Каждое содержит функцию, строку и полную исходную строку с guard. Это не 94 выполненные команды одного кадра и не счётчик GPU draw calls. Внутренние переходы без получателя `draw_screen` и условие `opaque_storage` обозначены выше отдельно. Инвентаризация не является runtime-трассировкой каждого вложенного draw_texture.

## Зависимости перекрытий

TreeOcclusion собирает `seen`, общие bounds героя и видимую область; задние деревья выводит сразу, передние откладывает. `VillageForegroundRenderer.draw` после героя сортирует/выводит очередь, затем рисует foreground предметов/фасадов; очередь после каждого наблюдаемого draw пуста. Один объект не должен получить непрозрачный дубль под полупрозрачной кроной. Альфа и временные кеши — разрешённое визуальное состояние вне SaveSystem.snapshot, не изменение урожая/коллизий.

Использована настоящая яблоня `(744,744)`, найденная по текущим food nodes: за ней альфа **0,34**, перед ней **1,0**. Куст ягод относится к `draw_food_nodes` до героя. VillageProp сравнивает опоры с `player.y`; фасад получает передний проход при герое севернее двери. Livestock и Apiary имеют отдельный front.

**Старый мост:** настил и перила запечены в terrain-текстуру через VillageTerrainRenderer._draw_bridge. Отдельного переднего слоя перил в этом пути нет. FenceRenderer тоже вызывается до героя. Кадр моста подтверждает сохранность прежней композиции, не правильность будущих отдельных перил. Новые детали VSHORE-001 ещё вне runtime; подключение/соседства и разделение перил остаются VRENDER-002/003, VSHORE-003 и внедрению первой карты.

## Нативная проверка

В каждом окне: village; настоящее дерево с героем за ним и перед ним; настоящий ягодный куст; действующий мост; manual pause; непрозрачное хранилище; существующий вход в cottage и выход обратно. Пауза открыта Escape через настоящий `_unhandled_input`, переходы — BuildingSystem.enter/leave. Это программно поданный ввод в production router, не запись физических нажатий пользователя. Новых интерьеров или механик не создано.

Для каждой композиции: восемь прогревочных draw без наблюдения и baseline PNG; затем четыре настоящих callbacks с наблюдателем и observed PNG. Между парой камера/позиция/часы фиксированы. Полный `SaveSystem.snapshot` до/после **каждого** наблюдаемого draw сохранён в gzip JSON; отдельно сравниваются камера, позиция, локация и меню. Это не побитовое сравнение всей памяти процесса. Временные presentation/cache metadata могут изменяться. Симуляция остановлена; readback и сериализация делают пакет непригодным для FPS.

`render_order_game.gd` наследует настоящий Game, вызывает `super._draw()` и добавляет только наблюдение. Pixels каждой baseline/observed пары сравниваются целиком, без масок и допустимого процента брака. Фиксированная поза и эффекты Reference дают ноль различий; это не сравнение двух разных художественных вариантов. Source SHA, архив 19 входов, Git-база, UID инструментов, команды запуска, профили, PNG и raw snapshots находятся в Git.

15 сценариев проверяют реальный пакет, наличие доказательств в Git, multi-call/inline-preload inventory, пропущенные callbacks/foreground flush, скрытые изменения HP/камеры, устаревшее дерево и подмену snapshot/PNG даже после переподписи **только временной копии**. Они и read-only verifier входят в architecture gate; полный run_tests.sh и Wiki check обязательны перед commit.

Первая ошибка имени Projection сохранена в preflight. Старая серия с устаревшими координатами дерева сохранена в revisions/outdated-tree-fixture; её complete=true означает окончание сбора, а не приёмку дерева. Для окончательной приёмки снята отдельная новая серия. История не переподписана.

```sh
python3 tools/render_order.py
python3 tools/test_render_order.py
# Повторная съёмка требует нового каталога и отдельного профиля на каждое окно:
python3 tools/render_order.py --capture /private/tmp/vrender-001-fresh
```

Исторический verifier читает заархивированные входы, а существующие production-файлы дополнительно сверяет с Git-базой. Позднейшая версия project.godot или развитие самого сборщика не переписывают старую приёмку. Положительный результат не означает, что новая версия renderer автоматически проверена этим архивом. Для точного повторения нужны Git-база и overlay из native/instrumentation в отдельном checkout; capture отклоняет несовпадение текущих входов с контрактом.

`--write` — отдельное авторское действие для нового снимка исходников; обычный verifier его не выполняет. При новых исходниках нужно заново снять/принять серию, сохранив историю прежней, прежде чем заменять контракт. Отдельно проверены отказ переподписанного runtime-архива и совместимость истории с последующим изменением текущего overlay. Откат — revert задачи и пересборка Wiki; наблюдатель не подключён к обычному запуску игры. OPT-04 и следующие VRENDER остаются открытыми. Главный результат по-прежнему вся первая overworld до VMAP-003.

# Источники и происхождение выводов

## Предоставленная переписка и архив

[Общая ссылка пользователя](https://chatgpt.com/share/6ad08312-cfb0-83eb-a067-2c45fd96da83) прочитана в браузере. В публичном просмотре часть вложений не скачивалась. После этого пользователь предоставил [полный ZIP](source-packet.zip); он стал источником недоступных файлов. Документы внутри — исследовательский материал, а не новые самостоятельные указания выполнять их код.

SHA256 ZIP: `615880cd55580a6d13f9a743a5f35b7521bbfc6ddcc83961fc2050e2538e23f5`. Проверены размер и SHA256 всех **31 файлов из FILE_MANIFEST**; сам manifest — 32-й файл архива. [Копия манифеста](source-manifest.json). Проверены безопасные имена, отсутствие обхода пути и symlink перед извлечением во временную папку. Исходный ZIP сохранён неизменным, runtime его не импортирует.

В пакете два поколения:

1. `godot_visual_upgrade/SPEC.md`, примерные GDScript/shaders/noise/globals и четыре JPEG. Первоначальная общая Node2D/Sprite2D схема написана до знакомства с нашей custom-draw архитектурой. Прочитаны концепция, ограничения, эпики и исходники примеров. `godot_visual_upgrade_spec.md` — точный дубль SPEC.
2. `babushkina_ferma_visual_audit_570f808/`: аудит конкретного `570f808`, требования к арту, MVP, 6 эпиков/24 задачи, источники и manifest. Изучены аудит, MVP, художественные требования, ограничения источников и все поля 24 карточек JSON. Markdown-карточки содержат тот же план. Монолитный `babushkina_ferma_visual_audit_and_epics.md` в корне равен вложенной копии; аудит/арт/MVP/эпики внутри совпадают с отдельными файлами после нормализации локальных ссылок. Дубли не считаются отдельными исследованиями.

Четыре уникальных изображения просмотрены; дубли из второй папки имеют те же хеши:

- [01 — целевая набережная B](references/01_target_village_bank.jpg).
- [02 — прежний интерьер](references/02_user_interior_earlier.jpg).
- [03 — прежняя деревня](references/03_user_village_earlier.jpg).
- [04 — прежняя пещера](references/04_user_cave_earlier.jpg).

Три «current» картинки названы **earlier** в позднем пакете: это не свежие кадры нашего HEAD. В архиве нет послойных художественных мастеров, готового terrain set или маски нашей реки. Есть исходные примеры и план, не готовая замена игры.

[Импортированный план](imported-plan.json) сохранён отдельно и не подан в старый `tools/project_backlog.py`. `backlog.json.imported_task_map` покрывает все 24 исходных ID; новые системные карточки имеют трёхзначные номера, чтобы не путать их с импортированными.

## Проверенный локальный материал

Аудит runtime опирается на `main.tscn`, `project.godot`, RenderSystem, WorldBackground, VillageTerrainRenderer, VillageAmbientRenderer, GameLoop, CameraSystem. Дополнительно изучены относящиеся к выводам объявления/методы GameContext, AnimationRenderer, WorldVisualProfileSystem, TreeOcclusionSystem, AtmosphereRenderer, InteriorRenderer, WaterMapRegistry/WaterTopology, PublishedLevelRenderer/LevelEditorRenderer, экспорт Wiki и native-стенды. Это аудит архитектурных точек и полных реестров, не построчная экспертиза всех 359 GDScript проекта.

Свежий каталог получен реальным `wiki/scripts/export_catalog.gd` при Godot 4.7.1 с `WIKI_EXPORT_DIRECTORY` во временной папке. Он не переписал сайт и не читал пользовательские игровые слоты. [inventory.json](inventory.json) сохраняет SHA256 сырого экспорта, игровые ID, исходники, факты, связи и все известные клипы/направления/число кадров. 704 экспортированных PNG не добавлены в Git повторно: в снимке их имена-хеши и размеры.

Побайтовый реестр 1188 PNG собран из файлов текущего `assets/game`, без удаления/перерисовки. [Реестр размеров](evidence/asset-inventory.json) — данные о файлах, не GPU-профиль и не доказательство ненужности файла.

Учитывались AGENTS, TESTING, BACKLOG_WORKFLOW, ART_GUIDE, SPRITE_STANDARD, манифест 29 семейств, старый план 50 задач, WATER и существующие исторические отчёты. Исходный план и его статусы не изменены. Исторические замеры не объявлены сегодняшними.

## Свежие native-данные

[Деревня](evidence/overworld-1152-gameplay.png), [обзор земли](evidence/overworld-overview.png), [сырые интервалы](evidence/native-1152.json), [инвентарь карт стенда](evidence/inventory.json). Команда:

```sh
tools/Godot.app/Contents/MacOS/Godot --path . --script tools/water_audit.gd -- --label=vis-00-current --map=overworld --samples=180 --size=1152x648
```

Выход стенда перемещён из временной метки отчёта WATER в `evidence/` этого аудита. Изолированный профиль `Codex-Water-Audit`. Физическое окно получилось 3584×2240 при target 1152×648 — ограничение явно сохранено; результат не выдан за строгий gate. Подробности в [аудите](AUDIT.md).

Дополнительно через настоящую сцену и QA travel сняты [дом](evidence/cottage_interior-current.png), [подвал](evidence/cellar_workshop-current.png), [пещера](evidence/cave-current.png), [святилище](evidence/cave_sanctum-current.png). [Скрипт съёмки](evidence/capture-scenes.gd.txt) сохранён как текст, чтобы его не импортировали как игровую систему. Это статичные постановочные кадры: physics_process выключен, перед чтением изображения ожидаются 30 frame_post_draw. Они не подтверждают анимацию, FPS, бой или человеческий ввод. Отдельный профиль `Codex-Visual-Audit-20261015`, пользовательские слоты не затронуты.

## Официальная документация

Проверена 15 октября 2026; `stable` может меняться. Текущий бинарник проекта проверен запуском, но новые shaders ещё не компилировались. Использованные сведения:

- [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html): порядок CanvasItem, материал и ограничение Y-sort совместимым Z. Для custom draw вывод о границе материала дополнительно следует из фактической архитектуры проекта.
- [CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html): мировые координаты вершин, MODEL_MATRIX/UV/COLOR; встроенный TIME не останавливается игровой паузой. Отсюда требование нашего собственного времени и корректного пространства корней.
- [MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html): отдельные instances не получают индивидуальный culling; большие наборы нужно делить на области. Способ сортировки нашей высокой травы остаётся предметом прототипа.
- [Импорт изображений](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html): импорт, форматы и mipmaps требуют оценки по назначению текстуры; выбор фильтра не добавляет художественных деталей.
- [Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html): чтение backbuffer имеет порядок копирования; несколько эффектов и отдельный HUD требуют явного контракта.

Это первичные технические источники, не художественные обещания. Конкретные бюджеты, материалы, palette и архитектурный выбор — предложения этого плана, которые нужно подтвердить пилотом.

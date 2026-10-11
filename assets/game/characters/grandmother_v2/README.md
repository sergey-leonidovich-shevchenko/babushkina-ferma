# Бабушка: исправленный цикл ходьбы, 0.0.90

Рабочий мастер: `walk_master.png`. Создан встроенной генерацией изображений, навык **imagegen**, с прежней бабушкой как референсом внешности. Исходник имеет служебный зелёный фон. Runtime `GrandmotherVisualSystem.texture()` один раз создаёт RGBA с прозрачностью, убирая также замкнутые зелёные точки и кант. Файл не обрабатывается на каждом кадре; общие правила matte остальных изображений не менялись.

В мастере четыре ряда: вниз, влево, вправо, вверх; по четыре нарисованные фазы. Движение по диагоналям сохраняется и использует соответствующий боковой ракурс. Вместо полосового смещения подола нарисованы цельные позы. Для каждого источника заданы целочисленный crop с запасом, горизонтальная опора корпуса и общая линия стоп ряда. Масштаб 0,30 одинаков по осям и фазам; сохранена прежняя мировая опора NPC `position + (0,24)`.

Старый `directional/npc_grandmother_walk_8dir.png` сохранён для совместимости редакторских документов и сравнения, но текущий архетип бабушки его больше не рисует. Оба каталожных пути сохраняют уникальность `npc:grandmother`. Остальные жители и напарники не перерисованы этим исправлением.

Проверка: `GrandmotherVisualSuite`, редакторские регрессии, нативный `tools/grandmother_animation_review.gd`; снимки и контактный лист в `assets/generated/level_drafts/`. Сильный перекос был в пикселях старого атласа, а не в повороте runtime: движущийся NPC уже рисовался без rotation и scale.

## Визуальная проверка

Сняты 16 фаз в настоящей игровой сцене при 1152×648 и отдельный лист сравнения старого и нового шага. Проверены цельный подол, неизменный масштаб, опора стоп и отсутствие служебного зелёного канта. Контрольные суммы трёх пользовательских сохранений до и после совпали.

- [Сравнение направлений и фаз](../../../generated/level_drafts/grandmother_review_contact_sheet.png).
- [Бабушка при ходьбе влево в игре](../../../generated/level_drafts/grandmother_review_ingame_left_0.png).

Портрет диалога использует ту же подготовленную RGBA-текстуру и вписывает прямоугольный кадр с сохранением пропорций. Инспектор F10 получает текущие границы из того же описания позы.

Итог 9 сентября 2026: полный `./run_tests.sh` — **6049 успешных утверждений, 0 ошибок**, без ошибок компиляции или выполнения; `tools/check_architecture.sh` пройден. Изолированно: 221 проверка нового визуального профиля и 35 проверок редакторских источников. Это поведенческие проверки, а не измерение line coverage.

## Промпт перерисовки

Use case: identity-preserve. Asset type: production 2D pixel-art NPC walk-cycle sprite sheet for an existing top-down farming RPG. Image 1 is the identity, outfit, palette and pixel-art style reference, NOT a layout to copy. Correct the broken sheared dress animation. Redraw the SAME kindly elderly grandmother: grey hair in high bun, soft elderly face, plum-purple long dress, red neckerchief with brass brooch, cream embroidered apron, brown ankle shoes. Make one square transparent RGBA sheet arranged as an exact regular 4-column x 4-row grid, 16 completely separate full-body sprites, no text or grid lines. Each cell has generous equal transparent padding, character horizontally centered with feet on the same baseline at about 90% of cell height. Fixed camera, scale and body proportions in EVERY frame. ROW 1: facing screen DOWN/front, all four frames. ROW 2: facing screen LEFT in profile, all four frames. ROW 3: facing screen RIGHT in profile, all four frames. ROW 4: facing screen UP/back, all four frames. Each row is a clean four-phase gentle walking loop: left foot forward, feet passing below body, right foot forward, feet passing below body. Feet take short believable elderly steps, hands naturally alternate gently, shoulders upright and level, minimal vertical bob. Head and torso remain centered, no sideways lean, no scaling between poses. Dress and apron are intact continuous cloth, subtle natural folds; NO horizontal sliced/sheared band at the hem, NO trailing carpet or strip sticking sideways, no dislocated limbs. The hem stays a compact bell shape centered under the hips; the legs move underneath it. Rich detailed crisp pixel clusters matching the reference, dark warm outlines, not blurry painting and not vector. True transparent background, no floor, no baked shadow, no props, no glow, no magenta fringe, no lettering. All four side-view frames must show the same true profile and the same height. Preserve the grandmother's recognizable original appearance. Output only this usable 4x4 animation sheet.

## Промпт служебного фона

Первая попытка прозрачности вернула нарисованную шахматку без alpha и не используется в игре. Выбран отдельный маттированный мастер; реальные игровые кадры подтверждают прозрачность после подготовки текстуры.

Use case: precise-object-edit. EDIT TARGET image 1. REPLACE ALL GRAY AND WHITE CHECKERBOARD BACKGROUND WITH ONE FLAT VIVID GREEN COLOR #00FF00. This is a chroma-key sprite sheet. The resulting image must have a SOLID LIME GREEN BACKGROUND, NOT a checkerboard, NOT white, NOT gray, NOT transparency visualization. Every empty pixel around every grandmother should be green. Preserve all 16 grandmother characters in their current exact positions and poses: gray hair, cream aprons, purple dresses, red scarves and brown shoes unchanged. Keep their soft dark outline and fine pixel-art details. Do not recolor hair or aprons. Change ONLY background pixels outside silhouettes. No extra shadows, lines, text or effects. Output the same square 4x4 sheet on pure bright green.

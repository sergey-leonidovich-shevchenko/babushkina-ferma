# Животные: читаемая анимация и безопасная охота

## Найденные причины

- Старый код проигрывал столбцы 1, 2, 3, хотя у оленя третий столбец содержал вдвое меньшую позу. Hurt также использовал маленький столбец 4.
- Лиса меняла не только размер, но и анатомию: в одном цикле были двуногие и четвероногие рисунки. Мышь содержала отрезанные фрагменты соседних строк.
- Паника повторно срабатывала каждый кадр, игнорируя место обитания. Полёт полностью обходил проверку земли, делая цель недоступной пешему герою.
- Враги проверяли неполный список препятствий и не учитывали тело героя. Пересечение, однажды возникшее из старого сохранения или движения врага, блокировало даже выход из него.

## Новый контракт

- Четыре визуальные стороны, движение по-прежнему свободное во всех направлениях.
- `WildlifeVisualSystem` выбирает согласованные кадры. Один коэффициент пикселей на вид, а не растяжение каждого кадра до рамки. Лапы привязаны к мировой позиции. Hurt использует правильную базовую позу с кратким оттенком.
- Новые лиса, ящерица и летучая мышь имеют четыре направления и четыре кадра. Олень использует пригодные три фазы старого арта. Кабан — два стабильных кадра; четыре полноценных кадра остаются небольшим арт-долгом.
- Рывок бегства длится 1,05 секунды, за ним 1,6 секунды восстановления. Место обитания ограничено радиусом 320 px. И наземные звери, и проекция мыши проходят проверку земли шагами до 6 px.
- Игрок может уменьшать существующее наложение на врага, но не входить глубже и не проходить сквозь камни. Вражеское отбрасывание также разбито на шаги и уважает тело героя.
- Старые сохранения сохраняют hp/alive и добычу; миграция деревни меняет только старые места обитания.

## Растровые исходники

В конструкторе неровные листы имеют явные `source_rect`: они не режутся по 128 px. Сырые новые звериные мастера исключены из декоративной кисти; существующих живых зверей можно разбирать через импорт текущей локации. Нового героя каталог предлагает единственным шаблоном SPAWN: размер 96×96, реальная обрезка, защита от дублей и от случайного превращения в декорацию. Для нового произвольного спауна животных нужен отдельный этап сущностей конструктора, а не рисунок зверя поверх карты.

Навык imagegen, встроенный режим (не API/CLI). Оригиналы не перезаписывались. Рабочие PNG:

- `assets/game/wildlife/directional/fox_walk_4dir_v2.png`
- `assets/game/wildlife/directional/bat_flight_4dir_v2.png`
- `assets/game/wildlife/directional/lizard_walk_4dir_v2.png`

Насыщенный внешний служебный matte генератора удаляет только явный opt-in `SpriteMatteSystem.clean_texture()`. Кэш одноразовый; исходные PNG, внутренние красные детали и оранжевый мех сохраняются.

## Дополнительная перерисовка ящерицы

Старый атлас содержал переднюю мордочку даже в направлении вверх. Новый набор имеет настоящий задний вид без видимых глаз.

```text
Use case: stylized-concept. Asset type: production transparent game character animation sprite sheet. Exactly four rows by four columns, 16 full-body sprites of the same little GREEN WOODLAND LIZARD: quadruped gecko-like animal, small yellow eyes, green scales, tiny golden leaflike spines along its back, a curled leafy tail. Detailed charming handmade pixel art for a cozy overhead farming RPG. Four columns show four subtle consecutive walking poses; body length, head size and tail size identical throughout, paws change placement. Each row is ONE direction. Row1 DOWN: face and eyes facing viewer, tail extending behind. Row2 LEFT: full side view with nose pointing left, tail right. Row3 UP: genuine rear view walking AWAY from the viewer, back of head visible, NO FACE AND NO EYES VISIBLE, hindquarters and leafy tail toward the viewer. Row4 RIGHT: nose pointing right, tail left. Consistent 3/4 overhead orthographic camera, same lighting and detail density. Keep ALL sprites within their equally sized grid cells with generous transparent padding, no clipping, no overlap. Genuinely transparent RGBA alpha background, no floor, no shadows, no checkerboard, no red or magenta matte, no colored fringe, no labels or text. Natural dark olive outline. Small consistent leg movements only, no morphing or zooming.
```

## Промпты генерации и точечных исправлений

### 1

```text
Use case: stylized-concept. Asset type: production transparent sprite sheet for a cozy top-down farming RPG. Draw a RED FOX quadruped, realistic animal anatomy but charming detailed pixel-art, warm rust orange fur, white muzzle/chest and tail tip, dark paws, no clothing. Exactly 4 columns and 4 rows in an evenly spaced square grid, no drawn grid. 16 separate complete fox sprites. Each row is one walk cycle with the SAME fox anatomy, body proportions, size and orthographic 3/4-overhead camera. Row 1: fox walking DOWN toward viewer, nose points bottom. Row 2: fox walking LEFT, nose points left. Row 3: fox walking UP away from viewer, rump toward viewer and nose hidden. Row 4: fox walking RIGHT, nose points right. Four columns show small consecutive paw movements of a natural four-legged walking cycle; body stays at identical height, length and scale in every column. Full tail and all paws visible, never standing on hind legs. Every cell has generous clear padding, sprites never touch neighboring cells. Uniform lighting upper left, natural dark warm outline, crisp hand-painted pixel clusters and fine fur detail, no magenta fringe. Genuinely transparent alpha background, no shadows, no floor, no text, no labels, no border, no watermark. All 16 foxes use exactly the same pixel density and camera distance.
```

### 2

```text
Use case: precise-object-edit. Image 1 is the edit target. Keep exactly these 16 quadruped red foxes, their poses, size, arrangement, fur detail and colors. Remove the unnatural bright pure-red/neon scarlet fringe and chunks around the outside of every fox, including around tails, ears and paws. All exterior pixels must be genuinely transparent with clean natural dark brown fur edges; no chroma-key colored fringe, no glow, no colored outline. Preserve legitimate orange/red fur on the fox bodies. Do not change pose or direction, do not add or remove foxes, do not add background, do not shift the layout. The result is the same clean 4x4 animation sheet on genuine transparent alpha.
```

### 3

```text
Use case: background-extraction. Image 1 is the edit target. Remove the entire white and grey checkerboard background from this 16-frame fox sprite sheet. Deliver a PNG with real transparent alpha; every background area must have alpha zero, NOT a drawn checkerboard and NOT a solid color. Preserve all 16 foxes in their exact current positions, size, pose, warm orange fur, dark outline and full tails. Clean alpha cutout only; no recoloring or colored fringe. No new image elements. Transparent background means actual RGBA alpha transparency, the gray/white squares must disappear completely.
```

### 4

```text
Use case: stylized-concept. Asset type: transparent production sprite sheet for a cozy top-down farming RPG. Exactly 4 columns by 4 rows of a charming little grey-brown BAT, sixteen complete full-body sprites, fine detailed pixel art. Four columns are a coherent wing flap cycle: wings raised, wings horizontal, wings down, wings horizontal again. Keep identical body and head size in every frame, no perspective zoom. Row1 faces DOWN toward viewer; row2 faces LEFT; row3 faces UP away from viewer; row4 faces RIGHT. Orthographic 3/4 overhead RPG view for all rows, not dramatic perspective. Soft grey fur, brown leathery bat wings, large ears, two tiny feet; black charcoal outline. Every sprite must be wholly inside its own equal grid cell with at least 15% transparent padding, even the widest wing pose. Do not crop wing tips, ears or feet. No disconnected body fragments, no frame can overlap its neighbor. Genuinely transparent alpha background, no colored matte, no red or magenta fringe, no checkerboard, no floor, no text, no labels, no grid lines.
```

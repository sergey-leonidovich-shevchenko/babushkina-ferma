extends "res://tests/suites/suite_base.gd"


## Запускает проверки атласов, направлений, боевых ролей и runtime-состояния противников.
func run() -> void:
	test_all_mobile_enemies_have_complete_walk_sets()
	test_atlases_follow_the_shared_grid_contract()
	test_every_combat_animation_family_is_represented()
	test_direction_changes_source_row_without_mirroring()
	test_attack_frames_are_non_looping_and_keep_bodies_visible()
	test_default_enemies_receive_action_runtime_state()
	test_ranged_enemies_use_real_ranged_distance()


## Сценарий: все восемь подвижных противников проверяются постоянным стандартом проекта.
## Исходное состояние: реестр содержит четыре обычных и четыре пиратских семейства.
## Ожидаемый результат: каждое семейство имеет восемь направлений и три кадра ходьбы.
func test_all_mobile_enemies_have_complete_walk_sets() -> void:
	var game := make_game()
	var kinds: Array = game.EnemyAnimationLibrary.CORE_FAMILIES + game.EnemyAnimationLibrary.PIRATE_FAMILIES
	for kind in kinds:
		expect(game.AnimationAssetRegistry.is_compliant(kind), "enemy has eight directions and three walk frames: %s" % kind)
	game.free()


## Сценарий: четыре новых изображения импортированы как одинаковые таблицы 12 на 8.
## Исходное состояние: каждая таблица состоит из четырёх семейств по три кадра и восьми строк.
## Ожидаемый результат: размер каждой текстуры равен 1536 на 1024 пикселя.
func test_atlases_follow_the_shared_grid_contract() -> void:
	var game := make_game()
	var textures := [game.EnemyAnimationLibrary.CORE_WALK, game.EnemyAnimationLibrary.CORE_ACTIONS, game.EnemyAnimationLibrary.PIRATE_WALK, game.EnemyAnimationLibrary.PIRATE_ACTIONS]
	for texture in textures:
		expect(texture.get_size() == Vector2(1536, 1024), "enemy animation atlas uses the exact 12 by 8 grid")
		var image: Image = texture.get_image()
		var all_cells_filled := true
		for row in 8:
			for column in 12:
				if not image.get_region(Rect2i(column * 128, row * 128, 128, 128)).get_used_rect().has_area(): all_cells_filled = false
		expect(image.get_pixel(0, 0).a < 0.05 and all_cells_filled, "enemy atlas has transparent background and no empty animation cells")
	game.free()


## Сценарий: каталог противников содержит ближний бой, стрельбу, магию и удар по земле.
## Исходное состояние: тип действия назначается по семейству, а не случайно во время отрисовки.
## Ожидаемый результат: все четыре визуально разные боевые серии доступны игровому AI.
func test_every_combat_animation_family_is_represented() -> void:
	var game := make_game(); var kinds: Array[String] = []
	for enemy_kind in game.EnemyAnimationLibrary.ACTION_KINDS:
		var action: String = game.EnemyAnimationLibrary.action_kind(enemy_kind)
		if action not in kinds: kinds.append(action)
	expect(kinds.has("melee") and kinds.has("shoot") and kinds.has("cast") and kinds.has("slam"), "enemy atlas exposes melee, shooting, casting and slam actions")
	expect(game.CombatSystem.enemy_action_kind("skeleton") == "shoot" and game.CombatSystem.enemy_action_kind("sea_ghost") == "cast", "combat AI agrees with visual action roles")
	game.free()


## Сценарий: движение вправо выбирает правую строку, а движение влево — левую.
## Исходное состояние: один и тот же орк смотрит в противоположные стороны без flip_h.
## Ожидаемый результат: исходные прямоугольники находятся в строках шесть и два.
func test_direction_changes_source_row_without_mirroring() -> void:
	var game := make_game()
	var right: Rect2 = game.EnemyAnimationLibrary.source_rect("orc", Vector2.RIGHT, 0)
	var left: Rect2 = game.EnemyAnimationLibrary.source_rect("orc", Vector2.LEFT, 0)
	expect(right.position.y == 6 * 128 and left.position.y == 2 * 128, "enemy east and west animations use separately drawn source rows")
	expect(right.position.x == left.position.x and right != left, "direction changes only the row while preserving family and frame")
	game.free()


## Сценарий: атака проходит ровно три стадии и не исчезает на кадре отделившегося снаряда.
## Исходное состояние: проверяются начало, середина и конец нормализованного действия.
## Ожидаемый результат: кадры идут 0, 1, 2, а стрелок и маг сохраняют pose-кадр тела.
func test_attack_frames_are_non_looping_and_keep_bodies_visible() -> void:
	var game := make_game()
	expect(game.EnemyAnimationLibrary.action_frame(0.0) == 0 and game.EnemyAnimationLibrary.action_frame(0.5) == 1 and game.EnemyAnimationLibrary.action_frame(1.0) == 2, "attack timeline advances through three non-looping frames")
	expect(game.EnemyAnimationLibrary.body_action_frame("skeleton", 2) == 1 and game.EnemyAnimationLibrary.effect_frame("skeleton") == 2, "skeleton body stays visible while arrow becomes a separate effect")
	expect(game.EnemyAnimationLibrary.body_action_frame("undead", 2) == 1 and game.EnemyAnimationLibrary.effect_frame("cave_guardian") == 1, "spell and ground slam keep actor and effect in separate layers")
	game.free()


## Сценарий: новые враги сразу готовы к воспроизведению своей боевой анимации.
## Исходное состояние: создаётся чистый каталог противников до первого игрового кадра.
## Ожидаемый результат: у каждой записи есть тип действия и сохранённая точка цели.
func test_default_enemies_receive_action_runtime_state() -> void:
	var game := make_game(); var enemies: Array = game.CombatSystem.default_enemies()
	for enemy in enemies:
		if not bool(game.CombatSystem.TYPES[enemy.kind].mobile): continue
		expect(enemy.has("action_kind") and enemy.action_kind == game.CombatSystem.enemy_action_kind(enemy.kind), "enemy runtime stores its action kind: %s" % enemy.kind)
		expect(enemy.has("action_target") and enemy.action_target == enemy.position, "enemy runtime starts with a safe local action target: %s" % enemy.kind)
	game.free()


## Сценарий: лучники, стрелки и колдуны не обязаны подходить вплотную для новой анимации.
## Исходное состояние: дальние роли читаются из единого каталога характеристик.
## Ожидаемый результат: их дистанция атаки заметно превышает ближние 68 пикселей.
func test_ranged_enemies_use_real_ranged_distance() -> void:
	var game := make_game()
	for kind in ["skeleton", "undead", "pirate", "sea_ghost", "drowned_captain"]:
		expect(float(game.CombatSystem.TYPES[kind].range) >= 180.0, "ranged enemy attacks from animation-compatible distance: %s" % kind)
	game.free()

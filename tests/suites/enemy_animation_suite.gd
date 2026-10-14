extends "res://tests/suites/suite_base.gd"


## Запускает проверки атласов, направлений, боевых ролей и runtime-состояния противников.
func run() -> void:
	test_all_mobile_enemies_have_complete_walk_sets()
	test_atlases_follow_the_shared_grid_contract()
	test_skeleton_frames_are_isolated_and_complete()
	test_skeleton_bow_faces_south_west_through_the_whole_shot()
	test_guardian_body_is_complete_and_effect_is_separate()
	test_every_combat_animation_family_is_represented()
	test_direction_changes_source_row_without_mirroring()
	test_attack_frames_are_non_looping_and_keep_bodies_visible()
	test_default_enemies_receive_action_runtime_state()
	test_ranged_enemies_use_real_ranged_distance()


## Сценарий: все восемь подвижных противников проверяются постоянным стандартом проекта.
## Исходное состояние: реестр содержит четыре обычных и четыре пиратских семейства.
## Ожидаемый результат: семь семейств сохраняют направленные кадры, временный цельный рисунок хранителя обозначен явным исключением.
func test_all_mobile_enemies_have_complete_walk_sets() -> void:
	var game := make_game()
	var kinds: Array = game.EnemyAnimationLibrary.CORE_FAMILIES + game.EnemyAnimationLibrary.PIRATE_FAMILIES
	for kind in kinds:
		expect(game.AnimationAssetRegistry.is_compliant(kind), "enemy satisfies its explicit directional or temporary whole-pose profile: %s" % kind)
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
	expect(game.EnemyAnimationLibrary.body_action_frame("skeleton", 2) == 2 and game.EnemyAnimationLibrary.effect_frame("skeleton") == -1, "skeleton recovery retains a full body and real arrows render independently")
	expect(game.EnemyAnimationLibrary.body_action_frame("undead", 2) == 1 and game.EnemyAnimationLibrary.effect_frame("cave_guardian") == 1, "spell and ground slam keep actor and effect in separate layers")
	game.free()

## Сценарий: скелет меняет все направления и кадры движения или стрельбы.
## Исходное состояние: новые листы нарезаны по измеренным целым фигурам и имеют прозрачные поля.
## Ожидаемый результат: все 48 кадров целые, содержат тело и не захватывают соседние позы.
func test_skeleton_frames_are_isolated_and_complete() -> void:
	var game:=make_game(); var library=game.EnemyAnimationLibrary
	for texture in [library.walk_texture("skeleton"),library.action_texture("skeleton")]:
		expect(texture.get_size()==Vector2(384,1024),"skeleton uses its own three-column atlas instead of corrupted shared cells")
		var image: Image=texture.get_image()
		for row in 8:
			for frame_index in 3:
				var direction:=Vector2(-sin(row*TAU/8),cos(row*TAU/8))
				var source: Rect2=library.source_rect("skeleton",direction,frame_index)
				var sprite: Image=image.get_region(Rect2i(source)); var used:=sprite.get_used_rect()
				expect(used.size.y>=85 and used.position.x>0 and used.position.y>0 and used.end.x<128 and used.end.y<128,"skeleton pose has a full body and transparent isolation margins: %d/%d"%[row,frame_index])
	game.free()


## Сценарий: скелет натягивает, выпускает стрелу и возвращает лук при стрельбе влево-вниз.
## Исходное состояние: в авторском нижнем левом ряду лук ошибочно нарисован справа, противоположная диагональ имеет правильную позу.
## Ожидаемый результат: все три фазы обращены влево через отражение целой противоположной фигуры, остальные семь ракурсов сохраняют свои позы.
func test_skeleton_bow_faces_south_west_through_the_whole_shot() -> void:
	var game:=make_game(); var library=game.EnemyAnimationLibrary
	for row in 8:
		var direction:=Vector2(-sin(row*TAU/8),cos(row*TAU/8))
		for frame_index in 3:
			var pose:Dictionary=library.action_pose("skeleton",direction,frame_index)
			var expected_row:=7 if row==1 else row
			expect(pose.texture==library.SKELETON_ACTIONS and pose.source==Rect2(frame_index*128,expected_row*128,128,128) and pose.flip==(row==1),"skeleton bow preparation, release and recovery agree with direction %d/%d"%[row,frame_index])
			var used:Rect2i=pose.texture.get_image().get_region(Rect2i(pose.source)).get_used_rect()
			expect(used.position.x>0 and used.end.x<128 and used.position.y>0 and used.end.y<128,"directional bow correction retains a whole isolated figure: %d/%d"%[row,frame_index])
	for level in range(1,6):
		var enemy:={"kind":"skeleton","position":Vector2(600,400),"level":level}
		var normal:Rect2=library.actor_rect(enemy); var mirrored:Rect2=library.oriented_actor_rect(enemy,true)
		expect(mirrored.position==normal.position and mirrored.size==Vector2(-normal.size.x,normal.size.y),"mirroring cannot shift the skeleton away from its health bar or ground point at level "+str(level))
	game.free()


## Сценарий: хранитель стоит, движется, атакует или получает урон при любом направлении.
## Исходное состояние: повреждённые общие ячейки отключены, выбран прежний цельный исходник с измеренной опорой ног.
## Ожидаемый результат: тело всегда целиком с прозрачными полями, эффект удара остаётся отдельной текстурой, временная поза не выдаётся за полный цикл.
func test_guardian_body_is_complete_and_effect_is_separate() -> void:
	var game:=make_game(); var library=game.EnemyAnimationLibrary
	for texture in [library.walk_texture("cave_guardian"),library.action_texture("cave_guardian")]:
		expect(texture==library.GUARDIAN_BODY,"guardian never reads a damaged shared body cell")
		for row in 8:
			for frame_index in 3:
				var source:Rect2=library.source_rect("cave_guardian",Vector2(-sin(row*TAU/8),cos(row*TAU/8)),frame_index)
				var used:Rect2i=texture.get_image().get_region(Rect2i(source)).get_used_rect()
				expect(source==Rect2(0,0,256,256) and used.position.x>0 and used.position.y>0 and used.end.x<256 and used.end.y==int(library.GUARDIAN_PIVOT.y),"guardian retains its whole head, both fists and feet in every state: %d/%d"%[row,frame_index])
	var effect:Rect2=library.action_effect_source("cave_guardian",Vector2.DOWN,1)
	expect(library.action_effect_texture("cave_guardian")==library.CORE_ACTIONS and effect==Rect2(1280,0,128,128),"guardian crystal eruption stays separate from its full-body image")
	var profile:Dictionary=game.AnimationAssetRegistry.AUDIT.cave_guardian
	expect(profile.directions==1 and profile.frames==1 and profile.status=="temporary_whole_pose","registry explicitly declares the static fallback while detailed animation is under review")
	for level in range(1,6):
		var enemy:={"kind":"cave_guardian","position":Vector2(400,500),"level":level}
		var rect:Rect2=library.actor_rect(enemy); var scale:float=rect.size.x/256.0
		expect(is_equal_approx(rect.position.y+library.GUARDIAN_PIVOT.y*scale,500) and library.health_bar_y(enemy)+7<rect.position.y+19*scale,"guardian feet and health bar remain outside the full head at level "+str(level))
	var actor:Dictionary=game.CombatSystem.default_enemies().filter(func(enemy): return enemy.kind=="cave_guardian")[0]
	game.current_location="cave"; actor.location="cave"; game.enemy_nodes=[actor]
	var entries:Array[Dictionary]=[]; preload("res://scripts/systems/debug_object_inspector_system.gd").append_enemies(game,entries)
	expect(entries.size()==1 and entries[0].bounds==library.actor_rect(actor),"F10 selection and sprite share the whole guardian bounds")
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

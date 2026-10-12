extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_animation_frame_modes()
	test_directional_character_atlas_frames()
	test_walking_follows_actual_motion_and_stops_at_obstacles()
	test_camera_keeps_small_rooms_visible_and_scrolls_large_halls()
	test_held_weapons_follow_camera_in_every_direction()
	test_hero_visual_scale_matches_world_proportions()
	test_every_human_atlas_uses_actual_left_and_right_rows()
	test_npc_wander_stays_near_home()
	test_living_sprite_motion_and_atlases()
	test_player_attack_and_slime_reaction()
	test_enemy_hurt_and_death_lifecycle()
	test_slime_attack_returns_to_idle()


## Сценарий: герой ходит от верхней стены дома к выходу, затем перемещается по большому замковому залу.
## Исходное состояние: известны границы комнаты, верхнего HUD и быстрых слотов, камера обновляется обычным методом игры.
## Ожидаемый результат: дом неподвижен и целиком помещается между панелями, большой зал прокручивается без выхода за стены.
func test_camera_keeps_small_rooms_visible_and_scrolls_large_halls() -> void:
	var game := make_game()
	game.current_location = "cottage_interior"
	game.player = Vector2(220, 320)
	game.update_camera()
	var first_offset: Vector2 = game.camera_offset
	game.player = Vector2(880, 490)
	game.update_camera()
	var room: Rect2 = game.BuildingSystem.INTERIORS.cottage_interior.room
	var visible_room := Rect2(room.position - game.camera_offset, room.size)
	expect(game.camera_offset == first_offset, "small cottage does not scroll or jump while the hero moves")
	expect(game.CameraSystem.playfield_rect(game).encloses(visible_room), "the entire cottage stays between the top HUD and quickbar")
	game.current_location = "castle_hall"
	game.player = Vector2(300, 260)
	game.update_camera()
	var near_corner: Vector2 = game.camera_offset
	game.player = Vector2(1550, 860)
	game.update_camera()
	var hall: Rect2 = game.BuildingSystem.INTERIORS.castle_hall.room
	var visible_world := Rect2(game.camera_offset + game.CameraSystem.playfield_rect(game).position, game.CameraSystem.playfield_rect(game).size)
	expect(game.camera_offset.x > near_corner.x and game.camera_offset.y > near_corner.y, "large castle hall continues to follow the hero on both axes")
	expect(hall.encloses(visible_world) and game.camera_offset == game.camera_offset.round(), "large hall camera stays within its walls on whole pixels")
	game.free()


## Сценарий: герой упирается в стену полигона, скользит вниз вдоль неё и открывает рюкзак.
## Исходное состояние: герой стоит в точке касания препятствия с известными координатами и удерживает вправо.
## Ожидаемый результат: у стены ноги не бегут, скольжение смотрит вниз и двигает цикл шага, рюкзак и отпускание останавливают анимацию.
func test_walking_follows_actual_motion_and_stops_at_obstacles() -> void:
	var game := make_game()
	game.current_location = game.DebugPlaygroundSystem.LOCATION
	game.player = Vector2(690.0 - game.PLAYER_RADIUS, 320.0)
	game.move_right_held = true
	var start: Vector2 = game.player
	game.update_player_movement(1.0 / 60.0)
	expect(game.player == start and not game.PlayerSystem.is_visually_moving(game), "pressing into a solid wall does not animate walking in place")
	game.move_down_held = true
	game.update_player_movement(1.0 / 60.0)
	expect(game.player.y > start.y and game.player.x == start.x and game.facing == Vector2.DOWN, "wall sliding keeps the visible facing aligned with actual travel")
	expect(game.PlayerSystem.is_visually_moving(game) and game.PlayerSystem.visual_animation_time(game, true) > 0.0, "real travel advances the walking cycle")
	game.inventory_open = true
	expect(not game.PlayerSystem.is_visually_moving(game), "opening inventory freezes walking even while a direction remains held")
	game.inventory_open = false
	game.clear_movement_keys()
	expect(not game.PlayerSystem.is_visually_moving(game) and game.PlayerSystem.visual_animation_time(game, true) == 0.0, "releasing movement returns to a stable idle frame")
	game.free()


## Сценарий: камера прокручивается во время замаха мечом, выпада копьём и выстрела во всех восьми направлениях.
## Исходное состояние: герой находится вдали от начала мира, две камеры отличаются на известное смещение, тряска выключена.
## Ожидаемый результат: центр оружия остаётся у руки, прокрутка переносит его ровно вместе с героем, а масштаб спрайта сохраняется.
func test_held_weapons_follow_camera_in_every_direction() -> void:
	var game := make_game()
	game.settings_state.screen_shake_enabled = false
	var position := Vector2(1480, 920)
	var camera_delta := Vector2(286, 153)
	for weapon_class in ["blade", "heavy", "spear", "bow", "staff"]:
		for index in 8:
			var direction := Vector2.RIGHT.rotated(index * TAU / 8.0)
			game.camera_offset = Vector2(704, 476)
			var initial: Dictionary = game.WorldPolishRenderer.held_weapon_pose(position, direction, weapon_class, 0.45, 1.0, game.PresentationSystem.world_offset(game))
			game.camera_offset += camera_delta
			var scrolled: Dictionary = game.WorldPolishRenderer.held_weapon_pose(position, direction, weapon_class, 0.45, 1.0, game.PresentationSystem.world_offset(game))
			var hand_distance: float = Vector2(scrolled.transform.origin).distance_to(position - game.camera_offset)
			expect(Vector2(initial.transform.origin - scrolled.transform.origin).is_equal_approx(camera_delta) and hand_distance < 64.0, "weapon remains attached during camera scrolling: %s direction %d" % [weapon_class, index])
			expect(Rect2(scrolled.destination).get_center().is_zero_approx() and is_equal_approx(scrolled.transform.x.length(), 1.0) and is_equal_approx(scrolled.transform.y.length(), 1.0), "weapon rotation preserves sprite proportions: %s direction %d" % [weapon_class, index])
	game.free()


## Сценарий: циклическая и одноразовая анимации выбирают правильные кадры.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_animation_frame_modes() -> void:
	var game := make_game()
	expect(game.AnimationSystem.frame(0.7, 4, 10.0) == 3, "looped animation wraps frames deterministically")
	expect(game.AnimationSystem.frame(2.0, 6, 10.0, false) == 5, "one-shot animation holds its final frame")
	game.free()


## Сценарий: герой, жители и напарники используют утверждённые модульные рамки с общей точкой ног.
## Исходное состояние: герой использует четыре ракурса, жители сохраняют восемь; физический радиус героя прежний.
## Ожидаемый результат: все квадратные кадры людей занимают 96×96 без сжатия по ширине, предмет и тень согласованы с профилем.
func test_hero_visual_scale_matches_world_proportions() -> void:
	var game := make_game()
	var characters = game.DirectionalCharacterSystem
	expect(characters.profiles_are_valid(), "hero four-direction and resident eight-direction profiles are valid")
	expect(characters.HERO_DRAW_SIZE==Vector2(96,96) and characters.NPC_DRAW_SIZE==Vector2(96,96) and characters.COMPANION_DRAW_SIZE==Vector2(96,96), "hero residents and companions preserve square atlas proportions at the same height")
	expect(characters.actor_rect(Vector2(200,200),characters.HERO_DRAW_SIZE).end.y==224.0 and characters.actor_rect(Vector2(200,200),characters.NPC_DRAW_SIZE).end.y==224.0, "different human frames share the exact same foot anchor")
	expect(characters.HERO_SHADOW_RADII == Vector2(18,6), "hero shadow follows the modular visual footprint")
	var held_item: Rect2 = game.WorldPolishRenderer.held_weapon_destination(Vector2.ZERO, Vector2.RIGHT, false, characters.HERO_VISUAL_SCALE)
	expect(held_item.size == Vector2(48,48), "held equipment uses one complete hand module without fractional scaling")
	expect(game.PLAYER_RADIUS == 18.0, "visual resizing does not silently alter navigation and interaction collision")
	var preview:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/generated/level_drafts/characters_ingame_preview.png")); expect(preview!=null and preview.get_size()==Vector2i(1152,648),"human profile migration keeps a current native gameplay preview")
	game.free()


## Сценарий: новый общий аниматор выбирает строку направления и четыре последовательных кадра.
## Исходное состояние: новый мастер героя имеет четыре ракурса с измеренными источниками; герой смотрит по диагонали вправо.
## Ожидаемый результат: диагональ выбирает правый ракурс, покой держит нейтральную фазу, а ходьба меняет только столбец.
func test_directional_character_atlas_frames() -> void:
	var game := make_game()
	var texture: Texture2D = game.DirectionalCharacterSystem.HERO_TEXTURES[0]
	var idle: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, -1), 0.4, false)
	var walking: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, -1), 0.4, true)
	expect(texture.get_size() == Vector2(1254,1254), "hero uses the new four-direction production master")
	expect(idle.position == Vector2(336,600) and idle.size == Vector2(300,300), "north-east selects the actual right-facing row and neutral phase")
	expect(walking.position.x > idle.position.x and walking.position.y == idle.position.y, "walk time advances the frame without changing direction")
	game.free()


## Сценарий: оставшиеся старые жители и напарники используют одинаковые реальные строки вправо и влево.
## Исходное состояние: старые атласы имеют ячейку 222×222; новые герой и бабушка проходят отдельные тесты четырёх ракурсов.
## Ожидаемый результат: движение вправо выбирает строку шесть, правые строки зеркальны левым, а содержимое каждого кадра имеет безопасный прозрачный отступ.
func test_every_human_atlas_uses_actual_left_and_right_rows() -> void:
	var game := make_game()
	var textures: Array[Texture2D] = []
	textures.append_array(game.DirectionalCharacterSystem.NPC_TEXTURES.slice(1))
	for companion_id in game.DirectionalCharacterSystem.COMPANION_TEXTURES:
		textures.append(game.DirectionalCharacterSystem.COMPANION_TEXTURES[companion_id])
	for texture in textures:
		var east: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.RIGHT, 0.0, false)
		var west: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.LEFT, 0.0, false)
		var north_east: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, -1), 0.0, false)
		var south_east: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2(1, 1), 0.0, false)
		expect(east.position.y == 1332.0 and west.position.y == 444.0, "human atlas keeps right and left poses on their actual rows: %s" % texture.resource_path)
		expect(north_east.position.y == 1110.0 and south_east.position.y == 1554.0, "human atlas keeps both right diagonals on their actual rows: %s" % texture.resource_path)
		var atlas := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
		var mirrored_pairs_are_exact := true
		for pair in [[1, 7], [2, 6], [3, 5]]:
			for frame in 4:
				var left_frame := atlas.get_region(Rect2i(frame * 222, pair[0] * 222, 222, 222))
				var right_frame := atlas.get_region(Rect2i(frame * 222, pair[1] * 222, 222, 222))
				left_frame.flip_x()
				mirrored_pairs_are_exact = mirrored_pairs_are_exact and left_frame.get_data() == right_frame.get_data()
		expect(mirrored_pairs_are_exact, "right-facing human rows are exact clean mirrors: %s" % texture.resource_path)
		var frames_keep_padding := true
		for row in 8:
			for frame in 4:
				var frame_image := atlas.get_region(Rect2i(frame * 222, row * 222, 222, 222))
				var opaque_bounds := frame_image.get_used_rect()
				frames_keep_padding = frames_keep_padding and opaque_bounds.position.y >= 8 and opaque_bounds.end.y <= 214
		expect(frames_keep_padding, "human frames do not leak into adjacent rows: %s" % texture.resource_path)
	game.free()


## Сценарий: житель начинает прогулку без случайности и не покидает безопасный радиус дома.
## Исходное состояние: бабушка стоит дома, её таймер ожидания принудительно завершён, активна деревня.
## Ожидаемый результат: движение начинается сразу, позиция меняется, радиус соблюдается и шаг обучения отмечается.
func test_npc_wander_stays_near_home() -> void:
	var game := make_game()
	game.language_screen = false; game.title_screen = false; game.current_location = "overworld"
	var state: Dictionary = game.npc_movement["grandmother"]
	var home: Vector2 = state.home
	state.timer = 0.0
	game.NpcMovementSystem.update(game, 0.1)
	expect(state.moving and state.position != home, "NPC starts a deterministic walk when the pause expires")
	for _frame in 80:
		game.NpcMovementSystem.update(game, 0.1)
	expect(state.position.distance_to(home) <= game.NpcMovementSystem.WANDER_RADIUS + 1.0, "NPC stays inside the configured home radius")
	expect(game.tutorial_events_completed.has("npc_wander"), "NPC walk has a tester tutorial event")
	game.free()


## Сценарий: единые атласы NPC и зверей используют разные циклы дыхания и шага.
## Исходное состояние: новая игра и детерминированные моменты времени для общего motion-профиля.
## Ожидаемый результат: оба прозрачных атласа загружены, покой живой, фазы различаются, а ходьба заметнее дыхания.
func test_living_sprite_motion_and_atlases() -> void:
	var game := make_game()
	expect(game.DirectionalCharacterSystem.profiles_are_valid(), "current directional NPC sprites are loaded through their runtime catalog")
	expect(game.WILDLIFE_ACTION_SHEETS.bat.get_size() == Vector2(768,1024) and game.WILDLIFE_ACTION_SHEETS.lizard.get_size() == Vector2(768,1024), "current bat and lizard action sheets are loaded")
	var idle_start: Dictionary = game.PresentationSystem.living_motion(0.0, false)
	var idle_later: Dictionary = game.PresentationSystem.living_motion(0.45, false)
	var shifted: Dictionary = game.PresentationSystem.living_motion(0.45, false, 1.7)
	var walking: Dictionary = game.PresentationSystem.living_motion(0.45, true)
	expect(idle_start.offset != idle_later.offset and idle_start.scale != idle_later.scale, "standing characters breathe instead of freezing")
	expect(idle_later.offset != shifted.offset, "living characters use desynchronized animation phases")
	expect(absf(walking.offset.y) > absf(idle_later.offset.y) and absf(walking.rotation) > absf(idle_later.rotation), "walking cycle has a stronger step and body lean")
	game.free()


## Сценарий: атака героя запускает замах и реакцию слизня на попадание.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_player_attack_and_slime_reaction() -> void:
	var game := make_game()
	game.player = game.slime_position
	expect(game.attack_slime(), "slime accepts a close combat hit")
	expect(game.player_attack_timer == game.WeaponSystem.attack_duration(game), "combat starts the selected weapon timeline immediately")
	game.WeaponSystem.update(game,game.WeaponSystem.attack_duration(game)*0.43+0.001)
	expect(game.slime_visual_state == "hurt", "surviving slime enters hurt animation")
	game.AnimationSystem.update(game, game.AnimationSystem.HURT_DURATION + 0.01)
	expect(game.slime_visual_state == "idle", "slime returns to idle after hurt animation")
	expect(game.tutorial_events_completed.has("combat_animation"), "combat animation has a tester tutorial event")
	game.free()


## Сценарий: обычный враг проходит состояния ранения, гибели и исчезновения.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_enemy_hurt_and_death_lifecycle() -> void:
	var game := make_game()
	game.current_location = "forest"
	game.player = game.enemy_nodes[0].position
	expect(game.CombatSystem.attack(game, 0), "animated enemy accepts damage")
	game.WeaponSystem.update(game,game.WeaponSystem.attack_duration(game)*0.43+0.001)
	expect(game.enemy_nodes[0].visual_state == "hurt", "enemy enters hurt state after a non-lethal hit")
	game.AnimationSystem.update(game, game.AnimationSystem.HURT_DURATION + 0.01)
	expect(game.enemy_nodes[0].visual_state == "idle", "enemy hurt state expires into idle")
	for _hit in 4:
		settle_player_attack(game)
		game.CombatSystem.attack(game, 0)
		settle_player_attack(game)
	expect(not game.enemy_nodes[0].alive and game.enemy_nodes[0].visual_state == "death", "defeated enemy enters a one-shot death animation")
	expect(game.AnimationSystem.enemy_is_visible(game.enemy_nodes[0]), "defeated enemy stays visible while death animation plays")
	game.AnimationSystem.update(game, game.AnimationSystem.DEATH_DURATION + 0.01)
	expect(not game.AnimationSystem.enemy_is_visible(game.enemy_nodes[0]), "enemy disappears after its death animation finishes")
	game.free()


## Сценарий: атака слизня завершается возвратом в состояние покоя.
## Исходное состояние: новая игра с живыми целями; здоровье, позиции, оружие и добыча настраиваются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_slime_attack_returns_to_idle() -> void:
	var game := make_game()
	game.AnimationSystem.begin_slime_attack(game)
	expect(game.slime_visual_state == "attack", "slime attack uses its own one-shot state")
	game.AnimationSystem.update(game, game.AnimationSystem.ENEMY_ATTACK_DURATION + 0.01)
	expect(game.slime_visual_state == "idle", "slime attack returns to idle")
	game.free()

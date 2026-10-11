extends "res://tests/suites/suite_base.gd"

const Visuals := preload("res://scripts/systems/wildlife_visual_system.gd")
const Matte := preload("res://scripts/systems/sprite_matte_system.gd")
const AnimalNavigation := preload("res://scripts/systems/wildlife_navigation_system.gd")


## Проверяет масштаб, досягаемость животных и безопасное разрешение столкновений после удара.
func run() -> void:
	preload("res://tests/suites/editor_actor_source_suite.gd").new(context).run()
	test_clean_matte_preserves_interior_colors()
	test_wildlife_frames_have_constant_pixel_scale_and_foot_anchor()
	test_animals_stop_fleeing_and_stay_in_reachable_habitat()
	test_animal_sweep_does_not_cross_solid_ground()
	test_player_can_escape_enemy_overlap_without_crossing_walls()
	test_enemy_knockback_cannot_tunnel_or_occupy_player()
	test_boar_windup_allows_evading_without_instant_damage()
	test_village_migration_preserves_hunted_animal_state()


## Сценарий: служебная красная кайма соседствует с прозрачностью, а внутри меха есть такая же красная деталь.
## Исходное состояние: изолированный RGBA-рисунок с оранжевым телом, красным центром и внешней двухпиксельной каймой.
## Ожидаемый результат: исчезает только внешняя связанная кайма; мех, внутренний красный пиксель и исходный Image не меняются.
func test_clean_matte_preserves_interior_colors() -> void:
	var source := Image.create(12, 12, false, Image.FORMAT_RGBA8); source.fill(Color.TRANSPARENT)
	for y in range(3, 9):
		for x in range(3, 9): source.set_pixel(x, y, Color(0.9, 0.4, 0.1, 1.0))
	source.set_pixel(5, 5, Color.RED); source.set_pixel(2, 5, Color.RED); source.set_pixel(1, 5, Color.RED)
	var cleaned := Matte.clean_image(source)
	expect(cleaned.get_pixel(1, 5).a == 0.0 and cleaned.get_pixel(2, 5).a == 0.0, "connected external matte is removed through both pixels")
	expect(cleaned.get_pixel(5, 5) == Color.RED and cleaned.get_pixel(4, 4) == source.get_pixel(4, 4), "interior red ornament and orange fur are preserved")
	expect(source.get_pixel(1, 5) == Color.RED, "import cleanup never modifies source image")
	var texture := ImageTexture.create_from_image(source)
	expect(Matte.clean_texture(texture) == Matte.clean_texture(texture), "explicit opt-in texture preprocessing reuses one cached ImageTexture")


## Сценарий: каждый зверь идёт в четыре стороны, получает удар и переходит в покой.
## Исходное состояние: реальные production-текстуры, единая точка лап и последовательные фазы каждого нового цикла.
## Ожидаемый результат: коэффициент пикселей неизменен; кадр внутри PNG, опора совпадает с позицией, миниатюрные дефектные столбцы не используются.
func test_wildlife_frames_have_constant_pixel_scale_and_foot_anchor() -> void:
	var game := make_game()
	for kind in game.WildlifeSystem.TYPES:
		var scale := -1.0
		var valid := true
		for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]:
			for frame in 8:
				var animal := {"kind": kind, "position": Vector2(200, 300), "direction": direction, "animation": frame / 9.0, "moving": true, "visual_state": "flee"}
				var packet := Visuals.frame_packet(game, animal)
				if scale < 0.0: scale = packet.scale
				valid = valid and is_equal_approx(scale, packet.scale)
				valid = valid and Rect2(Vector2.ZERO, packet.texture.get_size()).encloses(packet.source)
				valid = valid and is_equal_approx(absf(packet.destination.size.x), packet.source.size.x * scale)
				valid = valid and is_equal_approx(packet.destination.end.y, 284.0 if kind == "bat" else 300.0)
				animal.visual_state = "hurt"
				valid = valid and int(Visuals.frame_packet(game, animal).column) == 0
		expect(valid, "wildlife uses stable world pixels, complete crops and a fixed foot anchor: %s" % kind)
		expect(Visuals.frame_column(kind, 0, "flee", 0.34, true) != 3 or kind in ["fox", "bat", "lizard"], "legacy tiny attack frame is not inserted into running: %s" % kind)
	game.free()


## Сценарий: охотник преследует зверя; после короткого рывка цель отдыхает, а граница места обитания останавливает побег.
## Исходное состояние: новая лесная цель на найденной доступной площадке, игрок движется за ней на расстоянии 60 px.
## Ожидаемый результат: есть и бегство, и пауза; все позиции доступны пешему герою и не выходят за радиус дома.
func test_animals_stop_fleeing_and_stay_in_reachable_habitat() -> void:
	var game := clean_world(); var center := open_point(game)
	var animal: Dictionary = game.WildlifeSystem.default_animals()[0]
	animal.location = game.current_location; animal.position = center; animal.home = center; animal.habitat_validated = true
	game.wildlife_nodes = [animal]
	var stopped := false; var ran := false; var reachable := true; var bounded := true
	for _frame in 240:
		game.player = game.wildlife_nodes[0].position - Vector2(60, 0)
		game.WildlifeSystem.update(game, 1.0 / 60.0)
		animal = game.wildlife_nodes[0]
		ran = ran or bool(animal.moving)
		stopped = stopped or (not animal.moving and float(animal.recovery_timer) > 0.0)
		reachable = reachable and game.NavigationSystem.is_walkable(game, animal.position)
		bounded = bounded and animal.position.distance_to(center) <= game.WildlifeSystem.ROAM_RADIUS + 0.01
	expect(ran and stopped, "fleeing has a finite burst and a catchable recovery pause")
	expect(reachable and bounded, "animals remain on hunter-accessible ground inside their habitat")
	game.free()


## Сценарий: животное за один длинный кадр пытается пересечь камень, а мышь не может спрятаться за непроходимой стеной.
## Исходное состояние: площадка с ресурсом между начальной и конечной точками; движение превышает ширину препятствия.
## Ожидаемый результат: пошаговая проверка останавливается перед препятствием; итоговая точка достижима и до него, и после малого шага.
func test_animal_sweep_does_not_cross_solid_ground() -> void:
	var game := clean_world(); var center := open_point(game)
	game.resource_nodes = [{"kind": "stone", "location": game.current_location, "position": center + Vector2(80, 0), "hits": 3}]
	var finish := AnimalNavigation.move(game, center, Vector2(160, 0), center, 320.0)
	expect(finish.x < center.x + 80.0 and game.NavigationSystem.is_walkable(game, finish), "animal sweep cannot teleport through a solid resource")
	game.free()


## Сценарий: после боя живой враг уже наложился на героя, который пытается выйти наружу и затем идти сквозь него.
## Исходное состояние: две пересекающиеся окружности на свободном участке и отдельный твёрдый камень на пути отступления.
## Ожидаемый результат: разрешено только уменьшение наложения; повторный вход и шаг внутрь камня остаются запрещены.
func test_player_can_escape_enemy_overlap_without_crossing_walls() -> void:
	var game := clean_world(); var center := open_point(game)
	game.player = center
	game.enemy_nodes = [{"alive": true, "location": game.current_location, "position": center + Vector2(20, 0)}]
	game.NavigationSystem.move(game, Vector2(-64, 0))
	expect(game.player.x < center.x - 50.0 and game.NavigationSystem.is_walkable(game, game.player), "player can walk out of an existing enemy overlap after a hit")
	game.NavigationSystem.move(game, Vector2(120, 0))
	expect(game.player.x < center.x and game.NavigationSystem.is_walkable(game, game.player), "escape permission does not allow walking back through the enemy")
	game.player = center
	game.resource_nodes = [{"kind": "stone", "location": game.current_location, "position": center - Vector2(42, 0), "hits": 3}]
	game.NavigationSystem.move(game, Vector2(-48, 0))
	expect(game.player.x > center.x - 30.0, "overlap recovery never bypasses a static resource collision")
	game.free()


## Сценарий: враг получает сильное отбрасывание через камень и затем пытается войти прямо в героя.
## Исходное состояние: мобильная цель на площадке, ресурс впереди и герой рядом после второго размещения.
## Ожидаемый результат: большой импульс режется на безопасные шаги; враг не занимает тело героя, но может выйти из старого наложения.
func test_enemy_knockback_cannot_tunnel_or_occupy_player() -> void:
	var game := clean_world(); var center := open_point(game)
	game.player = center - Vector2(100, 0)
	game.enemy_nodes = [{"alive": true, "location": game.current_location, "position": center}]
	game.resource_nodes = [{"kind": "stone", "location": game.current_location, "position": center + Vector2(80, 0), "hits": 3}]
	var finish: Vector2 = game.NavigationSystem.move_enemy(game, 0, Vector2(160, 0))
	expect(finish.x < center.x + 80.0, "enemy knockback cannot tunnel through a resource in one large frame")
	game.resource_nodes.clear(); game.player = center + Vector2(52, 0)
	finish = game.NavigationSystem.move_enemy(game, 0, Vector2(32, 0))
	expect(finish.distance_to(game.player) >= game.PLAYER_RADIUS + 30.0, "moving enemy respects the player body")
	game.player = center + Vector2(20, 0)
	finish = game.NavigationSystem.move_enemy(game, 0, Vector2(-50, 0))
	expect(finish.x < center.x, "enemy may separate from a legacy overlap instead of becoming permanently stuck")
	game.free()


## Сценарий: кабан замахивается рядом с героем, игрок успевает отойти, затем принимает следующий удар вблизи.
## Исходное состояние: здоровый герой и кабан в пределах атаки на свободной земле; время шага явно контролируется.
## Ожидаемый результат: нет мгновенного урона при замахе, отход отменяет попадание, близкая цель получает ровно один удар.
func test_boar_windup_allows_evading_without_instant_damage() -> void:
	var game := clean_world(); var center := open_point(game)
	var animal: Dictionary = game.WildlifeSystem.default_animals()[4]
	animal.location = game.current_location; animal.position = center; animal.home = center; animal.habitat_validated = true
	game.wildlife_nodes = [animal]; game.player = center + Vector2(50, 0)
	var health: int = game.player_hp
	game.WildlifeSystem.update(game, 0.016)
	expect(game.player_hp == health and game.wildlife_nodes[0].visual_state == "attack", "boar attack begins with a visible windup without immediate damage")
	game.player += Vector2(100, 0); game.WildlifeSystem.update(game, 0.23)
	expect(game.player_hp == health, "moving away during the windup evades the boar")
	animal.visual_state = "idle"; animal.state_timer = 0.0; animal.attack_timer = 0.0
	game.wildlife_nodes[0] = animal; game.player = center + Vector2(50, 0)
	game.WildlifeSystem.update(game, 0.016); game.WildlifeSystem.update(game, 0.23)
	var after_hit: int = game.player_hp
	game.WildlifeSystem.update(game, 0.05)
	expect(after_hit < health and game.player_hp == after_hit, "nearby player receives one impact, not repeated damage on each animation frame")
	game.free()


## Сценарий: старое сохранение содержит убитого зверя и раненую лису на прежних координатах первой карты.
## Исходное состояние: список штатных животных сохранён, а hp/alive и позиции отличаются от нового старта.
## Ожидаемый результат: миграция меняет место обитания, но не возрождает добычу и не исцеляет животных.
func test_village_migration_preserves_hunted_animal_state() -> void:
	var game := make_game()
	game.wildlife_nodes[0].alive = false; game.wildlife_nodes[0].hp = 0; game.wildlife_nodes[0].position = Vector2(1800, 390)
	game.wildlife_nodes[1].hp = 1; game.wildlife_nodes[1].position = Vector2(2140, 430)
	game.WildlifeSystem.migrate_village_habitats(game)
	expect(not game.wildlife_nodes[0].alive and int(game.wildlife_nodes[0].hp) == 0, "village migration preserves the hunted animal and cannot duplicate its loot")
	expect(int(game.wildlife_nodes[1].hp) == 1 and game.wildlife_nodes[1].position == game.WildlifeSystem.SPAWNS[1].position, "village migration moves injured wildlife without healing it")
	game.free()


## Подготавливает независимую уличную сцену без динамических целей и предметных препятствий.
func clean_world() -> Node:
	var game := make_game(); game.current_location = "ruins"
	game.enemy_nodes.clear(); game.hazard_nodes.clear(); game.resource_nodes.clear(); game.food_nodes.clear(); game.world_loot_nodes.clear()
	game.wildlife_nodes.clear(); return game


## Находит полосу свободной земли для воспроизводимого теста, не привязываясь к художественным координатам карты.
func open_point(game: Node) -> Vector2:
	for y in range(300, 801, 120):
		for x in range(400, 1801, 200):
			var point := Vector2(x, y); var valid := true
			for offset in range(-120, 201, 6): valid = valid and game.NavigationSystem.is_walkable(game, point + Vector2(offset, 0))
			if valid: return point
	expect(false, "navigation fixture contains a free horizontal corridor")
	return Vector2(600, 600)

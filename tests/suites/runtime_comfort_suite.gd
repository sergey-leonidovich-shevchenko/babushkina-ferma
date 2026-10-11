extends "res://tests/suites/suite_base.gd"


## Запускает регрессии настоящего маршрутизатора ввода и непрерывного удержания клавиш.
func run() -> void:
	preload("res://tests/suites/debug_frame_budget_suite.gd").new(context).run()
	preload("res://tests/suites/navigation_broadphase_suite.gd").new(context).run()
	test_alternate_movement_keys_do_not_cancel_each_other()
	test_inventory_pointer_close_reaches_the_real_input_router()
	test_debug_grid_build_is_bounded_and_discards_old_locations()
	test_debug_pointer_probe_reuses_only_the_same_world_cell()
	test_dynamic_grid_batches_preserve_markers_and_reject_stale_generations()


## Сценарий: игрок одновременно удерживает D и стрелку вправо, затем отпускает их по очереди.
## Исходное состояние: новый экземпляр игры со стандартными клавишами и пустым списком удержания.
## Ожидаемый результат: первая отпущенная клавиша не прерывает движение, последняя останавливает, потеря фокуса очищает обе.
func test_alternate_movement_keys_do_not_cancel_each_other() -> void:
	var game := make_game()
	game.update_movement_key_state(key_event(KEY_D, KEY_D, true))
	game.update_movement_key_state(key_event(KEY_RIGHT, KEY_RIGHT, true))
	game.update_movement_key_state(key_event(KEY_D, KEY_D, false))
	expect(game.get_movement_direction() == Vector2.RIGHT, "releasing D preserves a held right arrow")
	game.update_movement_key_state(key_event(KEY_RIGHT, KEY_RIGHT, false))
	expect(game.get_movement_direction() == Vector2.ZERO, "releasing the final direction key stops movement")
	game.update_movement_key_state(key_event(KEY_D, KEY_D, true))
	game.update_movement_key_state(key_event(KEY_RIGHT, KEY_RIGHT, true))
	game.clear_movement_keys()
	game.update_movement_key_state(key_event(KEY_D, KEY_D, true))
	game.update_movement_key_state(key_event(KEY_D, KEY_D, false))
	expect(game.get_movement_direction() == Vector2.ZERO, "focus loss clears alternate key tracking before the next press")
	game.free()


## Сценарий: большая группа врагов обновляет F10-сетку, один враг уходит за границы начальной очереди.
## Исходное состояние: реальная сетка пещеры с восемью разнесёнными врагами; маркеры уже опубликованы.
## Ожидаемый результат: пакет ограничен 128 пробами, маркеры не пропадают до публикации, новая позиция учтена, старое поколение не записывается.
func test_dynamic_grid_batches_preserve_markers_and_reject_stale_generations() -> void:
	var game := make_game()
	game.current_location = "cave"; game.player = Vector2(900, 480); game.enemy_nodes.clear()
	game.hazard_nodes.clear(); game.resource_nodes.clear(); game.food_nodes.clear(); game.world_loot_nodes.clear()
	game.update_camera(); game.DebugOverlaySystem.toggle(game)
	for _batch in 500:
		if game.get_meta(game.DebugOverlaySystem.META_KEY).grid_build.is_empty(): break
		game.DebugOverlaySystem.update(game, 0.016)
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	var points: Array[Vector2] = []
	for cell in state.cache:
		var point: Vector2 = cell.rect.get_center()
		if cell.reason != "walkable" or not state.cache_rect.grow(-72).has_point(point): continue
		if points.any(func(other: Vector2): return point.distance_to(other) < 144.0): continue
		points.append(point)
		if points.size() >= 9: break
	expect(points.size() == 9, "dynamic grid fixture contains eight independent enemy regions and a ninth destination")
	if points.size() != 9:
		game.free(); return
	for point in points.slice(0, 8): game.enemy_nodes.append({"alive": true, "location": "cave", "position": point})
	state.dynamic_cells = game.DebugOverlaySystem.dynamic_cells(game, int(state.grid_size))
	for key in state.dynamic_cells:
		if state.cache_cells.has(key): state.cache_cells[key] = game.DebugOverlaySystem.classify_cell(game, key.x, key.y, int(state.grid_size), false)
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)
	var old_keys: Array = state.dynamic_cells.duplicate()
	game.DebugOverlaySystem.refresh_dynamic_cells(game)
	state = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(not state.dynamic_build.is_empty() and int(state.dynamic_build.cursor) <= 128, "periodic enemy refresh processes a bounded batch rather than all cave enemies synchronously")
	expect(state.dynamic_cells == old_keys, "published enemy markers remain visible while their replacement is incomplete")
	game.enemy_nodes[0].position = points[8]
	for _batch in 500:
		if game.get_meta(game.DebugOverlaySystem.META_KEY).dynamic_build.is_empty(): break
		game.DebugOverlaySystem.DynamicGridSystem.advance(game)
	state = game.get_meta(game.DebugOverlaySystem.META_KEY)
	var new_key := Vector2i(floori(points[8].x / state.grid_size) * int(state.grid_size), floori(points[8].y / state.grid_size) * int(state.grid_size))
	var old_key := Vector2i(floori(points[0].x / state.grid_size) * int(state.grid_size), floori(points[0].y / state.grid_size) * int(state.grid_size))
	expect(state.dynamic_build.is_empty() and new_key in state.dynamic_cells and state.cache_cells[new_key].reason == "enemy", "enemy that leaves the original queue gains its new marker before atomic publication")
	expect(old_key not in state.dynamic_cells, "old enemy marker is removed when the complete replacement publishes")
	game.DebugOverlaySystem.DynamicGridSystem.begin(game, state)
	state = game.get_meta(game.DebugOverlaySystem.META_KEY)
	state.cache_generation += 1; state.cache_cells[new_key].reason = "water"
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)
	game.DebugOverlaySystem.DynamicGridSystem.advance(game)
	state = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(state.dynamic_build.is_empty() and state.cache_cells[new_key].reason == "water", "stale dynamic generation cannot overwrite the next complete navigation cache")
	game.DebugOverlaySystem.DynamicGridSystem.begin(game, state)
	game.current_location = "cottage_interior"
	game.DebugOverlaySystem.DynamicGridSystem.advance(game)
	expect(game.get_meta(game.DebugOverlaySystem.META_KEY).dynamic_build.is_empty(), "changing location discards pending enemy classification immediately")
	game.free()


## Сценарий: неподвижный курсор запрашивает INFO каждый кадр, затем камера переносит его на соседнюю клетку.
## Исходное состояние: живая первая локация с известным смещением камеры и пустым кэшем навигационной подсказки.
## Ожидаемый результат: одна клетка переиспользует готовый результат; новая мировая клетка и другая локация пересчитываются сразу.
func test_debug_pointer_probe_reuses_only_the_same_world_cell() -> void:
	var game := make_game()
	var point := Vector2(220, 220)
	var first: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game, point)
	var memory: Dictionary = game.get_meta(game.DebugOverlaySystem.INSPECT_CACHE_META)
	var second: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game, point + Vector2.ONE)
	expect(first == second and memory == game.get_meta(game.DebugOverlaySystem.INSPECT_CACHE_META), "INFO reuses the exact same world-cell probe instead of repeating farming navigation each draw")
	game.camera_offset += Vector2(48, 0)
	var moved: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game, point)
	expect(moved.origin != first.origin, "moving camera to a new cursor cell immediately refreshes INFO")
	game.current_location = "cottage_interior"
	var interior: Dictionary = game.DebugOverlaySystem.inspect_screen_point(game, point)
	expect(String(interior.reason) == game.NavigationSystem.walkability_reason(game, interior.center), "changing location cannot reuse an old outdoor collision result")
	game.free()


## Сценарий: F10 строит тысячи клеток без синхронной остановки, а герой успевает перейти в другую локацию.
## Исходное состояние: первая локация, новая очередь сетки и последующий переход в маленький дом.
## Ожидаемый результат: за пакет не более 128 проб, управление доступно сразу, итоговые клетки относятся только к дому.
func test_debug_grid_build_is_bounded_and_discards_old_locations() -> void:
	var game := make_game()
	game.DebugOverlaySystem.toggle(game)
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(not state.grid_build.is_empty() and int(state.grid_build.cursor) <= 128, "opening F10 classifies a bounded batch instead of the whole world")
	var before: Vector2 = game.player
	game.DebugOverlaySystem.toggle_option(game, "noclip")
	game.update_movement_key_state(key_event(KEY_D, KEY_D, true))
	game.update_player_movement(1.0 / 60.0)
	expect(game.player.x > before.x, "movement remains immediately responsive while the diagnostic grid is building")
	game.current_location = "cottage_interior"
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.spawn
	game.update_camera()
	game.DebugOverlaySystem.update(game, 0.016)
	for _batch in 500:
		if game.get_meta(game.DebugOverlaySystem.META_KEY).grid_build.is_empty(): break
		game.DebugOverlaySystem.update(game, 0.016)
	state = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(state.grid_build.is_empty() and state.cache_location == "cottage_interior" and state.cache.size() > 200, "old location work is discarded and the complete interior grid publishes atomically")
	var matches := true
	for index in range(0, state.cache.size(), 37):
		var cell: Dictionary = state.cache[index]
		matches = matches and String(cell.reason) == game.NavigationSystem.walkability_reason(game, cell.rect.get_center())
	expect(matches, "published diagnostic cells match actual collision queries after asynchronous completion")
	game.free()


## Сценарий: мышь и палец нажимают нарисованный крестик рюкзака через настоящий входной метод игровой сцены.
## Исходное состояние: изолированная игровая сцена инициализирована, стартовые экраны выключены и открыт рюкзак.
## Ожидаемый результат: оба события проходят маршрутизатор и закрывают окно без прямого вызова вспомогательного обработчика.
func test_inventory_pointer_close_reaches_the_real_input_router() -> void:
	var game := make_game()
	game.open_inventory()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.ItemWindowRenderer.close_button_rect(game).get_center()
	game._input(click)
	expect(not game.inventory_open, "mouse close reaches the inventory through the actual scene input router")
	game.open_inventory()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = game.ItemWindowRenderer.close_button_rect(game).get_center()
	game._input(touch)
	expect(not game.inventory_open, "touch close reaches the inventory through the actual scene input router")
	game.free()

extends SceneTree

const GAME_SCENE := preload("res://main.tscn")
const Village := preload("res://scripts/systems/village_map_data.gd")
const REPORT_PATH := "res://docs/reports/runtime_comfort_review.json"
const STEP := 1.0 / 60.0
const MOVEMENT_KEYS := [KEY_A, KEY_D, KEY_W, KEY_S]

var game: Node
var checks: Array[Dictionary] = []
var held: Dictionary = {}
var simulated_frames := 0
var save_fingerprints: Dictionary = {}


## Откладывает создание настоящей игровой сцены до готовности корневого viewport.
func _initialize() -> void:
	_run.call_deferred()


## Проходит короткий маршрут через реальные ввод, физический цикл, двери, мост и предметное окно.
func _run() -> void:
	for path in ["user://farm-save.json", "user://farm-save-2.json", "user://farm-save-3.json"]:
		save_fingerprints[path] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
	seed(20260908)
	game = GAME_SCENE.instantiate()
	game.world_loot_seed = 20260908
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.LocaleSystem.set_locale("ru", false)
	game.InputSystem.apply_control_preset("standard")
	game.language_screen = false
	game.title_screen = false
	game.settings_state.screen_shake_enabled = false
	_review_cottage_exit()
	_review_home_approach()
	_review_bridge_and_camera()
	_review_village_path()
	_review_inventory_controls()
	_review_cave_approach()
	_review_collision_and_animation()
	for path in save_fingerprints:
		var current := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
		_check(current == save_fingerprints[path], "Сохранение пользователя не изменено", {"slot": path})
	_finish()


## Выходит из дома обычным движением вниз и проверяет, что наружная точка позволяет продолжить путь.
func _review_cottage_exit() -> void:
	_reset_controls()
	game.current_location = "cottage_interior"
	game.player = game.BuildingSystem.INTERIORS.cottage_interior.spawn
	game.update_camera()
	var room: Rect2 = game.BuildingSystem.INTERIORS.cottage_interior.room
	_check(game.CameraSystem.playfield_rect(game).encloses(Rect2(room.position - game.camera_offset, room.size)), "Комната целиком помещается между HUD и быстрыми слотами", {"camera": _point(game.camera_offset)})
	game.location_transition_armed = true
	game.location_transition_cooldown = 0.0
	_key(KEY_S, true)
	for frame in 45:
		_advance()
		if game.current_location == "overworld": break
	_reset_controls()
	_check(game.current_location == "overworld", "Выход из дома срабатывает при подходе без дополнительной кнопки")
	var before: Vector2 = game.player
	_key(KEY_D, true)
	for frame in 6: _advance()
	_reset_controls()
	_check(game.player.x > before.x + 10.0, "После выхода из дома можно сразу пройти вправо", {"from": _point(before), "to": _point(game.player), "authored_exit": _point(Village.COTTAGE_EXIT)})


## Идёт от выхода дома через стартовую точку к первой переправе по актуальному дорожному чертежу.
func _review_home_approach() -> void:
	var reached := _walk_to(Village.START, 100)
	_check(reached, "Стартовая точка достижима пешком от выхода дома", {"finish": _point(game.player), "start": _point(Village.START)})
	for index in [2, 3]:
		var target: Vector2 = Village.PATHS[0][index]
		reached = _walk_to(target, 200)
		_check(reached, "Домашняя дорога к мосту свободна, узел %d" % index, {"finish": _point(game.player), "target": _point(target)})


## Пересекает первую переправу по физическим кадрам и проверяет слежение камеры без скачков героя.
func _review_bridge_and_camera() -> void:
	_reset_controls()
	game.current_location = "overworld"
	var maximum_step := 0.0
	for index in Village.BRIDGES.size():
		var bridge: Rect2 = Village.BRIDGES[index]
		var center := bridge.get_center()
		game.player = Vector2(center.x, bridge.end.y + Village.CELL)
		game.update_camera()
		var finish := Vector2(center.x, bridge.position.y - Village.CELL)
		_key(KEY_W, true)
		for frame in 160:
			var before: Vector2 = game.player
			_advance()
			maximum_step = maxf(maximum_step, game.player.distance_to(before))
			if game.player.y <= finish.y: break
		_reset_controls()
		_check(game.player.y <= finish.y, "Мост %d проходим с берега на берег непрерывным движением" % (index + 1), {"bridge_center": _point(center), "finish": _point(game.player), "target": _point(finish)})
	_check(maximum_step <= game.speed * STEP + 0.01, "Физические кадры не добавляют скачок к скорости героя", {"max_step_px": maximum_step})
	var expected: Vector2 = game.CameraSystem.target_offset(game)
	_check(game.camera_offset == expected, "Камера после пересечения моста соответствует реальной позиции")


## Проходит участок видимой деревенской дороги между мостом и площадью, обнаруживая застревание у декора.
func _review_village_path() -> void:
	_reset_controls()
	game.current_location = "overworld"
	var bridge: Rect2 = Village.BRIDGES[0]
	game.player = Vector2(bridge.get_center().x, bridge.position.y - Village.CELL)
	game.update_camera()
	for index in [5, 6, 7]:
		var target: Vector2 = Village.PATHS[0][index]
		var reached := _walk_to(target, 200)
		_check(reached, "Видимая дорога от моста к площади свободна, узел %d" % index, {"finish": _point(game.player), "target": _point(target), "obstacle": game.NavigationSystem.walkability_reason(game, game.player + Vector2.RIGHT * 8.0)})
	_check(Village.SQUARE.has_point(game.player), "Путь приводит внутрь деревенской площади")


## Проходит северную тропу и входит в пещеру автоматическим переходом, не телепортируя героя внутрь.
func _review_cave_approach() -> void:
	_reset_controls()
	game.current_location = "overworld"
	game.location_transition_armed = true
	game.location_transition_cooldown = 0.0
	for index in [6, 5, 4]:
		var target: Vector2 = Village.PATHS[0][index]
		_check(_walk_to(target, 200), "Обратный путь от площади к северной тропе свободен, узел %d" % index, {"finish": _point(game.player), "target": _point(target)})
	var bend: Vector2 = Village.PATHS[6][1]
	_check(_walk_to(bend, 150), "Северная тропа от моста до поворота пещеры проходима", {"target": _point(bend), "finish": _point(game.player)})
	var reached := _walk_to(Village.CAVE_ENTRANCE, 180, "cave")
	_check(reached and game.current_location == "cave", "Вход в пещеру срабатывает от обычного движения по тропе", {"finish": _point(game.player), "location": game.current_location})


## Открывает рюкзак клавиатурой, проверяет остановку героя и закрывает окно настоящим нажатием на крестик.
func _review_inventory_controls() -> void:
	_reset_controls()
	var tab := _event(KEY_TAB, true)
	game._input(tab)
	game._unhandled_input(tab)
	_check(game.inventory_open, "TAB открывает рюкзак через игровой обработчик ввода")
	var before: Vector2 = game.player
	_key(KEY_D, true)
	for frame in 12: _advance()
	_check(game.player == before and not game.PlayerSystem.is_visually_moving(game), "Открытый рюкзак останавливает движение и анимацию ног")
	_reset_controls()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.ItemWindowRenderer.close_button_rect(game).get_center()
	game._input(click)
	_check(not game.inventory_open, "Нажатие на видимый крестик закрывает рюкзак")
	game.inventory_open = false


## Проверяет касание стены и скольжение вдоль неё в той же сцене и теми же обработчиками клавиатуры.
func _review_collision_and_animation() -> void:
	_reset_controls()
	game.current_location = game.DebugPlaygroundSystem.LOCATION
	game.DebugPlaygroundSystem.configure(game)
	game.player = Vector2(690 - game.PLAYER_RADIUS, 320)
	_key(KEY_D, true)
	game.update_player_movement(STEP)
	_check(not game.PlayerSystem.is_visually_moving(game), "При упоре в стену герой не бежит на месте")
	_key(KEY_S, true)
	var before: Vector2 = game.player
	game.update_player_movement(STEP)
	_check(game.player.y > before.y and game.facing == Vector2.DOWN and game.PlayerSystem.is_visually_moving(game), "При скольжении анимация смотрит по фактическому направлению")
	_reset_controls()
	game.current_location = "overworld"


## Ведёт героя к точке восьминаправленным вводом и прекращает попытку при превышении числа физических кадров.
func _walk_to(target: Vector2, limit: int, arrival_location: String = "") -> bool:
	var origin: Vector2 = game.player
	var direction := origin.direction_to(target)
	var length := origin.distance_to(target)
	for frame in limit:
		if not arrival_location.is_empty() and game.current_location == arrival_location:
			_reset_controls()
			return true
		var difference: Vector2 = target - game.player
		if difference.length() < 5.0:
			_reset_controls()
			return true
		# Короткая упреждающая точка чередует реальные стороны/диагонали вдоль дороги, а не срезает берег под 45°.
		var along: float = clampf((game.player - origin).dot(direction) + 18.0, 0.0, length)
		var steering: Vector2 = origin + direction * along - game.player
		_key(KEY_A, steering.x < -1.5)
		_key(KEY_D, steering.x > 1.5)
		_key(KEY_W, steering.y < -1.5)
		_key(KEY_S, steering.y > 1.5)
		_advance()
	_reset_controls()
	return false


## Выполняет полный физический цикл игры с фиксированным шагом без зависимости от частоты машины проверяющего.
func _advance() -> void:
	game._physics_process(STEP)
	simulated_frames += 1


## Посылает событие изменения клавиши через обработчик игры, исключая искусственный key repeat.
func _key(code: Key, pressed: bool) -> void:
	if bool(held.get(code, false)) == pressed: return
	held[code] = pressed
	game._input(_event(code, pressed))


## Создаёт физическое клавиатурное событие, совпадающее с обычным вводом пользователя.
func _event(code: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


## Отпускает направления перед сменой сценария и очищает транзитное состояние движения.
func _reset_controls() -> void:
	for code in MOVEMENT_KEYS: _key(code, false)
	game.clear_movement_keys()
	held.clear()


## Добавляет проверяемое наблюдение и его фактические значения в отчёт.
func _check(passed: bool, description: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "description": description, "details": details})
	print("%s: %s" % ["PASS" if passed else "FAIL", description])


## Представляет координаты обычным JSON-массивом для анализа маршрутов и сравнения отчётов.
func _point(value: Vector2) -> Array:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]


## Сохраняет воспроизводимый отчёт и возвращает ненулевой код при любой найденной проблеме.
func _finish() -> void:
	var failed := checks.filter(func(entry): return not entry.passed).size()
	var result := {"schema": 2, "engine": Engine.get_version_info().string, "map_revision": Village.REVISION, "world_seed": 20260908, "simulation_hz": 60, "simulated_frames": simulated_frames, "passed": checks.size() - failed, "failed": failed, "checks": checks}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Не удалось сохранить отчёт проверки комфорта игры")
		quit(2)
		return
	output.store_string(JSON.stringify(result, "  ") + "\n")
	output.close()
	print("RUNTIME COMFORT: %d passed, %d failed" % [checks.size() - failed, failed])
	game.queue_free()
	quit(0 if failed == 0 else 1)

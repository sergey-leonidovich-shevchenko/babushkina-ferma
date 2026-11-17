extends "res://tests/suites/suite_base.gd"

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Water := preload("res://scripts/systems/water_map_registry.gd")
const WaterLayout := preload("res://scripts/systems/water_layout_data.gd")
const Background := preload("res://scripts/world_background.gd")
const Surface := preload("res://scripts/presentation/village_water_surface.gd")
const GroundClock := preload("res://scripts/presentation/village_ground_clock.gd")
const DebugOverlay := preload("res://scripts/systems/debug_overlay_system.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Fishing := preload("res://scripts/systems/fishing_system.gd")

const VIEW_SIZE := Vector2i(1152, 648)
const CAMERA := Vector2(264, 144)
const ZOOM := 1.2
const WATER_SECONDS := 1.25
const SAVE_FIXTURE := "res://tests/fixtures/saves/v1-core.json"
const CUSTOM_USER_DIR := "application/config/use_custom_user_dir"
const USER_DIR_NAME := "application/config/custom_user_dir_name"
const SETTINGS_FILE := "farm-settings.cfg"
const SAVE_FILE := "farm-save.json"


## Временно отделяет пробные слоты и оба игровых экземпляра от профиля процесса.
func run() -> void:
	var previous_dir := OS.get_user_data_dir()
	var previous_setting: Variant = ProjectSettings.get_setting(CUSTOM_USER_DIR)
	var previous_name: Variant = ProjectSettings.get_setting(USER_DIR_NAME)
	var profile := "Codex-VCOMPAT-005-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	ProjectSettings.set_setting(CUSTOM_USER_DIR, true)
	ProjectSettings.set_setting(USER_DIR_NAME, profile)
	var control_dir := OS.get_user_data_dir()
	var owned := (
		control_dir != previous_dir
		and not DirAccess.dir_exists_absolute(control_dir)
		and DirAccess.make_dir_recursive_absolute(control_dir) == OK
	)
	expect(owned, "a fresh directory owns the dummy user files")
	if owned:
		_run_with_dummy_slots(previous_dir, control_dir, profile + "-replay")
	ProjectSettings.set_setting(USER_DIR_NAME, previous_name)
	ProjectSettings.set_setting(CUSTOM_USER_DIR, previous_setting)
	expect(
		OS.get_user_data_dir() == previous_dir,
		"the preceding user directory is restored for other suites",
	)


## Оставляет старые настройки и два слота в контрольном профиле и сравнивает их байты после запуска.
func _run_with_dummy_slots(
	previous_dir: String, control_dir: String, replay_profile: String
) -> void:
	var legacy := FileAccess.get_file_as_string(SAVE_FIXTURE)
	var expected := {
		SETTINGS_FILE: "[meta]\nschema_version=1\n[accessibility]\nreduced_motion=true\n",
		SAVE_FILE: legacy,
		SAVE_FILE + ".bak": legacy + "\n",
	}
	var prepared := true
	for filename: String in expected:
		var file := FileAccess.open(control_dir.path_join(filename), FileAccess.WRITE)
		if file == null:
			prepared = false
			continue
		var contents: String = expected[filename]
		file.store_string(contents)
		file.close()
	expect(prepared, "the dummy settings, primary and backup slots were created")

	ProjectSettings.set_setting(USER_DIR_NAME, replay_profile)
	var effective := OS.get_user_data_dir()
	var isolated := (
		effective != previous_dir
		and effective != control_dir
		and not DirAccess.dir_exists_absolute(effective)
		and (
			ProjectSettings.globalize_path("user://" + SETTINGS_FILE)
			== effective.path_join(SETTINGS_FILE)
		)
	)
	expect(isolated, "both scenes use a fresh user directory before entering the tree")
	if prepared and isolated:
		_compare_graphics_profiles()

	for filename: String in expected:
		var path := control_dir.path_join(filename)
		var contents: String = expected[filename]
		expect(
			FileAccess.get_file_as_bytes(path) == contents.to_utf8_buffer(),
			"the dummy %s keeps its exact original bytes" % filename,
		)
		DirAccess.remove_absolute(path)
	expect(DirAccess.remove_absolute(control_dir) == OK, "the owned fixture is removed")


## Сценарий: одинаковые команды вводятся в две сцены со статичной и анимированной водой.
## Исходное состояние: общий legacy JSON, один seed, камера, масштаб и размеры viewport.
## Ожидаемый результат: материалы различаются, а маршруты, рыбалка и игровые поля совпадают.
func _compare_graphics_profiles() -> void:
	var traces: Array[Dictionary] = []
	for animated: bool in [true, false]:
		var viewport := SubViewport.new()
		viewport.size = VIEW_SIZE
		viewport.disable_3d = true
		context.root.add_child(viewport)
		var game := Points.create_game() as GameScript
		viewport.add_child(game)
		expect(
			game.menu_state.title_selected == 1 and not game.settings_state.reduced_motion,
			"bootstrap sees neither the dummy save slots nor the dummy accessibility setting",
		)
		var camera_point: Dictionary = Points.registry().points[0]
		Points.configure(game, camera_point)
		traces.append(_replay(game, animated))
		viewport.free()
	expect(traces[0] == traces[1], "the two water profiles have identical gameplay traces")


## Загружает прежний формат и воспроизводит ходьбу и забросы с общим порядком действий.
func _replay(game: GameScript, animated: bool) -> Dictionary:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FIXTURE))
	legacy["location"] = "overworld"
	legacy["player"] = [1008, 720]
	if not game.SaveSystem.apply(game, legacy):
		expect(false, "the production loader accepts the version-one save")
		return {}
	expect(
		not Water.blocks("overworld", game.player, game.PLAYER_RADIUS),
		"the old player position is repaired out of the current water cells",
	)
	var legacy_coins: int = legacy.coins
	var legacy_wood: int = legacy.counts.wood
	expect(game.coins == legacy_coins, "the old save keeps money through migration")
	expect(game.inventory_item_count("wood") == legacy_wood, "the old save keeps its inventory")
	var loaded: Dictionary = game.SaveSystem.snapshot(game)
	_apply_profile(game, animated)
	expect(
		loaded == game.SaveSystem.snapshot(game),
		"changing the material and fixing the camera preserve the complete loaded save",
	)
	game.state.world.estate.event = ""
	game.enemy_nodes.clear()
	game.hazard_nodes.clear()
	game.slime_alive = false
	var routes := _walk(game)

	game.has_fishing_rod = true
	game.change_inventory_count("fishing_bait", 3)
	var casts: Array[Dictionary] = []
	casts.append(_cast(game, WaterLayout.HOME_BRIDGES[0].get_center(), "river"))
	casts.append(_cast(game, Vector2(1992, 888), "pond"))
	game.player = Vector2(396, 600)
	var bait := game.inventory_item_count("fishing_bait")
	var durability: Dictionary = game.state.inventory.durability.duplicate(true)
	expect(not Fishing.use_rod(game), "a dry field outside casting range does not start fishing")
	expect(
		(
			game.inventory_item_count("fishing_bait") == bait
			and game.state.inventory.durability == durability
			and game.state.fishing.phase == "idle"
		),
		"a rejected cast keeps consumables and leaves fishing idle",
	)
	expect(game.camera_offset == CAMERA, "both replays keep the camera fixed after migration")
	expect(
		(
			is_equal_approx(WorldProjection.zoom(game), ZOOM)
			and game.get_viewport().get_visible_rect().size == Vector2(VIEW_SIZE)
			and game.world_loot_seed == Points.SEED
		),
		"both replays keep the recorded zoom, viewport size and world seed",
	)
	return {
		"camera": game.camera_offset,
		"zoom": WorldProjection.zoom(game),
		"size": game.get_viewport().get_visible_rect().size,
		"seed": game.world_loot_seed,
		"loaded": loaded,
		"routes": routes,
		"casts": casts,
		"saved": game.SaveSystem.snapshot(game),
	}


## Прогоняет обычное обновление WorldBackground при смене настройки уменьшенного движения.
func _apply_profile(game: GameScript, animated: bool) -> void:
	WorldProjection.set_reference_zoom(game, ZOOM)
	game.camera_offset = CAMERA
	WorldProjection.sync_background(game)
	var background := game.get_node("WorldBackground") as Background
	var visual: Surface = background.water_surface
	var river := visual.get_node("RiverCurrent") as Node2D
	# В headless нет GPU-кадра, который обычно открывает подготовленный слой воды.
	if DisplayServer.get_name() == "headless":
		background.water_layer.show()
	game.set_meta(GroundClock.META, WATER_SECONDS)
	game.settings_state.reduced_motion = false
	background._process(0.0)
	expect(
		river.material is ShaderMaterial and visual.material is ShaderMaterial,
		"normal WorldBackground updates shader materials for the river and pond",
	)
	game.settings_state.reduced_motion = not animated
	background._process(0.0)
	if animated:
		expect(
			river.material is ShaderMaterial and visual.material is ShaderMaterial,
			"river and pond keep their shaders with normal motion",
		)
	else:
		expect(
			river.material == null and visual.material == null,
			"reduced motion removes both shaders through the same production update",
		)


## Пропускает один и тот же радиус героя через два настила и останавливает его на берегах.
func _walk(game: GameScript) -> Dictionary:
	var bridges: Array[Vector2] = []
	for deck: Rect2 in WaterLayout.HOME_BRIDGES:
		var center := deck.get_center()
		var start := center - Vector2(0, 72)
		game.player = start
		game.move_player_with_collisions(Vector2(0, 144))
		bridges.append(game.player)
		expect(
			game.player == center + Vector2(0, 72) and Water.has_surface("overworld", center),
			"the full body crosses the deck with water underneath",
		)
	var banks: Array[Dictionary] = []
	for point: Dictionary in [
		{"start": Vector2(396, 180), "direction": Vector2.DOWN},
		{"start": Vector2(2024, 888), "direction": Vector2.LEFT},
	]:
		var start: Vector2 = point.start
		var direction: Vector2 = point.direction
		var motion := direction * 144.0
		game.player = start
		game.move_player_with_collisions(motion)
		var stopped: Vector2 = game.player
		expect(_is_bank_stop(game, start, motion), "the body stops on dry ground before water")
		game.move_player_with_collisions(direction * 8.0)
		expect(game.player == stopped, "the next attempted step still stops at the bank")

		# Настоящий noclip выполняет ту же команду без коллизий как контроль ложного успеха.
		var debug := DebugOverlay.default_state()
		debug["noclip"] = true
		game.set_meta(DebugOverlay.META_KEY, debug)
		game.player = start
		game.move_player_with_collisions(motion)
		expect(
			game.player == start + motion and not _is_bank_stop(game, start, motion),
			"the same shore assertion rejects an actual noclip traverse",
		)
		game.remove_meta(DebugOverlay.META_KEY)
		game.player = stopped
		banks.append({"position": stopped, "next_step": direction * 8.0})
	return {"bridges": bridges, "banks": banks}


## Требует частичного перемещения и сухого места для полного тела перед блокирующей водой.
func _is_bank_stop(game: GameScript, start: Vector2, motion: Vector2) -> bool:
	var direction := motion.normalized()
	var traveled: float = (game.player - start).dot(direction)
	var next: Vector2 = game.player + direction * 8.0
	var reason: String = game.NavigationSystem.walkability_reason(game, next)
	return (
		traveled > 0.0
		and traveled < motion.length()
		and not Water.blocks(game.current_location, game.player, game.PLAYER_RADIUS)
		and reason == "water"
	)


## Проверяет точку, тип водоёма и расход при одном забросе удочки.
func _cast(game: GameScript, start: Vector2, expected_kind: String) -> Dictionary:
	game.player = start
	var bait := game.inventory_item_count("fishing_bait")
	var durability: int = game.state.inventory.durability.fishing_rod
	game.action_held = true
	var began := Fishing.use_rod(game)
	game.state.fishing.cast_power = 0.5
	game.action_held = false
	Fishing.update(game, 0.016)
	var target := Fishing.bobber_position(game)
	var geometry := Water.geometry("overworld")
	expect(
		(
			began
			and target.is_finite()
			and geometry.kind_at(target) == expected_kind
			and not geometry.on_bridge(target)
			and game.state.fishing.phase == "waiting"
		),
		"the released bobber belongs to the expected water body away from the deck",
	)
	var remaining_bait := game.inventory_item_count("fishing_bait")
	var remaining_durability: int = game.state.inventory.durability.fishing_rod
	var water_kind: String = game.state.fishing.water_kind
	var result := {
		"target": target,
		"kind": water_kind,
		"phase": game.state.fishing.phase,
		"bait": remaining_bait,
		"durability": remaining_durability,
	}
	expect(
		(
			water_kind == expected_kind
			and remaining_bait == bait - 1
			and remaining_durability == durability - 1
		),
		"each successful cast costs one bait and one point of durability",
	)
	Fishing.cancel(game)
	return result

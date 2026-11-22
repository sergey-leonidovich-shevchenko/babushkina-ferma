# Динамический игровой фасад и SceneTree.expect проверяются реальными игровыми suites.
@warning_ignore_start("untyped_declaration", "unsafe_method_access", "unsafe_property_access")
extends RefCounted

const Version := preload("res://scripts/presentation/visual_version.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const Store := preload("res://scripts/systems/atomic_json_store.gd")
const Editor := preload("res://scripts/systems/level_editor_system.gd")
const Published := preload("res://scripts/systems/published_level_system.gd")
const Wind := preload("res://scripts/presentation/foliage_wind.gd")
const CaptureCases := preload("res://tools/qa/world/rollback/cases.gd")
const Rng := preload("res://scripts/systems/world_rng_system.gd")
const PATH := "user://vcompat-010-save.json"
const LEVEL := "user://level_designs/vcompat_010_user_level.json"
const SETTINGS := "user://vcompat-010-settings.cfg"


## Проверяет обратимость на настоящих игровых владельцах и документах, не обращаясь к обычным
## слотам.
static func run(ctx: SceneTree) -> void:
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	_flags(ctx)
	_legacy(ctx)
	_levels(ctx)
	_replay(ctx)
	_capture_factory(ctx)
	for path: String in [PATH, LEVEL, SETTINGS]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


## Один общий выключатель не меняет адресные настройки и не распространяется на соседний
## игровой мир.
static func _flags(ctx: SceneTree) -> void:
	var a := _game()
	var b := _game()
	a.settings_state.reduced_motion = false
	var before := Save.snapshot(a)
	ctx.expect(a.SettingsSystem.save(a, SETTINGS), "test settings file uses the real config writer")
	var settings := FileAccess.get_sha256(SETTINGS)
	ctx.expect(Wind.allowed(a), "wind is actually eligible before the master rollback")
	var background := a.get_node("WorldBackground")
	background.joined_roads = false
	var child := Node2D.new()
	background.add_child(child)
	for iteration in 12:
		Version.set_enabled(a, false)
		ctx.expect(
			not Version.enabled(a) and not Version.enabled(child),
			"master rollback reaches its own nested canvas"
		)
		ctx.expect(Version.enabled(b), "rollback leaves the independent game enabled")
		ctx.expect(
			not preload("res://scripts/presentation/garden_soil.gd").enabled(a),
			"legacy farm soil uses the actual old drawing path"
		)
		ctx.expect(
			not preload("res://scripts/presentation/pilot_object_pass.gd").enabled(a),
			"master disables the real command replay"
		)
		ctx.expect(
			not preload("res://scripts/presentation/daylight_palette.gd").enabled(a),
			"master restores legacy daylight"
		)
		ctx.expect(not Wind.allowed(a), "master rejects new foliage material")
		ctx.expect(Save.snapshot(a) == before, "off preserves complete gameplay snapshot")
		Version.set_enabled(a, true)
		ctx.expect(
			Version.enabled(a) and not background.joined_roads,
			"return retains a pre-existing individual false setting"
		)
		ctx.expect(Save.snapshot(a) == before, "on preserves complete gameplay snapshot")
	for invalid in ["false", "true", 0, 1, {}, []]:
		Version.set_enabled(a, invalid)
		ctx.expect(not Version.enabled(a), "corrupt master flag falls back safely: " + str(invalid))
	Version.set_enabled(a, false)
	a.current_location = "cottage_interior"
	ctx.expect(Version.enabled(a), "first-map rollback keeps interior presentation unchanged")
	a.current_location = "overworld"
	a.remove_meta(Version.FLAG)
	var original: Variant = ProjectSettings.get_setting(Version.SETTING, true)
	ProjectSettings.set_setting(Version.SETTING, false)
	ctx.expect(
		not Version.enabled(a) and not Version.enabled(b),
		"startup project flag is effective without per-game metadata"
	)
	Version.set_enabled(a, true)
	ctx.expect(
		Version.enabled(a) and not Version.enabled(b),
		"local QA override remains scoped to its owner"
	)
	ProjectSettings.set_setting(Version.SETTING, original)
	ctx.expect(
		FileAccess.get_sha256(SETTINGS) == settings, "toggle never touches the settings source file"
	)
	ctx.expect(
		a.SettingsSystem.save(a, SETTINGS) and FileAccess.get_sha256(SETTINGS) == settings,
		"accessibility and display values serialize identically after rollback"
	)
	child.free()
	a.free()
	b.free()


## Оба профиля читают и записывают те же старые JSON без миграции графических полей.
static func _legacy(ctx: SceneTree) -> void:
	for name: String in ["v1-core", "v2-production", "v2-orchard-alchemy"]:
		var source := "res://tests/fixtures/saves/" + String(name) + ".json"
		var hash_before := FileAccess.get_sha256(source)
		var game := _game()
		ctx.expect(Save.load_at(game, source), "real legacy JSON loads: " + name)
		var expected: Dictionary = JSON.parse_string(JSON.stringify(Save.snapshot(game)))
		for modern in [false, true, false]:
			Version.set_enabled(game, modern)
			ctx.expect(Save.save_at(game, PATH), "old progress saves under either visual version")
			ctx.expect(
				Store.read(PATH) == expected,
				"actual saved document contains exactly the same gameplay"
			)
			var clone := _game()
			Version.set_enabled(clone, not modern)
			ctx.expect(
				Save.load_at(clone, PATH), "other presentation version reloads the saved progress"
			)
			ctx.expect(
				JSON.parse_string(JSON.stringify(Save.snapshot(clone))) == expected,
				"all legacy fields survive cross-profile round trip"
			)
			clone.free()
		ctx.expect(
			FileAccess.get_sha256(source) == hash_before,
			"original legacy fixture bytes remain unchanged"
		)
		game.free()


## Сохраняет и заново читает настоящий черновик с авторскими заметками, коллизией и runtime-ролями.
static func _levels(ctx: SceneTree) -> void:
	var game := _game()
	var state := Editor.default_state(game)
	state.level_name = "vcompat_010_user_level"
	state.level_notes = "Author notes survive both render paths"
	Editor.activate_asset(
		state,
		Editor.AssetCatalogSystem.metadata("res://assets/game/tiles/editor/terrain/grass_lush.png")
	)
	for point: Vector2 in [Vector2(492, 300), Vector2(684, 300), Vector2(588, 396)]:
		ctx.expect(
			Editor.place_selected_asset(game, state, point, false),
			"actual authoring places a level object"
		)
	state.objects[0].runtime_role = "spawn"
	state.objects[1].runtime_role = "exit"
	state.objects[2].collision = true
	state.objects[2].notes = "Keep this obstacle and its authored source"
	var before := Editor.document(state)
	ctx.expect(
		Editor.save_draft(game, state, false),
		"user level is written through the production document store"
	)
	var hash_before := FileAccess.get_sha256(LEVEL)
	for modern in [false, true, false, true]:
		Version.set_enabled(game, modern)
		ctx.expect(Editor.document(state) == before, "toggle keeps every authored object field")
		var restored := Editor.default_state(game)
		ctx.expect(
			Editor.load_draft(game, restored, LEVEL),
			"same user draft loads under either presentation"
		)
		ctx.expect(
			Editor.document(restored) == before,
			"notes, paths, roles, positions and collisions reload intact"
		)
		ctx.expect(
			FileAccess.get_sha256(LEVEL) == hash_before,
			"rollback never rewrites the user's source file"
		)
		ctx.expect(
			game.PublishedLevelSystem.start_playtest(game, restored, before, LEVEL),
			"authored level starts a real runtime playtest"
		)
		var runtime: Dictionary = game.get_meta(Published.META_KEY)
		ctx.expect(
			runtime.objects == restored.objects, "playtest retains all compiled author objects"
		)
		ctx.expect(
			game.PublishedLevelSystem.finish_playtest(game, false),
			"playtest returns to the same editor"
		)
		ctx.expect(
			Editor.document(restored) == before, "playtest return preserves the author document"
		)
	game.free()


## Одинаковый ввод и seed продвигают настоящий мир одинаково при разных визуальных версиях.
static func _replay(ctx: SceneTree) -> void:
	var a := _game()
	var b := _game()
	var initial := Save.snapshot(a)
	ctx.expect(
		Save.apply(a, initial) and Save.apply(b, initial),
		"replay starts with identical complete game state"
	)
	Version.set_enabled(a, true)
	Version.set_enabled(b, false)
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.ZERO]:
		var outputs := []
		for game: Node2D in [a, b]:
			seed(7200)
			game.clear_movement_keys()
			game.move_left_held = direction.x < 0
			game.move_right_held = direction.x > 0
			game.move_up_held = direction.y < 0
			game.move_down_held = direction.y > 0
			for step in 5:
				game._physics_process(1.0 / 30.0)
			outputs.append(Save.snapshot(game))
		ctx.expect(outputs[0] == outputs[1], "actual gameplay and RNG agree with master on/off")
	ctx.expect(
		a.game_minutes != initial.minutes,
		"replay advances simulation rather than comparing static fixtures"
	)
	a.free()
	b.free()


## Создаёт только изолированную настоящую сцену с известной камерой и одинаковым seed.
static func _game() -> Node2D:
	var game := Points.create_game() as Node2D
	game._ready()
	var point: Dictionary = Points.registry().points[0]
	Points.configure(game, point)
	game.WorkshopSystem.state(game, "pottery")
	return game


## Проверяет настоящий set_script/add_child/_ready до съёмки, включая оба окна и холодные флаги.
static func _capture_factory(ctx: SceneTree) -> void:
	var previous_setting: Variant = ProjectSettings.get_setting(Version.SETTING, true)
	var previous_size := ctx.root.size
	for width: int in [1152, 1280]:
		ctx.root.size = Vector2i(width, int(width * 9.0 / 16.0))
		var snapshots := []
		for modern: bool in [false, true]:
			ProjectSettings.set_setting(Version.SETTING, modern)
			var game := CaptureCases.create(ctx.root)
			ctx.expect(game.is_node_ready(), "capture factory executes the real ready lifecycle")
			ctx.expect(
				game.world_loot_seed == Points.SEED,
				"capture seed survives script replacement before ready"
			)
			ctx.expect(
				Rng.valid(game.state.world.rng_state, Points.SEED),
				"capture RNG belongs to the fixed world seed"
			)
			ctx.expect(
				Version.enabled(game) == modern and not game.has_meta(Version.FLAG),
				"capture factory respects cold project flags without local metadata"
			)
			snapshots.append(Save.snapshot(game))
			game.free()
		ctx.expect(
			snapshots[0] == snapshots[1],
			"independent capture factories produce identical complete gameplay"
		)
	ProjectSettings.set_setting(Version.SETTING, previous_setting)
	ctx.root.size = previous_size

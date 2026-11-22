extends "res://tests/suites/suite_base.gd"

const Quality := preload("res://scripts/presentation/lighting_quality.gd")
const Palette := preload("res://scripts/presentation/daylight_palette.gd")
const Save := preload("res://scripts/systems/save_system.gd")
const Version := preload("res://scripts/presentation/visual_version.gd")
const Buildings := preload("res://scripts/systems/building_system.gd")
const Audio := preload("res://scripts/systems/audio_system.gd")
const Menus := preload("res://scripts/systems/menu_system.gd")


## Проверяет независимость владельцев, наследование и полную сохранность игрового снимка.
func run() -> void:
	var first := make_game() as Node2D
	var second := make_game() as Node2D
	first.set("current_location", "overworld")
	second.set("current_location", "overworld")
	var child := Node2D.new()
	first.add_child(child)
	var before: Dictionary = Save.snapshot(first)
	var peer_before: Dictionary = Save.snapshot(second)
	expect(Quality.profile(first) == Quality.STANDARD, "lighting defaults to accepted standard")
	Quality.set_profile(first, Quality.LOW)
	expect(Quality.profile(child) == Quality.LOW, "world child inherits only its own owner profile")
	expect(Quality.profile(second) == Quality.STANDARD, "other viewport retains standard light")
	Quality.set_profile(child, Quality.STANDARD)
	expect(
		Quality.profile(child) == Quality.STANDARD, "explicit child standard overrides parent low"
	)
	child.remove_meta(Quality.META)
	expect(Quality.profile(child) == Quality.LOW, "removing child override restores inheritance")
	first.set_meta(Version.FLAG, false)
	expect(
		Quality.profile(child) == Quality.STANDARD,
		"common visual rollback preserves legacy lighting"
	)
	var requested: StringName = first.get_meta(Quality.META)
	expect(requested == Quality.LOW, "rollback retains component's requested low profile")
	first.remove_meta(Version.FLAG)
	expect(
		Quality.profile(child) == Quality.LOW,
		"enabling new visuals restores the requested low profile"
	)
	_test_tints(first)
	_test_values(first)
	for location: String in ["cave", "moon_glade", "village_market", "cellar_workshop"]:
		first.set("current_location", location)
		Quality.set_profile(first, Quality.OFF)
		expect(
			Quality.profile(first) == Quality.STANDARD and Quality.decorative_enabled(child),
			"unrelated location retains its existing lighting: " + location
		)
	first.set("current_location", "overworld")
	Quality.set_profile(first, Quality.STANDARD)
	expect(Save.snapshot(first) == before, "light profiles do not change full gameplay save")
	expect(Save.snapshot(second) == peer_before, "peer save remains byte-equivalent data")
	first.free()
	second.free()
	_test_saved_routes()


## Проверяет плавную календарную кривую и точный standard без повторения draw-реализации.
func _test_tints(owner: Node2D) -> void:
	for minute: float in [0.0, 300.0, 360.0, 420.0, 720.0, 1080.0, 1140.0, 1200.0, 1439.75]:
		var accepted := Palette.tint(minute)
		Quality.set_profile(owner, Quality.STANDARD)
		expect(Quality.tint(owner, accepted) == accepted, "standard preserves accepted tint")
		Quality.set_profile(owner, Quality.LOW)
		var low := Quality.tint(owner, accepted)
		expect(
			low.r == accepted.r and low.g == accepted.g and low.b == accepted.b,
			"low keeps the accepted calendar hue"
		)
		expect(low.a <= accepted.a, "low never darkens a target more than standard")
		if accepted.a > 0.0:
			expect(low.a > 0.0 and low.a < accepted.a, "low retains atmosphere with less dimming")
		Quality.set_profile(owner, Quality.OFF)
		expect(Quality.tint(owner, accepted) == Color.TRANSPARENT, "off removes only lighting tint")
	Quality.set_profile(owner, Quality.LOW)
	expect(
		Quality.tint(owner, Palette.tint(1140.25)) != Quality.tint(owner, Palette.tint(1140.0)),
		"low keeps fractional-minute transitions"
	)
	expect(not Quality.decorative_enabled(owner), "low skips optional lighting passes")
	Quality.set_profile(owner, Quality.STANDARD)
	expect(Quality.decorative_enabled(owner), "restoring standard restores optional light")


## Неверные типы и незнакомые строки не превращаются в неявное выключение.
func _test_values(owner: Node2D) -> void:
	for invalid: Variant in [null, true, false, 0, 1, {}, [], "LOW", "unexpected"]:
		owner.set_meta(Quality.META, invalid)
		expect(Quality.profile(owner) == Quality.STANDARD, "invalid metadata selects standard")
		Quality.set_profile(owner, invalid)
		expect(Quality.profile(owner) == Quality.STANDARD, "invalid API value selects standard")
	owner.set("current_location", "cottage_interior")
	Quality.set_profile(owner, "low")
	expect(Quality.profile(owner) == Quality.LOW, "existing home supports low light regression")
	Quality.set_profile(owner, "off")
	expect(not Quality.decorative_enabled(owner), "home off skips its optional window ray")
	owner.set("current_location", "overworld")


## Загружает реальные старые JSON и делает настоящую запись/чтение только своего тестового файла.
func _test_saved_routes() -> void:
	for name: String in ["v1-core", "v2-production", "v2-orchard-alchemy"]:
		var source := "res://tests/fixtures/saves/" + name + ".json"
		var original_hash := FileAccess.get_sha256(source)
		var game := make_game() as Node2D
		Audio.set_enabled(game, false)
		expect(Save.load_at(game, source), "actual legacy slot loads for light profiles: " + name)
		var expected := _snapshot(game)
		var path := "user://vlight-010-%d-%d.json" % [Time.get_ticks_usec(), game.get_instance_id()]
		for selected: StringName in [Quality.LOW, Quality.OFF, Quality.STANDARD]:
			Quality.set_profile(game, selected)
			expect(_snapshot(game) == expected, "profile keeps the complete migrated legacy data")
			expect(Save.save_at(game, path), "actual legacy progress writes under light profile")
			var loaded := make_game() as Node2D
			expect(Save.load_at(loaded, path), "actual profile save reloads into a separate owner")
			expect(
				_snapshot(loaded) == expected,
				"all legacy progress survives actual profile round trip"
			)
			expect(
				not loaded.has_meta(Quality.META),
				"temporary light profile never enters a saved slot"
			)
			loaded.free()
		game.free()
		for suffix: String in ["", ".tmp", ".bak"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
		expect(
			FileAccess.get_sha256(source) == original_hash,
			"original legacy fixture stays byte-exact"
		)
	var visitor := make_game() as Node2D
	Audio.set_enabled(visitor, false)
	visitor.set("current_location", "overworld")
	Quality.set_profile(visitor, Quality.LOW)
	expect(Buildings.enter(visitor, "cottage"), "ordinary cottage entry works under low lighting")
	expect(Quality.profile(visitor) == Quality.LOW, "low applies to the actual existing home")
	expect(Buildings.leave(visitor), "ordinary home exit works under low lighting")
	var location: String = visitor.get("current_location")
	expect(
		location == "overworld" and Quality.profile(visitor) == Quality.LOW,
		"ordinary return retains low profile in first overworld"
	)
	var menus: Menus.MenuState = visitor.get("menu_state")
	menus.pause_open = true
	var paused := _snapshot(visitor)
	Quality.set_profile(visitor, Quality.OFF)
	expect(
		menus.pause_open and _snapshot(visitor) == paused,
		"light switch does not unpause or alter paused gameplay"
	)
	visitor.free()


## Нормализует настоящий полный save тем же JSON-форматом, который используется на диске.
func _snapshot(game: Node) -> Dictionary:
	var result: Dictionary = JSON.parse_string(JSON.stringify(Save.snapshot(game)))
	return result

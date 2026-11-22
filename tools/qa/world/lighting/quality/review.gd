extends SceneTree

const Cases := preload("res://tools/qa/world/lighting/quality/cases.gd")
const Quality := preload("res://scripts/presentation/lighting_quality.gd")

var passed := 0
var failed := 0


## Отказывает до bootstrap игры, если движок открыл обычный пользовательский профиль.
func _initialize() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("Codex-VLIGHT-010-"):
		quit(2)
		return
	_run.call_deferred()


## Исполняет ту же профильную suite, которая подключена к полному Game-набору.
func _run() -> void:
	preload("res://tests/suites/lighting_quality_suite.gd").new(self).run()
	_test_capture_setup()
	print("LIGHTING QUALITY REVIEW: ", passed, " passed, ", failed, " failed")
	quit(0 if failed == 0 else 1)


## Исполняет настоящую фабрику и все ветки режимов до удалённой съёмки, без визуальной приёмки.
func _test_capture_setup() -> void:
	var baseline_modes := Cases.modes(true)
	var current_modes := Cases.modes(false)
	expect(
		baseline_modes.get_typed_builtin() == TYPE_STRING and baseline_modes == ["standard"],
		"baseline dispatch retains a typed standard-only array"
	)
	expect(
		(
			current_modes.get_typed_builtin() == TYPE_STRING
			and current_modes == ["standard", "low", "off"]
		),
		"candidate dispatch retains all three typed modes"
	)
	var game := Cases.create(root)
	for entry: Dictionary in Cases.ENTRIES:
		Cases.configure(game, entry)
		var before := Cases.state(game, false)
		expect(game.world_loot_seed == 20261015, "actual factory retains seed after script/_ready")
		for selected: String in current_modes:
			Cases.mode(game, selected, false)
			var after := Cases.state(game, false)
			var profile: String = after.profile
			expect(profile == selected, "capture invokes actual public light-profile API")
			expect(
				Quality.profile(game.get_node("WorldBackground")) == StringName(selected),
				"actual background inherits its owner's selected lighting"
			)
			var original_save: Dictionary = before.save
			var selected_save: Dictionary = after.save
			var original_geometry: Dictionary = before.geometry
			var selected_geometry: Dictionary = after.geometry
			var original_entities: Dictionary = before.entities
			var selected_entities: Dictionary = after.entities
			expect(
				(
					selected_save == original_save
					and selected_geometry == original_geometry
					and selected_entities == original_entities
				),
				"capture mode retains full fixture gameplay and camera"
			)
		var targets := Cases.targets(game)
		for target: String in ["door", "enemy", "resource"]:
			var bounds: Rect2 = targets[target]
			expect(bounds.has_area(), "actual production target has measured geometry: " + target)
	game.free()


## Создаёт настоящий game bootstrap только после проверки изолированного OS userdata.
func make_game() -> Node:
	var game := preload("res://scripts/game.gd").new()
	game._ready()
	preload("res://scripts/systems/locale_system.gd").set_locale("ru")
	game.language_screen = false
	game.title_screen = false
	return game


## Сохраняет каждое нарушенное условие в фактическом журнале без допуска по одному exit code.
func expect(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

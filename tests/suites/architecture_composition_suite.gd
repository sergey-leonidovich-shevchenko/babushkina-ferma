# SceneTree получает тестовый API expect() в реальном запускателе набора.
@warning_ignore_start(
	"untyped_declaration",
	"unsafe_call_argument",
	"unsafe_cast",
	"unsafe_method_access",
	"unsafe_property_access",
	"unsafe_void_return"
)
extends RefCounted


## Запускает контракты размеров и ответственности композиционных модулей.
static func run(context: SceneTree) -> void:
	test_composition_root_and_test_runner_stay_small(context)


## Сценарий: корень, отрисовщики и тестовый запуск сохраняют ограниченные ответственности.
## Исходное состояние: исходники фасадов, core-модулей и адаптеров читаются без сцены.
## Ожидаемый результат: каждый слой имеет отдельного владельца и строгий лимит размера.
static func test_composition_root_and_test_runner_stay_small(context: SceneTree) -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var core_source := FileAccess.get_file_as_string("res://scripts/game_core.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	var interface_source := FileAccess.get_file_as_string(
		"res://scripts/systems/interface_renderer.gd"
	)
	var input_source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	var inventory_input_source := FileAccess.get_file_as_string(
		"res://scripts/systems/inventory_input_system.gd"
	)
	var editor_source := FileAccess.get_file_as_string(
		"res://scripts/systems/level_editor_system.gd"
	)
	var editor_store := FileAccess.get_file_as_string(
		"res://scripts/editor/level_editor_document_store.gd"
	)
	var runner_source := FileAccess.get_file_as_string("res://tests/test_game.gd")
	context.expect(
		not game_source.contains("func draw_") and renderer_source.contains("func draw_world"),
		"composition root delegates all drawing to the renderer layer"
	)
	context.expect(
		_code_line_count(core_source) <= 750 and _code_line_count(renderer_source) <= 450,
		"composition and renderer stay below tightened size limits"
	)
	for module_name in [
		"game_bootstrap",
		"game_loop",
		"game_input_router",
		"game_interaction_router",
		"game_preview_bootstrap",
		"game_preview_controller",
		"game_unhandled_input_router",
	]:
		var module_source := FileAccess.get_file_as_string("res://scripts/core/%s.gd" % module_name)
		context.expect(
			not module_source.is_empty() and _code_line_count(module_source) <= 260,
			"bounded core module exists: %s" % module_name
		)
	context.expect(
		(
			core_source.contains("GameBootstrap.initialize")
			and core_source.contains("GameLoop.physics_process")
			and core_source.contains("GameInputRouter.route")
			and core_source.contains("GameInteractionRouter.perform")
		),
		"game core is a compatibility facade over explicit orchestration modules"
	)
	context.expect(
		(
			renderer_source.contains("InterfaceRenderer.draw(self)")
			and _code_line_count(interface_source) <= 300
		),
		"HUD and inventory rendering live in a bounded interface module"
	)
	context.expect(
		(
			renderer_source.contains("FarmRenderer.draw(self)")
			and (
				_code_line_count(
					FileAccess.get_file_as_string("res://scripts/presentation/farm_renderer.gd")
				)
				<= 180
			)
		),
		"farm visuals belong to a bounded presentation module"
	)
	context.expect(
		(
			editor_source.contains("DocumentStore.save_draft")
			and _code_line_count(editor_source) <= 420
			and _code_line_count(editor_store) <= 180
		),
		"level editor delegates JSON persistence to a bounded document store"
	)
	context.expect(
		(
			inventory_input_source.contains("func handle_mouse")
			and not input_source.contains("func handle_inventory_mouse")
			and not game_source.contains("func handle_inventory_mouse")
		),
		"inventory pointer behavior belongs to its dedicated input system"
	)
	context.expect(
		(
			_code_line_count(runner_source) < 80
			and runner_source.contains("CoreSuite.new(self).run()")
		),
		"test entry point only orchestrates bounded suites"
	)


## Считает исполняемые строки тем же способом, что обязательный архитектурный gate.
static func _code_line_count(source: String) -> int:
	var count := 0
	for line in source.split("\n"):
		if not line.strip_edges().is_empty() and not line.strip_edges().begins_with("#"):
			count += 1
	return count

extends RefCounted

const TEST_SAVE_PATH := "user://farm-refactor-test.json"


static func run(context: SceneTree) -> void:
	test_typed_state_is_the_source_of_truth(context)
	test_inventory_state_is_data_driven(context)
	test_input_actions_are_centralized(context)
	test_content_references_are_valid(context)
	test_composition_root_and_test_runner_stay_small(context)
	test_save_v2_migration_and_backup(context)
	test_presentation_calculations_are_pure(context)


static func test_typed_state_is_the_source_of_truth(context: SceneTree) -> void:
	var game: Node = context.make_game()
	game.player = Vector2(701, 419)
	game.player_hp = 73
	game.day = 8
	context.expect(game.state.player.position == Vector2(701, 419), "typed PlayerState owns the facade position")
	context.expect(game.state.player.hp == 73, "typed PlayerState owns RPG resources")
	context.expect(game.state.world.day == 8, "typed WorldState owns calendar data")
	game.state.player.hp = 61
	context.expect(game.player_hp == 61, "legacy scene facade reads the typed state without a copied value")
	game.free()


static func test_inventory_state_is_data_driven(context: SceneTree) -> void:
	var game: Node = context.make_game()
	context.expect(game.change_inventory_count("fiber", 4), "registered item count changes without a game facade match branch")
	context.expect(game.inventory_item_count("fiber") == 4 and game.state.inventory.count("fiber") == 4, "inventory facade and InventoryState share one count")
	context.expect(not game.change_inventory_count("unknown_item", 1), "unregistered item ids are rejected at the state boundary")
	var exported: Dictionary = game.export_inventory_counts()
	context.expect(exported.size() == game.state.inventory.counts.size() and exported.fiber == 4, "inventory export is generated from one catalog")
	game.free()


static func test_input_actions_are_centralized(context: SceneTree) -> void:
	var game: Node = context.make_game()
	for action in game.InputSystem.ACTION_BINDINGS:
		context.expect(InputMap.has_action(action), "InputMap registers action: %s" % action)
	context.expect(game.InputSystem.ACTION_BINDINGS.has("move_left") and game.InputSystem.ACTION_BINDINGS.has("use_item"), "movement and tool use share a rebindable action catalog")
	game.free()


static func test_content_references_are_valid(context: SceneTree) -> void:
	var game: Node = context.make_game()
	var errors: Array[String] = game.ContentRegistry.validate()
	context.expect(errors.is_empty(), "recipes loot quests spawns shops and tutorials reference valid catalog ids: %s" % [errors])
	context.expect(game.enemy_nodes == game.CombatSystem.SPAWNS and game.food_nodes == game.ForageSystem.SPAWNS, "feature systems own their default content instead of game.gd")
	game.free()


static func test_composition_root_and_test_runner_stay_small(context: SceneTree) -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	var interface_source := FileAccess.get_file_as_string("res://scripts/systems/interface_renderer.gd")
	var runner_source := FileAccess.get_file_as_string("res://tests/test_game.gd")
	context.expect(not game_source.contains("func draw_") and renderer_source.contains("func draw_world"), "composition root delegates all drawing to the renderer layer")
	context.expect(game_source.count("\n") + 1 <= 1100 and renderer_source.count("\n") + 1 <= 700, "composition and renderer stay below enforced size limits")
	context.expect(renderer_source.contains("InterfaceRenderer.draw(self)") and interface_source.count("\n") + 1 <= 300, "HUD and inventory rendering live in a bounded interface module")
	context.expect(runner_source.count("\n") + 1 < 80 and runner_source.contains("CoreSuite.new(self).run()"), "test entry point only orchestrates bounded suites")


static func test_save_v2_migration_and_backup(context: SceneTree) -> void:
	_cleanup_save_files()
	var game: Node = context.make_game()
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	context.expect(snapshot.version == 2 and snapshot.state_schema == "aggregate-v2", "new snapshots use typed-state save schema v2")
	var legacy := snapshot.duplicate(true)
	legacy.version = 1
	legacy.erase("state_schema")
	game.coins = 1
	context.expect(game.SaveSystem.apply(game, legacy) and game.coins == snapshot.coins, "v1 snapshot migrates to v2 before applying")
	game.coins = 91
	context.expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "first save is written through a validated temporary file")
	game.coins = 77
	context.expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "second atomic save succeeds and keeps the previous backup")
	var corrupt := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{broken json")
	corrupt.close()
	var restored: Node = context.make_game()
	context.expect(game.SaveSystem.load_at(restored, TEST_SAVE_PATH), "loader falls back to the last valid backup")
	context.expect(restored.coins == 91, "backup restores the previous complete save instead of partial data")
	game.free()
	restored.free()
	_cleanup_save_files()


static func test_presentation_calculations_are_pure(context: SceneTree) -> void:
	var game: Node = context.make_game()
	context.expect(game.PresentationSystem.animation_frame(560, 4, 140) == 0, "animation frame calculation wraps deterministically")
	context.expect(game.PresentationSystem.animation_frame(10, 0, 0) == 0, "animation frame calculation handles invalid content data")
	context.expect(game.PresentationSystem.discovery_card_rect() == game.discovery_card_rect(), "discovery layout has one presentation owner")
	game.free()


static func _cleanup_save_files() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix))

extends "res://tests/suites/suite_base.gd"


## Запускает сценарии получения топора, рубки, коллизий, восстановления, сохранения и обучения.
func run() -> void:
	test_axe_is_an_immediate_hotbar_tool()
	test_three_hits_fell_tree_and_give_wood()
	test_stump_grows_through_three_visible_stages()
	test_tree_collision_depends_on_growth_stage()
	test_tree_state_and_legacy_axe_are_saved_safely()
	test_tree_feature_has_audio_and_tutorial_coverage()


## Сценарий: новый герой сразу получает топор в седьмом быстром слоте и может удерживать действие.
## Исходное состояние: стандартный инвентарь, герой рядом со взрослым деревом, выбран слот клавишей 7.
## Ожидаемый результат: топор распознаётся инструментом, первое действие сразу наносит один удар.
func test_axe_is_an_immediate_hotbar_tool() -> void:
	var game := make_game()
	expect(game.inventory_item_count("axe") == 1 and game.hotbar_slots[6] == "axe", "new hero owns axe in quick slot seven")
	expect(game.InventorySystem.data("axe").tool == game.Tool.AXE, "axe catalog selects dedicated tool enum")
	game.select_hotbar(6); game.player = game.state.world.tree_nodes[0].position + Vector2(0, 28)
	var health_before: int = game.state.world.tree_nodes[0].health
	expect(game.InputSystem.perform_repeatable_action(game), "held action routes selected axe through shared tool input")
	expect(game.state.world.tree_nodes[0].health == health_before - 1, "held axe reacts without input delay")
	game.free()


## Сценарий: взрослое дерево выдерживает ровно три удара и выдаёт древесину за каждый успешный удар.
## Исходное состояние: герой с топором и полной энергией стоит внутри радиуса первого дерева.
## Ожидаемый результат: здоровье последовательно убывает, древесина и XP растут, после третьего удара остаётся пень.
func test_three_hits_fell_tree_and_give_wood() -> void:
	var game := _tree_game()
	var wood_before: int = game.wood
	var xp_before: int = game.player_xp
	for expected_health in [2, 1, 0]:
		expect(game.TreeSystem.chop_nearby(game), "axe hit is accepted while tree is grown")
		expect(game.state.world.tree_nodes[0].health == expected_health, "tree health matches hit count: %d" % expected_health)
	expect(game.state.world.tree_nodes[0].stage == 0, "third hit replaces grown tree with stump")
	expect(game.wood == wood_before + 3 and game.player_xp == xp_before + 3, "three hits grant three wood and three character XP")
	expect(game.energy == 9 and game.audio_last_sfx == "chop", "chopping spends one stamina and plays chop sound per hit")
	expect(game.tutorial_events_completed.has("tree_chop") and game.tutorial_events_completed.has("tree_fall"), "hits and felling complete dedicated tutorial steps")
	game.free()


## Сценарий: пень последовательно превращается в саженец, молодое и полностью восстановленное дерево.
## Исходное состояние: первое дерево срублено, таймер восстановления равен нулю.
## Ожидаемый результат: каждые десять секунд повышают стадию, через тридцать секунд здоровье полностью восстановлено.
func test_stump_grows_through_three_visible_stages() -> void:
	var game := _felled_tree_game()
	game.TreeSystem.update(game, 10.1)
	expect(game.state.world.tree_nodes[0].stage == 1, "stump becomes a sapling after first growth interval")
	game.TreeSystem.update(game, 10.0)
	expect(game.state.world.tree_nodes[0].stage == 1, "sapling waits instead of growing a collision through the player")
	game.player += Vector2(180, 0); game.TreeSystem.update(game, 0.1)
	expect(game.state.world.tree_nodes[0].stage == 2, "sapling becomes a young tree after second interval")
	game.TreeSystem.update(game, 10.0)
	expect(game.state.world.tree_nodes[0].stage == 3 and game.state.world.tree_nodes[0].health == game.TreeSystem.MAX_HEALTH, "young tree becomes a healthy adult after thirty seconds")
	expect(game.TreeSystem.regrow_progress(game.state.world.tree_nodes[0]) == 1.0 and game.tutorial_events_completed.has("tree_regrow"), "full regrowth fills progress and tutorial step")
	game.free()


## Сценарий: взрослый и молодой ствол блокируют проход, но низкий пень и саженец проходимы.
## Исходное состояние: одна и та же точка коллизии проверяется на четырёх стадиях дерева.
## Ожидаемый результат: геометрия меняется вместе с видимой высотой и вновь включается до полного взросления.
func test_tree_collision_depends_on_growth_stage() -> void:
	var game := make_game()
	var tree_position: Vector2 = game.state.world.tree_nodes[0].position + Vector2(0, 35)
	expect(not game.is_position_walkable(tree_position), "grown tree blocks player movement")
	game.state.world.tree_nodes[0].stage = 0
	expect(game.is_position_walkable(tree_position), "low stump no longer blocks player")
	game.state.world.tree_nodes[0].stage = 1
	expect(game.is_position_walkable(tree_position), "small sapling remains passable")
	game.state.world.tree_nodes[0].stage = 2
	expect(not game.is_position_walkable(tree_position), "young tree restores solid collision")
	game.free()


## Сценарий: срубленное дерево сохраняет стадию и таймер, а старый снимок автоматически получает топор.
## Исходное состояние: дерево находится на стадии саженца; из второй копии снимка удалены новые поля.
## Ожидаемый результат: современная загрузка продолжает рост, старая создаёт взрослые деревья и стартовый топор.
func test_tree_state_and_legacy_axe_are_saved_safely() -> void:
	var game := _felled_tree_game(); game.TreeSystem.update(game, 12.5)
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	var restored := make_game()
	expect(game.SaveSystem.apply(restored, snapshot), "save applies regenerative tree state")
	expect(restored.state.world.tree_nodes[0].stage == 1 and is_equal_approx(restored.state.world.tree_nodes[0].regrow_timer, 12.5), "tree stage and timer survive loading")
	var legacy := snapshot.duplicate(true); legacy.erase("trees"); legacy.counts.erase("axe")
	var old_game := make_game()
	expect(game.SaveSystem.apply(old_game, legacy), "older snapshot loads without tree fields")
	expect(old_game.state.world.tree_nodes[0].stage == 3 and old_game.inventory_item_count("axe") == 1, "legacy save receives grown trees and starter axe")
	game.free(); restored.free(); old_game.free()


## Сценарий: новая механика зарегистрирована в звуках, переводах, рисунке и последовательном обучении.
## Исходное состояние: полностью загруженные каталоги контента и исходные тексты модулей представления.
## Ожидаемый результат: chop.wav доступен, три шага обучения существуют, динамический слой владеет деревьями.
func test_tree_feature_has_audio_and_tutorial_coverage() -> void:
	var game := make_game()
	expect(load("res://assets/game/audio/sfx/chop.wav") != null and "chop" in game.AudioSystem.SFX_IDS, "axe has dedicated generated sound effect")
	for event_name in ["tree_chop", "tree_fall", "tree_regrow"]:
		expect(game.tutorial_steps.any(func(step): return step.event == event_name), "tutorial covers tree feature: %s" % event_name)
	var background_source := FileAccess.get_file_as_string("res://scripts/world_background.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	expect(not background_source.contains("for tree in trees") and renderer_source.contains("func draw_tree_nodes"), "regrowing trees are drawn by dynamic renderer instead of static background")
	game.free()


## Создаёт героя с выбранным топором рядом с первым взрослым деревом.
func _tree_game() -> Node:
	var game := make_game()
	game.selected_tool = game.Tool.AXE; game.player = game.state.world.tree_nodes[0].position + Vector2(0, 28)
	return game


## Создаёт игру, где первое дерево только что срублено и начало тридцатисекундное восстановление.
func _felled_tree_game() -> Node:
	var game := _tree_game()
	for _hit in game.TreeSystem.MAX_HEALTH: game.TreeSystem.chop_nearby(game)
	return game

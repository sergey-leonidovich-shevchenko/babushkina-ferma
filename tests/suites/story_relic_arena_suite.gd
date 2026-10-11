extends "res://tests/suites/suite_base.gd"

## Проверяет сюжетную миссию через настоящий бой в выбранной арене.
func run() -> void:
	test_story_and_side_mission_chains()


## Сценарий: сюжетная и побочная миссии проходят от диалога до цели, сдачи и награды.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_story_and_side_mission_chains() -> void:
	var game := make_game()
	game.player = game.guild_master_position
	expect(game.nearest_interaction() == "quest_npc:miron", "story mission giver is interactive")
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.story_relic == game.QuestSystem.ACTIVE, "guild master starts story mission")
	game.current_location = "cave_sanctum"
	game.player = preload("res://scripts/systems/cave_boss_arena_data.gd").ALTAR+Vector2(0,72)
	expect(game.GameInteractionRouter.perform(game),"altar awakens the story guardian")
	game.change_inventory_count("iron_spear",1); game.InventorySystem.equip(game,"iron_spear")
	var boss_index: int = game.CaveBossSystem.index(game)
	game.player = game.enemy_nodes[boss_index].position
	for _hit in 50:
		if not game.enemy_nodes[boss_index].alive: break
		game.attack_nearest_enemy()
		game.AnimationSystem.update(game, 1.1)
	expect(not game.enemy_nodes[boss_index].alive, "sanctuary guardian can be defeated for story mission")
	var relic_drop := -1
	for index in game.dropped_items.size():
		if game.dropped_items[index].kind == "moon_relic":
			relic_drop = index
	expect(relic_drop >= 0, "cave guardian drops the moon relic")
	game.collect_dropped_item(relic_drop)
	expect(game.materials.moon_relic == 1, "quest relic can be collected")
	game.current_location = "overworld"
	game.player = game.guild_master_position
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.story_relic == game.QuestSystem.COMPLETED, "relic can be returned to complete story mission")
	expect(game.coins == 140 and game.guardian_armor == 1, "story mission grants coins and equipment")
	game.player = game.herbalist_position
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.side_seed == game.QuestSystem.ACTIVE, "herbalist starts side mission")
	game.materials.rare_seeds = 1
	game.perform_context_action()
	game.AdventurePolishSystem.handle_dialogue_key(game, KEY_ENTER)
	expect(game.mission_states.side_seed == game.QuestSystem.COMPLETED, "side mission accepts its requested loot")
	expect(game.berries == 3 and game.coins == 175, "side mission grants food and coins")
	game.toggle_quest_log()
	expect(game.quest_log_open, "J journal state can be opened")
	game.toggle_quest_log()
	var journal_button := InputEventJoypadButton.new()
	journal_button.button_index = JOY_BUTTON_BACK
	journal_button.pressed = true
	expect(game.handle_gamepad_and_touch(journal_button) and game.quest_log_open, "gamepad can open mission journal")
	var journal_touch := InputEventScreenTouch.new()
	journal_touch.position = preload("res://scripts/systems/menu_hub_system.gd").CLOSE.get_center()
	journal_touch.pressed = true
	expect(game.handle_gamepad_and_touch(journal_touch) and not game.quest_log_open, "touch hub close button closes mission journal")
	game.free()

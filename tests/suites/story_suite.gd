extends "res://tests/suites/suite_base.gd"

## Запускает все сценарии сюжетных цепочек, жителей и расширенного журнала.
func run() -> void:
	test_story_and_side_catalog_structure()
	test_five_chapter_main_story_unlocks_in_order()
	test_after_eclipse_storyline_unlocks_and_completes()
	test_all_new_side_quests_can_be_completed()
	test_every_quest_npc_is_present_and_interactive()
	test_quest_markers_reflect_progress()
	test_quest_journal_has_keyboard_and_gamepad_pages()
	test_tracker_stays_compact_with_many_active_quests()
	test_old_save_receives_new_mission_states()

## Сценарий: контент содержит восемь связанных глав, десять побочных историй и двенадцать жителей.
## Исходное состояние: неизменённые декларативные каталоги сюжетной системы.
## Ожидаемый результат: количество, типы, зависимости, предметы и владельцы всех заданий согласованы.
func test_story_and_side_catalog_structure() -> void:
	var game := make_game()
	var story_ids: Array = game.QuestSystem.MISSIONS.keys().filter(func(id): return String(id).begins_with("story_"))
	var side_ids: Array = game.QuestSystem.MISSIONS.keys().filter(func(id): return String(id).begins_with("side_"))
	expect(story_ids.size() == 8, "main plot contains eight chapters")
	expect(side_ids.size() == 10, "world contains ten dedicated side quests")
	expect(game.QuestSystem.NPCS.size() == 12, "twelve named quest NPCs populate the world")
	var visual_signatures := {}
	for npc_id in game.QuestSystem.NPCS:
		var npc: Dictionary = game.QuestSystem.NPCS[npc_id]
		visual_signatures["%d:%s" % [npc.sprite, npc.tint.to_html()]] = true
	expect(visual_signatures.size() == game.QuestSystem.NPCS.size(), "every quest NPC has a distinct sprite and palette signature")
	for mission_id in game.QuestSystem.MISSIONS:
		var mission: Dictionary = game.QuestSystem.MISSIONS[mission_id]
		expect(game.InventorySystem.ITEM_DATA.has(mission.item) and game.InventorySystem.ITEM_DATA.has(mission.reward_item), "quest uses registered items: %s" % mission_id)
		expect(game.LocaleSystem.QUESTS.has("%s.title" % mission_id) and game.LocaleSystem.QUESTS.has("%s.description" % mission_id), "quest is localized: %s" % mission_id)
	game.free()

## Сценарий: основная история последовательно проходит от Лунной реликвии до восстановления печати.
## Исходное состояние: новый герой; нужные сюжетные предметы выдаются непосредственно перед сдачей каждой главы.
## Ожидаемый результат: следующая глава открывается только после предыдущей, награды начисляются, а финал завершается у Мирона.
func test_five_chapter_main_story_unlocks_in_order() -> void:
	var game := make_game()
	expect(game.QuestSystem.mission_state(game, "story_relic") == game.QuestSystem.AVAILABLE, "first story chapter is initially available")
	expect(game.QuestSystem.mission_state(game, "story_ancient_key") == game.QuestSystem.LOCKED, "second story chapter is initially locked")
	var chapters := [
		["miron","story_relic","moon_relic",1], ["elizar","story_ancient_key","ancient_key",1],
		["radomir","story_orc_blade","orc_blade",1], ["lada","story_cursed_gem","blue_gem",2],
		["miron","story_moon_seal","crystal",3],
	]
	for chapter in chapters:
		var npc_id: String = chapter[0]
		var mission_id: String = chapter[1]
		var npc: Dictionary = game.QuestSystem.NPCS[npc_id]
		game.current_location = npc.location
		game.player = game.QuestSystem.npc_position(game, npc_id)
		expect(game.perform_context_action(), "story NPC accepts interaction: %s" % mission_id)
		expect(game.mission_states[mission_id] == game.QuestSystem.ACTIVE, "story chapter becomes active: %s" % mission_id)
		game.change_inventory_count(chapter[2], chapter[3])
		expect(game.perform_context_action(), "story objective can be returned: %s" % mission_id)
		expect(game.mission_states[mission_id] == game.QuestSystem.COMPLETED, "story chapter completes: %s" % mission_id)
	expect(game.inventory_item_count("crystal_ring") == 1 and game.coins >= 740, "story finale grants the ring and cumulative coin rewards")
	expect(game.tutorial_events_completed.has("story_chain"), "main story has a dedicated tutorial event")
	game.free()

## Сценарий: три главы «Рассвета после затмения» связывают поляну, корабль и мастерскую.
## Исходное состояние: старая сюжетная печать восстановлена; победа на поляне сначала отсутствует, затем регистрируется вместе с уникальным Сердцем.
## Ожидаемый результат: арка открывается только после обоих условий, сохраняет Сердце и завершается Кристальным мечом с дополнительным очком навыка.
func test_after_eclipse_storyline_unlocks_and_completes() -> void:
	var game := make_game()
	game.mission_states.story_moon_seal = game.QuestSystem.COMPLETED
	expect(game.QuestSystem.mission_state(game, "story_eclipse_heart") == game.QuestSystem.LOCKED, "new story remains locked before first moon glade victory")
	game.state.world.moon_glade.completed_runs = 1
	game.change_inventory_count("eclipse_core", 1)
	expect(game.QuestSystem.mission_state(game, "story_eclipse_heart") == game.QuestSystem.AVAILABLE, "moon glade victory unlocks the after-eclipse arc")
	expect(game.QuestSystem.talk(game, "story_eclipse_heart"), "Lada accepts the eclipse heart chapter")
	expect(game.QuestSystem.talk(game, "story_eclipse_heart"), "Lada studies the unique eclipse heart")
	expect(game.inventory_item_count("eclipse_core") == 1 and game.tutorial_events_completed.has("story_after_eclipse"), "unique heart stays with hero and opens dedicated guidance")
	expect(game.QuestSystem.talk(game, "story_dead_tide"), "Elena accepts the dead tide chapter")
	var active_snapshot: Dictionary = game.SaveSystem.snapshot(game)
	game.mission_states.story_dead_tide = game.QuestSystem.AVAILABLE
	expect(game.SaveSystem.apply(game, active_snapshot), "after-eclipse storyline snapshot loads")
	expect(game.mission_states.story_dead_tide == game.QuestSystem.ACTIVE and game.inventory_item_count("eclipse_core") == 1, "active chapter and unique heart survive save roundtrip")
	game.change_inventory_count("ectoplasm", 3)
	expect(game.QuestSystem.talk(game, "story_dead_tide"), "three ectoplasm complete the ship chapter")
	var points_before: int = game.skill_points
	var level_before: int = game.player_level
	expect(game.QuestSystem.talk(game, "story_first_dawn"), "Tikhon accepts the dawn glass finale")
	game.change_inventory_count("green_crystal", 4)
	expect(game.QuestSystem.talk(game, "story_first_dawn"), "green crystals seal the final rift")
	expect(game.mission_states.story_first_dawn == game.QuestSystem.COMPLETED, "after-eclipse storyline reaches its finale")
	var level_points: int = game.player_level - level_before
	expect(game.inventory_item_count("crystal_sword") == 1 and game.skill_points == points_before + level_points + 1, "finale grants crystal sword and one bonus point beyond normal level rewards")
	game.free()

## Сценарий: каждое новое побочное задание принимается, проверяет свой предмет и выдаёт награду.
## Исходное состояние: новый герой; для каждой истории заранее известен связанный NPC и после принятия выдаётся точное требование.
## Ожидаемый результат: восемь новых и существующая лесная история завершаются независимо без повторной награды.
func test_all_new_side_quests_can_be_completed() -> void:
	var game := make_game()
	var owners := {"side_seed":"agafya","side_fisher":"varvara","side_smith":"gavrila","side_miner":"zlata","side_hunter":"saveliy","side_bones":"elizar","side_wings":"lada","side_glass":"tikhon","side_feast":"dunya","side_pirate_compass":"elena"}
	for mission_id in owners:
		var npc_id: String = owners[mission_id]
		var npc: Dictionary = game.QuestSystem.NPCS[npc_id]
		var mission: Dictionary = game.QuestSystem.MISSIONS[mission_id]
		game.current_location = npc.location
		game.player = game.QuestSystem.npc_position(game, npc_id)
		expect(game.QuestSystem.talk(game, mission_id), "side quest can be accepted: %s" % mission_id)
		game.change_inventory_count(mission.item, mission.count)
		var reward_before: int = game.inventory_item_count(mission.reward_item)
		expect(game.QuestSystem.talk(game, mission_id), "side quest can be returned: %s" % mission_id)
		expect(game.mission_states[mission_id] == game.QuestSystem.COMPLETED and game.inventory_item_count(mission.reward_item) == reward_before + int(mission.reward_count), "side quest grants exact reward: %s" % mission_id)
	expect(game.tutorial_events_completed.has("side_quests") and game.tutorial_events_completed.has("side_mission"), "side stories have tutorial coverage")
	game.free()

## Сценарий: каждый объявленный NPC существует в своей локации и выбирается ближайшим взаимодействием.
## Исходное состояние: герой последовательно телепортируется точно к каждому жителю.
## Ожидаемый результат: универсальный поиск возвращает идентификатор этого жителя и локализованное имя не пусто.
func test_every_quest_npc_is_present_and_interactive() -> void:
	var game := make_game()
	for npc_id in game.QuestSystem.NPCS:
		game.current_location = game.QuestSystem.NPCS[npc_id].location
		game.player = game.QuestSystem.npc_position(game, npc_id)
		expect(game.nearest_interaction() == "quest_npc:%s" % npc_id, "quest NPC is interactive: %s" % npc_id)
		expect(not game.QuestSystem.npc_name(npc_id).is_empty(), "quest NPC has localized name: %s" % npc_id)
	game.free()

## Сценарий: знак над жителем меняется между новым, активным и завершённым заданием.
## Исходное состояние: одиночная история рыбачки последовательно переводится через три состояния.
## Ожидаемый результат: маркеры равны !, ? и ✓ без зависимости от отрисовщика.
func test_quest_markers_reflect_progress() -> void:
	var game := make_game()
	expect(game.QuestSystem.npc_marker(game, "varvara") == "!", "available quest uses exclamation marker")
	game.mission_states.side_fisher = game.QuestSystem.ACTIVE
	expect(game.QuestSystem.npc_marker(game, "varvara") == "?", "active quest uses return marker")
	game.mission_states.side_fisher = game.QuestSystem.COMPLETED
	expect(game.QuestSystem.npc_marker(game, "varvara") == "✓", "completed NPC uses check marker")
	game.free()

## Сценарий: расширенный журнал листает все задания клавиатурой и геймпадом по три строки.
## Исходное состояние: журнал открыт на первой из пяти страниц.
## Ожидаемый результат: Right и D-pad меняют страницу, Left возвращает её, а B закрывает окно.
func test_quest_journal_has_keyboard_and_gamepad_pages() -> void:
	var game := make_game()
	game.toggle_quest_log()
	game.InputSystem.handle_modal_input(game, key_event(KEY_RIGHT, KEY_RIGHT, true))
	expect(game.quest_log_page == 1, "keyboard pages the expanded quest journal")
	var right := InputEventJoypadButton.new(); right.button_index = JOY_BUTTON_DPAD_RIGHT; right.pressed = true
	game.InputSystem.handle_modal_input(game, right)
	expect(game.quest_log_page == 2, "gamepad pages the expanded quest journal")
	game.InputSystem.handle_modal_input(game, key_event(KEY_LEFT, KEY_LEFT, true))
	expect(game.quest_log_page == 1, "journal can browse backward")
	expect(game.InputSystem.handle_quest_pointer(game, game.InterfaceRenderer.QUEST_NEXT.get_center()) and game.quest_log_page == 2, "touch arrow pages the quest journal")
	var close := InputEventJoypadButton.new(); close.button_index = JOY_BUTTON_B; close.pressed = true
	game.InputSystem.handle_modal_input(game, close)
	expect(not game.quest_log_open, "gamepad closes the quest journal")
	game.free()

## Сценарий: одновременное принятие множества историй не превращает HUD в длинный список.
## Исходное состояние: все восемнадцать миссий вручную отмечены активными для стресс-проверки представления.
## Ожидаемый результат: локализованная сводная строка существует, а визуальный контракт ограничивает трекер тремя целями и итогом.
func test_tracker_stays_compact_with_many_active_quests() -> void:
	var game := make_game()
	for mission_id in game.QuestSystem.MISSIONS: game.mission_states[mission_id] = game.QuestSystem.ACTIVE
	var lines: Array[String] = game.PresentationSystem.quest_tracker_lines(game)
	expect(lines.size() == 4 and lines.back().contains("15"), "tracker keeps three objectives and summarizes fifteen hidden quests")
	expect(30.0 + lines.size() * 22.0 <= 120.0, "quest tracker remains compact with eighteen active missions")
	game.free()

## Сценарий: сохранение старой версии с двумя миссиями получает безопасные состояния нового контента.
## Исходное состояние: снимок содержит завершённую старую главу, но новые идентификаторы из него удалены.
## Ожидаемый результат: старый прогресс сохраняется, новые задания добавляются, а следующая сюжетная глава открывается.
func test_old_save_receives_new_mission_states() -> void:
	var game := make_game()
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	snapshot.missions = {"story_relic":game.QuestSystem.COMPLETED,"side_seed":game.QuestSystem.ACTIVE}
	expect(game.SaveSystem.apply(game, snapshot), "legacy mission snapshot loads")
	expect(game.mission_states.size() == game.QuestSystem.MISSIONS.size(), "load appends every newly introduced mission state")
	expect(game.mission_states.side_seed == game.QuestSystem.ACTIVE and game.QuestSystem.mission_state(game, "story_ancient_key") == game.QuestSystem.AVAILABLE, "old progress unlocks the correct next chapter")
	game.free()

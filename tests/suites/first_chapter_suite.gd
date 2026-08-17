extends "res://tests/suites/suite_base.gd"

## Запускает сценарии последовательности главы, ремонта, наград, локализации и сохранения.
func run() -> void:
	test_five_day_route_uses_real_events_in_order()
	test_bridge_repair_gates_only_first_forest_departure()
	test_guardian_secret_and_reward_complete_chapter()
	test_chapter_copy_and_state_survive_locale_and_save()

## Сценарий: действия первых двух дней запоминаются, но не перескакивают через календарные главы.
## Исходное состояние: новая игра на первом дне без выполненных сюжетных событий.
## Ожидаемый результат: последовательность останавливается на дневных воротах и продолжает маршрут следующим утром.
func test_five_day_route_uses_real_events_in_order() -> void:
	var game := make_game(); var chapter: Variant = game.FirstChapterSystem; var value: Dictionary = chapter.state(game)
	expect(chapter.stage(game) == 0 and chapter.objective(game).contains("бабуш"), "first chapter begins with the grandmother objective")
	for event_name in ["talk","plant","shop"]: chapter.observe(game,event_name)
	expect(chapter.stage(game) == 3 and chapter.objective(game).contains("2-го дня") and is_equal_approx(chapter.progress(game),0.25), "day one forms an ordered talk plant and shop route with honest chapter progress")
	chapter.observe(game,"harvest"); chapter.observe(game,"quest_complete")
	expect(chapter.stage(game) == 3 and value.events.harvest and value.events.quest_complete, "early real actions are remembered without bypassing the day gate")
	game.day = 2; chapter.update(game)
	expect(chapter.stage(game) == 5 and chapter.objective(game).contains("3-го дня"), "second morning consumes remembered harvest and grandmother quest events")
	chapter.observe(game,"mission_accept"); expect(chapter.stage(game) == 5,"early village request waits for the third morning")
	game.day = 3; chapter.update(game); expect(chapter.stage(game) == 6,"third day opens the physical bridge repair objective")
	game.free()

## Сценарий: восточная граница до ремонта объясняет блокировку, а строительный узел списывает точную стоимость.
## Исходное состояние: глава дошла до ремонта, в рюкзаке сначала нет, затем достаточно древесины и камня.
## Ожидаемый результат: ресурсы не списываются частично, после ремонта переход в лес становится доступен.
func test_bridge_repair_gates_only_first_forest_departure() -> void:
	var game := make_game(); var chapter: Variant = game.FirstChapterSystem; var value: Dictionary = chapter.state(game); value.stage = 6; game.day = 3
	game.current_location = "overworld"; expect(not chapter.can_use_world_gate(game) and game.message.contains("переправ"),"unrepaired first departure gives a clear gate reason")
	var wood_before: int = game.inventory_item_count("wood"); var stone_before: int = game.inventory_item_count("stone")
	chapter.repair_bridge(game); expect(not value.bridge_repaired and game.inventory_item_count("wood") == wood_before and game.inventory_item_count("stone") == stone_before,"failed repair never consumes a partial cost")
	game.change_inventory_count("wood",chapter.REPAIR_WOOD); game.change_inventory_count("stone",chapter.REPAIR_STONE); chapter.repair_bridge(game)
	expect(value.bridge_repaired and chapter.stage(game) == 7,"exact materials restore the bridge and advance the chapter")
	expect(game.inventory_item_count("wood") == wood_before and game.inventory_item_count("stone") == stone_before,"successful bridge repair consumes the exact added materials")
	expect(chapter.can_use_world_gate(game) and game.tutorial_events_completed.has("chapter_bridge"),"repaired crossing unlocks the automatic forest gate and tutorial")
	game.WorldSystem.travel(game); expect(game.current_location == "forest" and chapter.stage(game) == 8,"real forest travel completes the crossing milestone")
	expect(game.NavigationSystem.is_walkable(game,chapter.REPAIR_POSITION),"bridge repair marker stands on reachable dry ground")
	game.WorldSystem.travel(game); expect(game.current_location == "overworld","unfinished first chapter gives the forest a direct return route to the village")
	game.free()

## Сценарий: лесной страж, тайник, поручение травницы и выбор награды завершают главу только один раз.
## Исходное состояние: четвёртый день, герой вошёл в лес и глава ждёт сильнейшее хищное растение.
## Ожидаемый результат: ранний противник не подходит, а страж и последующие события открывают уникальную награду пятого дня.
func test_guardian_secret_and_reward_complete_chapter() -> void:
	var game := make_game(); var chapter: Variant = game.FirstChapterSystem; var value: Dictionary = chapter.state(game); value.stage = 8; game.day = 4
	chapter.on_enemy_defeated(game,{"location":"forest","kind":"plant","level":4}); expect(chapter.stage(game) == 8,"ordinary forest plant cannot replace the chapter guardian")
	chapter.on_enemy_defeated(game,{"location":"forest","kind":"plant","level":5}); expect(chapter.stage(game) == 9 and game.tutorial_events_completed.has("chapter_guardian"),"level five grove guardian advances the real combat objective")
	chapter.observe(game,"secret_puzzle"); expect(chapter.stage(game) == 10,"forest secret advances the rare seed objective")
	game.mission_states.side_seed = game.QuestSystem.COMPLETED; chapter.update(game); expect(chapter.stage(game) == 10,"completed seed request waits for the fifth story day")
	game.day = 5; chapter.update(game); expect(value.reward_pending and chapter.modal_active(game),"fifth day opens a modal three-way reward choice")
	var saplings: int = game.inventory_item_count("fruit_sapling"); var seeds: int = game.inventory_item_count("rare_seeds"); var points: int = game.skill_points
	expect(chapter.select_reward(game,0),"farmer reward can be selected")
	expect(value.completed and value.reward_choice == "farmer" and not value.reward_pending,"reward choice permanently completes the chapter")
	expect(game.inventory_item_count("fruit_sapling") == saplings+3 and game.inventory_item_count("rare_seeds") == seeds+2 and game.skill_points == points+1,"farmer route grants physical items profession XP and one choice point")
	expect(not chapter.select_reward(game,1),"completed chapter cannot duplicate another reward")
	game.free()

## Сценарий: весь текст главы доступен на шести языках, а вложенное состояние проходит обычный save/load.
## Исходное состояние: отремонтированный мост и незавершённая глава с выбранной локалью.
## Ожидаемый результат: строки непустые на каждом языке, после загрузки сохраняются этап, события и мост.
func test_chapter_copy_and_state_survive_locale_and_save() -> void:
	var game := make_game(); var chapter: Variant = game.FirstChapterSystem
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		expect(not chapter.word(game,"title").is_empty() and not chapter.objective(game).is_empty(),"chapter title and objective are localized for %s" % locale)
	game.LocaleSystem.current = "ru"; var value: Dictionary = chapter.state(game); value.stage = 7; value.bridge_repaired = true; value.events.bridge_repaired = true
	var path := "user://first-chapter-suite.json"; expect(game.SaveSystem.save_at(game,path),"chapter state is accepted by the regular save document")
	var restored := make_game(); expect(restored.SaveSystem.load_at(restored,path),"chapter save can be loaded")
	var loaded: Dictionary = chapter.state(restored); expect(loaded.stage == 7 and loaded.bridge_repaired and loaded.events.bridge_repaired,"chapter stage bridge and event memory survive save roundtrip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); game.free(); restored.free()

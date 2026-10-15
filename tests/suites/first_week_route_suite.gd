extends "res://tests/suites/suite_base.gd"

var report: Array = []
const Regions := preload("res://scripts/systems/village_region_system.gd")
const Loot := preload("res://scripts/systems/dropped_loot_system.gd")

## Проверяет обычные источники материалов и настоящий порядок операций первой недели.
func run() -> void:
	test_ordinary_first_week_route()
	test_early_events_keep_order_without_calendar_wait()

## Сценарий: хозяйство, поручение, переправа и лес приводят к одной награде первой главы.
## Исходное состояние: новая игра с обычными восемью семенами и двадцатью монетами.
## Ожидаемый результат: все события получены игровыми операциями, без шкафа и выдачи материалов.
func test_ordinary_first_week_route() -> void:
	var game := make_game(); var started := Time.get_ticks_usec()
	game.state.player.adventure_ui.creation_open = false
	game.FarmLifeSystem.state(game).cutscene = ""
	expect(game.coins == 20 and game.seeds == 8, "first week starts with ordinary supplies")
	game.QuestSystem.talk_to_grandmother(game)
	for index in 3: crop(game, index)
	game.player = game.BuildingSystem.SHOP_STALL_POSITION
	game.open_shop(); game.shop_open = false
	expect(game.ShopSystem.buy(game,0), "a five-coin seed packet extends ordinary starter supplies")
	record(game,"farm and shop"); sleep(game)
	for index in range(3,6): crop(game,index)
	record(game,"second harvest and rest"); sleep(game)
	for index in range(6,9): crop(game,index)
	record(game,"third harvest and rest"); sleep(game)
	crop(game,9)
	expect(game.carrots >= 10, "ordinary crops supply grandmother's ten carrots")
	game.QuestSystem.talk_to_grandmother(game)
	expect(game.quest_complete and game.coins >= 65, "actual carrot delivery funds ordinary supplies")
	var passage: Dictionary = Regions.Data.passages("overworld").filter(func(row): return row.port == "top")[0]
	game.player = passage.position
	expect(Regions.travel(game,"top"), "herbalist is reached through the actual village link")
	game.QuestSystem.talk_to_npc(game,"agafya")
	game.player = Regions.Data.port_position("village_garden","bottom")
	expect(Regions.travel(game,"bottom"), "the garden has an actual return link")
	record(game,"carrots delivered; Agafya request")
	game.selected_tool = game.Tool.AXE
	for hit in 8:
		if game.wood >= 8: break
		var tree: Dictionary = game.state.world.tree_nodes.filter(func(row): return int(row.stage) == 3)[0]
		game.player = game.TreeSystem.collision_rect(tree).get_center() + Vector2(0,70)
		expect(game.TreeSystem.chop_nearby(game), "bridge timber is actually chopped")
	for amount in 4:
		for index in game.shop_products.size():
			if game.shop_products[index].kind == "stone": expect(game.ShopSystem.buy(game,index), "bridge stone has an ordinary funded source")
	game.player = game.FirstChapterSystem.REPAIR_POSITION
	game.FirstChapterSystem.repair_bridge(game)
	expect(game.FirstChapterSystem.state(game).bridge_repaired, "paid bridge opens from actual ordinary resources")
	game.WorldSystem.travel(game)
	expect(game.current_location == "forest", "repaired crossing reaches the forest")
	record(game,"paid bridge; forest"); sleep(game)
	game.current_location = "forest"; game.equipped_weapon = "axe"
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if enemy.location != "forest" or enemy.kind != "plant" or int(enemy.level) != 5: continue
		game.player = enemy.position + Vector2(0,80)
		for hit in 20:
			if not enemy.alive: break
			expect(preload("res://scripts/systems/player_attack_system.gd").begin(game,"enemy",index), "ordinary axe starts a real guardian contact")
			game.WeaponSystem.update(game,1.1)
		game.player = enemy.position
		for drop in range(game.dropped_items.size()-1,-1,-1): Loot.collect(game,drop)
		expect(not enemy.alive, "real weapon damage defeats the grove guardian")
	game.player = game.FarmLifeSystem.SECRETS.forest.position
	game.FarmLifeSystem.interact(game,"life:secret:forest")
	for drop in range(game.dropped_items.size()-1,-1,-1): Loot.collect(game,drop)
	expect(game.inventory_item_count("rare_seeds") > 0, "forest combat/cache supply Agafya without QA grants")
	game.WorldSystem.travel(game)
	expect(game.current_location == "overworld", "first chapter forest returns directly to the home region")
	record(game,"guardian contact and cache"); sleep(game)
	game.player = passage.position; Regions.travel(game,"top")
	game.QuestSystem.talk_to_npc(game,"agafya"); game.FirstChapterSystem.update(game)
	expect(game.FirstChapterSystem.modal_active(game), "actual seed delivery opens the chapter reward")
	expect(game.FirstChapterSystem.select_reward(game,0), "ordinary route selects one permanent reward")
	record(game,"seed delivered; farmer reward"); sleep(game)
	game.FarmLifeSystem.update_achievements(game); record(game,"optional exploration and planning")
	expect(game.day == 7 and game.FirstChapterSystem.state(game).completed, "chapter and optional days form a complete first week")
	report.append({"model_wall_ms":(Time.get_ticks_usec()-started)/1000.0,"scope":"service operations, accelerated crop growth; no human/walking/combat reaction timing"})
	game.free()

## Выращивает морковь настоящими инструментами с двумя поливами, ускоряя только ожидание роста.
func crop(game: Node, index: int) -> void:
	var cell := Vector2i(index%4,index/4)
	game.player = Vector2(game.FARM_ORIGIN) + Vector2(cell)*48 + Vector2(24,24) - Vector2(42,0)
	game.facing = Vector2.RIGHT; game.selected_hotbar = 1
	for tool in [game.Tool.HOE,game.Tool.SEEDS,game.Tool.WATER]:
		game.selected_tool = tool; game.use_selected_tool()
	var plot: Dictionary = game.plots[cell]
	game.FarmSystem.update_plot(game,plot,100)
	game.use_selected_tool(); game.FarmSystem.update_plot(game,plot,100)
	game.selected_tool = game.Tool.HAND; game.use_selected_tool()
	expect(not plot.planted and game.energy >= 0, "first-week carrot is harvested within the energy budget")

## Записывает фактический итог этапа без подмены времени человеческого прохождения.
func record(game: Node, label: String) -> void:
	report.append({"day":game.day,"step":label,"chapter_stage":game.FirstChapterSystem.stage(game),"coins":game.coins,"energy":game.energy,"wood":game.wood,"stone":game.stone,"carrots":game.carrots,"seeds":game.seeds})

## Выполняет настоящий сон в доме и возвращает модель к домашней ферме без изменения запасов.
func sleep(game: Node) -> void:
	game.current_location = "cottage_interior"; game.sleep_until_morning(); game.current_location = "overworld"

## Сценарий: опытный игрок выполняет поздние действия заранее и продолжает в первом дне.
## Исходное состояние: новая глава без ресурсов и завершённых целей.
## Ожидаемый результат: ранние события сохраняются, но не заменяют предшествующие цели.
func test_early_events_keep_order_without_calendar_wait() -> void:
	var game := make_game(); var chapter: Variant = game.FirstChapterSystem
	for event_name in ["guardian_defeated","secret_puzzle","mission_accept","harvest","quest_complete"]: chapter.observe(game,event_name)
	expect(chapter.stage(game) == 0, "out-of-order future events cannot skip the opening")
	for event_name in ["talk","plant","shop"]: chapter.observe(game,event_name)
	expect(chapter.stage(game) == 6 and game.day == 1, "remembered real actions do not demand meaningless calendar waiting")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		for index in [3,5,8,10]:
			chapter.state(game).stage = index
			expect(not chapter.objective(game).is_empty(), "actionable chapter copy is present in " + locale)
	game.free()

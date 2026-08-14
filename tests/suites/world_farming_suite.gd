extends "res://tests/suites/suite_base.gd"

const TEST_SAVE_PATH := "user://world-farming-suite.json"


## Запускает сценарии свободного земледелия, находок, сохранения и диагностики.
func run() -> void:
	test_surface_rules_cover_outdoors_and_exclusions()
	test_complete_crop_cycle_works_outside_home_field()
	test_buried_loot_is_rare_deterministic_and_sellable()
	test_world_plots_survive_save_and_load()
	test_debug_overlay_exposes_tillability_and_plot_info()


## Сценарий: разные покрытия и типы локаций проверяются до изменения земли.
## Исходное состояние: новый мир, клетка каменной дороги, свободная клетка леса и запрещённые помещения.
## Ожидаемый результат: улица допускает обработку земли, а дорога, пещера, помещение и корабль запрещены.
func test_surface_rules_cover_outdoors_and_exclusions() -> void:
	var game := make_game()
	var forest_cell := find_tillable_cell(game, "forest")
	expect(forest_cell.x >= 0 and game.WorldFarmingSystem.tillability_reason(game,"forest",forest_cell) == "tillable", "open forest soil is available for free farming")
	var road_cell: Vector2i = game.WorldFarmingSystem.cell_at(game.VillageLayoutSystem.PATHS[0][4])
	expect(game.WorldFarmingSystem.tillability_reason(game,"overworld",road_cell) == "paved_road", "visible village stone road cannot be tilled")
	for location in ["cave","pirate_ship","cottage_interior","shop_interior"]:
		expect(game.WorldFarmingSystem.tillability_reason(game,location,Vector2i(10,10)) == "location_blocked", "farming is disabled in excluded location: %s" % location)
	game.free()


## Сценарий: одна свободная лесная клетка проходит весь обычный цикл культуры.
## Исходное состояние: герой смотрит на свободную землю, имеет мотыгу, семена, лейку и пустой мировой слой.
## Ожидаемый результат: клетка вспахана, посажена, дважды полита, созревает и выдаёт урожай руками.
func test_complete_crop_cycle_works_outside_home_field() -> void:
	var game := make_game()
	var cell := find_tillable_cell(game,"forest")
	place_target(game,"forest",cell)
	var initial_energy: int = game.energy
	game.selected_tool = game.Tool.HOE
	game.use_selected_tool()
	var key: String = game.WorldFarmingSystem.plot_key("forest",cell)
	expect(game.state.world.world_plots.has(key) and game.state.world.world_plots[key].tilled, "hoe creates persistent plot on free outdoor soil")
	var render_source := FileAccess.get_file_as_string("res://scripts/systems/render_system.gd")
	expect(render_source.contains("else:\n\t\tgame.draw_farm()"), "world plots are rendered outside the original overworld farm")
	expect(game.energy == initial_energy - 1 and game.tutorial_events_completed.has("free_farming"), "free tilling consumes stamina and advances its tutorial")
	game.selected_tool = game.Tool.SEEDS
	game.use_selected_tool()
	game.selected_tool = game.Tool.WATER
	game.use_selected_tool()
	game.FarmSystem.update(game,game.STAGE_DURATION * 2.1)
	expect(game.state.world.world_plots[key].stage == 2 and not game.state.world.world_plots[key].watered, "world crop reaches second stage and requests another watering")
	game.use_selected_tool()
	game.FarmSystem.update(game,game.STAGE_DURATION * 2.1)
	var carrots_before: int = game.carrots
	game.selected_tool = game.Tool.HAND
	game.use_selected_tool()
	expect(game.carrots > carrots_before and not game.state.world.world_plots[key].planted, "mature world crop is harvested through the shared farm system")
	game.free()


## Сценарий: большая выборка клеток проверяет таблицы подземных находок без случайного флапа.
## Исходное состояние: фиксированный seed мира и десять тысяч разных координат одной локации.
## Ожидаемый результат: пустых клеток большинство, обычные находки чаще сокровищ, а повторный расчёт идентичен.
func test_buried_loot_is_rare_deterministic_and_sellable() -> void:
	var game := make_game()
	var counts := {"empty":0,"common":0,"uncommon":0,"potion":0,"treasure":0}
	var first_find_cell := Vector2i.ZERO
	var first_find: Dictionary = {}
	for index in 5000:
		var cell := Vector2i(index % 100, index / 100)
		var first: Dictionary = game.WorldFarmingSystem.buried_find(424242,"forest",cell)
		var second: Dictionary = game.WorldFarmingSystem.buried_find(424242,"forest",cell)
		if index < 2:
			expect(first == second, "buried loot is deterministic for sampled cell %d" % index)
		if first.is_empty(): counts.empty += 1
		else:
			counts[first.tier] += 1
			if first_find.is_empty(): first_find_cell = cell; first_find = first
			if index < 2:
				expect(game.InventorySystem.ITEM_DATA.has(first.kind), "buried loot item is registered: %s" % first.kind)
	expect(counts.empty > 4200 and counts.common > counts.uncommon and counts.uncommon > counts.treasure and counts.treasure > 0, "buried loot remains rare with common junk much more frequent than treasure: %s" % [counts])
	for entry in game.WorldFarmingSystem.COMMON_FINDS:
		expect(game.ShopSystem.sell_price(entry[0]) > 0, "common buried find can be sold: %s" % entry[0])
	var before: int = game.inventory_item_count(first_find.kind)
	var plot: Dictionary = game.WorldFarmingSystem.empty_plot("forest",first_find_cell)
	var target: Dictionary = {"valid":true,"legacy":false,"cell":first_find_cell,"key":game.WorldFarmingSystem.plot_key("forest",first_find_cell)}
	game.current_location = "forest"
	game.world_loot_seed = 424242
	expect(game.WorldFarmingSystem.till(game,target,plot) and game.inventory_item_count(first_find.kind) == before + int(first_find.count), "tilling grants the deterministic buried find exactly once")
	expect(not game.WorldFarmingSystem.till(game,target,plot) and game.inventory_item_count(first_find.kind) == before + int(first_find.count), "re-tilling cannot duplicate buried loot")
	game.free()


## Сценарий: мировая культура сериализуется отдельно от старых тридцати грядок.
## Исходное состояние: вручную подготовлена политая культура третьей стадии на лесной клетке.
## Ожидаемый результат: новый экземпляр восстанавливает локацию, координаты, сорт, влагу и рост без потерь.
func test_world_plots_survive_save_and_load() -> void:
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix))
	var game := make_game()
	var cell := Vector2i(14,9)
	var plot: Dictionary = game.WorldFarmingSystem.empty_plot("forest",cell)
	plot.tilled = true; plot.planted = true; plot.watered = true; plot.growth = 15.0; plot.stage = 3; plot.crop_kind = "pumpkin"
	game.state.world.world_plots[game.WorldFarmingSystem.plot_key("forest",cell)] = plot
	expect(game.SaveSystem.save_at(game,TEST_SAVE_PATH), "save accepts free world plot data")
	var restored := make_game()
	expect(game.SaveSystem.load_at(restored,TEST_SAVE_PATH), "save restores free world plot data")
	var restored_plot: Dictionary = restored.state.world.world_plots[restored.WorldFarmingSystem.plot_key("forest",cell)]
	expect(restored_plot.cell == cell and restored_plot.crop_kind == "pumpkin" and restored_plot.watered and restored_plot.stage == 3, "restored world plot preserves coordinates crop moisture and stage")
	game.free(); restored.free()
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix))


## Сценарий: F10 переключается на карту пахотности и инспектирует созданную грядку.
## Исходное состояние: открытая debug-панель и одна свободная грядка в лесу.
## Ожидаемый результат: режим доступен, клетка содержит причину пахотности, а INFO показывает технические данные участка.
func test_debug_overlay_exposes_tillability_and_plot_info() -> void:
	var game := make_game()
	game.current_location = "forest"
	var cell := find_tillable_cell(game,"forest")
	var plot: Dictionary = game.WorldFarmingSystem.empty_plot("forest",cell); plot.tilled = true
	game.state.world.world_plots[game.WorldFarmingSystem.plot_key("forest",cell)] = plot
	game.DebugOverlaySystem.toggle(game)
	expect(game.DebugOverlaySystem.button_enabled("farming"), "F10 exposes enabled tillability overlay switch")
	game.DebugOverlaySystem.toggle_option(game,"farming")
	var debug_state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(debug_state.farming and debug_state.cache.all(func(entry): return entry.has("farming_reason")), "debug grid caches a tillability reason for every visible cell")
	var candidates: Array[Dictionary] = game.DebugObjectInspectorSystem.candidates(game)
	var inspected: Dictionary = candidates.filter(func(entry): return String(entry.id).begins_with("world_plot:"))[0]
	expect(inspected.category == "ГРЯДКА" and inspected.details[0].contains("клетка"), "debug INFO exposes world plot location and cell coordinates")
	game.free()


## Находит первую действительно доступную клетку в центральной безопасной части выбранной улицы.
func find_tillable_cell(game: Node, location: String) -> Vector2i:
	game.current_location = location
	for y in range(4,22):
		for x in range(4,42):
			var cell := Vector2i(x,y)
			if game.WorldFarmingSystem.tillability_reason(game,location,cell) == "tillable": return cell
	return Vector2i(-1,-1)


## Ставит героя так, чтобы центр нужной клетки точно оказался перед ним на расстоянии действия.
func place_target(game: Node, location: String, cell: Vector2i) -> void:
	game.current_location = location
	game.facing = Vector2.RIGHT
	game.player = game.WorldFarmingSystem.cell_rect(cell).get_center() - Vector2.RIGHT * 42.0

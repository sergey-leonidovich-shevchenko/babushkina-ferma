extends "res://tests/suites/suite_base.gd"

const TEST_SAVE_PATH := "user://world-farming-suite.json"

## Проверяет границы фермы, полный цикл, широкую мотыгу и перенос старых посадок.
func run() -> void:
	test_only_home_field_can_be_cultivated()
	test_complete_crop_cycle_works_on_home_field()
	test_wide_tilling_stays_inside_farm()
	test_buried_find_is_granted_once_on_farm()
	test_buried_find_tables_remain_rare()
	test_old_world_crops_move_home_without_loss()
	test_full_farm_refunds_old_crops_once()
	test_debug_and_learning_show_farm_limits()
	test_orchard_keeps_separate_outdoor_rules()

## Сценарий: обработка запрещена на дорогах, газоне, в других биомах и помещениях.
## Исходное состояние: герой с семенами и целой мотыгой смотрит на землю вне домашней фермы.
## Ожидаемый результат: инструменты оставляют мир, энергию, прочность и семена неизменными; устаревшая цель тоже отклоняется.
func test_only_home_field_can_be_cultivated() -> void:
	var game := make_game(); var home := home_target(game,Vector2i.ZERO)
	for location in ["overworld","forest","rocky","ruins","cursed","glassworks","moon_glade","cave","pirate_ship","cottage_interior","shop_interior"]:
		place_target(game,location,Vector2i(14,9))
		var energy: int = game.energy
		var counts: Dictionary = game.export_inventory_counts().duplicate(true)
		var durability: Dictionary = game.state.inventory.durability.duplicate(true)
		for tool in [game.Tool.HOE,game.Tool.SEEDS,game.Tool.WATER,game.Tool.HAND]:
			game.selected_tool=tool; game.use_selected_tool()
		expect(not game.WorldFarmingSystem.target(game).valid and game.state.world.world_plots.is_empty(),"no cultivation outside farm: "+location)
		expect(game.energy==energy and game.export_inventory_counts()==counts and game.state.inventory.durability==durability,"blocked tools spend nothing: "+location)
		if location != "overworld": expect(game.WorldFarmingSystem.till_pattern(game,home)==0,"cached home target cannot till another location: "+location)
	game.current_location="overworld"
	var forged := {"valid":true,"legacy":false,"cell":Vector2i(14,9),"key":"overworld:14:9"}
	var plot: Dictionary = game.WorldFarmingSystem.empty_plot("overworld",Vector2i(14,9))
	expect(not game.WorldFarmingSystem.till(game,forged,plot),"caller validity flag cannot bypass farm restriction")
	game.WorldFarmingSystem.write_target(game,forged,plot)
	expect(game.state.world.world_plots.is_empty(),"world plot write cannot bypass farm restriction")
	game.free()

## Сценарий: таблица подземных находок проверяется большой детерминированной выборкой.
## Исходное состояние: фиксированный ключ мира и пять тысяч разных клеток.
## Ожидаемый результат: пустых клеток большинство, обычные находки чаще сокровищ, мусор продаётся, повторный расчёт идентичен.
func test_buried_find_tables_remain_rare() -> void:
	var game := make_game(); var counts := {"empty":0,"common":0,"uncommon":0,"potion":0,"treasure":0}
	for index in 5000:
		var cell := Vector2i(index%100,index/100)
		var found: Dictionary = game.WorldFarmingSystem.buried_find(424242,"overworld",cell)
		if index<2: expect(found==game.WorldFarmingSystem.buried_find(424242,"overworld",cell),"buried loot remains deterministic: "+str(index))
		if found.is_empty(): counts.empty+=1
		else: counts[found.tier]+=1
	expect(counts.empty>4200 and counts.common>counts.uncommon and counts.uncommon>counts.treasure and counts.treasure>0,"buried loot remains rare with common junk more frequent than treasure")
	for entry in game.WorldFarmingSystem.COMMON_FINDS: expect(game.ShopSystem.sell_price(entry[0])>0,"common buried find remains sellable: "+entry[0])
	game.free()

## Сценарий: домашняя грядка проходит весь обычный цикл культуры.
## Исходное состояние: герой смотрит на нетронутую клетку участка у дома и имеет инструменты с семенами.
## Ожидаемый результат: мотыга, посадка, два полива, рост и сбор работают на прежнем участке.
func test_complete_crop_cycle_works_on_home_field() -> void:
	var game := make_game(); home_target(game,Vector2i.ZERO)
	var plot: Dictionary = game.plots[Vector2i.ZERO]; var initial_energy: int = game.energy
	game.selected_tool=game.Tool.HOE; game.use_selected_tool()
	expect(plot.tilled and game.energy==initial_energy-1 and game.tutorial_events_completed.has("free_farming"),"home hoe creates soil, pays stamina and completes tutorial")
	game.selected_tool=game.Tool.SEEDS; game.use_selected_tool()
	game.selected_tool=game.Tool.WATER; game.use_selected_tool()
	game.FarmSystem.update(game,game.STAGE_DURATION*2.1)
	expect(plot.stage==2 and not plot.watered,"home crop requests second watering")
	game.use_selected_tool(); game.FarmSystem.update(game,game.STAGE_DURATION*2.1)
	var before: int = game.carrots
	game.selected_tool=game.Tool.HAND; game.use_selected_tool()
	expect(game.carrots>before and not plot.planted and plot.tilled,"home crop harvest preserves cultivated bed")
	expect(game.state.world.world_plots.is_empty(),"ordinary farming never allocates world plots")
	game.free()

## Сценарий: улучшенная мотыга работает на границах участка и рядом с ним.
## Исходное состояние: открыты три на три клетки, все тридцать домашних грядок пусты.
## Ожидаемый результат: внутри обрабатываются девять клеток, в углах четыре, за границей ни одной; энергия снимается только за успешное действие.
func test_wide_tilling_stays_inside_farm() -> void:
	var game := make_game(); game.talent_levels.farm_wide_till=1; game.talent_levels.farm_field_master=1
	for cell in [Vector2i(2,2),Vector2i.ZERO,Vector2i(5,0),Vector2i(0,4),Vector2i(5,4)]:
		for bed in game.plots.values(): bed.tilled=false
		game.energy=12; var target := home_target(game,cell)
		var expected := 9 if cell==Vector2i(2,2) else 4
		expect(game.WorldFarmingSystem.till_pattern(game,target)==expected and game.energy==9,"wide hoe clips farm boundary: "+str(cell))
		expect(game.plots.values().filter(func(bed): return bed.tilled).size()==expected and game.state.world.world_plots.is_empty(),"wide hoe creates no extra soil: "+str(cell))
	for bed in game.plots.values(): bed.tilled=false
	game.player=Vector2(game.FARM_ORIGIN)+Vector2(-24,24)-Vector2.RIGHT*42; game.facing=Vector2.RIGHT
	var outside: Dictionary = game.WorldFarmingSystem.target(game); game.energy=12
	expect(game.WorldFarmingSystem.till_pattern(game,outside)==0 and game.energy==12 and game.plots.values().all(func(bed): return not bed.tilled),"outside origin cannot leak wide hoe into field")
	game.free()

## Сценарий: подземная находка выдаётся один раз в настоящей домашней грядке.
## Исходное состояние: фиксированный перебор семян мира на одной допустимой клетке.
## Ожидаемый результат: первая вспашка выдаёт находку, повторная не добавляет предметов и не расходует энергию.
func test_buried_find_is_granted_once_on_farm() -> void:
	var game := make_game(); var target := home_target(game,Vector2i.ZERO); var found := {}
	for seed_value in 1000:
		found=game.WorldFarmingSystem.buried_find(seed_value,"overworld",Vector2i.ZERO)
		if not found.is_empty(): game.world_loot_seed=seed_value; break
	expect(not found.is_empty(),"deterministic home fixture contains a buried find")
	var plot: Dictionary = game.plots[Vector2i.ZERO]; var before: int = game.inventory_item_count(found.kind)
	expect(game.WorldFarmingSystem.till(game,target,plot) and game.inventory_item_count(found.kind)==before+int(found.count),"home till grants buried find once")
	var energy: int = game.energy
	expect(not game.WorldFarmingSystem.till(game,target,plot) and game.energy==energy and game.inventory_item_count(found.kind)==before+int(found.count),"repeat till cannot duplicate buried find")
	game.free()

## Сценарий: старый слот содержит грядки на дороге и в лесу.
## Исходное состояние: домашняя культура и удобренная пустая грядка заняты; старые посадки имеют рост и полив.
## Ожидаемый результат: чужие грядки исчезают, посадки занимают свободные домашние клетки без потери состояния и проходят сохранение.
func test_old_world_crops_move_home_without_loss() -> void:
	var game := make_game(); game.current_location="cottage_interior"; game.plots[Vector2i.ZERO].planted=true
	game.plots[Vector2i(1,0)].tilled=true; game.plots[Vector2i(1,0)].fertilizer="compost"
	add_old_plot(game,"forest",Vector2i(14,9),"pumpkin",15.0,"growth_fertilizer")
	add_old_plot(game,"overworld",Vector2i(20,10),"wheat",12.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game))); var restored := make_game()
	data.world_plots.append(data.world_plots[0].duplicate(true))
	expect(game.SaveSystem.apply(restored,data),"old world crop snapshot passes save validation")
	var pumpkin: Dictionary = restored.plots[Vector2i(2,0)]
	expect(pumpkin.crop_kind=="pumpkin" and pumpkin.growth==15.0 and pumpkin.stage==3 and pumpkin.watered and pumpkin.fertilizer=="growth_fertilizer","relocation preserves crop, growth, stage, water and fertilizer")
	expect(restored.plots[Vector2i.ZERO].planted and restored.plots[Vector2i(1,0)].fertilizer=="compost" and restored.plots[Vector2i(3,0)].crop_kind=="wheat","migration never overwrites home crops or paid fertilizer")
	expect(restored.current_location=="cottage_interior" and restored.state.world.world_plots.is_empty(),"migration leaves location unchanged and clears remote soil")
	expect(restored.plots.values().filter(func(bed): return bed.planted).size()==3,"duplicate legacy plot key never creates duplicate crops")
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH+suffix))
	expect(game.SaveSystem.save_at(restored,TEST_SAVE_PATH),"migrated crops save to disk")
	var loaded := make_game()
	expect(game.SaveSystem.load_at(loaded,TEST_SAVE_PATH) and loaded.plots[Vector2i(2,0)].growth==15.0 and loaded.state.world.world_plots.is_empty(),"reloaded crops remain at home without second relocation")
	game.free(); restored.free(); loaded.free()
	for suffix in ["",".tmp",".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH+suffix))

## Сценарий: перенос старых грядок встречает полностью занятую домашнюю ферму.
## Исходное состояние: тридцать домашних растений, незрелая тыква, зрелая клубника и удобренная пустая земля вне участка.
## Ожидаемый результат: возвращаются семена, готовый урожай и удобрения без опыта, энергии и повторного начисления после сохранения.
func test_full_farm_refunds_old_crops_once() -> void:
	var game := make_game()
	for bed in game.plots.values(): bed.tilled=true; bed.planted=true
	add_old_plot(game,"forest",Vector2i(14,9),"pumpkin",15.0,"compost")
	add_old_plot(game,"overworld",Vector2i(20,10),"strawberry",40.0,"quality_fertilizer")
	var bare: Dictionary = game.WorldFarmingSystem.empty_plot("forest",Vector2i(15,9))
	bare.tilled=true; bare.fertilizer="growth_fertilizer"; game.state.world.world_plots["forest:15:9"]=bare
	var before: Dictionary = game.export_inventory_counts().duplicate(true); var data: Dictionary = game.SaveSystem.snapshot(game)
	var restored := make_game(); expect(game.SaveSystem.apply(restored,data),"full farm migration loads")
	for kind in ["pumpkin_seeds","strawberry_seeds","compost","quality_fertilizer","growth_fertilizer"]:
		expect(restored.inventory_item_count(kind)==int(before.get(kind,0))+1,"overflow returns invested item: "+kind)
	expect(restored.inventory_item_count("strawberry")==int(before.get("strawberry",0))+game.CropCatalogSystem.harvest_count(game,"strawberry")+1,"mature overflow returns complete harvest including fertilizer bonus")
	expect(restored.energy==game.energy and restored.player_xp==game.player_xp and restored.plots.values().all(func(bed): return bed.planted),"migration spends no stamina, grants no XP and keeps existing crops")
	var refunded: Dictionary = restored.export_inventory_counts().duplicate(true)
	expect(game.SaveSystem.apply(restored,game.SaveSystem.snapshot(restored)) and restored.export_inventory_counts()==refunded,"new save cannot refund old crops twice")
	game.free(); restored.free()

## Сценарий: диагностика и обучение отражают новое ограничение.
## Исходное состояние: домашняя грядка вспахана, открыта панель пахотности, перебираются шесть языков.
## Ожидаемый результат: домашняя клетка разрешена, лес запрещён, инспектор видит грядку, обучение объясняет участок у дома.
func test_debug_and_learning_show_farm_limits() -> void:
	var game := make_game(); home_target(game,Vector2i.ZERO); game.plots[Vector2i.ZERO].tilled=true
	game.DebugOverlaySystem.toggle(game); game.DebugOverlaySystem.toggle_option(game,"farming")
	var debug_state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	expect(debug_state.farming and debug_state.cache.all(func(entry): return entry.has("farming_reason")),"F10 caches farm restriction reasons")
	var cell: Vector2i = game.WorldFarmingSystem.cell_at(Vector2(game.FARM_ORIGIN))
	expect(game.WorldFarmingSystem.tillability_reason(game,"overworld",cell)=="tillable" and game.WorldFarmingSystem.tillability_reason(game,"forest",cell)=="outside_farm","debug differentiates home field from same cell in another location")
	expect(game.DebugObjectInspectorSystem.candidates(game).any(func(entry): return String(entry.id).begins_with("home_plot:") and entry.category=="ГРЯДКА"),"F10 inspector includes home beds")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		expect(game.LocaleSystem.text("farming_farm_only")!="farming_farm_only" and game.LocaleSystem.tutorial("free_farming")!="free_farming","farm restriction is taught and translated: "+locale)
	game.LocaleSystem.current="ru"; game.free()

## Сценарий: ограничение мотыги не отключает посадку плодового сада в подходящей земле.
## Исходное состояние: изучен садовод, есть саженец и свободная лесная земля.
## Ожидаемый результат: мотыга запрещена, саженец посажен и оплачен по отдельным правилам сада.
func test_orchard_keeps_separate_outdoor_rules() -> void:
	var game := make_game(); game.talent_levels.farm_orchard=1; game.change_inventory_count("fruit_sapling",1)
	var cell := find_tillable_cell(game,"forest"); place_target(game,"forest",cell); var before: int = game.food_nodes.size()
	expect(not game.WorldFarmingSystem.target(game).valid and game.OrchardSystem.plant_sapling(game) and game.food_nodes.size()==before+1,"fruit tree planting keeps its own outdoor placement rule")
	game.free()

## Находит свободную уличную землю для сценариев сада и архивного сравнения рамки.
func find_tillable_cell(game: Node, location: String) -> Vector2i:
	game.current_location=location
	for y in range(4,22):
		for x in range(4,42):
			var cell := Vector2i(x,y)
			if game.WorldFarmingSystem.outdoor_soil_reason(game,location,cell)=="tillable": return cell
	return Vector2i(-1,-1)

## Ставит героя перед мировой клеткой без изменения допустимости этой поверхности.
func place_target(game: Node, location: String, cell: Vector2i) -> void:
	game.current_location=location; game.facing=Vector2.RIGHT
	game.player=game.WorldFarmingSystem.cell_rect(cell).get_center()-Vector2.RIGHT*42.0

## Ставит героя перед локальной домашней грядкой и возвращает настоящую цель инструмента.
func home_target(game: Node, cell: Vector2i) -> Dictionary:
	game.current_location="overworld"; game.facing=Vector2.RIGHT
	game.player=game.FarmVisualSystem.plot_rect(Vector2(game.FARM_ORIGIN),cell).get_center()-Vector2.RIGHT*42.0
	return game.WorldFarmingSystem.target(game)

## Добавляет посадку старого формата для проверки совместимости сохранений.
func add_old_plot(game: Node, location: String, cell: Vector2i, crop: String, growth: float, fertilizer: String = "") -> void:
	var plot: Dictionary = game.WorldFarmingSystem.empty_plot(location,cell)
	plot.tilled=true; plot.planted=true; plot.watered=true; plot.growth=growth; plot.stage=3; plot.crop_kind=crop; plot.fertilizer=fertilizer
	game.state.world.world_plots[game.WorldFarmingSystem.plot_key(location,cell)]=plot

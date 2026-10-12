extends "res://tests/suites/suite_base.gd"

const Furnace := preload("res://scripts/systems/furnace_system.gd")
const Visual := preload("res://scripts/presentation/furnace_renderer.gd")

## Проверяет сырьё, загрузку, отложенную плавку, уровни, управление и сохранение очереди.
func run() -> void:
	test_materials_and_real_sources()
	test_queue_fuel_pause_and_exact_completion()
	test_all_fuels_idle_and_capacity()
	test_three_levels_batch_and_efficiency()
	test_glass_vials_charcoal_steel_and_slag()
	test_input_and_disk_roundtrip()
	test_old_save_resource_defaults()

## Открывает действующий горн обычным контекстным действием в проверочной модели.
func station(game: Node) -> void:
	game.current_location="forge_interior"; game.player=Furnace.STATION
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","furnace has a walkable actual interaction point")
	expect(game.nearest_interaction()=="interior_service:furnace" and game.perform_context_action() and game.crafting_station=="furnace","context action opens furnace without replacing equipment forge service")
	var life:Dictionary=game.FarmLifeSystem.state(game); life.cutscene=""; life.cutscene_timer=0.0; life.first_day=6
	game.tutorial_visible=false

## Различает три плавки металла по стабильному ID, а не одинаковому выходу.
func index_for(game: Node, id: String) -> int:
	return game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="furnace:"+id)

## Сценарий: новые материалы имеют изображения и доступны реальной добыче.
## Исходное состояние: чистая карта содержит шесть дополнительных источников, герой получил кирку.
## Ожидаемый результат: возле каждого источника есть проходимая точка, удар выдаёт зарегистрированный материал.
func test_materials_and_real_sources() -> void:
	var game:=make_game(); game.current_location="rocky"; game.has_pickaxe=true; game.selected_tool=game.Tool.PICKAXE
	expect(Furnace.Data.ITEMS.size()==9 and Furnace.Data.RECIPES.size()==7,"furnace adds nine materials and seven actual production recipes")
	for kind in Furnace.Data.ITEMS: expect(game.VisualAssetSystem.has_item_icon(kind) and game.InventorySystem.ITEM_DATA.has(kind),"furnace material has a real shared icon and count: "+kind)
	for spawn in Furnace.Data.SPAWNS:
		var index:int=game.resource_nodes.find_custom(func(node): return node.kind==spawn.kind and node.position==spawn.position and node.location==spawn.location)
		var point:=Vector2.INF
		for direction in 16:
			var candidate:Vector2=spawn.position+Vector2(80,0).rotated(TAU*direction/16.0)
			if game.NavigationSystem.walkability_reason(game,candidate,-1,false)=="walkable": point=candidate; break
		expect(point!=Vector2.INF,"resource has a real reachable harvesting approach: "+spawn.kind)
		game.player=point; var before:int=game.inventory_item_count(spawn.kind)
		expect(index>=0 and game.ResourceSystem.mine(game,index) and game.inventory_item_count(spawn.kind)>before,"pickaxe genuinely provides furnace material: "+spawn.kind)
	game.free()

## Сценарий: первая плавка списывает руду и ждёт топливо, затем выполняется по игровому времени.
## Исходное состояние: уровень один, две руды, дрова в рюкзаке, очередь пуста.
## Ожидаемый результат: металл не появляется сразу, меню приостанавливает работу, двенадцать секунд дают ровно металл и шлак.
func test_queue_fuel_pause_and_exact_completion() -> void:
	var game:=make_game(); station(game); game.change_inventory_count("iron_ore",4)
	var index:=index_for(game,"ore")
	expect(Furnace.summary(game,game.CraftingSystem.RECIPES[index]).contains(game.inventory_item_name("slag")),"ore recipe visibly explains its secondary slag output")
	expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count("iron_ore")==2 and game.materials.metal==0,"ore is reserved when queued without instant output")
	var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not game.CraftingSystem.craft(game,index) and game.export_inventory_counts()==before,"full queue refuses another batch atomically")
	Furnace.update(game,100.0); expect(Furnace.state(game).queue[0].remaining==12.0,"no fuel means no progress or granted metal")
	var wood:int=game.wood; expect(Furnace.load_fuel(game) and game.wood==wood-1,"one wood portion provides twelve base heat seconds")
	game._physics_process(30.0); expect(Furnace.state(game).heat==12.0 and Furnace.state(game).queue[0].remaining==12.0,"crafting window pauses furnace through the actual game loop")
	game.crafting_open=false; game._physics_process(6.0)
	expect(is_equal_approx(Furnace.state(game).heat,6.0) and is_equal_approx(Furnace.state(game).queue[0].remaining,6.0),"ordinary game loop consumes exactly active processing time")
	game._physics_process(6.0)
	expect(game.materials.metal==1 and game.inventory_item_count("slag")==1 and Furnace.state(game).queue.is_empty() and is_zero_approx(Furnace.state(game).heat),"completed ore grants metal plus slag exactly once")
	Furnace.update(game,100.0); expect(game.materials.metal==1 and Furnace.state(game).completed==1,"idle updates cannot duplicate a completed batch")
	game.free()

## Сценарий: пять поддерживаемых горючих материалов загружаются отдельными порциями.
## Исходное состояние: пустая очередь и нулевой запас жара, затем резерв заполнен.
## Ожидаемый результат: энергия соответствует топливу, простой её не расходует, переполнение не уничтожает предмет.
func test_all_fuels_idle_and_capacity() -> void:
	var game:=make_game(); station(game)
	for kind in Furnace.Data.FUELS:
		var value:=Furnace.state(game); value.fuel=kind; value.heat=0.0; game.change_inventory_count(kind,1)
		var before:int=game.inventory_item_count(kind)
		expect(Furnace.load_fuel(game) and game.inventory_item_count(kind)==before-1 and value.heat==Furnace.Data.FUELS[kind],"exact fuel energy and debit: "+kind)
		Furnace.update(game,100.0); expect(value.heat==Furnace.Data.FUELS[kind],"idle furnace preserves stored heat: "+kind)
	var value:=Furnace.state(game); value.fuel="trash"; value.heat=119.0; game.change_inventory_count("trash",1)
	var counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Furnace.load_fuel(game) and game.export_inventory_counts()==counts and value.heat==119.0,"overfull fuel reserve rejects entire portion without waste")
	game.current_location="overworld"; value.heat=0.0
	expect(not Furnace.load_fuel(game) and game.export_inventory_counts()==counts,"fuel loading cannot bypass physical furnace station")
	game.free()

## Сценарий: два улучшения расширяют очередь и ускоряют уже поставленную работу.
## Исходное состояние: одна партия частично готова, все материалы и деньги для улучшений выданы.
## Ожидаемый результат: уровни ограничены тремя, доля готовности сохраняется, большая дельта останавливается после исчерпания жара.
func test_three_levels_batch_and_efficiency() -> void:
	var game:=make_game(); station(game); game.change_inventory_count("sand",30)
	game.CraftingSystem.craft(game,index_for(game,"glass")); Furnace.state(game).heat=100.0; Furnace.update(game,2.0)
	var ratio:float=float(Furnace.state(game).queue[0].remaining)/float(Furnace.state(game).queue[0].duration)
	var before:Dictionary=game.export_inventory_counts().duplicate(); var coins:int=game.coins
	expect(not Furnace.upgrade(game) and game.export_inventory_counts()==before and game.coins==coins,"unaffordable upgrade leaves all state untouched")
	game.coins=1000
	for cost in Furnace.Data.UPGRADES:
		for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
		expect(Furnace.upgrade(game),"each supported upgrade applies exact declared cost")
		expect(is_equal_approx(float(Furnace.state(game).queue[0].remaining)/float(Furnace.state(game).queue[0].duration),ratio),"upgrade preserves progress fraction while accelerating queued work")
	expect(Furnace.state(game).level==3 and game.coins==720 and not Furnace.upgrade(game),"furnace stops at third level after spending eighty and two hundred coins")
	Furnace.update(game,100.0); var glass:int=game.inventory_item_count("glass")
	expect(game.CraftingSystem.craft_many(game,index_for(game,"glass"),99)==3,"third level caps batch queue at three instead of instant ninety-nine products")
	expect(game.message==game.LocaleSystem.ui("furnace_queued_many",[3]),"batch message describes queued rather than already granted products")
	Furnace.state(game).heat=10.0; Furnace.update(game,100.0)
	expect(game.inventory_item_count("glass")==glass+2 and Furnace.state(game).queue.size()==2 and is_zero_approx(Furnace.state(game).heat),"third-level efficiency completes one batch and partially heats the next with ten energy units")
	Furnace.state(game).fuel="coal"; game.change_inventory_count("coal",1); Furnace.load_fuel(game); Furnace.update(game,100.0)
	expect(game.inventory_item_count("glass")==glass+6 and Furnace.state(game).queue.is_empty(),"refilling resumes remaining work without recreating already completed glass")
	game.free()

## Сценарий: стекло обеспечивает алхимию, дрова превращаются в уголь, сталь и шлак используют уровни.
## Исходное состояние: сырьё выдано, уровень один затем последовательно разрешаются новые рецепты.
## Ожидаемый результат: каждый из семи рецептов имеет точный отложенный выход и необходимые ограничения.
func test_glass_vials_charcoal_steel_and_slag() -> void:
	var game:=make_game(); station(game)
	for recipe in Furnace.Data.RECIPES:
		Furnace.state(game).level=1; var index:=index_for(game,recipe.id.trim_prefix("furnace:"))
		for kind in recipe.inputs: game.change_inventory_count(kind,int(recipe.inputs[kind]))
		if int(recipe.furnace_level)>1: expect(not game.CraftingSystem.craft(game,index),"advanced recipe requires its furnace level: "+recipe.id)
		Furnace.state(game).level=int(recipe.furnace_level); Furnace.state(game).heat=100.0
		var before:int=game.inventory_item_count(recipe.output); var counter:int=game.state.player.profile.get("workbench_crafts",0)
		expect(game.CraftingSystem.craft(game,index) and game.inventory_item_count(recipe.output)==before,"output stays deferred for recipe: "+recipe.id)
		Furnace.update(game,100.0)
		expect(game.inventory_item_count(recipe.output)==before+int(recipe.count) and Furnace.state(game).queue.is_empty(),"exact completed recipe output: "+recipe.id)
		expect(game.state.player.profile.workbench_crafts==counter,"furnace completion never advances workbench master counter")
	expect(game.inventory_item_count("glass_vial")==3 and game.inventory_item_count("charcoal")==2 and game.inventory_item_count("steel")==1,"furnace products support alchemy, fuel and highest upgrade")
	expect(game.tutorial_events_completed.has("furnace_queue") and game.tutorial_events_completed.has("furnace_done"),"actual production teaches queue and completed products")
	game.free()

## Сценарий: управление меняет топливо и сохраняется частично нагретая партия через настоящий файл.
## Исходное состояние: обычный горн открыт, есть руда и уголь, очередь работает три секунды.
## Ожидаемый результат: клавиатура, геймпад и касание сохраняют окно, загрузка продолжает работу один раз, повреждённый слот не меняет мир.
func test_input_and_disk_roundtrip() -> void:
	var game:=make_game(); station(game); game.change_inventory_count("iron_ore",2); game.change_inventory_count("coal",2)
	game.handle_crafting_input(key_event(KEY_Q,KEY_Q,true)); expect(Furnace.state(game).fuel=="log","Q cycles ordinary furnace fuel")
	game.handle_crafting_input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true)); expect(Furnace.state(game).fuel=="coal","right shoulder selects coal")
	game.ItemWindowRenderer.handle_crafting_pointer(game,Visual.LOAD_BUTTON.get_center())
	expect(Furnace.state(game).heat==36.0 and game.inventory_item_count("coal")==1,"touch loads one coal without enqueuing a recipe")
	game.CraftingSystem.craft(game,index_for(game,"ore")); Furnace.update(game,3.0)
	var path:="/private/tmp/farm-furnace-save-%d.json"%Time.get_ticks_usec()
	expect(game.SaveSystem.save_at(game,path),"partial furnace queue writes an actual validated disk slot")
	var restored:=make_game(); expect(game.SaveSystem.load_at(restored,path),"partial furnace queue reloads from disk")
	expect(Furnace.state(restored).fuel=="coal" and Furnace.state(restored).heat==33.0 and Furnace.state(restored).queue[0].remaining==9.0,"selected fuel, unspent heat and partial work roundtrip exactly")
	Furnace.update(restored,9.0); expect(restored.materials.metal==1 and restored.inventory_item_count("slag")==1,"loaded work finishes without charging ore again")
	var data:Dictionary=restored.SaveSystem.snapshot(restored); var unchanged:Dictionary=data.duplicate(true)
	data.estate.expansion.furnace.queue=[{"id":"furnace:ore","duration":12.0,"remaining":"broken"}]
	expect(not restored.SaveSystem.apply(restored,data) and restored.SaveSystem.snapshot(restored)==unchanged,"malformed queue is rejected before changing live state")
	DirAccess.remove_absolute(path); game.free(); restored.free()

## Сценарий: старый слот содержит только прежние источники без новых материалов горна.
## Исходное состояние: старый кристалл истощён, шесть добавленных узлов изменены в живой модели.
## Ожидаемый результат: загрузка сохраняет прежнее истощение и восстанавливает новые источники с начальным запасом.
func test_old_save_resource_defaults() -> void:
	var game:=make_game(); var data:Dictionary=game.SaveSystem.snapshot(game)
	var legacy_count:int=game.resource_nodes.find_custom(func(node): return node.kind==Furnace.Data.SPAWNS[0].kind and node.position==Furnace.Data.SPAWNS[0].position)
	data.resource_hits.resize(legacy_count); data.resource_hits[2]=0
	for index in range(legacy_count,game.resource_nodes.size()): game.resource_nodes[index].hits=0
	expect(game.SaveSystem.apply(game,data),"pre-furnace snapshot remains loadable")
	expect(game.resource_nodes[2].hits==0,"pre-furnace snapshot preserves historical depletion")
	for index in Furnace.Data.SPAWNS.size():
		var spawn:Dictionary=Furnace.Data.SPAWNS[index]; var node:Dictionary=game.resource_nodes[legacy_count+index]
		expect(node.kind==spawn.kind and node.position==spawn.position and node.hits==spawn.hits,"absent furnace source restores exact initial stock: "+spawn.kind)
	game.free()

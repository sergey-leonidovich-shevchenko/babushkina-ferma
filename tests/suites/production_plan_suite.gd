extends "res://tests/suites/suite_base.gd"

const Plan := preload("res://scripts/systems/production_plan_system.gd")
const Graph := preload("res://scripts/systems/production_graph_system.gd")
const Guide := preload("res://scripts/systems/production_guide_system.gd")

## Проверяет весь граф, округление, побочные продукты, реальные партии и безопасность справочника.
func run() -> void:
	test_catalog_and_sources()
	test_rounding_byproducts_and_cycles()
	test_real_craft_and_current_talents()
	test_guide_controls_and_remote_stock()

## Сценарий: каждый существующий рецепт раскрывается до внешнего сырья без изменения игры.
## Исходное состояние: чистая ферма и общий каталог рецептов с настоящими источниками.
## Ожидаемый результат: планы конечны, количества положительны, важные сырьевые источники подтверждены реестрами.
func test_catalog_and_sources() -> void:
	var game:=make_game(); var before:Dictionary=game.SaveSystem.snapshot(game); var graph:=Graph.catalog(game)
	expect(graph.recipes.size()==game.CraftingSystem.RECIPES.size(),"planner exports every canonical recipe")
	for index in graph.recipes.size():
		var result:=Plan.plan(graph.recipes,index)
		expect(not result.truncated and result.output_count==int(graph.recipes[index].count),"complete finite baseline plan: "+graph.recipes[index].id)
		for kind in result.missing:
			expect(game.InventorySystem.ITEM_DATA.has(kind) and int(result.missing[kind])>0,"external input is registered and strictly positive: "+kind)
	for kind in ["wheat","milk","egg","log","iron_ore","chamomile","bees","pollen","glass_shard"]:
		expect(graph.sources.has(kind) and not graph.sources[kind].is_empty(),"real source documented for "+kind)
	expect(game.SaveSystem.snapshot(game)==before,"building all graph plans changes no inventory coins knowledge RNG or paid work")
	var flower:int=game.shop_products.find_custom(func(product): return product.kind=="flower")
	expect(game.ShopSystem.buy(game,flower) and game.inventory_item_count("flower")==1 and game.coins==12,"previously unavailable flower has a real affordable source")
	expect(game.ShopSystem.sell(game,flower) and game.coins==19,"flower purchase and resale cannot generate coins")
	game.free()

## Сценарий: вложенные партии дают остатки, побочный воск покрывает другой вход, цикл требует внешнего предмета.
## Исходное состояние: маленькие графы с заранее вычисленными количествами и намеренно длинной цепью.
## Ожидаемый результат: нет округления вниз, повторного списания остатков или бесконечной рекурсии.
func test_rounding_byproducts_and_cycles() -> void:
	var recipes:=[{"id":"part","output":"part","count":2,"inputs":{"ore":3}},{"id":"tool","output":"tool","count":1,"inputs":{"part":3}}]
	var result:=Plan.plan(recipes,1,{},2)
	expect(result.missing=={"ore":9} and result.output_count==2,"three complete nested batches satisfy two roots without rounding down")
	result=Plan.plan(recipes,1,{"part":1},2)
	expect(result.missing=={"ore":9} and result.remaining.get("part",0)==1,"partial stock and excess output are reused across batches")
	var wax:=[{"id":"honey","output":"honey","count":1,"inputs":{"comb":1},"byproducts":{"wax":1}},{"id":"candle","output":"candle","count":1,"inputs":{"wax":2,"honey":1}}]
	result=Plan.plan(wax,1)
	expect(result.missing=={"comb":2} and result.remaining=={"honey":1},"byproduct production reuses its primary honey without extra raw comb")
	var cycle:=[{"id":"a","output":"a","count":1,"inputs":{"b":1}},{"id":"b","output":"b","count":1,"inputs":{"a":1}}]
	result=Plan.plan(cycle,0)
	expect(result.missing=={"a":1} and "cycle:a" in result.warnings,"cycle asks for one external seed item instead of inventing free resources")
	var deep:Array=[]
	for index in 20: deep.append({"id":str(index),"output":"node"+str(index),"count":1,"inputs":{"node"+str(index+1):2}})
	result=Plan.plan(deep,0,{},999)
	expect(result.truncated and result.steps.size()<=Plan.MAX_OPERATIONS,"deep large plan stops at a hard operation limit")
	expect(Plan.plan(recipes,-1).truncated,"unknown root recipe is rejected before planning")
	recipes.append({"id":"wood_part","output":"part","count":3,"inputs":{"wood":2}})
	expect(Plan.plan(recipes,1,{},1,{"part":2}).missing=={"wood":2},"chosen alternative changes actual nested raw materials")
	result=Plan.plan(recipes,0,{},1,{}, {"counter":4,"master":true,"costs":{"0":{"ore":1}}})
	expect(result.missing=={"ore":1} and result.output_count==4,"custom current cost and fifth-craft bonus are applied in the same batch")

## Сценарий: рассчитанные партии реально изготавливаются с текущей экономией и пятым бонусным крафтом.
## Исходное состояние: два коврика, счётчик четыре, фиксированный высокий ранг кузнеца и талант мастера.
## Ожидаемый результат: выданного расчётом сырья хватает ровно для указанного порядка; выход и остатки совпадают.
func test_real_craft_and_current_talents() -> void:
	var game:=make_game(); game.skill_levels.smithing=10; game.talent_levels.craft_efficient=1; game.talent_levels.craft_master=1
	game.state.player.profile.workbench_crafts=4
	var graph:=Graph.catalog(game)
	var index:int=graph.recipes.find_custom(func(recipe): return recipe.output=="woven_rug" and recipe.station=="workbench")
	var stock:={}
	for kind in game.InventorySystem.ITEM_DATA: stock[kind]=game.inventory_item_count(kind)
	var before:Dictionary=game.SaveSystem.snapshot(game)
	var result:=Plan.plan(graph.recipes,index,stock,2,{},Graph.options(game))
	expect(game.SaveSystem.snapshot(game)==before,"current-skill plan only reads the hero state")
	for kind in result.missing: game.change_inventory_count(kind,int(result.missing[kind]))
	game.crafting_station="workbench"
	for step in result.steps: expect(game.CraftingSystem.craft(game,int(step.index)),"actual ordered batch accepts planned inputs: "+step.id)
	expect(game.inventory_item_count("woven_rug")==int(result.output_count),"actual master output matches planned output")
	for kind in result.remaining: expect(game.inventory_item_count(kind)==int(result.remaining[kind]),"actual virtual-stock remainder agrees: "+kind)
	game.free()

## Сценарий: план использует только рюкзак, переживает смену разделов и принимает все способы выбора.
## Исходное состояние: пшеница только в удалённом сундуке, открыт справочник хлеба.
## Ожидаемый результат: сундук ничего не оплачивает, мир на паузе, клавиши и кнопки меняют только временный выбор.
func test_guide_controls_and_remote_stock() -> void:
	var game:=make_game(); game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	game.state.player.adventure_ui.creation_open=false; game.state.player.adventure_ui.dialogue_open=false
	game.state.storage.change("wheat",999); game.WorldMapSystem.toggle(game); game.WorldMapSystem.set_page(game,4)
	game.world_guide_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="kitchen:bread")
	var before:Dictionary=game.SaveSystem.snapshot(game); var result:Dictionary=Guide.data(game).plan
	expect(result.missing.get("wheat",0)==4,"remote chest stock never supplies a planning ingredient")
	game._input(key_event(KEY_EQUAL,KEY_EQUAL,true))
	expect(Guide.state(game).batches==2,"real modal key increases planned batches")
	game._input(key_event(KEY_G,KEY_G,true))
	expect(Guide.state(game).tab==1 and game.world_map_open,"plan section key preserves the shared menu")
	game._input(joypad_button_event(JOY_BUTTON_Y,true)); game._input(joypad_button_event(JOY_BUTTON_DPAD_RIGHT,true)); game._input(joypad_button_event(JOY_BUTTON_A,true))
	expect(Guide.state(game).batches==3,"controller focus activates the actual plus control")
	game.WorldMapSystem.handle_pointer(game,Guide.BUTTONS[6].get_center())
	expect(Guide.state(game).tab==2 and not Guide.rows(game).is_empty(),"pointer opens actual source records")
	game.WorldMapSystem.handle_pointer(game,Guide.BUTTONS[5].get_center())
	expect(Guide.rows(game).size()>6,"nested bread plan contains enough rows for actual scrolling")
	var wheel:=InputEventMouseButton.new(); wheel.pressed=true; wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.position=Vector2(800,400); game._input(wheel)
	expect(Guide.state(game).row==1,"wheel scrolls the plan by one row")
	game.GameLoop.physics_process(game,10)
	expect(game.SaveSystem.snapshot(game)==before,"planning and all controls preserve world time and inventory")
	game.message="old world notification"; game.hud_message_timer=3
	expect(not preload("res://scripts/systems/story_ui_renderer.gd").notification_visible(game),"world toast cannot obscure the full-screen production guide")
	expect(Guide.data(game).rowsets.size()<=3,"planner retains only one plan and at most three row sets")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		expect(Guide.data(game).graph.names.wheat==game.inventory_item_name("wheat"),"planner cache refreshes localized item names: "+locale)
	game.LocaleSystem.current="ru"; game.free()

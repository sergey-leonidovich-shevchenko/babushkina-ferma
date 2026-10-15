extends "res://tests/suites/basement_suite.gd"

const Queue := preload("res://scripts/systems/production_queue_system.gd")

## Проверяет точную стоимость и возврат каждой производственной очереди на всех уровнях.
func run() -> void:
	expect(preload("res://scripts/systems/tutorial_system.gd").STEP_IDS[0]=="move","production lesson preserves the existing first tutorial step")
	test_every_station_cost_and_refund()
	test_cancel_controls_and_json()
	test_full_backpack_output_and_dismantle()

## Подготавливает реальный личный станок и канонический простой рецепт, не смешивая экземпляры.
func setup(kind: String, level: int=1) -> Dictionary:
	var game:=make_game(); enter(game); var item:=place(game,kind,28,18); finish(game,item)
	item.level=level; item.production.level=level; game.energy=1000
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
	var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("station","")==kind and Basement.Data.recipe_level(recipe)==1 and not recipe.has("talent") and not recipe.has("study_kind"))
	if kind=="cauldron": index=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="kitchen:soup")
	var recipe:Dictionary=game.CraftingSystem.RECIPES[index]
	for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
	if kind=="furnace" or kind=="cauldron" or game.WorkshopSystem.thermal(kind):
		game.change_inventory_count("wood",10)
		for portion in 10:
			if kind=="furnace": game.FurnaceSystem.load_fuel(game)
			elif kind=="cauldron": game.CraftingSystem.Kitchen.load_fuel(game)
			else: game.WorkshopSystem.load_fuel(game)
	game.crafting_selected=index
	return {"game":game,"item":item,"recipe":recipe,"index":index}

## Продвигает только переданную личную очередь по настоящему правилу данного станка.
func advance(game: Node, item: Dictionary, seconds: float) -> void:
	if item.kind=="furnace": game.FurnaceSystem.advance(game,item.production,seconds)
	elif item.kind=="cauldron": game.CraftingSystem.Kitchen.advance(game,item.production,seconds)
	else: game.WorkshopSystem.advance(game,item.kind,item.production,seconds)

## Сценарий: каждый станок отменяет половину оплаченной партии, затем делает её заново до конца.
## Исходное состояние: полный состав, запас настоящего топлива и уровни от первого до третьего.
## Ожидаемый результат: отмена возвращает только сырьё один раз; предпросмотр жара совпадает с расходом готовой партии.
func test_every_station_cost_and_refund() -> void:
	var kinds:Array=["furnace","cauldron"]+preload("res://scripts/systems/workshop_data.gd").STATIONS.keys()
	for kind in kinds:
		for level in range(1,4):
			var fixture:=setup(kind,level); var game:Node=fixture.game; var item:Dictionary=fixture.item; var recipe:Dictionary=fixture.recipe
			var counts:Dictionary=game.export_inventory_counts().duplicate(); var expected:=Queue.heat_cost(game,recipe)
			var crafts:int=game.state.player.craft_count
			expect(game.CraftingSystem.craft(game,fixture.index),"reserve canonical batch: %s/%d"%[kind,level])
			var half:float=item.production.queue[0].remaining*0.5
			advance(game,item,half); var heat:float=item.production.heat; var energy:int=game.energy
			expect(Queue.cancel_first(game),"cancel actual half-finished batch: %s/%d"%[kind,level])
			expect(game.export_inventory_counts()==counts and game.energy==energy and item.production.heat==heat and game.state.player.craft_count==crafts,"refund includes no fuel energy output or XP: %s/%d"%[kind,level])
			var before:Dictionary=game.SaveSystem.snapshot(game)
			expect(not Queue.cancel_first(game) and game.SaveSystem.snapshot(game)==before,"duplicate cancel is atomic: "+kind)
			expect(game.CraftingSystem.craft(game,fixture.index),"returned ingredients form one new paid batch: "+kind)
			advance(game,item,100)
			expect(item.production.queue.is_empty() and is_equal_approx(heat-float(item.production.heat),expected),"preview heat matches full real batch at tier %d: %s"%[level,kind])
			expect(game.inventory_item_count(recipe.output)==int(counts.get(recipe.output,0))+int(recipe.count),"completion grants canonical output once: "+kind)
			var done:Dictionary=game.export_inventory_counts().duplicate(); advance(game,item,100)
			expect(game.export_inventory_counts()==done,"idle queue never repeats output: "+kind)
			game.free()

## Сценарий: отмена вызывается всеми способами, а затем повторяется после загрузки полупартии.
## Исходное состояние: личный горн, его рабочая сторона и отдельные оплаченные партии.
## Ожидаемый результат: ввод не создаёт новую партию, загрузка сохраняет цену, удалённая отмена отклоняется.
func test_cancel_controls_and_json() -> void:
	var fixture:=setup("furnace"); var game:Node=fixture.game; var recipe:Dictionary=fixture.recipe; var item:Dictionary=fixture.item
	for mode in 3:
		if mode>0:
			for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
		game.CraftingSystem.craft(game,fixture.index)
		if mode==0: game.CraftingSystem.handle_input(game,key_event(KEY_DELETE,KEY_DELETE,true))
		elif mode==1: game.CraftingSystem.handle_input(game,joypad_button_event(JOY_BUTTON_RIGHT_STICK,true))
		else: game.ItemWindowRenderer.handle_crafting_pointer(game,Queue.BUTTON.get_center())
		expect(item.production.queue.is_empty(),"queue cancel consumes the explicit input: %d"%mode)
	game.CraftingSystem.craft(game,fixture.index); advance(game,item,1)
	var loaded:=make_game()
	expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))),"reserved half-batch loads before cancellation")
	var saved:Dictionary=Basement.state(loaded).objects[0]
	loaded.player=Basement.Layout.center(Basement.Layout.approach_cell(saved)); Stations.interact(loaded,saved.id)
	expect(Queue.cancel_first(loaded) and saved.production.queue.is_empty(),"loaded paid ledger refunds exactly once")
	game.crafting_open=true; game.current_location="overworld"
	var before:Dictionary=game.SaveSystem.snapshot(game)
	expect(not Queue.cancel_first(game) and game.SaveSystem.snapshot(game)==before,"cancel cannot reach a remote station")
	game.free(); loaded.free()

## Сценарий: зрительно заполненный рюкзак принимает результат, занятый станок разбирается через чертёж.
## Исходное состояние: больше шестидесяти видов вещей и одна оплаченная плавка.
## Ожидаемый результат: выход не теряется; демонтаж возвращает резерв один раз и отменять исчезнувшую очередь нельзя.
func test_full_backpack_output_and_dismantle() -> void:
	var fixture:=setup("furnace"); var game:Node=fixture.game; var item:Dictionary=fixture.item
	var filled:=0
	for kind in game.InventorySystem.ITEM_DATA:
		if game.InventorySystem.category(kind)!="resource": continue
		game.change_inventory_count(kind,1); filled+=1
		if filled>=70: break
	expect(filled>=60,"output test exceeds the original visible backpack capacity")
	var metal:int=game.inventory_item_count("metal")
	game.CraftingSystem.craft(game,fixture.index); advance(game,item,100)
	expect(game.inventory_item_count("metal")==metal+1,"completed output enters the unbounded inventory without hidden output-slot loss")
	for kind in fixture.recipe.inputs: game.change_inventory_count(kind,int(fixture.recipe.inputs[kind]))
	game.CraftingSystem.craft(game,fixture.index)
	game.crafting_open=false; game.player=Basement.Data.BOARD; Basement.open(game)
	expect(Build.dismantle(game,item.id),"occupied station dismantles using its paid ledger")
	var before:Dictionary=game.SaveSystem.snapshot(game); game.crafting_open=true
	expect(not Queue.cancel_first(game),"dismantled queue cannot return its ingredients a second time")
	game.crafting_open=false
	expect(game.SaveSystem.snapshot(game)==before,"failed cancellation after dismantling preserves the saved world")
	game.free()

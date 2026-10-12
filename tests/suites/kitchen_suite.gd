extends "res://tests/suites/basement_suite.gd"

const Kitchen := preload("res://scripts/systems/kitchen_system.gd")
const FX := preload("res://scripts/presentation/kitchen_fx_renderer.gd")

## Проверяет личную кухню, топливо, рецепты, улучшения, сохранения и прежнее начало игры.
func run() -> void:
	test_payment_heat_and_completion()
	test_upgrade_capacity_and_independence()
	test_save_refund_and_invalid_payloads()
	test_input_filters_and_legacy_food()
	test_bulk_limits_and_cross_room_pause()
	test_art_languages_and_food_effects()

## Находит устойчивый рецепт по результату, не завися от индекса каталога.
func recipe_index(game: Node, kind: String) -> int:
	return game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output==kind)

## Выдаёт полный тестовый состав блюда и открывает единственную сторону конкретной кухни.
func prepare(game: Node, item: Dictionary, kind: String, times: int=1) -> Dictionary:
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
	var recipe:Dictionary=game.CraftingSystem.RECIPES[recipe_index(game,kind)]
	for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material])*times)
	game.energy=12; return recipe

## Улучшает оплаченный экземпляр настоящей сборкой через чертёж.
func improve(game: Node, item: Dictionary) -> void:
	game.crafting_open=false; game.player=Basement.Data.BOARD; Basement.open(game); game.coins=1000
	var cost:=Basement.Data.upgrade_cost("cauldron",item.level)
	for material in cost.inputs: game.change_inventory_count(material,int(cost.inputs[material]))
	expect(Build.upgrade(game,item.id),"kitchen upgrade is paid at blueprint")
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
	for second in int(item.duration): game.energy=int(item.energy); Build.update_hold(game,1)
	expect(item.phase=="ready" and item.level==item.target,"paid upgrade finishes by actual held assembly")

## Сценарий: горячая партия оплачивается сразу, ждёт топливо и готовится после закрытия окна.
## Исходное состояние: новый котелок, полные ингредиенты супа, нулевой жар и одна порция дерева.
## Ожидаемый результат: расход единожды, пауза останавливает очередь, результат и опыт выдаются только после восьми секунд работы.
func test_payment_heat_and_completion() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"cauldron",28,18); finish(game,item)
	var recipe:=prepare(game,item,"soup"); var crafts:int=game.state.player.craft_count; var farming:int=game.skill_xp.farming
	expect(Kitchen.enqueue(game,recipe) and game.energy==11 and game.inventory_item_count("carrot")==0 and item.production.queue.size()==1,"enqueue atomically reserves exact soup ingredients and one energy")
	expect(game.inventory_item_count("soup")==0 and game.state.player.craft_count==crafts and game.skill_xp.farming==farming,"queued food has neither output nor premature XP")
	Production.update(game,100); expect(item.production.queue[0].remaining==8 and not FX.working(item),"unheated hot job waits with no false flame or completion")
	game.change_inventory_count("wood",1); expect(Kitchen.load_fuel(game) and item.production.heat==12,"one wood contributes exact clean cooking heat")
	var before:Dictionary=game.export_inventory_counts().duplicate(); expect(not Kitchen.enqueue(game,recipe) and game.export_inventory_counts()==before and game.energy==11,"full queue refuses all further charges")
	game._physics_process(10); expect(item.production.queue[0].remaining==8 and item.production.heat==12,"open cooking window pauses world production")
	game.crafting_open=false; game.tutorial_visible=false; game._physics_process(3)
	expect(is_equal_approx(item.production.queue[0].remaining,5) and is_equal_approx(item.production.heat,9) and FX.working(item),"active world consumes exactly one heat per second at tier one")
	Production.update(game,5); expect(item.production.queue.is_empty() and game.inventory_item_count("soup")==1 and game.state.player.craft_count==crafts+1 and game.skill_xp.farming==farming+3,"completed soup grants exact food and farming XP once")
	Production.update(game,100); expect(item.production.heat==4 and game.inventory_item_count("soup")==1 and not FX.working(item),"idle kitchen neither burns heat nor duplicates output")
	prepare(game,item,"flour"); Kitchen.enqueue(game,Kitchen.Data.recipe("kitchen:flour")); item.production.heat=0; Production.update(game,4)
	expect(game.inventory_item_count("flour")==1 and item.production.heat==0,"cold preparation succeeds without any fuel")
	prepare(game,item,"soup"); Kitchen.enqueue(game,recipe); item.production.heat=2; Production.update(game,100)
	expect(item.production.queue[0].remaining==6 and item.production.heat==0,"insufficient heat advances only the affordable fraction")
	item.production.heat=115; game.change_inventory_count("wood",1); var wood:int=game.inventory_item_count("wood")
	expect(not Kitchen.load_fuel(game) and item.production.heat==115 and game.inventory_item_count("wood")==wood,"full portion never silently clamps away paid fuel")
	item.production.fuel="trash"; expect(not Kitchen.load_fuel(game),"kitchen refuses dirty furnace fuel")
	game.free()

## Сценарий: улучшение сохраняет долю партии, увеличивает очередь и не влияет на соседнюю кухню.
## Исходное состояние: два готовых котелка, наполовину сваренный суп и ингредиенты сложной еды.
## Ожидаемый результат: очередь ускоряется без доплаты, уровни открывают жарку и выпечку, все экземпляры работают один раз.
func test_upgrade_capacity_and_independence() -> void:
	var game:=make_game(); enter(game); var left:=place(game,"cauldron",25,18); finish(game,left); var right:=place(game,"cauldron",38,18); finish(game,right)
	var soup:=prepare(game,left,"soup"); Kitchen.enqueue(game,soup); left.production.heat=40; Production.update(game,4)
	var fry:=prepare(game,left,"fried_vegetables"); var counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(not Kitchen.enqueue(game,fry) and Kitchen.reason(game,fry)=="basement_recipe_level" and counts==game.export_inventory_counts(),"tier one cannot fry or spend locked ingredients")
	game.crafting_open=false; game.player=Basement.Data.BOARD; Basement.open(game); game.coins=1000
	for material in Basement.Data.upgrade_cost("cauldron",1).inputs: game.change_inventory_count(material,int(Basement.Data.upgrade_cost("cauldron",1).inputs[material]))
	expect(Build.upgrade(game,left.id),"chosen instance enters paid upgrade")
	Production.update(game,20); expect(left.production.queue[0].remaining==4 and right.level==1,"unfinished upgrade freezes only its own job")
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(left)); Stations.interact(game,left.id)
	for second in 7: game.energy=2; Build.update_hold(game,1)
	expect(left.level==2 and is_equal_approx(left.production.queue[0].duration,6.4) and is_equal_approx(left.production.queue[0].remaining,3.2),"tier two keeps fifty-percent progress and speeds duration by 1.25")
	prepare(game,left,"fried_vegetables"); expect(Kitchen.enqueue(game,fry) and left.production.queue.size()==2,"tier two opens frying and a second queue slot")
	Production.update(game,3.2); expect(game.inventory_item_count("soup")==1 and is_equal_approx(left.production.heat,40-4-3.2/1.2),"tier two heat efficiency is applied to actual remaining work")
	improve(game,left); prepare(game,left,"mushroom_pie",3); var pie:=Kitchen.Data.recipe("kitchen:mushroom_pie")
	expect(Kitchen.enqueue(game,pie) and Kitchen.enqueue(game,pie) and not Kitchen.enqueue(game,pie) and left.production.queue.size()==3,"tier three includes prior job and holds at most three paid batches")
	prepare(game,right,"soup"); Kitchen.enqueue(game,soup); right.production.heat=12; left.production.heat=100; game.crafting_open=false; Production.update(game,100)
	expect(right.production.queue.is_empty() and left.production.queue.is_empty() and game.inventory_item_count("soup")==2 and game.inventory_item_count("mushroom_pie")==2,"each independent kitchen finishes all paid jobs once without active-binding duplication")
	game.free()

## Сценарий: оплаченная еда проходит настоящий файл сохранения, подделанные партии отвергаются, разборка возвращает сырьё.
## Исходное состояние: печь третьего уровня с запеканкой и частичным прогрессом.
## Ожидаемый результат: уровень, очередь и журнал сохраняются; неверные топливо, длительность и состав не изменяют живой слот.
func test_save_refund_and_invalid_payloads() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"cauldron",30,18); finish(game,item); improve(game,item); improve(game,item)
	var recipe:=prepare(game,item,"vegetable_casserole"); Kitchen.enqueue(game,recipe); item.production.heat=80; Production.update(game,2.5)
	var path:="/private/tmp/farm-kitchen-save-%d.json"%Time.get_ticks_usec()
	expect(game.SaveSystem.save_at(game,path),"real file accepts full paid kitchen ledger and timed food job")
	var restored:=make_game(); expect(restored.SaveSystem.load_at(restored,path),"disk load restores approved three-tier kitchen")
	var loaded:=Basement.object(restored,item.id)
	expect(loaded.level==3 and loaded.paid==item.paid and is_equal_approx(loaded.production.queue[0].remaining,9.5),"disk keeps exact level, payment ledger and job progress")
	var snapshot:Dictionary=restored.SaveSystem.snapshot(restored)
	for corruption in ["fuel","duration","paid","tier"]:
		var broken:Dictionary=snapshot.duplicate(true); var entry:Dictionary=broken.estate.expansion.basement.objects[0]
		match corruption:
			"fuel": entry.production.fuel="trash"
			"duration": entry.production.queue[0].duration=0.01; entry.production.queue[0].remaining=0.005
			"paid": entry.production.queue[0].paid.erase("egg")
			"tier": entry.production.queue[0].id="kitchen:unknown"
		expect(not restored.SaveSystem.apply(restored,broken) and restored.SaveSystem.snapshot(restored)==snapshot,"invalid kitchen payload refuses atomically: "+corruption)
	game.player=Basement.Data.BOARD; Basement.open(game); var advertised:=Build.salvage(item); var counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(Build.dismantle(game,item.id),"blueprint dismantles chosen kitchen with unfinished food")
	for kind in advertised: expect(game.inventory_item_count(kind)==int(counts.get(kind,0))+int(advertised[kind]),"salvage matches advertised building halves and full food ingredients: "+kind)
	expect(game.inventory_item_count("vegetable_casserole")==0 and not Build.dismantle(game,item.id),"cancelled food never completes or refunds twice")
	DirAccess.remove_absolute(path); game.free(); restored.free()

## Сценарий: все способы ввода разделяют топливо и группы, старый домашний маршрут остаётся доступен.
## Исходное состояние: готовый личный котелок и обычная кухня дома без улучшений.
## Ожидаемый результат: мышь и геймпад совпадают с клавиатурой, обратная сторона блокирует готовку, новые блюда доступны только личной кухне.
func test_input_filters_and_legacy_food() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"cauldron",32,18); finish(game,item); prepare(game,item,"flour")
	game.CraftingSystem.handle_input(game,key_event(KEY_TAB,KEY_TAB,true)); expect(game.get_meta("kitchen_filter")=="hot","keyboard selects hot group")
	game.CraftingSystem.handle_input(game,joypad_button_event(JOY_BUTTON_DPAD_RIGHT,true)); expect(game.get_meta("kitchen_filter")=="cold" and game.CraftingSystem.visible_indices(game).size()==3,"gamepad selects exactly three cold preparations")
	game.ItemWindowRenderer.handle_crafting_pointer(game,preload("res://scripts/presentation/kitchen_renderer.gd").FILTER.get_center()+Vector2(10,0)); expect(game.get_meta("kitchen_filter")=="all","pointer cycles same recipe groups")
	game.CraftingSystem.handle_input(game,key_event(KEY_Q,KEY_Q,true)); expect(item.production.fuel=="log","keyboard cycles only clean fuels")
	game.change_inventory_count("log",1); game.CraftingSystem.handle_input(game,joypad_button_event(JOY_BUTTON_Y,true)); expect(item.production.heat==32 and game.crafting_open,"gamepad Y loads fuel and keeps kitchen window open")
	game.player=Basement.Layout.rect(item).get_center()-Vector2(0,100); var counts:Dictionary=game.export_inventory_counts().duplicate()
	expect(not game.CraftingSystem.craft(game,recipe_index(game,"flour")) and game.export_inventory_counts()==counts,"wrong side cannot fall back to instantaneous public food crafting")
	game.crafting_open=false; game.current_location="cottage_interior"; game.player=Vector2(930,390); game.change_inventory_count("egg",2); game.change_inventory_count("milk",1)
	expect(game.BuildingSystem.use_service(game,"cauldron") and game.CraftingSystem.craft(game,recipe_index(game,"omelet")) and game.inventory_item_count("omelet")==1,"legacy first-morning omelet stays accessible without private upgrades")
	expect(not game.CraftingSystem.visible_indices(game).has(recipe_index(game,"mushroom_pie")) and not game.CraftingSystem.craft(game,recipe_index(game,"mushroom_pie")),"new oven foods do not bypass progression through public kitchen")
	game.free()

## Сценарий: массовая постановка ограничена энергией и местами, производство продолжается вне комнаты и замирает в рюкзаке.
## Исходное состояние: печь с сырьём пяти пирогов и четырьмя единицами энергии, затем кухня с пустым запасом.
## Ожидаемый результат: оплачиваются две полные партии, частичный состав не списывается, вне подвала очередь продвигается один раз.
func test_bulk_limits_and_cross_room_pause() -> void:
	var game:=make_game(); enter(game); var item:=place(game,"cauldron",32,18); finish(game,item); improve(game,item); improve(game,item)
	var recipe:=prepare(game,item,"mushroom_pie",5); game.energy=4
	expect(game.CraftingSystem.max_craftable(game,recipe)==2 and game.CraftingSystem.craft_many(game,recipe_index(game,"mushroom_pie"),99)==2,"bulk jobs obey energy even with three open slots")
	expect(item.production.queue.size()==2 and game.energy==0 and game.inventory_item_count("mushroom")==6 and game.inventory_item_count("mushroom_pie")==0,"bulk reserves exactly two complete recipes with no premature output")
	var before:Dictionary=game.export_inventory_counts().duplicate(); expect(not Kitchen.enqueue(game,recipe) and game.export_inventory_counts()==before,"zero energy refusal leaves every remaining ingredient intact")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		expect(game.LocaleSystem.UI.has(Kitchen.reason(game,recipe)) and Kitchen.reason_text(game,recipe).contains("2"),"energy refusal shows localized exact cost: "+locale)
	game.LocaleSystem.current="ru"
	game.energy=12; game.change_inventory_count("butter",-game.inventory_item_count("butter")); before=game.export_inventory_counts().duplicate()
	expect(not Kitchen.enqueue(game,recipe) and game.energy==12 and before==game.export_inventory_counts(),"missing final ingredient cannot partially consume other stocks or energy")
	item.production.heat=100; game.crafting_open=false; game.tutorial_visible=false; game.current_location="cottage_interior"; game.player=Vector2(700,450)
	game._physics_process(1); var remaining:float=item.production.queue[0].remaining
	expect(is_equal_approx(remaining,20.0/1.5-1),"private queue advances once while hero is in another room")
	game.inventory_open=true; game._physics_process(20)
	expect(is_equal_approx(item.production.queue[0].remaining,remaining),"backpack pauses distant kitchens without consuming reserved heat")
	game.free()

## Сценарий: выбранный рисунок A и четыре новых блюда включены в обычные каталоги игры.
## Исходное состояние: три уровня, четыре ракурса, три подсказки и шесть языков.
## Ожидаемый результат: спрайты отдельны, названия полны, фактическое лечение совпадает с карточкой и продукты продаются.
func test_art_languages_and_food_effects() -> void:
	var game:=make_game(); var art=preload("res://scripts/presentation/kitchen_visual_system.gd")
	for row in art.STATION:
		for texture in row: expect(texture is AtlasTexture and texture.region.size.x>100 and texture.region.size.y>100,"kitchen has an independently measured full silhouette")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for level in range(1,4): expect(game.LocaleSystem.ui("kitchen_stage%d"%level)!="kitchen_stage%d"%level,"every cooking level has localized name")
		for tutorial in ["kitchen_queue","kitchen_fuel","kitchen_done"]: expect(game.LocaleSystem.tutorial(tutorial)!=tutorial,"kitchen tutorial is localized: "+locale)
		for kind in Kitchen.Data.ITEMS: expect(game.LocaleSystem.item(kind)!=kind,"new food is localized: "+kind)
	game.LocaleSystem.current="ru"
	for kind in Kitchen.Data.ITEMS:
		var data:Dictionary=Kitchen.Data.ITEMS[kind]; game.player_hp=10; game.energy=0; game.change_inventory_count(kind,1)
		expect(game.consume_item(kind) and game.player_hp==10+int(data.effect[1]) and game.energy==int(data.effect[2]),"new food applies exactly displayed health and energy: "+kind)
		expect(game.VisualAssetSystem.item_texture(kind) is AtlasTexture and game.ShopSystem.PRODUCTS.any(func(product): return product.kind==kind and int(product.sell)==int(data.sell)),"new food has real icon and sale price: "+kind)
	game.free()

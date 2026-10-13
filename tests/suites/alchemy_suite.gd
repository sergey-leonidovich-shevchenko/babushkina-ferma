extends "res://tests/suites/suite_base.gd"

const ApiaryCounts := preload("res://scripts/systems/apiary_data.gd")

const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")
const Products := preload("res://scripts/systems/alchemy_product_data.gd")
const Recipes := preload("res://scripts/systems/alchemy_recipe_data.gd")
const Alchemy := preload("res://scripts/systems/alchemy_system.gd")

## Проверяет сбор, полные производственные цепочки, развитие, управление и совместимость сохранений.
func run() -> void:
	test_catalog_and_harvest_positions()
	test_processing_and_first_potion()
	test_rank_talent_station_and_batch()
	test_filters_and_localization()
	test_save_migration_and_validation()
	preload("res://tests/suites/alchemy_effects_suite.gd").new(context).run()

## Находит рецепт алхимии по постоянному идентификатору, не смешивая его с вариантом верстака.
func recipe_index(game: Node, output: String) -> int:
	return game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:"+output)

## Размещает проверочную модель у действующей станции без изменения правил рецептов.
func station(game: Node) -> void:
	game.current_location="cottage_interior"; game.player=Alchemy.STATION
	expect(game.NavigationSystem.walkability_reason(game,game.player,-1,false)=="walkable","alchemy table has a real walkable interaction point")
	expect(game.nearest_interaction()=="interior_service:alchemy" and game.perform_context_action() and game.crafting_open and game.crafting_station=="alchemy","ordinary context action opens actual home alchemy service")

## Сценарий: новый каталог подключён к реальным местам сбора и всем реестрам предметов.
## Исходное состояние: чистая игра содержит исторические узлы и двадцать четыре новых растения.
## Ожидаемый результат: позиции проходимы, сбор даёт два растения, все результаты и побочные продукты зарегистрированы.
func test_catalog_and_harvest_positions() -> void:
	var game:=make_game()
	expect(Herbs.HERBS.size()==24 and Products.names().size()==148+ApiaryCounts.RAW.size()+ApiaryCounts.POTIONS.size() and Recipes.recipes().size()==139+ApiaryCounts.MIXES.size(),"alchemy retains 24 herbs and grows complete item/recipe catalogs through apiary and artisan paths")
	expect(game.ContentRegistry.validate().is_empty(),"alchemy references belong to complete content registries")
	for kind in Products.names(): expect(game.VisualAssetSystem.has_item_icon(kind),"shared visual registry provides an actual alchemy texture: "+kind)
	for spawn in Herbs.spawns():
		game.current_location=spawn.location; game.player=spawn.position; game.game_minutes=1260
		expect(game.NavigationSystem.walkability_reason(game,spawn.position,-1,false)=="walkable","herb stands on accessible solid ground: "+spawn.kind)
		var index:int=game.food_nodes.find_custom(func(node): return node.get("id","")==spawn.id)
		game.game_minutes=720 if Herbs.HERBS[spawn.kind].condition=="day" else 1260
		expect(index>=16 and game.ForageSystem.collect(game,index),"herb can be physically harvested: "+spawn.kind)
		expect(game.inventory_item_count(spawn.kind)==2 and not game.ForageSystem.collect(game,index),"herb harvest gives exactly two and cannot repeat: "+spawn.kind)
		game.game_minutes+=Herbs.HERBS[spawn.kind].growth_minutes; game.ForageSystem.update(game)
		expect(game.food_nodes[index].active,"herb regrows after its own interval: "+spawn.kind)
	for recipe in Recipes.recipes():
		expect(int(recipe.count)>0 and not recipe.inputs.is_empty(),"recipe has positive output and actual inputs: "+recipe.id)
		for kind in recipe.inputs: expect(int(recipe.inputs[kind])>0 and game.InventorySystem.ITEM_DATA.has(kind),"recipe has positive registered input: "+recipe.id+":"+kind)
	game.current_location="forest"; game.game_minutes=720
	var night:Dictionary=Herbs.spawns()[8]
	expect(not game.ForageSystem.is_collectable(game,night),"dreamroot is unavailable during daytime")
	game.game_minutes=1260; expect(game.ForageSystem.is_collectable(game,night),"dreamroot becomes available at night")
	game.game_minutes=1080; expect(game.ForageSystem.is_collectable(game,night),"nocturnal herbs open when the sun leaves the celestial dial")
	game.game_minutes=360; expect(not game.ForageSystem.is_collectable(game,night),"nocturnal herbs close at sunrise without a hidden digital clock")
	expect(game.tutorial_events_completed.has("alchemy_herbs"),"first herb unlocks harvesting tutorial")
	game.free()

## Сценарий: собранная ромашка становится соком, тоником и кормом через домашний стол.
## Исходное состояние: герой собирает настоящую ромашку, покупает воду и флакон в общей лавке.
## Ожидаемый результат: сырьё расходуется точно, жмых сохраняется, тоник лечит, опыт выдаётся один раз за открытие.
func test_processing_and_first_potion() -> void:
	var game:=make_game(); var index:int=game.food_nodes.find_custom(func(node): return node.kind=="chamomile")
	game.player=game.food_nodes[index].position; expect(game.ForageSystem.collect(game,index),"basic potion starts from a real meadow patch")
	for kind in ["clean_water","glass_vial"]:
		var product:int=game.shop_products.find_custom(func(entry): return entry.kind==kind)
		expect(game.ShopSystem.buy(game,product),"starting coins buy basic alchemy carrier: "+kind)
	station(game); var juice:int=recipe_index(game,"chamomile_juice")
	expect(game.CraftingSystem.craft(game,juice),"two fresh chamomiles can be pressed at home")
	expect(game.inventory_item_count("chamomile")==0 and game.inventory_item_count("chamomile_juice")==1 and game.inventory_item_count("herb_pulp")==1,"press spends two and grants juice plus intact pulp")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"meadow_tonic")),"juice, purchased water and vial brew a tonic")
	game.player_hp=60; expect(game.consume_item("meadow_tonic") and game.player_hp==85,"brewed tonic restores exactly twenty-five health")
	var xp:int=game.player_xp; game.change_inventory_count("chamomile",4)
	expect(game.CraftingSystem.craft_many(game,juice,2)==2 and game.player_xp==xp and Alchemy.state(game).xp==8,"repeat batches give products without repeated discovery experience")
	var feed_before:int=game.inventory_item_count("animal_feed")
	game.change_inventory_count("wheat",1); expect(game.CraftingSystem.craft(game,recipe_index(game,"animal_feed")),"press waste and wheat become usable farm feed")
	expect(game.inventory_item_count("animal_feed")==feed_before+2 and game.inventory_item_count("herb_pulp")==1,"feed consumes exactly two pulp and yields two feed")
	game.change_inventory_count("nettle",2)
	expect(game.CraftingSystem.craft(game,recipe_index(game,"nettle_dried")) and game.inventory_item_count("nettle_dried")==2,"drying preserves two portions")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"nettle_powder")) and game.inventory_item_count("nettle_powder")==1,"mortar turns two dry portions into one powder")
	expect(game.tutorial_events_completed.has("alchemy_processing") and game.tutorial_events_completed.has("alchemy_brewing"),"actual chain teaches processing and brewing")
	game.free()

## Сценарий: сложная обработка требует ранга, таланта и станции, а вершина требует лабораторию.
## Исходное состояние: сырьё выдано, ограничения последовательно снимаются, ремесленные бонусы включены.
## Ожидаемый результат: отказ не расходует сырьё, алхимия не получает скидок и дублей, партия ограничена девяноста девятью.
func test_rank_talent_station_and_batch() -> void:
	var game:=make_game(); station(game); game.change_inventory_count("field_mint_juice",1); game.change_inventory_count("herb_solvent",1)
	var tincture:int=recipe_index(game,"field_mint_tincture"); var before:Dictionary=game.export_inventory_counts().duplicate()
	expect(not game.CraftingSystem.craft(game,tincture) and game.export_inventory_counts()==before,"locked tincture leaves all inputs untouched")
	game.skill_points=10
	for talent in ["craft_apprentice","craft_alchemy","craft_efficient","craft_engineering","craft_master"]: expect(game.TalentSystem.unlock(game,talent),"fixture really enables talent: "+talent)
	expect(not game.CraftingSystem.can_craft(game,game.CraftingSystem.RECIPES[tincture]),"talent alone cannot bypass alchemy rank")
	for herb in Herbs.HERBS.keys().slice(0,10):
		game.change_inventory_count(herb,2); expect(game.CraftingSystem.craft(game,recipe_index(game,herb+"_dried")),"different basic discoveries increase rank: "+herb)
	expect(Alchemy.rank(game)==2 and Alchemy.state(game).xp==40,"ten distinct discoveries reach second rank")
	expect(game.CraftingSystem.craft(game,tincture) and game.inventory_item_count("herb_solvent")==0,"second rank and talent enable exact tincture chain")
	game.change_inventory_count("field_mint",200); var juice:int=recipe_index(game,"field_mint_juice"); var crafts:int=game.state.player.profile.workbench_crafts
	expect(game.CraftingSystem.material_cost(game,game.CraftingSystem.RECIPES[juice],"field_mint")==2,"workbench efficiency cannot discount plant processing")
	expect(game.CraftingSystem.craft_many(game,juice,1000)==99 and game.inventory_item_count("field_mint")==2 and game.inventory_item_count("field_mint_juice")==99,"batch cap spends exactly one hundred ninety-eight fresh portions")
	expect(game.inventory_item_count("herb_pulp")==99 and game.state.player.profile.workbench_crafts==crafts,"each batch keeps its pulp without workbench master duplication")
	game.player=Vector2(300,500); before=game.export_inventory_counts().duplicate()
	expect(not game.CraftingSystem.craft(game,juice) and game.export_inventory_counts()==before,"production cannot bypass physical table distance")
	station(game); var value:=Alchemy.state(game); value.discovered=[]
	for recipe in Recipes.recipes().slice(0,60): value.discovered.append(recipe.id)
	Alchemy.restore(game); var solar:int=recipe_index(game,"solar_concentrate")
	for kind in game.CraftingSystem.RECIPES[solar].inputs: game.change_inventory_count(kind,1)
	expect(Alchemy.rank(game)==4 and not game.CraftingSystem.can_craft(game,game.CraftingSystem.RECIPES[solar]),"fourth rank still requires the estate laboratory")
	game.state.world.estate.level=4; expect(game.CraftingSystem.craft(game,solar),"laboratory completes the highest tier potion")
	game.free()

## Сценарий: рецепт выбирается клавиатурой, плечевыми кнопками и касанием фильтра.
## Исходное состояние: открыта алхимия, все шесть языков и восемь разделов доступны.
## Ожидаемый результат: фильтры показывают нужные рецепты, имена и эффекты не превращаются в сырые идентификаторы.
func test_filters_and_localization() -> void:
	var game:=make_game(); station(game)
	game.handle_crafting_input(key_event(KEY_TAB,KEY_TAB,true))
	expect(game.get_meta("alchemy_filter")=="juice" and game.CraftingSystem.visible_indices(game).size()==24,"Tab selects all twenty-four juice recipes")
	game.handle_crafting_input(joypad_button_event(JOY_BUTTON_RIGHT_SHOULDER,true))
	expect(game.get_meta("alchemy_filter")=="dried","right shoulder selects drying recipes")
	game.ItemWindowRenderer.handle_crafting_pointer(game,Vector2(650,132))
	expect(game.get_meta("alchemy_filter")=="powder","touchable filter selects mortar recipes")
	game.ItemWindowRenderer.handle_crafting_pointer(game,Vector2(230,132))
	expect(game.get_meta("alchemy_filter")=="dried","left side of touch filter returns to previous section")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in Products.names(): expect(game.inventory_item_name(kind)!=kind and not game.inventory_item_name(kind).is_empty(),"localized alchemy item: "+locale+":"+kind)
		for kind in Products.POTIONS: expect(not game.ItemPresentationSystem.effect_text(game,kind).is_empty(),"localized potion mechanics: "+locale+":"+kind)
		expect(game.LocaleSystem.crafting_ingredient("nettle_powder")!=game.LocaleSystem.crafting_ingredient("sage_powder"),"compact materials preserve botanical source in "+locale)
	game.LocaleSystem.current="ru"; game.free()

## Сценарий: старый слот содержит посаженное дерево на месте будущего первого нового растения.
## Исходное состояние: исторические шестнадцать узлов, одно дерево игрока, затем новый слот со срезанной травой.
## Ожидаемый результат: дерево и трава сохраняются отдельно, открытия нормализуются, повреждённые записи не меняют игру.
func test_save_migration_and_validation() -> void:
	var game:=make_game(); var saved:Dictionary=game.SaveSystem.snapshot(game)
	saved.forage=saved.forage.slice(0,16)
	saved.forage.append({"kind":"apple","active":false,"ready_at":2500.0,"stage":1,"position":[800.0,900.0],"location":"overworld","planted_by_player":true})
	saved.estate.expansion.erase("alchemy")
	var restored:=make_game(); expect(game.SaveSystem.apply(restored,saved),"historical orchard slot loads into expanded herb world")
	var planted:Dictionary=restored.food_nodes.back()
	expect(restored.food_nodes.size()==game.ForageSystem.default_nodes().size()+1 and planted.kind=="apple" and planted.position==Vector2(800,900) and planted.stage==1 and planted.planted_by_player,"player tree at historical index sixteen remains a separate planted tree")
	var herb:int=restored.food_nodes.find_custom(func(node): return node.get("id","")=="herb:field_mint")
	restored.food_nodes[herb].active=false; restored.food_nodes[herb].ready_at=999.0; restored.change_inventory_count("field_mint_powder",3)
	var value:=Alchemy.state(restored); value.discovered=["alchemy:field_mint_juice","alchemy:field_mint_juice","unknown"]; value.xp=9999; value.effects.mining=44.0
	saved=restored.SaveSystem.snapshot(restored); expect(game.SaveSystem.apply(game,saved),"new herb state and materials roundtrip")
	expect(not game.food_nodes[herb].active and game.food_nodes[herb].ready_at==999.0 and game.inventory_item_count("field_mint_powder")==3,"stable herb identity preserves regrowth and inventory")
	expect(Alchemy.state(game).xp==4 and Alchemy.state(game).discovered.size()==1 and Alchemy.remaining(game,"mining")==44.0,"save normalizes duplicate discoveries and retains real buff duration")
	var snapshot:Dictionary=game.SaveSystem.snapshot(game); saved.estate.expansion.alchemy.effects.mining="broken"
	expect(not game.SaveSystem.apply(game,saved) and game.SaveSystem.snapshot(game)==snapshot,"malformed alchemy effects are rejected before live state mutation")
	game.free(); restored.free()

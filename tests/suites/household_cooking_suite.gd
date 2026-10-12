extends "res://tests/suites/suite_base.gd"

const Presentation := preload("res://scripts/systems/item_presentation_system.gd")

## Проверяет кухню от стартовых животных до блюда, домашние материалы, станции и предел партии.
func run() -> void:
	test_first_morning_products_make_a_basic_meal()
	test_station_and_talent_fail_before_spending()
	test_feed_and_wool_to_rug_chain()
	test_food_data_effects_and_localization()
	test_workshop_bonuses_do_not_duplicate_kitchen_food()
	test_large_batches_stay_bounded()

## Находит устойчивый рецепт по предмету результата, не привязываясь к номеру новой строки.
func recipe_index(game: Node, output: String) -> int:
	return game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output==output)

## Сценарий: первая обслуженная ночь даёт ингредиенты для домашнего омлета.
## Исходное состояние: новая ферма без талантов и улучшений имеет только конечный стартовый корм.
## Ожидаемый результат: продукция настоящих животных готовится на кухне и восстанавливает заявленные HP и энергию.
func test_first_morning_products_make_a_basic_meal() -> void:
	var game:=make_game(); var life: Dictionary=game.FarmLifeSystem.state(game)
	game.FarmLifeSystem.Livestock.interact(game,life,"life:trough"); game.FarmLifeSystem.Livestock.interact(game,life,"life:water")
	game.day=2; game.FarmLifeSystem.Livestock.update(game,life,0)
	for id in ["hen","hen_2","hen_3","cow"]: game.FarmLifeSystem.Livestock.interact(game,life,"life:animal:"+id)
	game.current_location="cottage_interior"; game.player=Vector2(930,390)
	expect(game.BuildingSystem.use_service(game,"cauldron") and game.crafting_open,"existing home kitchen is usable before learning cooking talent")
	expect(game.CraftingSystem.RECIPES[game.crafting_selected].output=="omelet","kitchen selects a recipe available from actual first-morning products")
	var smithing_before: int=game.skill_xp.smithing
	expect(game.CraftingSystem.craft(game,recipe_index(game,"omelet")) and game.inventory_item_count("egg")==1 and game.inventory_item_count("milk")==0,"basic omelet consumes exactly two eggs and one milk")
	game.player_hp=20; game.energy=1
	expect(game.consume_item("omelet") and game.player_hp==68 and game.energy==9 and game.inventory_item_count("omelet")==0,"first farm meal applies its card's 48 HP and 8 energy once")
	expect(game.skill_xp.smithing==smithing_before and game.tutorial_events_completed.has("cooking"),"cooking is taught and does not award smithing profession XP")
	game.free()

## Сценарий: игрок пробует готовить у верстака или делать сложное блюдо без способности.
## Исходное состояние: нужные ингредиенты уже имеются, однако станция или талант не подходят.
## Ожидаемый результат: отказ сохраняет все количества и статистику; правильная кухня разрешает базовый рецепт.
func test_station_and_talent_fail_before_spending() -> void:
	var game:=make_game(); game.change_inventory_count("milk",3); var before: Dictionary=game.export_inventory_counts().duplicate(true)
	expect(not game.CraftingSystem.craft(game,recipe_index(game,"cheese")) and game.export_inventory_counts()==before,"wrong station cannot spend milk or produce cheese")
	game.CraftingSystem.open(game,"cauldron")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"cheese")) and game.inventory_item_count("cheese")==1,"correct station cooks basic cheese without a talent")
	for kind in ["truffle","milk","mushroom"]: game.change_inventory_count(kind,1)
	before=game.export_inventory_counts().duplicate(true)
	expect(not game.CraftingSystem.craft(game,recipe_index(game,"truffle_soup")) and game.export_inventory_counts()==before,"advanced recipe checks its talent before consuming a complete ingredient set")
	game.talent_levels.farm_cooking=1
	expect(game.CraftingSystem.craft(game,recipe_index(game,"truffle_soup")),"learning cooking unlocks the gourmet farm recipe")
	game.free()

## Сценарий: хозяйственное сырьё проходит полную цепочку корма и текстиля.
## Исходное состояние: верстак имеет зерно, волокно, три шерсти и два хлопка.
## Ожидаемый результат: корм готовится порциями, шерсть превращается в ткань и полезный ковёр с точным остатком.
func test_feed_and_wool_to_rug_chain() -> void:
	var game:=make_game(); game.change_inventory_count("wheat",2); game.change_inventory_count("fiber",1)
	var feed: int=game.inventory_item_count("animal_feed")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"animal_feed")) and game.inventory_item_count("animal_feed")==feed+2,"two wheat and one fiber create two usable yard feed portions")
	game.change_inventory_count("wool",3); game.change_inventory_count("cotton",2)
	expect(game.CraftingSystem.craft_many(game,recipe_index(game,"yarn"),3)==3 and game.inventory_item_count("yarn")==6,"sheep wool becomes six yarn without free ingredients")
	expect(game.CraftingSystem.craft_many(game,recipe_index(game,"cloth"),2)==2 and game.inventory_item_count("cloth")==2,"four yarn and two cotton become two cloth")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"woven_rug")) and game.inventory_item_count("woven_rug")==1 and game.inventory_item_count("yarn")==1 and game.inventory_item_count("cloth")==0,"cloth has a real furniture use with a preserved material remainder")
	expect(game.tutorial_events_completed.has("animal_feed_recipe") and game.tutorial_events_completed.has("textile_chain"),"both household production chains have their own learning steps")
	game.free()

## Сценарий: все съедобные предметы и новые товары показывают действительные переведённые эффекты.
## Исходное состояние: каталоги переключаются на шесть языков, новые запасы сохраняются и загружаются.
## Ожидаемый результат: еда не расходуется без эффекта, иконки и названия доступны, количества и слоты сохраняются.
func test_food_data_effects_and_localization() -> void:
	var game:=make_game()
	for kind in game.InventorySystem.ITEM_DATA:
		if game.InventorySystem.can_use(kind) and not game.PotionSystem.is_potion(kind): expect(Presentation.FOOD_EFFECTS.has(kind),"every declared edible food has an actual effect: "+kind)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		for kind in ["mayonnaise","pancakes","porridge","truffle_soup","yarn","cloth"]:
			expect(game.LocaleSystem.item(kind)!=kind and game.VisualAssetSystem.item_texture(kind)!=null,"household output has a separate icon and localized name: "+locale+"/"+kind)
		for event in ["cooking","animal_feed_recipe","textile_chain"]: expect(event in game.TutorialSystem.STEP_IDS and game.LocaleSystem.tutorial(event)!=event,"production learning is translated: "+locale+"/"+event)
	game.LocaleSystem.current="ru"
	for kind in ["mayonnaise","pancakes","porridge","truffle_soup","yarn","cloth"]: game.change_inventory_count(kind,2)
	var restored:=make_game()
	expect(restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game)),"new kitchen and textile counts pass production save validation")
	for kind in ["mayonnaise","pancakes","porridge","truffle_soup","yarn","cloth"]: expect(restored.inventory_item_count(kind)==2 and kind in restored.inventory_slots,"household output survives load with its inventory slot: "+kind)
	game.player_hp=10; game.energy=0; game.consume_item("pancakes")
	expect(game.player_hp==46 and game.energy==10,"pancakes prioritize useful field energy and match the visible effect data")
	game.change_inventory_count("pie",1); game.player_hp=10; game.energy=0; game.consume_item("pie")
	expect(game.player_hp==90 and game.energy==10,"advanced pie gives a meaningful condensed recovery reward for multiple farm ingredients")
	game.free(); restored.free()

## Сценарий: ремесленные скидки и пятый выпуск не создают кухонную прибыль из купленного молока.
## Исходное состояние: мастер и экономия активны, старое сохранение имеет четыре созданных предмета.
## Ожидаемый результат: кухня сохраняет точную рецептуру и один выход, следующий верстак сохраняет старый бонус; счётчик переживает загрузку.
func test_workshop_bonuses_do_not_duplicate_kitchen_food() -> void:
	var game:=make_game(); game.talent_levels.craft_master=1; game.talent_levels.craft_efficient=1; game.state.player.craft_count=4
	game.change_inventory_count("milk",2); game.CraftingSystem.open(game,"cauldron")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"butter")) and game.inventory_item_count("milk")==0 and game.inventory_item_count("butter")==1,"workshop talents cannot halve milk costs and double cooking yield")
	game.change_inventory_count("log",1); game.CraftingSystem.open(game,"workbench")
	expect(game.CraftingSystem.craft(game,recipe_index(game,"plank")) and game.inventory_item_count("plank")==8,"legacy fourth craft still reaches the fifth workbench bonus after an intervening meal")
	var restored:=make_game(); restored.SaveSystem.apply(restored,game.SaveSystem.snapshot(game))
	expect(int(restored.state.player.profile.workbench_crafts)==5,"separate workshop bonus counter survives a save roundtrip")
	game.free(); restored.free()

## Сценарий: огромный запас сырья отправляется в ускоренный крафт.
## Исходное состояние: у игрока миллион брёвен, запрошены миллионы операций за одно нажатие.
## Ожидаемый результат: действие ограничено 99 полными партиями и оставляет правильное сырьё вместо долгого блокирующего цикла.
func test_large_batches_stay_bounded() -> void:
	var game:=make_game(); game.change_inventory_count("log",1000000)
	expect(game.CraftingSystem.craft_many(game,recipe_index(game,"plank"),1000000)==99,"one input cannot execute an unbounded craft loop")
	expect(game.inventory_item_count("log")==999901 and game.inventory_item_count("plank")==396,"bounded batch applies every cost and output exactly once")
	game.free()

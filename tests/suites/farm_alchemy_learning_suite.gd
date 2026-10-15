extends "res://tests/suites/suite_base.gd"

const Learning := preload("res://scripts/systems/alchemy_learning_system.gd")

## Проверяет десять опытов из реального сбора и покупки без шкафа и внешней справки.
func run() -> void:
	test_ten_ordinary_experiments()
	test_failure_and_learning_labels()

## Сценарий: новичок собирает пять дворовых трав, покупает воду с тарой и проходит десять опытов.
## Исходное состояние: обычный инвентарь и двадцать монет, все таланты и открытия пусты.
## Ожидаемый результат: два полезных препарата, сорок опыта алхимии и десять точных открытий сохраняются через JSON.
func test_ten_ordinary_experiments() -> void:
	var game:=make_game(); var herbs:=["chamomile","field_mint","nettle","red_clover","wild_thyme"]
	for kind in herbs:
		var index:int=game.food_nodes.find_custom(func(node): return node.kind==kind and node.location=="overworld")
		expect(index>=0,"learning herb has a real starter-map source: "+kind)
		var node:Dictionary=game.food_nodes[index]; var point:Vector2=node.position; var found:=false
		for x in [-48,0,48]:
			for y in [-48,0,48]:
				var candidate:=point+Vector2(x,y)
				if game.NavigationSystem.is_walkable(game,candidate): game.player=candidate; found=true; break
			if found: break
		expect(found and game.ForageSystem.collect(game,index),"ordinary hero reaches and collects herb within interaction radius: "+kind)
	var helper:=preload("res://tests/suites/farm_economy_suite.gd").new(context)
	for index in 2: helper.buy(game,"clean_water"); helper.buy(game,"glass_vial")
	expect(game.coins==12,"four real starter purchases cost exactly eight coins")
	game.current_location="cottage_interior"; game.player=game.CraftingSystem.Alchemy.STATION
	for id in Learning.LESSONS:
		game.CraftingSystem.open(game,"alchemy")
		var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")==id)
		expect(game.crafting_selected==index and Learning.next_id(game)==id,"station selects the next obtainable learning recipe")
		expect(game.CraftingSystem.craft(game,index),"ordinary collected inputs complete learning experiment: "+id)
	var value:Dictionary=game.CraftingSystem.Alchemy.state(game)
	expect(value.discovered.size()==10 and value.xp==40 and game.CraftingSystem.Alchemy.rank(game)==2,"ten distinct experiments unlock exactly rank two")
	expect(game.inventory_item_count("meadow_tonic")==1 and game.inventory_item_count("clarity_drops")==1,"learning ends with useful health and mana preparations")
	var loaded:=make_game()
	expect(loaded.SaveSystem.apply(loaded,JSON.parse_string(JSON.stringify(game.SaveSystem.snapshot(game)))) and Learning.next_id(loaded).is_empty(),"learning progress resumes from actual saved discoveries")
	game.player_hp=50; game.player_mana=0
	expect(game.PotionSystem.consume(game,"meadow_tonic") and game.player_hp==75,"learning tonic actually restores twenty-five health")
	expect(game.PotionSystem.consume(game,"clarity_drops") and game.player_mana==15,"learning drops actually restore fifteen mana")
	game.free(); loaded.free()

## Сценарий: неполный опыт и повтор старого открытия не открывают всю алхимию и не теряют сырьё.
## Исходное состояние: пустой стол, затем один уже известный учебный рецепт и шесть языков.
## Ожидаемый результат: отказ атомарен, три статуса различимы и источники доступны из игры.
func test_failure_and_learning_labels() -> void:
	var game:=make_game(); game.current_location="cottage_interior"; game.player=game.CraftingSystem.Alchemy.STATION
	game.CraftingSystem.open(game,"alchemy")
	var before:Dictionary=game.SaveSystem.snapshot(game)
	expect(not game.CraftingSystem.craft(game,game.crafting_selected) and game.SaveSystem.snapshot(game)==before,"failed experiment loses no ingredients XP coins or discoveries")
	var first:Dictionary=game.CraftingSystem.RECIPES[game.crafting_selected]
	var other_index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:meadow_tonic")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current=locale
		expect(Learning.status(game,first)!=Learning.status(game,game.CraftingSystem.RECIPES[other_index]) and not Learning.sources(game,first).is_empty(),"learning step and untried formula have distinct localized labels: "+locale)
	game.CraftingSystem.Alchemy.state(game).discovered.append(first.id)
	expect(Learning.status(game,first)==Learning.word(game,"known") and game.CraftingSystem.Alchemy.rank(game)==1,"one known formula cannot unlock the whole branch")
	game.LocaleSystem.current="ru"; game.free()

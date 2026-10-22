extends RefCounted

## Снимает общий граф действующих рецептов, уровней и реальных способов получения сырья.
static func catalog(game: Node) -> Dictionary:
	var recipes:Array=[]; var names:={}; var sources:={}
	for index in game.CraftingSystem.RECIPES.size():
		var recipe:Dictionary=game.CraftingSystem.RECIPES[index].duplicate(true)
		recipe.id=recipe.get("id","legacy-"+str(index)); recipe.station=recipe.get("station","workbench")
		recipe.level=preload("res://scripts/systems/basement_data.gd").recipe_level(recipe)
		recipe.public_kitchen=recipe.station=="cauldron" and not recipe.get("private_kitchen",false)
		recipe.no_bonus=recipe.output in game.InventorySystem.UNIQUE_ITEMS or recipe.output=="home_chest" or recipe.has("study_kind") or recipe.get("research_supply",false)
		recipes.append(recipe)
	for kind in game.InventorySystem.ITEM_DATA: names[kind]=game.inventory_item_name(kind)
	for product in game.ShopSystem.PRODUCTS:
		if int(product.buy)>0: add(sources,product.kind,{"type":"shop","location":"shop_interior","amount":int(product.get("amount",1)),"buy":int(product.buy)})
	for crop in game.CropCatalogSystem.CROPS:
		var data:Dictionary=game.CropCatalogSystem.CROPS[crop]
		add(sources,data.harvest,{"type":"crop","location":"overworld","seed":data.seed,"seasons":data.seasons,"amount":data.yield})
	for node in game.food_nodes:
		var record:={"type":"gather","location":String(node.get("location","overworld"))}
		var herbs:=preload("res://scripts/systems/alchemy_herb_data.gd")
		if herbs.HERBS.has(node.kind): record.condition=herbs.HERBS[node.kind].condition
		if game.ForageSystem.OrchardSystem.handles(node.kind): record.seasons=["spring","summer","autumn"]
		add(sources,node.kind,record)
	for node in game.resource_nodes: add(sources,node.kind,{"type":"mine","location":String(node.get("location","overworld"))})
	for kind in ["wood","log"]: add(sources,kind,{"type":"tree","location":"overworld"})
	for animal in preload("res://scripts/systems/livestock_data.gd").ANIMALS:
		add(sources,animal.product,{"type":"animal","location":"overworld","interval":animal.interval})
	add(sources,"fish",{"type":"fish","location":"overworld"})
	add(sources,"crab",{"type":"trap","location":"overworld"})
	for wild in preload("res://scripts/systems/apiary_data.gd").WILD:
		for kind in ["bees","honeycomb"]: add(sources,kind,{"type":"apiary","location":wild.location,"level":1})
	add(sources,"pollen",{"type":"apiary","location":"overworld","level":2})
	add(sources,"propolis",{"type":"apiary","location":"overworld","level":3})
	for enemy in game.enemy_nodes:
		var data:Dictionary=game.CombatSystem.TYPES.get(enemy.kind,{})
		for kind in data.get("loot",{}):
			if names.has(kind): add(sources,kind,{"type":"enemy","location":String(enemy.get("location","overworld")),"enemy":enemy.kind})
	for animal in game.wildlife_nodes:
		var data:Dictionary=game.WildlifeSystem.TYPES.get(animal.kind,{})
		for kind in data.get("loot",{}): add(sources,kind,{"type":"wildlife","location":String(animal.get("location","overworld")),"animal":animal.kind})
	for entry in game.ResearchSystem.Data.ENTRIES:
		for kind in entry.parts: add(sources,kind,{"type":"recycle","item":entry.kind,"amount":entry.parts[kind],"batch":entry.batch,"level":entry.tier})
	for id in game.QuestSystem.MISSIONS:
		var mission:Dictionary=game.QuestSystem.MISSIONS[id]
		add(sources,mission.reward_item,{"type":"quest","quest":id,"amount":mission.reward_count})
	var locations:={}; var stations:={}; var quests:={}; var seasons:={}; var conditions:={}
	for recipe in recipes: stations[recipe.station]=game.CraftingSystem.station_name(game,recipe.station)
	for kind in sources:
		for record in sources[kind]:
			if record.has("location"): locations[record.location]=game.LocaleSystem.location(record.location)
	for id in game.QuestSystem.MISSIONS: quests[id]=game.LocaleSystem.quest(id,"title")
	for id in game.WorldEventSystem.SEASONS: seasons[id]=game.LocaleSystem.ui("season_"+id)
	for id in ["day","night"]: conditions[id]=game.LocaleSystem.ui("alchemy_"+id)
	return {"schema":1,"recipes":recipes,"names":names,"sources":sources,"locations":locations,"stations":stations,"quests":quests,"seasons":seasons,"conditions":conditions}

## Добавляет только неповторяющийся подтверждённый способ получения данного предмета.
static func add(sources: Dictionary, kind: String, record: Dictionary) -> void:
	if not sources.has(kind): sources[kind]=[]
	if record not in sources[kind]: sources[kind].append(record)

## Передаёт планировщику фактическую экономию и счётчик ремесла без изменения опыта и состояния.
static func options(game: Node) -> Dictionary:
	var costs:={}
	for index in game.CraftingSystem.RECIPES.size():
		var recipe:Dictionary=game.CraftingSystem.RECIPES[index]; var inputs:={}
		for kind in recipe.inputs: inputs[kind]=game.CraftingSystem.material_cost(game,recipe,kind)
		costs[str(index)]=inputs
	return {"costs":costs,"counter":int(game.state.player.profile.get("workbench_crafts",game.state.player.craft_count)),"master":game.TalentSystem.has(game,"craft_master")}

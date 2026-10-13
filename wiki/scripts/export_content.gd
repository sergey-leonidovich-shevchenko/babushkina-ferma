extends RefCounted

const Research := preload("res://scripts/systems/research_data.gd")
const Herbs := preload("res://scripts/systems/alchemy_herb_data.gd")

## Выгружает все предметы, рецепты, растения и поручения из действующих игровых каталогов.
static func export_all(ctx: Object) -> void:
	items(ctx); recipes(ctx); quests(ctx); plants(ctx)

## Собирает эффекты, торговые цены, экипировку, способы изготовления и изучение каждого предмета.
static func items(ctx: Object) -> void:
	var game:Node=ctx.game
	for kind in game.InventorySystem.ITEM_DATA:
		var data:Dictionary=game.InventorySystem.data(kind); var effect:String=game.ItemPresentationSystem.effect_text(game,kind)
		var category:String={"tool":"Инструменты","food":"Еда","equipment":"Экипировка","quest":"Квестовые предметы","resource":"Материалы"}[game.InventorySystem.category(kind)]
		var entry:Dictionary=ctx.add("items",kind,ctx.item_name(kind),effect if not effect.is_empty() else "%s Лунной долины. Здесь собраны свойства предмета, способы получения и связанные рецепты."%category,[category],"scripts/systems/inventory_system.gd")
		entry.icon=ctx.still(game.item_texture(kind))
		ctx.fact(entry,"Редкость",game.LocaleSystem.ui("item_rarity_"+game.ItemPresentationSystem.rarity(kind)))
		for stat in game.ItemPresentationSystem.stats(game,kind): ctx.fact(entry,{"damage":"Бонус к урону","defense":"Защита","health":"Бонус к здоровью","speed":"Бонус к скорости"}.get(stat,stat),game.ItemPresentationSystem.stats(game,kind)[stat])
		if not String(data.get("equip","")).is_empty(): ctx.fact(entry,"Экипировка",{"hands":"Руки","head":"Голова","body":"Тело","boots":"Обувь","shield":"Щит","ring":"Кольцо"}.get(data.equip,data.equip))
		for product in game.ShopSystem.PRODUCTS:
			if product.kind==kind:
				ctx.fact(entry,"Покупка",str(product.buy)+" монет"); ctx.fact(entry,"Продажа",str(product.sell)+" монет"); break
		var study:Dictionary=Research.entry(kind)
		if not study.is_empty():
			ctx.fact(entry,"Уровень изучения",study.tier)
			ctx.fact(entry,"Партия разбора",study.get("batch",1))
			entry.sections.append({"title":"Изучение и разборка","text":"Сначала изучите предмет на исследовательском столе нужного уровня. После изучения его можно разобрать на следующие материалы."})
			entry.salvage=ctx.materials(study.get("returns",study.get("parts",{})))
		for index in game.CraftingSystem.RECIPES.size():
			var recipe:Dictionary=game.CraftingSystem.RECIPES[index]; var id:String=recipe.get("id","legacy-"+str(index))
			if recipe.output==kind: ctx.link(entry,"craft",id,"","Получить через крафт")
			if recipe.inputs.has(kind): ctx.link(entry,"craft",id,"","Используется в рецептах")
		for npc in game.QuestSystem.MISSIONS:
			if kind in [game.QuestSystem.MISSIONS[npc].item,game.QuestSystem.MISSIONS[npc].reward_item]: ctx.link(entry,"missions",npc,"","Задания")

## Передаёт точные ингредиенты, выход, побочные продукты и ограничения всех рецептов.
static func recipes(ctx: Object) -> void:
	var game:Node=ctx.game
	for index in game.CraftingSystem.RECIPES.size():
		var data:Dictionary=game.CraftingSystem.RECIPES[index]; var station:String=data.get("station","workbench")
		var name:String=game.CraftingSystem.station_name(game,station)
		var entry:Dictionary=ctx.add("craft",data.get("id","legacy-"+str(index)),ctx.item_name(data.output),"Изготовление: %s × %d. Рабочее место: %s."%[ctx.item_name(data.output),data.count,name],[name],"scripts/systems/crafting_system.gd")
		entry.icon=ctx.still(game.item_texture(data.output)); entry.ingredients=ctx.materials(data.inputs); entry.yields=ctx.materials({data.output:data.count})
		entry.byproducts=ctx.materials(data.get("byproducts",{})); entry.output=data.output; entry.station=station
		ctx.link(entry,"buildings","station-"+station,name,"Рабочее место")
		ctx.link(entry,"items",data.output,"","Результат")
		for key in ["seconds","energy","alchemy_rank","workshop_level","furnace_level"]:
			if data.has(key): ctx.fact(entry,{"seconds":"Время, сек.","energy":"Энергия","alchemy_rank":"Ранг алхимии","workshop_level":"Уровень станка","furnace_level":"Уровень горна"}[key],data[key])
		if data.get("station","")=="cauldron": ctx.fact(entry,"Уровень кухни",preload("res://scripts/systems/kitchen_data.gd").level(data))
		if data.has("talent"): ctx.fact(entry,"Требуется талант",game.TalentSystem.word(game,String(data.talent)))
		if data.has("study_kind"): ctx.fact(entry,"Нужно изучить",ctx.item_name(data.study_kind))
		if data.get("private_kitchen",false): ctx.fact(entry,"Размещение","Личная кухня подвала")
		if data.get("laboratory",false): ctx.fact(entry,"Лаборатория","Усадьба уровня 4")

## Сохраняет основной сюжет, побочные задания, первую главу, ежедневные и личные поручения.
static func quests(ctx: Object) -> void:
	var game:Node=ctx.game
	for id in game.QuestSystem.MISSIONS:
		var data:Dictionary=game.QuestSystem.MISSIONS[id]
		var entry:Dictionary=ctx.add("missions",id,data.title,data.description,["Основной сюжет" if id.begins_with("story_") else "Побочные задания"],"scripts/systems/quest_system.gd")
		entry.icon=ctx.still(game.item_texture(data.item)); entry.ingredients=ctx.materials({data.item:data.count}); entry.yields=ctx.materials({data.reward_item:data.reward_count})
		ctx.fact(entry,"Выдаёт",data.giver); ctx.fact(entry,"Монеты",data.coins); ctx.fact(entry,"Опыт",data.xp)
		if data.get("keep_item",false): ctx.fact(entry,"Предмет","Показывается и остаётся у героя")
		if data.has("requires"): ctx.link(entry,"missions",data.requires,"","Предыдущее задание")
		if data.has("condition"): ctx.fact(entry,"Условие","Победить Стража Лунной поляны")
		for npc in game.QuestSystem.NPCS:
			if id in game.QuestSystem.NPCS[npc].missions: ctx.link(entry,"characters",npc,"","Заказчик")
	var chapter:=preload("res://scripts/systems/first_chapter_system.gd")
	for index in chapter.MILESTONES.size():
		var entry:Dictionary=ctx.add("missions","chapter-"+str(index),"Возвращение · шаг "+str(index+1),chapter.OBJECTIVES[index][0],["Первая глава"],"scripts/systems/first_chapter_system.gd")
		ctx.fact(entry,"Доступно с дня",chapter.MILESTONES[index].day)
		if index==4: entry.ingredients=ctx.materials({"carrot":10})
		if index==6: entry.ingredients=ctx.materials({"wood":chapter.REPAIR_WOOD,"stone":chapter.REPAIR_STONE})
		if index==10: entry.ingredients=ctx.materials({"rare_seeds":1})
		if index==11:
			for reward in chapter.REWARDS: entry.sections.append({"title":chapter.WORDS["reward_"+reward][0],"text":chapter.WORDS["reward_"+reward+"_desc"][0]})
		if index>0: ctx.link(entry,"missions","chapter-"+str(index-1),"","Предыдущий шаг")
	for npc in game.VillageLifeSystem.PERSONAL_REQUESTS:
		var data:Dictionary=game.VillageLifeSystem.PERSONAL_REQUESTS[npc]
		var entry:Dictionary=ctx.add("missions","personal-"+npc,"Личное поручение · "+game.QuestSystem.npc_name(npc),data.text,["Личные поручения"],"scripts/systems/village_life_system.gd")
		entry.ingredients=ctx.materials({data.item:data.count}); entry.icon=ctx.still(game.item_texture(data.item))
		ctx.fact(entry,"Дружба",data.friendship); ctx.fact(entry,"Монеты",data.coins); ctx.fact(entry,"Опыт",data.xp); ctx.link(entry,"characters",npc,"","Заказчик")
	for pool in game.ContractSystem.POOLS:
		for index in game.ContractSystem.POOLS[pool].size():
			var data:Dictionary=game.ContractSystem.POOLS[pool][index]
			var entry:Dictionary=ctx.add("missions","contract-"+pool+"-"+str(index),"Заказ гильдии · "+ctx.item_name(data.item),"Доставка %d × %s. Заказы меняются каждый игровой день."%[data.amount,ctx.item_name(data.item)],["Ежедневные заказы"],"scripts/systems/contract_system.gd")
			entry.ingredients=ctx.materials({data.item:data.amount}); entry.icon=ctx.still(game.item_texture(data.item)); ctx.fact(entry,"Монеты",data.coins); ctx.fact(entry,"Опыт",data.xp)
			ctx.link(entry,"buildings","guild_hall","","Доска заказов")

## Связывает каждую культуру и лекарственную траву с урожаем, семенами, обработкой и реальными местами сбора.
static func plants(ctx: Object) -> void:
	var game:Node=ctx.game
	for kind in game.CropCatalogSystem.CROPS:
		var data:Dictionary=game.CropCatalogSystem.CROPS[kind]
		var entry:Dictionary=ctx.add("plants",kind,ctx.item_name(data.harvest),"Огородная культура. Посадите семена в подготовленную землю, поливайте грядку и дождитесь урожая.",["Огород"],"scripts/systems/crop_catalog_system.gd")
		entry.icon=ctx.still(game.item_texture(data.harvest)); ctx.link(entry,"items",data.seed,"","Семена"); ctx.link(entry,"items",data.harvest,"","Урожай")
		for key in ["growth","yield","regrow"]:
			if data.has(key): ctx.fact(entry,{"growth":"Рост, сек.","yield":"Урожай","regrow":"Повторный рост, сек."}[key],data[key])
		var seasons:=[]
		for season in data.seasons: seasons.append({"spring":"Весна","summer":"Лето","autumn":"Осень","winter":"Зима"}[season])
		ctx.fact(entry,"Сезоны",", ".join(seasons))
	for kind in Herbs.HERBS:
		var entry:Dictionary=ctx.add("plants",kind,ctx.item_name(kind),"Лекарственная трава. Из неё получают сок, сухую траву, порошок и настойку; они используются в алхимических смесях.",["Алхимические травы"],"scripts/systems/alchemy_herb_data.gd")
		entry.icon=ctx.still(game.item_texture(kind)); ctx.fact(entry,"Сложность",Herbs.HERBS[kind].tier); ctx.link(entry,"items",kind,"","Сырьё")
		for form in Herbs.FORMS: ctx.link(entry,"items",kind+"_"+form,"","Обработка")
		var seen:={}
		for node in game.ForageSystem.default_nodes():
			if node.kind==kind and not seen.has(node.location): seen[node.location]=true; ctx.link(entry,"locations",node.location,"","Где собирать")

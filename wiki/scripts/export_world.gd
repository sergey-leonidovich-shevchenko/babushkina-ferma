extends RefCounted

const Basement := preload("res://scripts/systems/basement_data.gd")
const StationArt := preload("res://scripts/presentation/basement_visual_system.gd")
const Region := preload("res://scripts/systems/village_region_data.gd")
const Caves := preload("res://scripts/systems/cave_room_data.gd")
const Apiary := preload("res://scripts/systems/apiary_data.gd")
const ApiaryArt := preload("res://scripts/presentation/apiary_visual_system.gd")
const HOUSE_NAMES := {"cottage":"Дом бабушки","shop_house":"Сельская лавка","guild_hall":"Гильдия","forge":"Кузница","chapel":"Часовня","prison":"Тюрьма","wizard_tower":"Башня мага","moon_castle":"Лунный замок"}

## Выгружает здания, все уровни станков, области мира, рыбалку и таланты.
static func export_all(ctx: Object) -> void:
	buildings(ctx); stations(ctx); locations(ctx); skills(ctx); fishing(ctx); acquisition(ctx)

## Связывает наружные фасады с местами входа, доступными интерьерами и условиями открытия.
static func buildings(ctx: Object) -> void:
	for id in ctx.game.BuildingSystem.BUILDINGS:
		var data:Dictionary=ctx.game.BuildingSystem.BUILDINGS[id]
		var entry:Dictionary=ctx.add("buildings",id,HOUSE_NAMES[id],"Здание долины. Внутри доступны связанные с ним занятия и услуги.",["Здания"],"scripts/systems/building_system.gd")
		entry.icon=ctx.still(ctx.game.BuildingVisualSystem.texture(id),0.5)
		ctx.link(entry,"locations",data.location,"","Где находится"); ctx.link(entry,"locations",data.interior,"","Внутри")
		if not String(data.unlock).is_empty(): ctx.fact(entry,"Открывается",{"mining":"Навык добычи","ancient_key":"Древний ключ","mana":"Запас маны","story":"Продвижение основной истории"}.get(data.unlock,data.unlock))
		for area in ctx.game.BuildingSystem.INTERIORS:
			if ctx.game.BuildingSystem.INTERIORS[area].building==id and area!=data.interior: ctx.link(entry,"locations",area,"","Другие помещения")

## Показывает настоящие четыре ракурса и строительную кучу каждого из трёх уровней станка.
static func stations(ctx: Object) -> void:
	for kind in Basement.STATIONS:
		var data:Dictionary=Basement.STATIONS[kind]
		var title:String="Наковальня кузницы" if kind=="forge" else ctx.game.CraftingSystem.station_name(ctx.game,kind).capitalize()
		var entry:Dictionary=ctx.add("buildings","station-"+kind,title,"Рабочее место подвала. Строится с первого уровня через настенный чертёж; его можно повернуть, улучшить до третьего уровня или разобрать с возвратом части материалов.",["Мастерские"],"scripts/systems/basement_data.gd")
		entry.ingredients=ctx.materials(data.inputs); entry.levels=[]
		ctx.fact(entry,"Основание, клетки","%d × %d"%[data.size.x,data.size.y]); ctx.fact(entry,"Начальная стройка, сек.",Basement.WORK_SECONDS[0]); ctx.fact(entry,"Энергия в секунду",data.energy)
		ctx.link(entry,"locations","cellar_workshop","","Место строительства")
		var clips:=[]
		for level in 3:
			var cost:Dictionary={"inputs":data.inputs,"coins":0} if level==0 else Basement.upgrade_cost(kind,level)
			entry.levels.append({"level":level+1,"coins":cost.get("coins",0),"ingredients":ctx.materials(cost.inputs),"seconds":Basement.WORK_SECONDS[level]})
			clips.append(station_clip(ctx,kind,level+1,false))
		clips.append(station_clip(ctx,kind,1,true)); entry.animation={"clips":clips}; entry.icon=clips[0].frames.south[0]
		for index in ctx.game.CraftingSystem.RECIPES.size():
			var recipe:Dictionary=ctx.game.CraftingSystem.RECIPES[index]
			if recipe.get("station","workbench")==kind: ctx.link(entry,"craft",recipe.get("id","legacy-"+str(index)),"","Рецепты рабочего места")
	var hive:Dictionary=ctx.add("buildings","apiary","Улей","Деревянный улей фермы. Заселите его пчёлами, ухаживайте за семьёй и собирайте продукты пасеки.",["Ферма"],"scripts/systems/apiary_data.gd")
	hive.levels=[]
	for level in 3:
		var cost:Dictionary=Apiary.COSTS[level]
		hive.levels.append({"level":level+1,"coins":cost.get("coins",0),"ingredients":ctx.materials(cost.get("inputs",{})),"seconds":0})
	for item in ["bees","honeycomb","honey","beeswax","pollen","propolis"]:
		if ctx.game.InventorySystem.ITEM_DATA.has(item): ctx.link(hive,"items",item,"","Продукты и заселение")
	hive.icon=ctx.still(ApiaryArt.TEXTURES.hive_1); ctx.link(hive,"locations","overworld","","Ферма")

## Передаёт подготовленную текстуру уровня и направления без повторного вращения исходного рисунка.
static func station_clip(ctx: Object, kind: String, level: int, pile: bool) -> Dictionary:
	var frames:={}; var dirs:=["south","west","north","east"]
	for index in 4: frames[dirs[index]]=[ctx.still(StationArt.texture(kind,level,index,pile),0.5)]
	return {"id":"construction" if pile else "level-"+str(level),"title":"Материалы для стройки" if pile else "Уровень "+str(level),"fps":1,"frames":frames}

## Описывает все биомы, районы, комнаты пещер и интерьеры с обратимыми ссылками на их дороги.
static func locations(ctx: Object) -> void:
	var ids:Array=ctx.game.WorldSystem.NAMES.keys()
	for id in Caves.IDS+ctx.game.BuildingSystem.INTERIORS.keys():
		if id not in ids: ids.append(id)
	for id in ids:
		var tag:="Пещеры" if id in Caves.IDS else ("Помещения" if ctx.game.BuildingSystem.is_interior(id) else ("Деревня" if Region.contains(id) else "Биомы"))
		var entry:Dictionary=ctx.add("locations",id,ctx.game.LocaleSystem.location(id),"Исследуйте локацию, встречайте её жителей и используйте связанные с ней ресурсы и рабочие места.",[tag],"scripts/systems/world_system.gd")
		for link in Region.passages(id): ctx.link(entry,"locations",link.target,"","Дороги")
		if id in Caves.IDS:
			for link in Caves.passages(id): ctx.link(entry,"locations",link.target,"","Туннели")
		for building in ctx.game.BuildingSystem.BUILDINGS:
			if ctx.game.BuildingSystem.BUILDINGS[building].location==id: ctx.link(entry,"buildings",building,"","Здания")
		if ctx.game.BuildingSystem.INTERIORS.has(id):
			var data:Dictionary=ctx.game.BuildingSystem.INTERIORS[id]
			ctx.link(entry,"buildings",data.building,"","Вход")
			for service in data.get("services",[]):
				if Basement.STATIONS.has(service.id): ctx.link(entry,"buildings","station-"+String(service.id),"","Рабочие места")
		for area in Region.SERVICES.get(id,{}):
			if Basement.STATIONS.has(area): ctx.link(entry,"buildings","station-"+String(area),"","Услуги района")

## Собирает все таланты, их описания, предшествующие требования и максимальный ранг.
static func skills(ctx: Object) -> void:
	var names:={"combat":"Бой","farming":"Фермерство","fishing":"Рыбалка","crafting":"Ремёсла"}
	for data in ctx.game.TalentSystem.TALENTS:
		var entry:Dictionary=ctx.add("skills",data.id,ctx.game.TalentSystem.word(ctx.game,data.id),ctx.game.TalentSystem.word(ctx.game,data.id,true),[names.get(data.group,data.group)],"scripts/systems/talent_system.gd")
		ctx.fact(entry,"Максимальный ранг",data.get("max_rank",1)); ctx.fact(entry,"Очки на ранг",1)
		for requirement in data.requires: ctx.link(entry,"skills",requirement,"","Требуется изучить")

## Описывает каждый вид рыбы с настоящими сезонами, глубиной, погодой и требованием к снасти.
static func fishing(ctx: Object) -> void:
	var words:={"pond":"Пруд","river":"Река","shallow":"Мелководье","middle":"Средняя глубина","deep":"Глубина","spring":"Весна","summer":"Лето","autumn":"Осень","winter":"Зима","clear":"Ясно","rain":"Дождь","storm":"Гроза"}
	for data in ctx.game.FishingSystem.FISH_CATALOG:
		var entry:Dictionary=ctx.add("fishing",data.id,ctx.game.LocaleSystem.text(data.name_key),"Рыба долины. Появляется только при подходящих условиях; сложность определяет поведение в рыболовной мини-игре.",["Рыбалка"],"scripts/systems/fishing_catalog_system.gd")
		entry.icon=ctx.still(ctx.game.item_texture("fish")); ctx.fact(entry,"Размер, см","%d–%d"%[data.min_size,data.max_size]); ctx.fact(entry,"Сложность",data.difficulty)
		for key in ["waters","depths","seasons","weather"]:
			if not data.has(key): continue
			var labels:=[]
			for value in data[key]: labels.append(words.get(value,value))
			ctx.fact(entry,{"waters":"Водоём","depths":"Глубина","seasons":"Сезон","weather":"Погода"}[key],", ".join(labels))
		if data.get("advanced_rod",false): ctx.link(entry,"items","advanced_fishing_rod","","Необходимая снасть")
		if data.has("requires"): ctx.link(entry,"skills",data.requires,"","Нужный талант")
		if data.has("time"): ctx.fact(entry,"Время","Ночь" if data.time=="night" else "Лунное затмение")

## Дополняет страницы предметов местами сбора, добычей врагов и животными, которые дают продукт.
static func acquisition(ctx: Object) -> void:
	var found:={}
	for entry in ctx.entries:
		if entry.category=="items": found[entry.id]=entry
	for node in ctx.game.ForageSystem.default_nodes()+ctx.game.ResourceSystem.default_nodes():
		if not found.has(node.kind): continue
		var entry:Dictionary=found[node.kind]
		if not entry.relations.any(func(rel): return rel.category=="locations" and rel.id==node.location): ctx.link(entry,"locations",node.location,"","Где собирать")
	for kind in ctx.game.CombatSystem.TYPES:
		for item in ctx.game.CombatSystem.TYPES[kind].loot:
			if found.has(item): ctx.link(found[item],"characters",kind,"","Добыча с противника")
	for animal in FarmAnimals():
		if found.has(animal.product): ctx.link(found[animal.product],"characters",animal.id,"","Даёт животное")

## Возвращает исходный состав фермы, не включая состояние конкретного сохранения.
static func FarmAnimals() -> Array:
	return preload("res://scripts/systems/livestock_data.gd").ANIMALS

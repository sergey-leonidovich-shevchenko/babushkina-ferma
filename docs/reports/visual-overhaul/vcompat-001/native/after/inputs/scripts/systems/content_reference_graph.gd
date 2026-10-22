extends RefCounted

const Inventory := preload("res://scripts/systems/inventory_system.gd")
const Crafting := preload("res://scripts/systems/crafting_system.gd")
const Quests := preload("res://scripts/systems/quest_system.gd")
const Locale := preload("res://scripts/systems/locale_system.gd")
const Stations := preload("res://scripts/systems/basement_data.gd")
const Icons := preload("res://assets/game/items/ui/catalog.gd")

## Отделяет проверяемые копии реестров от живых статических данных без создания героя или чтения слотов.
static func snapshot() -> Dictionary:
	return {"items":Inventory.ITEM_DATA,"recipes":Crafting.RECIPES,"missions":Quests.MISSIONS,"stations":Stations.STATIONS,"talents":preload("res://scripts/systems/talent_system.gd").default_levels(),"icons":Icons.DATA.entries,"locales":{"items":Locale.ITEMS,"ui":Locale.UI,"tutorial":Locale.TUTORIAL,"text":Locale.TEXT,"quests":Locale.QUESTS,"entities":Locale.ENTITIES,"locations":Locale.LOCATIONS,"skills":Locale.SKILLS}}.duplicate(true)

## Проверяет связность рецептов, миссий, станков, локализации и подготовленных иконок одним чистым контрактом.
static func errors(data: Dictionary, check_files: bool=true) -> Array[String]:
	var result:Array[String]=[]; var items:Dictionary=data.items; var ids:={}
	for index in data.recipes.size():
		var recipe:Dictionary=data.recipes[index]; var owner:="recipe[%d]"%index
		var id:String=String(recipe.get("id",""))
		if not id.is_empty():
			owner+="("+id+")"
			if ids.has(id): result.append(owner+".id duplicates "+String(ids[id]))
			ids[id]=owner
		item(result,items,recipe.get("output"),owner+".output")
		costs(result,items,recipe.inputs,owner+".inputs"); costs(result,items,recipe.get("byproducts",{}),owner+".byproducts")
		if not quantity(recipe.get("count",0)): result.append(owner+".count must be a positive whole number")
		var station:String=String(recipe.get("station","workbench"))
		if not data.stations.has(station): result.append(owner+".station -> "+station)
		for field in ["furnace_level","workshop_level"]:
			if recipe.has(field) and (not quantity(recipe[field]) or float(recipe[field])>3): result.append(owner+"."+field+" outside station levels 1..3")
		for talent in recipe.get("talents",[])+([recipe.talent] if recipe.has("talent") else []):
			if not data.talents.has(talent): result.append(owner+".talent -> "+String(talent))
	for station in data.stations:
		costs(result,items,data.stations[station].inputs,"station."+station+".inputs")
		for tier in data.stations[station].get("upgrades",[]).size(): costs(result,items,data.stations[station].upgrades[tier].inputs,"station.%s.upgrades[%d].inputs"%[station,tier])
	for id in data.missions:
		var mission:Dictionary=data.missions[id]
		item(result,items,mission.get("item"),"mission."+id+".item"); item(result,items,mission.get("reward_item"),"mission."+id+".reward_item")
		var dependency:String=String(mission.get("requires",""))
		if not dependency.is_empty() and not data.missions.has(dependency): result.append("mission."+id+".requires -> "+dependency)
		for field in ["type","title","giver","description"]:
			if not data.locales.quests.has(id+"."+field): result.append("mission."+id+".locale -> quests."+id+"."+field)
	mission_cycles(result,data.missions)
	for kind in items:
		if not data.locales.items.has(kind): result.append("locale.items."+kind+" missing")
		if not data.icons.has(kind): result.append("icons."+kind+" missing prepared item")
		elif check_files and not ResourceLoader.exists("res://assets/game/items/ui/preview/"+kind+".png"): result.append("icons."+kind+".preview missing file")
	for table in data.locales:
		for key in data.locales[table]:
			var values:Variant=data.locales[table][key]; var owner:String="locale."+table+"."+key
			if not values is Array or values.size()!=6: result.append(owner+" requires six languages"); continue
			for language in 6:
				if not values[language] is String or values[language].is_empty(): result.append(owner+"[%d] empty translation"%language)
	return result

## Проверяет существование ссылки и выдаёт владельца, поле и отсутствующий идентификатор.
static func item(result: Array[String], items: Dictionary, id: Variant, owner: String) -> void:
	if not id is String or not items.has(id): result.append(owner+" -> "+str(id))

## Проверяет ингредиенты и возвраты по тому же реестру, включая корректность количества партии.
static func costs(result: Array[String], items: Dictionary, values: Dictionary, owner: String) -> void:
	for kind in values:
		item(result,items,kind,owner+"."+kind)
		if not quantity(values[kind]): result.append(owner+"."+kind+" invalid quantity")

## Принимает только положительное целое число; булевы значения и дроби не являются количеством.
static func quantity(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>0 and float(value)==floorf(float(value))

## Находит недостижимые циклы миссий и показывает всю цепочку требований без рекурсивного переполнения.
static func mission_cycles(result: Array[String], missions: Dictionary) -> void:
	for start in missions:
		var chain:Array[String]=[]; var cursor:String=start
		while not cursor.is_empty() and missions.has(cursor):
			if cursor in chain:
				chain.append(cursor); result.append("mission."+start+".requires cycle: "+" -> ".join(chain)); break
			chain.append(cursor); cursor=String(missions[cursor].get("requires",""))

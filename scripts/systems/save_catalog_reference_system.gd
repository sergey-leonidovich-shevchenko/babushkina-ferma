extends RefCounted

const Items := preload("res://scripts/systems/inventory_system.gd")
const Missions := preload("res://scripts/systems/quest_system.gd")
const World := preload("res://scripts/systems/world_system.gd")
const Furnace := preload("res://scripts/systems/furnace_data.gd")
const Workshops := preload("res://scripts/systems/workshop_data.gd")
const Kitchen := preload("res://scripts/systems/kitchen_data.gd")
const Research := preload("res://scripts/systems/research_data.gd")

## Находит первую неподдерживаемую ссылку после структурной проверки, не удаляя записи из слота.
static func first_error(data: Dictionary) -> String:
	var error:=item_keys(data.counts,"counts")
	if error.is_empty(): error=item_keys(data.get("storage",{}).get("counts",{}),"storage.counts")
	for field in ["slots","hotbar"]:
		for index in data[field].size():
			if error.is_empty(): error=item(data[field][index],"%s[%d]"%[field,index],true)
	for slot in data.equipment:
		if error.is_empty(): error=item(data.equipment[slot],"equipment."+slot,true)
	for field in ["drops","containers"]:
		for index in data.get(field,[]).size():
			var entry:Dictionary=data[field][index]; var owner:="%s[%d]"%[field,index]
			if error.is_empty() and field=="drops": error=item(entry.kind,owner+".kind")
			if error.is_empty() and field=="containers": error=item_keys(entry.contents,owner+".contents",true)
	for id in data.get("missions",{}):
		if error.is_empty() and not Missions.MISSIONS.has(id): error="missions."+id
	if error.is_empty() and not location(data.location): error="location: "+data.location
	if error.is_empty() and not preload("res://scripts/systems/weapon_system.gd").DATA.has(data.weapons.equipped): error="weapons.equipped: "+data.weapons.equipped
	var expansion:Dictionary=data.get("estate",{}).get("expansion",{})
	for id in expansion.get("research",{}).get("known",[]):
		if error.is_empty() and Research.entry(id).is_empty(): error="estate.expansion.research.known: "+id
	if error.is_empty(): error=queue(expansion.get("furnace",{}).get("queue",[]),"furnace","estate.expansion.furnace.queue")
	for station in expansion.get("workshops",{}):
		if not error.is_empty(): break
		if not Workshops.STATIONS.has(station): error="estate.expansion.workshops."+station
		else: error=queue(expansion.workshops[station].get("queue",[]),station,"estate.expansion.workshops."+station+".queue")
	for index in expansion.get("basement",{}).get("objects",[]).size():
		if not error.is_empty(): break
		var entry:Dictionary=expansion.basement.objects[index]
		if not preload("res://scripts/systems/basement_data.gd").STATIONS.has(entry.kind): return "estate.expansion.basement.objects[%d].kind: %s"%[index,entry.kind]
		error=queue(entry.production.queue,entry.kind,"estate.expansion.basement.objects[%d].production.queue"%index)
	return error

## Проверяет имя предмета и сохраняет точный путь владельца для диагностики отказа.
static func item(id: String, owner: String, empty_allowed: bool=false) -> String:
	return "" if (empty_allowed and id.is_empty()) or Items.ITEM_DATA.has(id) else owner+": "+id

## Проверяет ключи материального журнала; монеты разрешены только в содержимом мировых контейнеров.
static func item_keys(values: Dictionary, owner: String, coins_allowed: bool=false) -> String:
	for id in values:
		if coins_allowed and id=="coins": continue
		var error:=item(id,owner+"."+id)
		if not error.is_empty(): return error
	return ""

## Проверяет оплаченные рецепты до нормализации очереди, которая прежде молча удаляла неизвестную работу.
static func queue(jobs: Array, station: String, owner: String) -> String:
	for index in jobs.size():
		var job:Dictionary=jobs[index]
		var recipe:Dictionary=Furnace.recipe(job.id) if station=="furnace" else (Kitchen.recipe(job.id) if station=="cauldron" else Workshops.Recipes.recipe(job.id))
		if recipe.is_empty() or recipe.get("station","")!=station: return "%s[%d].id: %s"%[owner,index,job.id]
		var error:=item_keys(job.get("paid",{}),"%s[%d].paid"%[owner,index])
		if not error.is_empty(): return error
	return ""

## Принимает существующие мировые, внутренние и пещерные локации без создания игровой модели.
static func location(id: String) -> bool:
	return World.NAMES.has(id) or preload("res://scripts/systems/building_system.gd").INTERIORS.has(id) or preload("res://scripts/systems/cave_room_data.gd").is_cave(id) or id==preload("res://scripts/systems/debug_playground_system.gd").LOCATION

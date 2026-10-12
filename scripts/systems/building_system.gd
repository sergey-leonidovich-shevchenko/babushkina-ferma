extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")
const BuildingVisualSystem := preload("res://scripts/systems/building_visual_system.gd")
const InteriorVisualSystem := preload("res://scripts/systems/interior_visual_system.gd")
const InteriorRenderer := preload("res://scripts/systems/interior_renderer.gd")
const VillageMapData := preload("res://scripts/systems/village_map_data.gd")

const SHOP_STALL_POSITION := VillageMapData.SHOP_STALL
const SELL_CRATE_POSITION := VillageMapData.SELL_CRATE
const SELL_CRATE_RECT := Rect2(1482,549,60,54)
const VILLAGE_SQUARE := VillageMapData.SQUARE
const VILLAGE_MAIN_PATH := Rect2(324,624,360,96)
const FARM_YARD_RECT := VillageMapData.FARM_YARD
const FARM_FENCE_CELL_SIZE := 24
const FARM_FENCE_SPANS := VillageMapData.FENCE_SPANS
const FARM_GATE_SPANS := VillageMapData.GATE_SPANS

const BUILDINGS := {
	"cottage":{"location":"overworld","door":VillageMapData.COTTAGE_DOOR,"outside_spawn":VillageMapData.COTTAGE_EXIT,"interior":"cottage_interior","unlock":""},
	"shop_house":{"location":"overworld","door":VillageMapData.SHOP_DOOR,"interior":"shop_interior","unlock":""},
	"guild_hall":{"location":"overworld","door":VillageMapData.GUILD_DOOR,"interior":"guild_interior","unlock":""},
	"forge":{"location":"rocky","door":Vector2(760,470),"interior":"forge_interior","unlock":"mining"},
	"chapel":{"location":"cursed","door":Vector2(610,470),"interior":"chapel_interior","unlock":"ancient_key"},
	"prison":{"location":"ruins","door":Vector2(500,480),"interior":"prison_interior","unlock":""},
	"wizard_tower":{"location":"forest","door":Vector2(1710,470),"interior":"tower_interior","unlock":"mana"},
	"moon_castle":{"location":"ruins","door":Vector2(1590,510),"interior":"castle_hall","unlock":"story"},
}

const INTERIORS := {
	"cottage_interior":{"building":"cottage","room":Rect2(132, 112, 888, 448),"spawn":Vector2(576, 500),"exit":Vector2(576, 545),"color":Color("876a45"),"service":"bed","service_position":Vector2(300, 390),"services":[{"id":"bed","position":Vector2(300,390)},{"id":"cauldron","position":Vector2(930,390)},{"id":"alchemy","position":Vector2(700,490)},{"id":"pottery","position":Vector2(480,490)}]},
	"shop_interior":{"building":"shop_house","room":Rect2(170, 100, 812, 470),"spawn":Vector2(576, 510),"exit":Vector2(576, 555),"color":Color("9b7445"),"service":"shop","service_position":Vector2(576, 330)},
	"guild_interior":{"building":"guild_hall","room":Rect2(120, 90, 912, 500),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("79573d"),"service":"contracts","service_position":Vector2(576, 330),"services":[{"id":"contracts","position":Vector2(576,330)},{"id":"study","position":Vector2(340,470)},{"id":"sawmill","position":Vector2(885,485)}]},
	"forge_interior":{"building":"forge","room":Rect2(150, 100, 852, 480),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("6b5347"),"service":"forge","service_position":Vector2(576, 340),"services":[{"id":"forge","position":Vector2(576,340)},{"id":"furnace","position":Vector2(660,370)},{"id":"recycling","position":Vector2(315,480)},{"id":"glassblowing","position":Vector2(850,490)}]},
	"chapel_interior":{"building":"chapel","room":Rect2(210, 80, 732, 500),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("665b72")},
	"prison_interior":{"building":"prison","room":Rect2(100, 80, 952, 510),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("55575d")},
	"tower_interior":{"building":"wizard_tower","room":Rect2(220, 70, 712, 520),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("58456d")},
	"castle_hall":{"building":"moon_castle","room":Rect2(100, 80, 1700, 920),"spawn":Vector2(900, 910),"exit":Vector2(900, 965),"color":Color("6b5c56"),"links":[{"position":Vector2(1490, 220),"target":"castle_upper","spawn":Vector2(576, 520)},{"position":Vector2(270, 830),"target":"castle_dungeon","spawn":Vector2(576, 520)}]},
	"castle_upper":{"building":"moon_castle","room":Rect2(180, 80, 792, 500),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("76655a"),"back":"castle_hall","back_spawn":Vector2(1430, 250)},
	"castle_dungeon":{"building":"moon_castle","room":Rect2(120, 80, 912, 510),"spawn":Vector2(576, 520),"exit":Vector2(576, 570),"color":Color("3d4650"),"back":"castle_hall","back_spawn":Vector2(330, 800)},
}
## Возвращает твёрдые секции старого фермерского периметра как прямоугольники базовых клеток 24 px.
static func farm_fence_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for span in FARM_FENCE_SPANS:
		result.append(Rect2(Vector2(span.position * FARM_FENCE_CELL_SIZE), Vector2(span.size * FARM_FENCE_CELL_SIZE)))
	return result


## Возвращает две честные калитки фермы, которые остаются видимыми в F10 и свободными для движения.
static func farm_gate_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for span in FARM_GATE_SPANS:
		result.append(Rect2(Vector2(span.position * FARM_FENCE_CELL_SIZE), Vector2(span.size * FARM_FENCE_CELL_SIZE)))
	return result


## Проверяет, относится ли идентификатор локации к интерьеру здания.
static func is_interior(location: String) -> bool:
	return INTERIORS.has(location)


## Возвращает данные интерьера либо пустой словарь для внешней локации.
static func interior(location: String) -> Dictionary:
	return INTERIORS.get(location, {})


## Возвращает прямоугольник назначения спрайта относительно координаты двери.
static func destination_rect(building_id: String) -> Rect2:
	return BuildingVisualSystem.destination_rect(building_id,Vector2(BUILDINGS[building_id].door))


## Возвращает две твёрдые секции фундамента с честным свободным проёмом двери 48 px.
static func collision_rects(building_id: String) -> Array[Rect2]:
	return BuildingVisualSystem.collision_rects(building_id,Vector2(BUILDINGS[building_id].door))


## Возвращает интерактивную область внешней двери шириной две базовые клетки.
static func door_rect(building_id: String) -> Rect2:
	return BuildingVisualSystem.door_rect(building_id,Vector2(BUILDINGS[building_id].door))


## Возвращает твёрдую часть здания, оставляя свободный подход к двери снизу.
static func collision_rect(building_id: String) -> Rect2:
	return BuildingVisualSystem.collision_bounds(building_id,Vector2(BUILDINGS[building_id].door))


## Возвращает здания, расположенные в указанной внешней локации.
static func buildings_at(location: String) -> Array[String]:
	var result: Array[String] = []
	for building_id in BUILDINGS:
		if BUILDINGS[building_id].location == location:
			result.append(building_id)
	return result


## Проверяет условие открытия здания по текущему прогрессу персонажа.
static func can_enter(game: Node, building_id: String) -> bool:
	if not BUILDINGS.has(building_id):
		return false
	match String(BUILDINGS[building_id].unlock):
		"mining": return game.SkillSystem.skill(game, "mining") >= 1
		"ancient_key": return game.inventory_item_count("ancient_key") > 0
		"mana": return game.SkillSystem.skill(game, "mana") >= 2
		"story": return game.mission_states.get("story_relic", "available") == game.QuestSystem.COMPLETED and game.player_level >= 3
	return true


## Возвращает локализованную причину закрытой двери.
static func locked_message(game: Node, building_id: String) -> String:
	match String(BUILDINGS.get(building_id, {}).get("unlock", "")):
		"mining": return game.LocaleSystem.text("building_need_mining")
		"ancient_key": return game.LocaleSystem.text("building_need_key")
		"mana": return game.LocaleSystem.text("building_need_mana")
		"story": return game.LocaleSystem.text("building_need_story")
	return game.LocaleSystem.text("building_locked")


## Находит ближайшую дверь, выход или переход между этажами активной локации.
static func nearest_interaction(game: Node, distance_limit: float = 92.0) -> String:
	if not is_interior(game.current_location):
		var nearest := ""
		for building_id in buildings_at(game.current_location):
			var distance: float = game.player.distance_to(BUILDINGS[building_id].door)
			if distance < distance_limit:
				distance_limit = distance
				nearest = "building:%s" % building_id
		return nearest
	var data: Dictionary = INTERIORS[game.current_location]
	var nearest := "interior_exit" if game.player.distance_to(data.exit) < distance_limit else ""
	if not nearest.is_empty():
		distance_limit = game.player.distance_to(data.exit)
	for link in data.get("links", []):
		var distance: float = game.player.distance_to(link.position)
		if distance < distance_limit:
			distance_limit = distance
			nearest = "interior_link:%s" % String(link.target)
	if data.has("services"):
		for service in data.services:
			var service_distance:float=game.player.distance_to(service.position)
			if service_distance<distance_limit: distance_limit=service_distance; nearest="interior_service:%s"%String(service.id)
	elif data.has("service"):
		var service_distance: float = game.player.distance_to(data.service_position)
		if service_distance < distance_limit:
			nearest = "interior_service:%s" % String(data.service)
	return nearest


## Возвращает мировую позицию взаимодействия со зданием или интерьером.
static func interaction_position(game: Node, interaction: String) -> Vector2:
	if interaction.begins_with("building:"):
		return BUILDINGS.get(interaction.get_slice(":", 1), {}).get("door", Vector2.ZERO)
	if interaction == "interior_exit" and is_interior(game.current_location):
		return INTERIORS[game.current_location].exit
	if interaction.begins_with("interior_link:") and is_interior(game.current_location):
		var target := interaction.get_slice(":", 1)
		for link in INTERIORS[game.current_location].get("links", []):
			if link.target == target:
				return link.position
	if interaction.begins_with("interior_service:") and is_interior(game.current_location):
		var data:Dictionary=INTERIORS[game.current_location]; var service_id:=interaction.get_slice(":",1)
		for service in data.get("services",[]):
			if String(service.id)==service_id: return Vector2(service.position)
		return data.get("service_position", Vector2.ZERO)
	return Vector2.ZERO


## Выполняет назначенную помещению услугу без дублирования правил магазина, сна или крафта.
static func use_service(game: Node, service: String) -> bool:
	if game.WorkshopSystem.handles(service): game.open_crafting(service); game.notify_tutorial(service); return true
	match service:
		"shop": game.open_shop()
		"bed": game.sleep_until_morning()
		"craft": game.open_crafting()
		"cauldron": game.open_crafting("cauldron")
		"alchemy": game.open_crafting("alchemy"); game.notify_tutorial("alchemy_processing")
		"furnace": game.open_crafting("furnace"); game.notify_tutorial("furnace_queue")
		"study", "recycling": game.open_crafting(service)
		"forge": game.open_forge()
		"contracts": game.ContractSystem.open(game)
		_: return false
	return true


## Переводит героя через внешнюю дверь после проверки условия доступа.
static func enter(game: Node, building_id: String) -> bool:
	if not BUILDINGS.has(building_id) or BUILDINGS[building_id].location != game.current_location:
		return false
	if not can_enter(game, building_id):
		game.message = locked_message(game, building_id)
		game.play_sfx("hit")
		game.notify_tutorial("locked_building")
		return false
	var target: String = BUILDINGS[building_id].interior
	game.current_location = target
	game.player = INTERIORS[target].spawn
	game.sync_background_location()
	game.update_camera()
	game.message = game.LocaleSystem.location(target)
	game.play_sfx("door_open")
	game.notify_tutorial("building_enter"); game.notify_tutorial("interior_furniture")
	return true


## Выполняет переход между помещениями одного здания.
static func travel_inside(game: Node, target: String) -> bool:
	if not INTERIORS.has(target) or not is_interior(game.current_location):
		return false
	for link in INTERIORS[game.current_location].get("links", []):
		if link.target == target:
			game.current_location = target
			game.player = link.spawn
			game.sync_background_location()
			game.update_camera()
			game.message = game.LocaleSystem.location(target)
			game.play_sfx("door_open")
			game.notify_tutorial("castle_floor")
			return true
	return false


## Возвращает героя на предыдущий этаж либо наружу через дверь здания.
static func leave(game: Node) -> bool:
	if not is_interior(game.current_location):
		return false
	var data: Dictionary = INTERIORS[game.current_location]
	if data.has("back"):
		game.current_location = data.back
		game.player = data.back_spawn
	else:
		var building: Dictionary = BUILDINGS[data.building]
		game.current_location = building.location
		game.player = outdoor_spawn(game, String(data.building))
	game.sync_background_location()
	game.update_camera()
	game.message = game.LocaleSystem.location(game.current_location)
	game.play_sfx("door_close")
	return true


## Находит свободную точку снаружи двери, не зажатую фундаментом, забором или динамическим объектом.
static func outdoor_spawn(game: Node, building_id: String) -> Vector2:
	var building: Dictionary = BUILDINGS.get(building_id, {})
	if building.is_empty(): return game.player
	var door := Vector2(building.door)
	var preferred := Vector2(building.get("outside_spawn", door + Vector2(0, 96)))
	var candidates: Array[Vector2] = [
		preferred,
		preferred + Vector2(-48, 0), preferred + Vector2(48, 0),
		preferred + Vector2(0, 48), preferred + Vector2(-96, 48), preferred + Vector2(96, 48),
	]
	for candidate in candidates:
		if game.NavigationSystem.is_walkable(game, candidate): return candidate
	return preferred


## Проверяет, остаётся ли центр героя внутри доступной площади помещения.
static func is_walkable_inside(location: String, position: Vector2, radius: float) -> bool:
	if not INTERIORS.has(location):
		return true
	var data: Dictionary = INTERIORS[location]
	var room: Rect2 = data.room
	if not room.grow(-radius).has_point(position): return false
	var floor := InteriorRenderer.floor_rect(room)
	var on_floor := floor.grow(-radius).has_point(position)
	var doorway := Rect2(Vector2(data.exit.x - 38.0, floor.end.y - 48.0), Vector2(76.0, room.end.y - floor.end.y + 48.0))
	var in_doorway := doorway.grow(-radius).has_point(position)
	for link in data.get("links", []):
		if link.position.y >= floor.position.y: continue
		var passage := Rect2(Vector2(link.position.x - 38.0, link.position.y - 32.0), Vector2(76.0, floor.position.y - link.position.y + 80.0))
		in_doorway = in_doorway or passage.grow(-radius).has_point(position)
	if not on_floor and not in_doorway: return false
	for solid in InteriorVisualSystem.collision_rects(location):
		if (solid as Rect2).grow(radius).has_point(position): return false
	return true

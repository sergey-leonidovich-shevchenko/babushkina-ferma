extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const SHOP_STALL_POSITION := Vector2(1500, 430)
const SELL_CRATE_POSITION := Vector2(1580, 455)
const SELL_CRATE_RECT := Rect2(1550, 428, 60, 54)
const VILLAGE_SQUARE := Rect2(930, 270, 870, 340)
const VILLAGE_MAIN_PATH := Rect2(315, 760, 720, 105)
const FARM_YARD_RECT := Rect2(38, 830, 420, 350)
const FARM_FENCE_RECTS := [Rect2(38,826,120,10),Rect2(220,826,242,10),Rect2(38,826,10,358),Rect2(452,826,10,358),Rect2(38,1174,424,10)]

const BUILDINGS := {
	"cottage":{"location":"overworld","door":Vector2(420, 790),"sprite":0,"interior":"cottage_interior","size":Vector2(300, 300),"unlock":""},
	"shop_house":{"location":"overworld","door":Vector2(1480, 390),"sprite":1,"interior":"shop_interior","size":Vector2(300, 300),"unlock":""},
	"guild_hall":{"location":"overworld","door":Vector2(2110, 250),"sprite":2,"interior":"guild_interior","size":Vector2(330, 310),"unlock":""},
	"forge":{"location":"rocky","door":Vector2(760, 470),"sprite":3,"interior":"forge_interior","size":Vector2(300, 300),"unlock":"mining"},
	"chapel":{"location":"cursed","door":Vector2(610, 470),"sprite":4,"interior":"chapel_interior","size":Vector2(290, 300),"unlock":"ancient_key"},
	"prison":{"location":"ruins","door":Vector2(500, 480),"sprite":5,"interior":"prison_interior","size":Vector2(330, 310),"unlock":""},
	"wizard_tower":{"location":"forest","door":Vector2(1710, 470),"sprite":6,"interior":"tower_interior","size":Vector2(300, 320),"unlock":"mana"},
	"moon_castle":{"location":"ruins","door":Vector2(1590, 510),"sprite":7,"interior":"castle_hall","size":Vector2(380, 350),"unlock":"story"},
}

const INTERIORS := {
	"cottage_interior":{"building":"cottage","room":Rect2(210, 120, 732, 440),"spawn":Vector2(576, 500),"exit":Vector2(576, 545),"color":Color("876a45"),"service":"bed","service_position":Vector2(350, 340)},
	"shop_interior":{"building":"shop_house","room":Rect2(170, 100, 812, 470),"spawn":Vector2(576, 510),"exit":Vector2(576, 555),"color":Color("9b7445"),"service":"shop","service_position":Vector2(576, 330)},
	"guild_interior":{"building":"guild_hall","room":Rect2(120, 90, 912, 500),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("79573d"),"service":"contracts","service_position":Vector2(576, 330)},
	"forge_interior":{"building":"forge","room":Rect2(150, 100, 852, 480),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("6b5347"),"service":"forge","service_position":Vector2(576, 340)},
	"chapel_interior":{"building":"chapel","room":Rect2(210, 80, 732, 500),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("665b72")},
	"prison_interior":{"building":"prison","room":Rect2(100, 80, 952, 510),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("55575d")},
	"tower_interior":{"building":"wizard_tower","room":Rect2(220, 70, 712, 520),"spawn":Vector2(576, 525),"exit":Vector2(576, 575),"color":Color("58456d")},
	"castle_hall":{"building":"moon_castle","room":Rect2(100, 80, 1700, 920),"spawn":Vector2(900, 910),"exit":Vector2(900, 965),"color":Color("6b5c56"),"links":[{"position":Vector2(1490, 220),"target":"castle_upper","spawn":Vector2(576, 520)},{"position":Vector2(270, 830),"target":"castle_dungeon","spawn":Vector2(576, 520)}]},
	"castle_upper":{"building":"moon_castle","room":Rect2(180, 80, 792, 500),"spawn":Vector2(576, 520),"exit":Vector2(576, 565),"color":Color("76655a"),"back":"castle_hall","back_spawn":Vector2(1430, 250)},
	"castle_dungeon":{"building":"moon_castle","room":Rect2(120, 80, 912, 510),"spawn":Vector2(576, 520),"exit":Vector2(576, 570),"color":Color("3d4650"),"back":"castle_hall","back_spawn":Vector2(330, 800)},
}
const INTERIOR_SOLIDS := {
	"cottage_interior":[Rect2(265,195,150,120),Rect2(738,225,105,105)],
	"shop_interior":[Rect2(471,163,210,125),Rect2(795,220,90,90)],
	"guild_interior":[Rect2(476,163,200,125),Rect2(806,241,88,88)],
	"forge_interior":[Rect2(486,170,180,140),Rect2(806,241,88,88)],
}


## Проверяет, относится ли идентификатор локации к интерьеру здания.
static func is_interior(location: String) -> bool:
	return INTERIORS.has(location)


## Возвращает данные интерьера либо пустой словарь для внешней локации.
static func interior(location: String) -> Dictionary:
	return INTERIORS.get(location, {})


## Возвращает прямоугольник назначения спрайта относительно координаты двери.
static func destination_rect(building_id: String) -> Rect2:
	var data: Dictionary = BUILDINGS[building_id]
	var size: Vector2 = data.size
	return Rect2(data.door - Vector2(size.x * 0.5, size.y - 24.0), size)


## Возвращает твёрдую часть здания, оставляя свободный подход к двери снизу.
static func collision_rect(building_id: String) -> Rect2:
	var destination := destination_rect(building_id)
	return Rect2(destination.position + Vector2(34, 44), destination.size - Vector2(68, 82))


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
	if data.has("service"):
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
		return INTERIORS[game.current_location].get("service_position", Vector2.ZERO)
	return Vector2.ZERO


## Выполняет назначенную помещению услугу без дублирования правил магазина, сна или крафта.
static func use_service(game: Node, service: String) -> bool:
	match service:
		"shop": game.open_shop()
		"bed": game.sleep_until_morning()
		"craft": game.open_crafting()
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
	game.play_sfx("travel")
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
			game.play_sfx("travel")
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
		game.player = building.door + Vector2(0, 62)
	game.sync_background_location()
	game.update_camera()
	game.message = game.LocaleSystem.location(game.current_location)
	game.play_sfx("travel")
	return true


## Проверяет, остаётся ли центр героя внутри доступной площади помещения.
static func is_walkable_inside(location: String, position: Vector2, radius: float) -> bool:
	if not INTERIORS.has(location):
		return true
	if not INTERIORS[location].room.grow(-radius).has_point(position): return false
	for solid in INTERIOR_SOLIDS.get(location, []):
		if (solid as Rect2).grow(radius).has_point(position): return false
	return true

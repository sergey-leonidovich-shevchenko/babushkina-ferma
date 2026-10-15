extends RefCounted

const WaterData := preload("res://scripts/systems/water_layout_data.gd")
const Water := preload("res://scripts/systems/water_map_registry.gd")
const IDS := ["overworld","village_market","village_garden","village_river","village_workyard","village_orchard"]
const SIZE := Vector2(2040,1200)
const PORTS := {"left":Vector2(120,624),"right":Vector2(1920,624),"top":Vector2(1008,168),"bottom":Vector2(1008,1080)}
const INWARD := {"left":Vector2.RIGHT,"right":Vector2.LEFT,"top":Vector2.DOWN,"bottom":Vector2.UP}
const LINKS := {
	"overworld":{"right":["village_market","left"],"top":["village_garden","bottom"],"bottom":["village_orchard","top"]},
	"village_market":{"left":["overworld","right"],"top":["village_workyard","bottom"],"bottom":["village_river","top"]},
	"village_garden":{"bottom":["overworld","top"],"right":["village_workyard","left"]},
	"village_workyard":{"left":["village_garden","right"],"bottom":["village_market","top"],"right":["village_river","right"]},
	"village_river":{"top":["village_market","bottom"],"left":["village_orchard","right"],"right":["village_workyard","right"]},
	"village_orchard":{"top":["overworld","bottom"],"right":["village_river","left"]},
}
const NPC_AREAS := {"agafya":"village_garden","varvara":"village_river","gavrila":"village_workyard","dunya":"village_market"}
const NPC_POINTS := {"agafya":Vector2(960,552),"varvara":Vector2(744,696),"gavrila":Vector2(960,552),"dunya":Vector2(1104,648)}
const HOUSES := {
	"village_market":[{"kind":"shop_house","position":Vector2(552,432)},{"kind":"cottage","position":Vector2(1488,432)}],
	"village_garden":[{"kind":"cottage","position":Vector2(864,408)}],
	"village_workyard":[{"kind":"forge","position":Vector2(960,432)},{"kind":"cottage","position":Vector2(1656,456)}],
	"village_river":[{"kind":"cottage","position":Vector2(504,432)}],
	"village_orchard":[],
}
const PROPS := {
	"village_market":[{"kind":"well","position":Vector2(1008,552)},{"kind":"cart","position":Vector2(1512,576)},{"kind":"bench","position":Vector2(720,768)},{"kind":"bench","position":Vector2(1320,768)},{"kind":"lamp","position":Vector2(792,432)},{"kind":"lamp","position":Vector2(1272,432)}],
	"village_garden":[{"kind":"well","position":Vector2(576,816)},{"kind":"table","position":Vector2(1200,480)},{"kind":"bench","position":Vector2(1488,816)},{"kind":"board","position":Vector2(648,432)}],
	"village_workyard":[{"kind":"workbench","position":Vector2(1440,768),"direction":0},{"kind":"cart","position":Vector2(480,768)},{"kind":"board","position":Vector2(1248,480)},{"kind":"bench","position":Vector2(768,864)}],
	"village_river":[{"kind":"bench","position":Vector2(744,768)},{"kind":"bench","position":Vector2(1296,768)},{"kind":"lamp","position":Vector2(864,384)},{"kind":"lamp","position":Vector2(1152,384)}],
	"village_orchard":[{"kind":"bench","position":Vector2(1248,672)},{"kind":"cart","position":Vector2(1752,840)},{"kind":"well","position":Vector2(480,672)}],
}
const SERVICES := {"village_market":{"shop":Vector2(1512,648)},"village_garden":{"alchemy":Vector2(1200,552)},"village_workyard":{"workbench":Vector2(1440,840)}}
const PATHS := {
	"overworld":[[Vector2(2016,744),Vector2(2160,672),Vector2(2232,672)],[Vector2(1776,600),Vector2(1968,600),Vector2(1968,192),Vector2(1560,192)],[Vector2(1248,1080),Vector2(1200,1248)]],
	"village_market":[[Vector2(120,624),Vector2(576,624),Vector2(1008,624),Vector2(1008,1080)],[Vector2(1008,168),Vector2(1008,624),Vector2(1512,648)]],
	"village_garden":[[Vector2(1008,1080),Vector2(768,864),Vector2(768,600),Vector2(1104,600),Vector2(1440,720),Vector2(1920,624)],[Vector2(768,600),Vector2(864,480),Vector2(1200,552)]],
	"village_workyard":[[Vector2(120,624),Vector2(672,624),Vector2(1008,624),Vector2(1392,624),Vector2(1920,624)],[Vector2(1008,1080),Vector2(1008,864),Vector2(1392,864),Vector2(1392,624)]],
	"village_river":[[Vector2(624,168),Vector2(624,480),Vector2(1152,480),Vector2(1440,576),Vector2(1920,624)],[Vector2(120,624),Vector2(624,624),Vector2(624,480)],[Vector2(624,624),Vector2(624,864),Vector2(1392,864),Vector2(1632,624),Vector2(1920,624)]],
	"village_orchard":[[Vector2(1008,168),Vector2(1008,480),Vector2(624,480),Vector2(624,816),Vector2(1392,816),Vector2(1560,720),Vector2(1920,624)]],
}
const WATER := WaterData.VILLAGE_WATER
const BRIDGES := WaterData.VILLAGE_BRIDGES
const RAILS := [Rect2(912,120,24,288),Rect2(912,552,24,240),Rect2(912,936,24,216),Rect2(1080,120,24,288),Rect2(1080,552,24,240),Rect2(1080,936,24,216)]
static var _trees:Dictionary={}
static var _routes:Dictionary={}

## Возвращает общие прямоугольные маршруты для покрытия, цветов и карты каждого деревенского района.
static func routes(location:String) -> Array:
	if not _routes.has(location): _routes[location]=preload("res://scripts/systems/cardinal_path_system.gd").routes(PATHS.get(location,[]))
	return _routes[location]

## Определяет расширенную стартовую область без добавления её районов в линейную смену биомов.
static func contains(location: String) -> bool:
	return location in IDS

## Отделяет пять новых карт от первоначальной фермы с её существующими постройками и сюжетной переправой.
static func added(location: String) -> bool:
	return contains(location) and location!="overworld"

## Возвращает фактическую точку прохода с поправкой на старую ферму и северный берег новой реки.
static func port_position(location: String, port: String) -> Vector2:
	if location=="overworld": return {"right":Vector2(2232,672),"top":Vector2(1560,192),"bottom":Vector2(1200,1248)}[port]
	if location=="village_river" and port=="top": return Vector2(624,168)
	return PORTS[port]

## Собирает двусторонние переходы с безопасным появлением в стороне от обратного триггера.
static func passages(location: String) -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for port in LINKS.get(location,{}):
		var target:Array=LINKS[location][port]
		result.append({"port":port,"position":port_position(location,port),"target":target[0],"arrival":target[1],"spawn":port_position(target[0],target[1])+INWARD[target[1]]*96})
	return result

## Проверяет единую видимую воду и два настоящих мостовых настила с учётом радиуса тела.
static func water_blocks(location: String, point: Vector2, radius: float=0) -> bool:
	return Water.blocks(location,point,radius) if location=="village_river" else false

## Размещает рамку деревьев за пределами проходов, реки и её мостов; результат кешируется для каждой карты.
static func trees(location: String) -> Array:
	if not added(location): return []
	if _trees.has(location): return _trees[location]
	var result:=[]; var candidates:=[]
	for x in range(96,2000,168): candidates.append(Vector2(x,192)); candidates.append(Vector2(x,1128))
	for y in range(360,1100,168): candidates.append(Vector2(72,y)); candidates.append(Vector2(1968,y))
	for point in candidates:
		if water_blocks(location,point,36) or passages(location).any(func(link): return Vector2(link.position).distance_to(point)<144): continue
		result.append({"position":point,"stage":2 if posmod(int(point.x+point.y*3),5)<2 else 3})
	_trees[location]=result; return result

extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Soil := preload("res://scripts/presentation/garden_soil.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Masks := preload("res://scripts/presentation/ground_edge_masks.gd")
const Plaza := preload("res://scripts/presentation/plaza_ground.gd")
const Checks := preload("res://tests/suites/axial_road_suite.gd")
const CASES := [
	{"id":"spring","day":1,"season":"spring","weather":"clear"},
	{"id":"summer","day":8,"season":"summer","weather":"clear"},
	{"id":"autumn","day":15,"season":"autumn","weather":"clear"},
	{"id":"winter","day":22,"season":"winter","weather":"clear"},
	{"id":"wet","day":3,"season":"spring","weather":"rain"},
]
const VIEWS := {"homestead":Vector2(360,648),"farm-end":Vector2(456,984),"square":Vector2(1392,744),
	"bridge-west":Vector2(864,456),"bridge-east":Vector2(1608,960),"road-turn":Vector2(2016,744)}

## Устанавливает настоящий календарь и его естественную погоду без шага симуляции или автоматического полива.
static func configure(game: Node, profile: Dictionary, reference: bool = true) -> void:
	game.day=int(profile.day); game.state.world.weather_day=game.day; game.state.world.weather=String(profile.weather)
	game.sync_background_environment()
	if reference: preload("res://scripts/presentation/visual_reference_mode.gd").enable(game,true)
	else: preload("res://scripts/presentation/visual_reference_mode.gd").disable(game)

## Хеширует реальные массивы геометрии и альфы отдельно от тонов материалов и календаря.
static func geometry() -> Dictionary:
	Soil.warmup()
	var meshes:={"meadow":Meadow.mesh(Map.WORLD_SIZE),"old-main":Masks.MAIN,"old-connectors":Masks.CONNECTORS,
		"axial-main":Masks.AXIAL_MAIN,"axial-connectors":Masks.AXIAL_CONNECTORS,"network-main":Masks.NETWORK_MAIN,
		"network-connectors":Masks.NETWORK_CONNECTORS,"plaza-apron":Plaza.APRON,"plaza-contact":Plaza.CONTACT,"plaza-stone":Plaza.STONE,"garden":Soil._base}
	for cell: Vector2i in Soil._plots: meshes["plot-"+str(cell)]=Soil._plots[cell]
	var ids:={}; var hashes:={}
	for key: String in meshes:
		var mesh: ArrayMesh=meshes[key]; ids[key]=mesh.get_instance_id(); hashes[key]=digest(mesh.surface_get_arrays(0))
	var layout:={"routes":Map.routes(),"connectors":preload("res://scripts/systems/village_region_data.gd").routes("overworld"),
		"river":Map.river_polygon(),"pond":Map.pond_polygon(),"river-bank":Map.river_polygon(10.0),"pond-bank":Map.pond_polygon(10.0),
		"bridges":Map.BRIDGES,"fences":Map.FENCE_SPANS,"farm":Soil.FARM}
	return {"mesh_hashes":hashes,"mesh_ids":ids,"layout_sha256":digest(layout),"mesh_count":meshes.size(),"world":Points.pair(Map.WORLD_SIZE)}

## Читает реальные правила в 1 200 точках и восемь физических движений у двух мостов.
static func rules(game: Node) -> Dictionary:
	var values:=Checks._rules(game); var motions:=Checks._motions(game).map(func(v:Vector2): return Points.pair(v))
	return {"rules":values,"motions":motions,"rules_sha256":digest(values),"motions_sha256":digest(motions)}

## Вычисляет точную подпись значений, не заменяя их приблизительным счётчиком.
static func digest(value: Variant) -> String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()

extends RefCounted

const Sources := preload("res://tools/qa/ground/compiled_sources.gd")

const Masks := preload("res://scripts/presentation/ground_edge_masks.gd")
const Field := preload("res://tools/qa/ground/axial_road_field.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Farm := preload("res://scripts/systems/world_farming_system.gd")
const Legacy := preload("res://tools/qa/ground/ground_edge_field.gd")

## Проверяет отдельные от цвета маски, неизменность физики и актуальность скомпилированного чертежа.
static func run(context: SceneTree) -> void:
	for mesh: ArrayMesh in [Masks.AXIAL_MAIN,Masks.AXIAL_CONNECTORS]:
		var arrays := mesh.surface_get_arrays(0); var valid := true; var soft := 0
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector2=arrays[Mesh.ARRAY_VERTEX][i]; var color: Color=arrays[Mesh.ARRAY_COLOR][i]
			if point.x<0 or point.y<0 or point.x>2400 or point.y>1368 or color.r!=1.0 or color.g!=1.0 or color.b!=1.0 or color.a<0 or color.a>1: valid=false
			if color.a>0 and color.a<1: soft+=1
			if point.distance_to(arrays[Mesh.ARRAY_TEX_UV][i]*384.0)>.001: valid=false
		context.expect(valid and soft>100 and mesh.get_surface_count()==1,"compiled mask has clipped geometry, independent white RGB, smooth alpha and shared world UV")
		var source_names: Array=mesh.get_meta("source_sha256").keys(); source_names.sort()
		context.expect(source_names==["scripts/systems/cardinal_path_system.gd","scripts/systems/village_map_data.gd","scripts/systems/village_region_data.gd","tools/axial_road_builder.gd","tools/axial_road_field.gd","tools/ground_edge_field.gd"],"source coverage includes cardinal route conversion and both canonical maps")
		for path: String in mesh.get_meta("source_sha256"):
			context.expect(Sources.matches(path,mesh.get_meta("source_sha256").get(path)),"compiled mask follows current canonical source: "+path)
	var edges := Field.segments([[Vector2(96,144),Vector2(384,144)],[Vector2(240,144),Vector2(240,384)]])
	var flat_end := true
	for offset in [-20.0,0.0,20.0]:
		if Field.coverage(Vector2(414,144+offset),edges)<.95: flat_end=false
	context.expect(flat_end and Legacy.coverage(Vector2(414,164),edges)<.8,"wide flat end replaces a semicircle instead of merely blurring the same capsule")
	context.expect(Field.coverage(Vector2(432,144),edges)==0.0 and Field.coverage(Vector2(120,192),edges)==0.0,"edge wear cannot leave the existing axial corridor bounds plus feather")
	context.expect(Field.coverage(Vector2(240,144),edges)==1.0 and Field.coverage(Vector2(240,80),edges)==0.0,"union includes T centre and excludes ground outside road width")
	var continuous := true; var last := 0.0
	for i in 181:
		var value := Field.coverage(Vector2(120,100+i*.5),edges)
		if absf(value-last)>.16: continuous=false
		last=value
	context.expect(continuous,"half-world-pixel samples have no binary alpha jump across straight road")
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var bg: Node=game.get_node("WorldBackground"); bg._ready()
	var before := _rules(game); var motions := _motions(game); var saved: Dictionary=game.SaveSystem.snapshot(game)
	bg.set_rectangular_roads(false)
	context.expect(before==_rules(game),"legacy edges retain all 1200 walkability/tillability results")
	context.expect(motions==_motions(game),"legacy bridge corner movement remains unchanged")
	bg.set_rectangular_roads(true)
	context.expect(motions==_motions(game),"rectangular paint creates no new diagonal passage around either bridge")
	context.expect(before==_rules(game) and saved==game.SaveSystem.snapshot(game),"soft edges retain all rules and complete saved world")
	game.free()

## Проверяет реальные диагональные движения у обоих настилов, а не объявляет новую краску навигацией.
static func _motions(game: Node) -> Array:
	var start: Vector2=game.player; var result := []
	for bridge: Rect2 in game.VillageLayoutSystem.BRIDGES:
		for side in [-1.0,1.0]:
			for end in [-1.0,1.0]:
				game.player=bridge.get_center()+Vector2(side*60.0,end*100.0)
				game.NavigationSystem.move(game,Vector2(-side*48.0,-end*48.0))
				result.append(game.player)
	game.player=start
	return result

## Читает настоящие правила земли после штатной ленивой инициализации, не заменяя их маской покрытия.
static func _rules(game: Node) -> Array:
	var result := []
	for y in range(120,1320,48):
		for x in range(48,2352,48):
			var point := Vector2(x,y)
			result.append([game.NavigationSystem.walkability_reason(game,point),Farm.tillability_reason(game,"overworld",Farm.cell_at(point))])
	return result

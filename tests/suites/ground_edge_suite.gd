extends RefCounted

const Masks := preload("res://scripts/presentation/ground_edge_masks.gd")
const Field := preload("res://tools/ground_edge_field.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const Farm := preload("res://scripts/systems/world_farming_system.gd")

## Проверяет отдельные от цвета маски, неизменность физики и актуальность скомпилированного чертежа.
static func run(context: SceneTree) -> void:
	for mesh: ArrayMesh in [Masks.MAIN,Masks.CONNECTORS]:
		var arrays := mesh.surface_get_arrays(0); var valid := true; var soft := 0
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector2=arrays[Mesh.ARRAY_VERTEX][i]; var color: Color=arrays[Mesh.ARRAY_COLOR][i]
			if point.x<0 or point.y<0 or point.x>2400 or point.y>1368 or color.r!=1.0 or color.g!=1.0 or color.b!=1.0 or color.a<0 or color.a>1: valid=false
			if color.a>0 and color.a<1: soft+=1
			if point.distance_to(arrays[Mesh.ARRAY_TEX_UV][i]*384.0)>.001: valid=false
		context.expect(valid and soft>100 and mesh.get_surface_count()==1,"compiled mask has clipped geometry, independent white RGB, smooth alpha and shared world UV")
		var source_names: Array=mesh.get_meta("source_sha256").keys(); source_names.sort()
		context.expect(source_names==["scripts/systems/cardinal_path_system.gd","scripts/systems/village_map_data.gd","scripts/systems/village_region_data.gd","tools/ground_edge_builder.gd","tools/ground_edge_field.gd"],"source coverage includes cardinal route conversion and both canonical maps")
		for path: String in mesh.get_meta("source_sha256"):
			context.expect(FileAccess.get_sha256("res://"+path)==mesh.get_meta("source_sha256")[path],"compiled mask follows current canonical source: "+path)
	var edges := Field.segments([[Vector2(96,144),Vector2(384,144)],[Vector2(240,144),Vector2(240,384)]])
	context.expect(Field.coverage(Vector2(240,144),edges)==1.0 and Field.coverage(Vector2(240,80),edges)==0.0,"union includes T centre and excludes ground outside road width")
	var continuous := true; var last := 0.0
	for i in 181:
		var value := Field.coverage(Vector2(120,100+i*.5),edges)
		if absf(value-last)>.16: continuous=false
		last=value
	context.expect(continuous,"half-world-pixel samples have no binary alpha jump across straight road")
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var bg: Node=game.get_node("WorldBackground"); bg._ready()
	var before := _rules(game); var saved: Dictionary=game.SaveSystem.snapshot(game)
	bg.set_soft_ground_edges(false)
	context.expect(before==_rules(game),"legacy edges retain all 1200 walkability/tillability results")
	bg.set_soft_ground_edges(true)
	context.expect(before==_rules(game) and saved==game.SaveSystem.snapshot(game),"soft edges retain all rules and complete saved world")
	game.free()

## Читает настоящие правила земли после штатной ленивой инициализации, не заменяя их маской покрытия.
static func _rules(game: Node) -> Array:
	var result := []
	for y in range(120,1320,48):
		for x in range(48,2352,48):
			var point := Vector2(x,y)
			result.append([game.NavigationSystem.walkability_reason(game,point),Farm.tillability_reason(game,"overworld",Farm.cell_at(point))])
	return result

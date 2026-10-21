extends RefCounted

const Masks := preload("res://scripts/presentation/ground_edge_masks.gd")
const Field := preload("res://tools/axial_road_field.gd")
const Compiler := preload("res://tools/road_network_compile.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const AxialTests := preload("res://tests/suites/axial_road_suite.gd")
const Points := preload("res://tools/visual_camera_points.gd")

## Проверяет реальную геометрию двух владельцев общего поля, UV, непересечение и сохранность игровых правил.
static func run(context: SceneTree) -> void:
	var all_edges := Field.segments(Map.routes()+Regions.routes("overworld")); var occupied := {}; var valid := true; var duplicate := false
	for mesh: ArrayMesh in [Masks.NETWORK_MAIN,Masks.NETWORK_CONNECTORS]:
		var spec: Dictionary=mesh.get_meta("mask_spec"); var arrays := mesh.surface_get_arrays(0)
		context.expect(spec.shape=="axial-union-partition" and spec.radius==Map.PATH_HALF_WIDTH and spec.period_world==384.0 and mesh.get_surface_count()==1,"network shares width, material coordinates and one surface per owner")
		context.expect(mesh.get_meta("source_sha256").size()==Compiler.SOURCES.size(),"network compiler preserves complete source coverage")
		for path: String in Compiler.SOURCES:
			context.expect(FileAccess.get_sha256("res://"+path)==mesh.get_meta("source_sha256").get(path),"compiled network follows canonical input: "+path)
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector2=arrays[Mesh.ARRAY_VERTEX][i]; var uv: Vector2=arrays[Mesh.ARRAY_TEX_UV][i]; var color: Color=arrays[Mesh.ARRAY_COLOR][i]
			if point.distance_to(uv*384.0)>.001 or absf(color.a-Field.coverage(point,all_edges))>1.0/255.0+.00001 or color.r!=1 or color.g!=1 or color.b!=1: valid=false
		var vertices: PackedVector2Array=arrays[Mesh.ARRAY_VERTEX]; var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]; var count := 0
		for i in range(0,indices.size(),6):
			var a: Vector2=vertices[indices[i]]; var b: Vector2=vertices[indices[i+1]]; var c: Vector2=vertices[indices[i+2]]
			if b.y!=a.y or c.x!=b.x or c.y-a.y!=2 or b.x<=a.x: valid=false
			for x in range(int(a.x),int(b.x),2):
				var key := Vector2i(x,int(a.y)); count+=1
				if occupied.has(key): duplicate=true
				occupied[key]=true
		context.expect(count==spec.occupied_cells,"compiled ownership metadata counts actual nonoverlapping cells")
	context.expect(valid,"every network vertex uses global UV, white color and the exact union coverage")
	context.expect(not duplicate and not occupied.is_empty(),"neither layer draws the same world cell twice")
	var reference := preload("res://tools/axial_road_builder.gd").build(Map.routes()+Regions.routes("overworld"),Map.WORLD_SIZE)
	var ref_arrays := reference.surface_get_arrays(0); var expected := {}
	for i in range(0,ref_arrays[Mesh.ARRAY_INDEX].size(),6):
		var a: Vector2=ref_arrays[Mesh.ARRAY_VERTEX][ref_arrays[Mesh.ARRAY_INDEX][i]]
		var b: Vector2=ref_arrays[Mesh.ARRAY_VERTEX][ref_arrays[Mesh.ARRAY_INDEX][i+1]]
		for x in range(int(a.x),int(b.x),2): expected[Vector2i(x,int(a.y))]=true
	context.expect(expected==occupied,"partition covers exactly the independently compiled single union across the complete world")
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var bg: Node=game.get_node("WorldBackground"); bg._ready()
	var rules := AxialTests._rules(game); var motions := AxialTests._motions(game); var saved: Dictionary=game.SaveSystem.snapshot(game)
	bg.set_joined_roads(false)
	context.expect(rules==AxialTests._rules(game) and motions==AxialTests._motions(game),"old network keeps 1200 rules and eight bridge corner movements")
	bg.set_joined_roads(true)
	context.expect(rules==AxialTests._rules(game) and motions==AxialTests._motions(game) and saved==game.SaveSystem.snapshot(game),"joined network preserves rules, real movements and full saved world")
	game.free()

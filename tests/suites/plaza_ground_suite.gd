extends RefCounted

const Plaza := preload("res://scripts/presentation/plaza_ground.gd")
const Compiler := preload("res://tools/plaza_compile.gd")
const Field := preload("res://tools/plaza_field.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Rules := preload("res://tests/suites/axial_road_suite.gd")
const Points := preload("res://tools/visual_camera_points.gd")

## Проверяет происхождение, ограниченность слоя, мировую фазу материала и прежние правила земли.
static func run(context: SceneTree) -> void:
	context.expect(Plaza.SOURCE.get_size()==Vector2(512,512) and Plaza.SOURCE.get_image().has_mipmaps(),"plaza uses a bounded 512px material with mipmaps")
	context.expect(Plaza.texture()==Plaza.texture() and Plaza.texture().texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and Plaza.texture().texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED,"plaza sampler is retained and isolated")
	for mesh: ArrayMesh in [Plaza.APRON,Plaza.CONTACT,Plaza.STONE]:
		var spec: Dictionary=mesh.get_meta("mask_spec"); var arrays := mesh.surface_get_arrays(0); var valid := true; var soft := 0
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector2=arrays[Mesh.ARRAY_VERTEX][i]; var color: Color=arrays[Mesh.ARRAY_COLOR][i]
			if not Map.SQUARE.grow(24.1).has_point(point) or color.r!=1 or color.g!=1 or color.b!=1 or color.a<0 or color.a>1: valid=false
			if color.a>0 and color.a<1: soft+=1
			if arrays[Mesh.ARRAY_TEX_UV][i].distance_to(Meadow.uv_at(point,Vector2i((point/192.0).floor())))>.00001: valid=false
		context.expect(valid and soft>100 and mesh.get_surface_count()==1,"plaza geometry stays bounded with smooth independent alpha and continuous mirrored world UV")
		context.expect(spec.chips==22 and spec.vertices<7000 and mesh.get_meta("source_sha256").size()==Compiler.SOURCES.size(),"plaza contains bounded debris, compact geometry and complete source coverage")
		for path: String in Compiler.SOURCES: context.expect(mesh.get_meta("source_sha256").get(path)==FileAccess.get_sha256("res://"+path),"compiled plaza follows source: "+path)
	var fragments := Field.chips(); var chips_visible := 0; var contacts := 0
	for rect: Rect2 in fragments:
		if Field.coverage(rect.get_center(),"stone",fragments)>.9: chips_visible+=1
		if Field.coverage(rect.get_center()+Vector2(1,2),"contact",fragments)>.09: contacts+=1
	context.expect(chips_visible==22 and contacts==22,"each decorative chip has actual stone coverage and subtle ground contact")
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0]); var bg: Node=game.get_node("WorldBackground"); bg._ready()
	var rules := Rules._rules(game); var motions := Rules._motions(game); var saved: Dictionary=game.SaveSystem.snapshot(game)
	bg.set_soft_plaza(false); context.expect(rules==Rules._rules(game) and motions==Rules._motions(game),"legacy plaza retains 1200 rules and eight bridge corner motions")
	bg.set_soft_plaza(true); context.expect(rules==Rules._rules(game) and motions==Rules._motions(game) and saved==game.SaveSystem.snapshot(game),"soft plaza retains navigation, tillability, movement and complete save")
	game.free()

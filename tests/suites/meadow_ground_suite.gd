extends RefCounted

const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Farm := preload("res://scripts/systems/world_farming_system.gd")

## Проверяет реальные UV общих сторон, ограниченность геометрии и сохранность правил земли при откате.
static func run(context: SceneTree) -> void:
	var horizontal := true; var vertical := true
	for y in 5:
		for x in 5:
			for step in 17:
				var edge := Vector2(x+1,y+float(step)/16.0)*Meadow.CELL
				if Meadow.uv_at(edge,Vector2i(x,y)) != Meadow.uv_at(edge,Vector2i(x+1,y)): horizontal=false
				edge=Vector2(x+float(step)/16.0,y+1)*Meadow.CELL
				if Meadow.uv_at(edge,Vector2i(x,y)) != Meadow.uv_at(edge,Vector2i(x,y+1)): vertical=false
	context.expect(horizontal and vertical,"all sampled 5x5 seams read identical texture coordinates, including corners")
	var size := Vector2(2400,1368); var mesh := Meadow.mesh(size); var arrays := mesh.surface_get_arrays(0)
	var bounded := true
	for point in arrays[Mesh.ARRAY_VERTEX]:
		if point.x<0 or point.y<0 or point.x>size.x or point.y>size.y: bounded=false
	context.expect(bounded and arrays[Mesh.ARRAY_VERTEX].size()==416,"partial last row and column clip exactly to world bounds")
	context.expect(Meadow.mesh(size)==mesh and mesh.get_surface_count()==1,"retained mesh has one surface and is reused")
	context.expect(Meadow.SOURCE.get_size()==Vector2(512,512) and Meadow.SOURCE.get_image().has_mipmaps(),"runtime texture is 512 square with imported mipmaps")
	context.expect(Meadow.texture().texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and Meadow.texture().texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED,"grass owns filtering and clamped edges independently of legacy sampler")
	var game := Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var bg: Node=game.get_node("WorldBackground"); bg._ready()
	var old := _rules(game); var saved: Dictionary=game.SaveSystem.snapshot(game)
	bg.set_painted_grass(false)
	context.expect(not bg.painted_grass and old==_rules(game),"legacy grass preserves every sampled walkability and tillability result")
	bg.set_painted_grass(true)
	context.expect(bg.painted_grass and old==_rules(game),"painted grass preserves every sampled walkability and tillability result")
	bg.set_location("cottage_interior"); bg.set_painted_grass(false); bg.set_location("overworld"); bg.set_painted_grass(true)
	context.expect(saved==game.SaveSystem.snapshot(game),"material toggles and region round trip leave complete save unchanged")
	game.free()

## Читает настоящую навигацию и всю фермерскую сетку, а не выводит их из рисунка новой травы.
static func _rules(game: Node) -> Array:
	var result := []
	for y in range(120,1320,48):
		for x in range(48,2352,48):
			var point := Vector2(x,y)
			result.append([game.NavigationSystem.walkability_reason(game,point),Farm.tillability_reason(game,"overworld",Farm.cell_at(point))])
	return result

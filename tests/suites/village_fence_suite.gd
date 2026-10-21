extends RefCounted
const F:=preload("res://scripts/presentation/village_fence_visual.gd")
const Points:=preload("res://tools/visual_camera_points.gd")
const Rules:=preload("res://tools/ground_seasons_fixture.gd")

## Проверяет все соединения и реальные старые коллизии без изменения игровых правил.
static func run(ctx:SceneTree)->void:
	for mask in 16:
		var count:=0
		for bit in [1,2,4,8]:
			if mask&bit:count+=1
		var values:=F.arms(mask)
		ctx.expect(values.size()==count,"fence exact neighbors: "+str(mask))
		var axial:=true
		for arm in values:axial=axial and arm.length()==12 and (arm.x==0 or arm.y==0)
		ctx.expect(axial,"fence all arms on base grid: "+str(mask))
	for part in ["post","rail","depth"]:
		ctx.expect(F.texture(part)!=null and F.texture(part)==F.texture(part),"fence shared standalone texture: "+part)
	ctx.expect(F.texture("rail").get_width()-16>=96 and F.texture("rail").get_height()-16>=64,"longest horizontal slice stays inside content and padding")
	ctx.expect(F.texture("depth").get_width()-16>=28 and F.texture("depth").get_height()-16>=96,"longest depth slice stays inside content and padding")
	var cells:=F.farm_cells();var count:=0
	for span in F.MapData.FENCE_SPANS:count+=span.size.x*span.size.y
	ctx.expect(cells.size()==count,"fence exact original farm cell count")
	for gap in F.MapData.GATE_SPANS:
		var clear:=true
		for y in range(gap.position.y,gap.end.y):
			for x in range(gap.position.x,gap.end.x):clear=clear and not cells.has(Vector2i(x,y))
		ctx.expect(clear,"original farm opening stays visually empty: "+str(gap))
	ctx.expect(F.farm_mask(Vector2i(4,32))==6,"northwest fence corner joins right and down")
	ctx.expect(F.farm_mask(Vector2i(22,45))==9,"southeast fence corner joins up and left")
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	var rules:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	for i in 64:F.farm_cells();F.farm_mask(Vector2i(4,32));F.arms(i%16);F.texture("post")
	ctx.expect(game.SaveSystem.snapshot(game)==before,"fence visual lookup retains complete save")
	ctx.expect(Rules.rules(game)==rules,"fence visual lookup retains 1200 navigation samples")
	var values:Array=game.FenceSystem.structures(game);var saved:Array=values.duplicate(true);values.clear()
	for orientation in [0,1]:
		values.append({"location":"overworld","cell":[64,40],"style":0,"kind":"gate","orientation":orientation,"open":false})
		for cell in game.FenceSystem.occupied_cells(values[0]):
			ctx.expect(game.FenceSystem.blocks_position(game,game.FenceSystem.cell_center(cell),1),"closed gate blocks each occupied cell: "+str(orientation))
		ctx.expect(game.FenceSystem.toggle_gate(game,0),"existing interaction opens gate: "+str(orientation))
		for cell in game.FenceSystem.occupied_cells(values[0]):
			ctx.expect(not game.FenceSystem.blocks_position(game,game.FenceSystem.cell_center(cell),1),"open gate passes each occupied cell: "+str(orientation))
		var snapshot:Dictionary=game.SaveSystem.snapshot(game)
		ctx.expect(snapshot.estate.expansion.fences.size()==1 and bool(snapshot.estate.expansion.fences[0].open),"gate remains in existing save aggregate")
		values.clear()
	values.append_array(saved);game.free()

extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Data := preload("res://tools/qa/foliage/grass_compare/mesh_data.gd")
const Field := preload("res://tools/qa/foliage/grass_compare/field.gd")
var passed := 0
var failed := 0

## Использует только отдельный профиль, включая headless-проверку математики и жизненного цикла.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VRENDER-002-review-"+str(Time.get_ticks_usec()))
	_run.call_deferred()

## Проверяет реальные массивы/службы игры; это не доказательство нативной графики или FPS.
func _run() -> void:
	var game:=Points.create_game(); root.add_child(game); Points.configure(game,Points.registry().points[0])
	var before:Dictionary=game.SaveSystem.snapshot(game)
	var positions:=Data.positions(game,1024)
	var after:Dictionary=game.SaveSystem.snapshot(game)
	for key in before:
		if before[key]!=after[key]: print("ROOT STATE DIFFERENCE ",key,": ",str(before[key]).left(800)," => ",str(after[key]).left(800))
	_check(positions.size()==1024,"full stress root count")
	_check(before==after,"root generation leaves saved state/RNG unchanged")
	for p in positions:
		_check(game.VillageLayoutSystem.overworld_tile(Vector2i(floori(p.x/24),floori(p.y/24)))==game.VillageLayoutSystem.OVERWORLD_TILE_GRASS,"root on grassy cell")
	var arrays:=Data.arrays(positions.slice(0,4)); var base:PackedVector2Array=arrays[Mesh.ARRAY_VERTEX]
	_check(base.size()==4*18,"same eighteen vertices per tuft")
	_check(arrays[Mesh.ARRAY_INDEX].size()==4*60,"same twenty triangles per tuft")
	for time in [0.0,1.25,3.5,100.0]:
		var bent:=Data.deform(arrays,time)
		for i in base.size():
			_check(absf(bent[i].x-base[i].x)<=2.4001 and bent[i].y==base[i].y,"bounded horizontal motion")
			if i%18>=12: _check(bent[i]==base[i],"root row and below-root pixels stay fixed")
	_check(arrays[Mesh.ARRAY_VERTEX]==base,"deformation does not modify immutable input vertices")
	for method in ["none","cpu","items","batch"]:
		var field:=Field.new(); game.add_child(field); field.configure(game,method,positions.slice(0,256))
		var expected:=0 if method=="none" else (256 if method=="items" else 4)
		_check(field.get_child_count()==expected,"actual CanvasItem structure "+method)
		var builds:int=field.mesh_builds
		field.set_time(1.25); field.controlled=false; field._process(0.25)
		_check(absf(field.wind_time-1.5)<0.00001,"visual clock advances "+method)
		game.MenuSystem.open_pause(game); var time:float=field.wind_time; var updates:int=field.vertex_updates
		field._process(0.5)
		_check(field.wind_time==time and field.vertex_updates==updates,"manual pause stops clock and uploads "+method)
		game.MenuSystem.resume(game); game.BuildingSystem.enter(game,"cottage"); field._process(0.5)
		_check(not field.visible and field.wind_time==time,"interior hides layer and freezes clock "+method)
		game.BuildingSystem.leave(game); field._process(0.25)
		_check(field.visible and field.mesh_builds==builds,"return reuses existing meshes "+method)
		_check(field.show_behind_parent,"ground layer cannot cover parent HUD "+method)
		field.queue_free(); await process_frame
	print("GRASS REVIEW: ",passed," passed, ",failed," failed; headless is not native/FPS acceptance")
	quit(0 if failed==0 else 1)

## Каждый отказ сохраняет конкретную инварианту вместо молчаливого усечения проверки.
func _check(condition: bool, label: String) -> void:
	if condition: passed+=1
	else: failed+=1; print("FAIL: ",label)

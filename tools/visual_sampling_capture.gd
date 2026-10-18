extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
const Dial := preload("res://scripts/systems/celestial_dial_assets_system.gd")
const Prepared := preload("res://scripts/presentation/prepared_item_icon_system.gd")
const Interior := preload("res://scripts/systems/interior_visual_system.gd")
var output := OS.get_environment("VSAMPLING_OUTPUT")
var faults: Array = []
var game: Node
var gallery: Gallery
var frames: Array = []

## Запрещает перезапись доказательства и использование обычного профиля игрока.
func _initialize() -> void:
	var profile := OS.get_environment("VSAMPLING_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-003-") or "/" in profile or "\\" in profile:
		push_error("Нужны новые output и профиль VPIPELINE-003"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает комнату и адресную матрицу при двух общих фильтрах без изменения игровых источников.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны графический движок и свежий профиль"); quit(2); return
	var point: Dictionary
	for candidate in Points.registry().points:
		if candidate.location=="cottage_interior": point=candidate; break
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	game=Points.create_game(); root.add_child(game); current_scene=game; Points.configure(game,point); Reference.enable(game,true)
	faults.append_array(game.ContentRegistry.validate())
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE
	DirAccess.make_dir_recursive_absolute(output)
	for inherited in [0,1]:
		root.canvas_item_default_texture_filter=inherited
		await _redraw(); _save("room-default-"+str(inherited),{"kind":"room","default_filter":inherited})
	game.hide(); gallery=Gallery.new(); root.add_child(gallery); Sampling.preserve_legacy(gallery)
	for inherited in [0,1]:
		root.canvas_item_default_texture_filter=inherited
		for scale in [0.75,1.0,1.2]:
			gallery.zoom=scale
			for family in ["legacy_world","painted_world"]:
				gallery.select(family)
				var name := "samples-%d-%s-%s"%[inherited,str(scale).replace(".","_"),family]
				await _redraw(); _save(name,{"kind":"samples","default_filter":inherited,"scale":scale,"family":family})
	var data := Points.snapshot(game,point)
	faults.append_array(Points.errors(game,point))
	data.merge({"engine":Engine.get_version_info().string,"profile":OS.get_user_data_dir().get_file(),"framebuffer":[1152,648],"frames":frames,"errors":faults,"performance_eligible":false})
	var table := Interior.destination_rect("rustic_table",Vector2(708,456))
	table.position-=game.camera_offset
	data.changed_region=[table.position.x,table.position.y,table.end.x,table.end.y]
	data.scene_policy={"legacy_canvas":game.texture_filter,"table":Resources.sampled_texture("prop.rustic_table").texture_filter,"clock":Dial.texture("frame").texture_filter}
	data.application_version=ProjectSettings.get_setting("application/config/version")
	data.implementation_sha256={}
	for path in ["assets/game/visual_sampling.json","assets/game/visual_resources.json","scripts/presentation/visual_sampling_system.gd","scripts/systems/visual_resource_catalog.gd","scripts/presentation/house_furniture_visual_system.gd","scripts/systems/celestial_dial_assets_system.gd","scripts/core/game_bootstrap.gd","scripts/systems/level_editor_renderer.gd","tools/visual_sampling_capture.gd"]:
		data.implementation_sha256[path]=FileAccess.get_sha256("res://"+path)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("SAMPLING CAPTURE: ",output); quit(0 if faults.is_empty() else 2)

## Дожидается настоящего readback даже при перекрытом окне, не подменяя его размером viewport.
func _redraw() -> void:
	for index in 20:
		game.queue_redraw(); if gallery!=null: gallery.queue_redraw()
		await process_frame; RenderingServer.force_draw(false)

## Сохраняет целый нативный кадр и параметры выборки без обрезки или постобработки.
func _save(name: String, row: Dictionary) -> void:
	var image := root.get_texture().get_image()
	if image.get_size()!=Points.SIZE or image.save_png(output.path_join(name+".png"))!=OK: faults.append("Invalid native frame: "+name)
	row.file=name+".png"; frames.append(row)

class Gallery extends Node2D:
	var zoom := 1.0
	var selected: Array = []
	var candidate_clock: Texture2D
	var protected_bread: Texture2D
	var wrappers: Dictionary = {}
	const FONT := preload("res://assets/game/fonts/ui_font.tres")

	## Готовит шесть адресных обёрток один раз, а не во время рисования каждого кадра.
	func select(family: String) -> void:
		if protected_bread==null: protected_bread=Prepared.Padded.frame("bread",64)
		if not wrappers.has(family):
			var row: Array = []
			for side in ["south","west","east"]: row.append(Sampling.create(Resources.texture("prop.rustic_table",side),family))
			row.append(Sampling.create(Dial.texture("frame").diffuse_texture,family))
			wrappers[family]=row
		selected=wrappers[family]; candidate_clock=selected[3]

	## Сравнивает тот же исходник в мировом размере и увеличенном инспекторе; нижние контрольные элементы неизменны.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("eee3c5"))
		draw_string(FONT,Vector2(28,42),"VPIPELINE-003 · адресная фильтрация",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("493721"))
		for index in 3:
			var view := Resources.describe("prop.rustic_table",["south","west","east"][index])
			var x := 210.25+index*360
			draw_string(FONT,Vector2(x-65,85),["Вниз","Влево","Вправо"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("493721"))
			for row in 2:
				var position := Vector2(x,210.5+row*215)
				var bounds: Vector2 = view.logical_size*zoom*(1.0 if row==0 else 2.0)
				draw_texture_rect_region(selected[index],Resources.destination(view,position,bounds),view.source)
		draw_rect(Rect2(24,480,700,144),Color("253b32"))
		draw_string(FONT,Vector2(175,525),"Шрифт и атлас: без размытия",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("f6ecd3"))
		draw_string(FONT,Vector2(175,563),"Аа 012345 · размер 16",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f6ecd3"))
		draw_texture_rect(protected_bread,Rect2(60,520,64,64),false)
		draw_texture_rect(candidate_clock,Rect2(795.25,495.5,128,128),false)
		draw_texture_rect(Dial.texture("frame"),Rect2(1030.25,520.5,64,64),false)

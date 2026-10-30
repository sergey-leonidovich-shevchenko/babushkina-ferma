extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vshore-001/"
const Canvas := preload("res://tools/qa/world/shore_kit_canvas.gd")
var output := ""
var profile := ""
var sources: Dictionary={}

## Требует новый каталог, нативную графику и отдельные пользовательские данные.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VSHORE-001-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль VSHORE-001"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Подписывает действительные источники без подмены художественного решения текущей версией игры.
func _source(path: String) -> void:
	sources[path]=FileAccess.get_sha256(path)

## Нарезает точные регионы и удерживает готовые текстуры вне отрисовки.
func _prepare(canvas: Canvas) -> Dictionary:
	var masters: Dictionary={}
	var exports: Array=[]
	var decoded_bytes:=0
	for p: Dictionary in canvas.data.parts:
		var source: String=REPORT+p.source
		if not masters.has(source): masters[source]=Image.load_from_file(source); _source(source)
		var r: Array=p.rect
		var image: Image=masters[source].get_region(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))
		var file: String="sprites/"+p.id+".png"
		image.save_png(output.path_join(file))
		if image.generate_mipmaps()!=OK: push_error("Не удалось создать mipmaps"); return {}
		decoded_bytes+=image.get_data_size()
		canvas.textures[p.id]=ImageTexture.create_from_image(image)
		canvas.parts[p.id]=p
		exports.append({"id":p.id,"file":file,"sha256":FileAccess.get_sha256(output.path_join(file)),"rect":r,"size":[image.get_width(),image.get_height()]})
	var hero_source: String=REPORT+canvas.data.hero.source
	canvas.hero=ImageTexture.create_from_image(Image.load_from_file(hero_source)); _source(hero_source)
	return {"exports":exports,"decoded_image_bytes_with_mips":decoded_bytes}

## Снимает стабильные листы и отдельное движение камеры без игрового времени и слотов.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):
		push_error("Нужен нативный дисплей"); quit(2); return
	DirAccess.make_dir_recursive_absolute(output.path_join("sprites"))
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	var canvas:=Canvas.new()
	canvas.data=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"profile.json"))
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for path in [REPORT+"profile.json",REPORT+"source.json","res://tools/qa/world/shore_kit_canvas.gd","res://tools/qa/world/shore_kit_capture.gd","res://scripts/systems/water_topology.gd","res://scripts/systems/water_layout_data.gd","res://scripts/systems/water_map_registry.gd"]: _source(path)
	var prepared:=_prepare(canvas)
	if prepared.is_empty(): quit(2); return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1152,648)
	viewport.size_2d_override=Vector2i(960,540)
	viewport.size_2d_override_stretch=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport); viewport.add_child(canvas)
	root.title="VSHORE-001 · низкий берег · отдельная витрина"
	root.size=Vector2i(1152,648); root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var preview:=TextureRect.new(); preview.texture=viewport.get_texture(); preview.size=Vector2(1152,648); root.add_child(preview)
	var frames: Array=[]
	for page: String in ["stone","reuse"]:
		for background: String in ["light","dark","grass"]:
			canvas.page=page
			canvas.background=Color({"light":"f4efdf","dark":"252e36","grass":"6f8651"}[background])
			if not await _frame(viewport,canvas,page+"-"+background,frames): return
	canvas.page="scene"
	canvas.wide_bridge=false
	if not await _frame(viewport,canvas,"scene-narrow",frames): return
	canvas.wide_bridge=true
	for candidate: bool in [false,true]:
		canvas.candidate=candidate
		if not await _frame(viewport,canvas,"scene-"+("stone" if candidate else "earth"),frames): return
	canvas.on_bridge=true
	if not await _frame(viewport,canvas,"scene-bridge",frames): return
	canvas.show_grid=true
	if not await _frame(viewport,canvas,"scene-grid",frames): return
	canvas.on_bridge=false; canvas.show_grid=false
	var motion: Array=[]
	for index in 120:
		canvas.camera=Vector2(index*.5,index*.125)
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
		var image:=viewport.get_texture().get_image()
		var name: String="frames/%04d.png"%index
		image.save_png(output.path_join(name))
		if index in [0,60,119]: image.save_png(output.path_join("motion-%03d.png"%index))
		var transform_value:=viewport.get_stretch_transform()*Transform2D(0,-canvas.camera)
		var foot: Vector2=transform_value*Vector2(420,336)
		motion.append({"frame":index,"camera":[canvas.camera.x,canvas.camera.y],"foot_pixel":[foot.x,foot.y],"file":name,"sha256":FileAccess.get_sha256(output.path_join(name))})
	var proof:={"schema":1,"kind":"native-shore-art-study","native_gameplay":false,"runtime_integration":false,"performance_eligible":false,"fixed_clock_video":true,"profile":profile,"base_commit":canvas.data.base_commit,
		"target":[1152,648],"field":[960,540],"zoom":1.2,"grid":24,"camera_static":[0,0],"sources":sources,"frames":frames,"motion":motion,"fps":30,
		"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"texture_loads_inside_draw":0,"texture_filter":"linear_with_mipmaps","material_repeat":"reference mirrored study material; seamless production joins remain open"}
	proof.merge(prepared)
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(proof,"\t")+"\n")
	print("SHORE CAPTURE: 29 exact exports, 11 static frames and 120 native camera frames; not FPS")
	quit(0)

## Сверяет настоящий framebuffer и повторный readback одной неподвижной сцены.
func _frame(viewport: SubViewport, canvas: Canvas, id: String, frames: Array) -> bool:
	canvas.queue_redraw()
	for tick in 3: await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image()
	await RenderingServer.frame_post_draw
	if image.get_size()!=Vector2i(1152,648) or image.get_data()!=viewport.get_texture().get_image().get_data():
		push_error("Размер или повторный readback различаются"); quit(2); return false
	var file:=id+".png"; image.save_png(output.path_join(file))
	frames.append({"id":id,"file":file,"sha256":FileAccess.get_sha256(output.path_join(file)),"repeat_equal":true})
	return true

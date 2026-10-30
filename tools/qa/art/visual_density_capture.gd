extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vart-006/"
const SIZE := Vector2i(1152,648)
var folder := ""
var profile := ""

class DensityCanvas extends Node2D:

	var data: Dictionary
	var textures: Dictionary
	var variant := "a"
	var pairs := false

	## Рисует самостоятельные области с одной плотностью и опорой для A/B; герой всегда из A.
	func _draw() -> void:
		if pairs:
			draw_string(ThemeDB.fallback_font,Vector2(210,28),"A",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f5f0dc"))
			draw_string(ThemeDB.fallback_font,Vector2(690,28),"B",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f5f0dc"))
		var row:=0
		for part: Dictionary in data.parts:
			if pairs:
				var ground: float=[135,295,530,645,760][row]
				_part(part,"a",Vector2(240,ground)); _part(part,"b",Vector2(720,ground)); row+=1
			else: _part(part,variant,Vector2(float(part.feet[0]),float(part.feet[1])))

	## Использует ту же нарезку и коэффициент в сцене и парном листе.
	func _part(part: Dictionary, side: String, feet: Vector2) -> void:
		if part.source_policy=="a_only": side="a"
		var r: Array=part.source_rect
		var atlas:=AtlasTexture.new()
		atlas.atlas=textures[side]; atlas.region=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3])); atlas.filter_clip=true
		var size:=Vector2(float(r[2]),float(r[3]))*float(part.world_scale)
		draw_texture_rect(atlas,Rect2(feet-Vector2(size.x*0.5,size.y),size),false)

## Требует новый каталог и отдельный профиль; игровые сцены и сохранения не загружаются.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not profile.begins_with("Codex-VART-006-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный profile Codex-VART-006-*"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает шесть настоящих GPU-readback; браузерный zoom на их размеры не влияет.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):
		push_error("Нужны графический renderer и отдельный профиль"); quit(2); return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"density-profile.json"))
	var viewport:=SubViewport.new()
	viewport.size=SIZE; viewport.size_2d_override=Vector2i(960,540); viewport.size_2d_override_stretch=true
	viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background:=ColorRect.new(); background.size=Vector2(960,540); viewport.add_child(background)
	var canvas:=DensityCanvas.new(); canvas.data=data; canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var sources: Dictionary={}
	for side: String in ["a","b"]:
		var path: String=REPORT+String(data.variants[side].master)
		var image:=Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(1536,1024): push_error("Неверный мастер"); quit(2); return
		if image.generate_mipmaps()!=OK: push_error("Не удалось подготовить уменьшение"); quit(2); return
		canvas.textures[side]=ImageTexture.create_from_image(image); sources[side]=FileAccess.get_sha256(path)
	viewport.add_child(canvas)
	root.title="VART-006 · статичный лист фактуры"
	root.mode=Window.MODE_WINDOWED; root.size=SIZE
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var display:=TextureRect.new(); display.texture=viewport.get_texture(); display.size=Vector2(SIZE); root.add_child(display)
	DirAccess.make_dir_recursive_absolute(folder)
	var frames: Array=[]
	for side: String in ["a","b"]:
		for backdrop: String in ["light","dark","grass"]:
			canvas.variant=side; background.color=Color(String(data.backgrounds[backdrop].color)); canvas.queue_redraw()
			for tick in 3: await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			await RenderingServer.frame_post_draw
			var repeated:=viewport.get_texture().get_image()
			var name: String=side+"-"+backdrop+".png"
			if image.get_size()!=SIZE or image.get_data()!=repeated.get_data() or image.save_png(folder.path_join(name))!=OK:
				push_error("Неверный readback/повтор: "+name); quit(2); return
			var matrix:=viewport.get_stretch_transform()
			if matrix.get_scale().distance_to(Vector2.ONE*1.2)>0.00001: push_error("Неверная проекция"); quit(2); return
			frames.append({"variant":side,"background":backdrop,"file":name,"size":[image.get_width(),image.get_height()],
				"projection":[[matrix.x.x,matrix.x.y],[matrix.y.x,matrix.y.y],[matrix.origin.x,matrix.origin.y]],
				"repeat_equal":true,"sha256":FileAccess.get_sha256(folder.path_join(name))})
	viewport.size=Vector2i(1152,960); viewport.size_2d_override=Vector2i(960,800)
	background.size=Vector2(960,800); background.color=Color(String(data.backgrounds.grass.color)); canvas.pairs=true; canvas.queue_redraw()
	for tick in 3: await RenderingServer.frame_post_draw
	var board:=viewport.get_texture().get_image()
	await RenderingServer.frame_post_draw
	if board.get_size()!=Vector2i(1152,960) or board.get_data()!=viewport.get_texture().get_image().get_data() or board.save_png(folder.path_join("pairs.png"))!=OK:
		push_error("Неверный парный лист"); quit(2); return
	var result:={"schema":1,"task":"VART-006","kind":"native-density-study","native_gameplay":false,"performance_eligible":false,
		"capture_script_sha256":FileAccess.get_sha256("res://tools/qa/art/visual_density_capture.gd"),
		"profile":profile,"source_sha256":sources,"profile_sha256":FileAccess.get_sha256(REPORT+"density-profile.json"),
		"field":[960,540],"target":[1152,648],"texture_filter":"linear_with_mipmaps","mipmaps":"generated_once_in_memory; original PNG unchanged","hero_source":"a",
		"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),
		"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"frames":frames,
		"comparison_board":{"file":"pairs.png","size":[1152,960],"field":[960,800],"repeat_equal":true,"sha256":FileAccess.get_sha256(folder.path_join("pairs.png"))}}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("DENSITY CAPTURE: 6 GPU images 1152x648, repeat equal, field 960x540; not gameplay/FPS")
	quit(0)

extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vart-007/"
var folder := ""
var profile := ""

class LightCanvas extends Node2D:
	var data: Dictionary
	var cuts: Dictionary={}
	var side := "a"
	var layer := "combined"

	## Показывает отдельные компоненты; падающие тени рисуются раньше контакта и самого предмета.
	func _draw() -> void:
		if layer in ["combined","cast"]:
			for part: Dictionary in data.parts:
				if part.cast: _cast(part)
		if layer in ["combined","contact"]:
			for part: Dictionary in data.parts: _contact(part)
		if layer in ["combined","form"]:
			for part: Dictionary in data.parts:
				draw_set_transform(Vector2(float(part.feet[0]),float(part.feet[1])))
				draw_texture_rect(cuts[side+part.id],_rect(part),false)
		draw_set_transform(Vector2.ZERO)

	## Опора измеряется внутри source rect, а не по нижней границе прозрачного холста.
	func _rect(part: Dictionary) -> Rect2:
		var k: float=part.scale
		return Rect2(-Vector2(float(part.pivot[0]),float(part.pivot[1]))*k,Vector2(float(part.rect[2]),float(part.rect[3]))*k)

	## Художественная alpha-проекция на землю; не 3D-освещение и не shadow map.
	func _cast(part: Dictionary) -> void:
		var direction: Array=data.variants[side].cast
		var feet:=Vector2(float(part.feet[0]),float(part.feet[1]))
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				var origin:=feet+Vector2(dx,dy)*float(data.penumbra_world)
				draw_set_transform_matrix(Transform2D(Vector2.RIGHT,Vector2(-float(direction[0]),-float(direction[1])),origin))
				draw_texture_rect(cuts[side+part.id],_rect(part),false,Color(0,0,0,float(data.cast_opacity)/9.0))
		draw_set_transform(Vector2.ZERO)

	## Мягкое основание; у стола два пятна точно под ножками.
	func _contact(part: Dictionary) -> void:
		var feet:=Vector2(float(part.feet[0]),float(part.feet[1]))
		for ellipse: Array in part.contact:
			draw_set_transform(feet+Vector2(float(ellipse[0]),float(ellipse[1])),0,Vector2(float(ellipse[2]),float(ellipse[3])))
			for ring in range(7,0,-1):draw_circle(Vector2.ZERO,float(ring)/7.0,Color(0,0,0,0.032))
		draw_set_transform(Vector2.ZERO)

## Отказывается перезаписывать вывод и не использует игровые слоты.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
	if folder.is_empty() or DirAccess.dir_exists_absolute(folder) or not profile.begins_with("Codex-VART-007-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль VART-007");quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сохраняет 24 GPU-readback: два направления, три фона, четыре набора слоёв.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):push_error("Нужна нативная графика");quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"light-profile.json"))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.size_2d_override=Vector2i(960,540);viewport.size_2d_override_stretch=true
	viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var bg:=ColorRect.new();bg.size=Vector2(960,540);viewport.add_child(bg)
	var canvas:=LightCanvas.new();canvas.data=data;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var sources: Dictionary={};var textures: Dictionary={}
	for side: String in ["a","b"]:
		for part: Dictionary in data.parts:
			var path: String=REPORT+String(data.variants[side].master if part.source=="variant" else part.source)
			if not textures.has(path):
				var image:=Image.load_from_file(path)
				if image==null or image.generate_mipmaps()!=OK:push_error("Неверный источник");quit(2);return
				textures[path]=ImageTexture.create_from_image(image);sources[path.trim_prefix(REPORT)]=FileAccess.get_sha256(path)
			var atlas:=AtlasTexture.new();atlas.atlas=textures[path];atlas.filter_clip=true
			atlas.region=Rect2(float(part.rect[0]),float(part.rect[1]),float(part.rect[2]),float(part.rect[3]));canvas.cuts[side+part.id]=atlas
	viewport.add_child(canvas);root.title="VART-007 · свет и три компонента";root.size=Vector2i(1152,648);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.size=Vector2(1152,648);root.add_child(preview)
	DirAccess.make_dir_recursive_absolute(folder);var frames: Array=[]
	for side: String in ["a","b"]:
		for backdrop: String in ["light","dark","grass"]:
			for layer: String in data.layers:
				canvas.side=side;canvas.layer=layer;bg.color=Color(String(data.backgrounds[backdrop]));canvas.queue_redraw()
				for tick in 3:await RenderingServer.frame_post_draw
				var image:=viewport.get_texture().get_image();await RenderingServer.frame_post_draw
				var name: String=side+"-"+backdrop+"-"+layer+".png"
				if image.get_size()!=Vector2i(1152,648) or image.get_data()!=viewport.get_texture().get_image().get_data() or image.save_png(folder.path_join(name))!=OK:push_error("Readback/повтор");quit(2);return
				frames.append({"variant":side,"background":backdrop,"layer":layer,"file":name,"sha256":FileAccess.get_sha256(folder.path_join(name)),"size":[1152,648],"repeat_equal":true})
	var matrix:=viewport.get_stretch_transform()
	var proof:={"schema":1,"kind":"native-light-study","native_gameplay":false,"performance_eligible":false,"field":[960,540],"target":[1152,648],"profile":profile,
		"profile_sha256":FileAccess.get_sha256(REPORT+"light-profile.json"),"script_sha256":FileAccess.get_sha256("res://tools/visual_light_capture.gd"),"sources":sources,
		"projection":[[matrix.x.x,matrix.x.y],[matrix.y.x,matrix.y.y],[matrix.origin.x,matrix.origin.y]],"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),
		"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"frames":frames,"shadow_model":"separate soft affine alpha projection; not 3D or runtime cost","texture_filter":"linear_with_mipmaps"}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(proof,"\t")+"\n");print("LIGHT CAPTURE: 24 frames 1152x648, separate form/contact/cast, repeat equal");quit(0)

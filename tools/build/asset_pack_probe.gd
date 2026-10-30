extends SceneTree

const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
var output:=OS.get_environment("VASSET_OUTPUT")
var textures:Dictionary={}
var errors:Array=[]
var viewport:SubViewport
var gallery:Gallery

## Разрешает только отдельный проект, новый каталог результата и отдельный профиль без игровых слотов.
func _initialize() -> void:
	var profile:=OS.get_environment("VASSET_PROFILE")
	if ProjectSettings.get_setting("application/config/name")!="VPIPELINE-010 export fixture" or output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-010-") or "/" in profile or "\\" in profile:quit(2);return
	if OS.get_environment("VASSET_PACK")=="1" and FileAccess.file_exists(ProjectSettings.globalize_path("res://")+"project.godot"):quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Читает настоящие импортированные пиксели последовательно, не выдавая суммарный потенциал за живую память.
func _start() -> void:
	var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("VASSET_INPUT")))
	var visible:Array=[]
	for path in input.paths:
		var texture:=load("res://"+path) as Texture2D
		if texture==null:errors.append("missing texture: "+path);continue
		var image:=texture.get_image()
		if image.is_compressed():image.decompress()
		var format:=image.get_format();var mipmaps:=image.has_mipmaps();var image_bytes:=image.get_data().size()
		image.convert(Image.FORMAT_RGBA8)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
		textures[path]={"pixels":[texture.get_width(),texture.get_height()],"class":texture.get_class(),"image_format":format,"mipmaps":mipmaps,"image_bytes":image_bytes,"nominal_rgba8_bytes":image.get_data().size(),"rgba_sha256":hash.finish().hex_encode()}
	for path in input.sentinels:
		if FileAccess.file_exists("res://"+path) or ResourceLoader.exists("res://"+path):visible.append(path)
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name()!="headless":
		viewport=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(viewport);gallery=Gallery.new();viewport.add_child(gallery)
		for background in ["dark","light"]:
			gallery.light=background=="light";gallery.queue_redraw()
			for frame in 8:await process_frame;RenderingServer.force_draw(false)
			var image:=viewport.get_texture().get_image()
			if image.get_size()!=Vector2i(1152,648) or image.save_png(output.path_join(background+".png"))!=OK:errors.append("invalid framebuffer")
	var capture:={"textures":textures,"visible_sentinels":visible,"errors":errors,"framebuffer":[1152,648],"camera":{"position":[0,0],"zoom":1,"framebuffer":[1152,648]},"display_server":DisplayServer.get_name(),"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"engine":Engine.get_version_info().string,"profile":OS.get_user_data_dir().get_file(),"performance_eligible":false,"probe_sha256":FileAccess.get_sha256(OS.get_environment("VASSET_PROBE"))}
	capture.resource_root=ProjectSettings.globalize_path("res://");capture.physical_project_present=FileAccess.file_exists(capture.resource_root+"project.godot")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(capture,"\t")+"\n")
	if viewport!=null:viewport.free()
	print("ASSET PACK PROBE: ",textures.size()," textures; errors=",errors)
	quit(0 if errors.is_empty() else 2)

class Gallery extends Node2D:
	var light:=false
	## Рисует один и тот же реальный ресурс через production-каталог при фиксированной камере.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("efe5ca") if light else Color("1b2529"))
		for index in 3:
			var side:String=["south","west","east"][index]
			var view:Dictionary=Resources.describe("prop.rustic_table",side)
			var point:=Vector2(192+index*384,440);var size:Vector2=Vector2(view.logical_size)*3
			draw_texture_rect_region(Resources.sampled_texture(view.id,side),Resources.destination(view,point,size),view.source)
			draw_string(ThemeDB.fallback_font,point+Vector2(-120,40),side,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("443728") if light else Color("efe5c9"))

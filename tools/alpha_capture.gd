extends SceneTree

const FONT := preload("res://assets/game/fonts/ui_font.tres")
const BACKGROUNDS := {"light":"f1ead8","dark":"19232b","green":"61764b","purple":"745576"}
var output := OS.get_environment("VALPHA_OUTPUT")
var fixture := OS.get_environment("VALPHA_FIXTURES")
var gallery: Gallery

## Требует свежие диагностические папки и отдельный профиль без доступа к игровому слоту.
func _initialize() -> void:
	var profile := OS.get_environment("VALPHA_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or ProjectSettings.localize_path(output).begins_with("res://assets/") or fixture.is_empty() or not profile.begins_with("Codex-VPIPELINE-007-") or "/" in profile or "\\" in profile:quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	capture.call_deferred()

## Снимает неизменные источники и контрольные повреждения на четырёх фонах одним настоящим renderer.
func capture() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1.0
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1152,648)
	DirAccess.make_dir_recursive_absolute(output)
	gallery=Gallery.new();gallery.prepare(fixture);root.add_child(gallery)
	var data := {"engine":Engine.get_version_info().string,"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"profile":OS.get_user_data_dir().get_file(),"framebuffer":[1152,648],"performance_eligible":false,"frames":{},"sources":gallery.sources,"backgrounds":BACKGROUNDS,"source_sha256":FileAccess.get_sha256("res://tools/alpha_capture.gd")}
	for page in ["controls","sources"]:
		gallery.page=page
		for background in BACKGROUNDS:
			gallery.background=background
			for frame in 12:gallery.queue_redraw();await process_frame;RenderingServer.force_draw(false)
			var name: String=page+"-"+background;var image := root.get_texture().get_image()
			if image.get_size()!=Vector2i(1152,648) or image.save_png(output+"/"+name+".png")!=OK:quit(3);return
			data.frames[name]=FileAccess.get_sha256(output+"/"+name+".png")
	FileAccess.open(output+"/capture.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
	print("ALPHA CAPTURE: ",output);quit()

class Gallery extends Node2D:
	var page := "controls"
	var background := "light"
	var controls: Array=[]
	var sources: Array=[]
	var textures: Dictionary={}

	## Подготавливает диагностические числовые изображения и настоящие источники без изменения их пикселей.
	func prepare(folder: String) -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		for entry in JSON.parse_string(FileAccess.get_file_as_string(folder+"/fixtures.json")):
			controls.append(entry.id);textures[entry.id]=ImageTexture.create_from_image(Image.load_from_file(folder+"/"+entry.file))
		for row in [
			["milk-preview","res://assets/game/items/ui/preview/milk.png","Live prepared preview"],
			["clean-well","res://assets/game/locations/overworld/modular/prop_well_v1.png","Current standalone source"],
			["clean-cart","res://assets/game/locations/overworld/modular/prop_cart_v1.png","Current standalone source"],
			["legacy-props","res://assets/game/environment/village_prop_atlas_v2.png","Raw atlas; runtime may preprocess"]]:
			var texture: Texture2D=load(row[1]);textures[row[0]]=texture
			sources.append({"id":row[0],"path":row[1],"sha256":FileAccess.get_sha256(row[1]),"pixels":[texture.get_width(),texture.get_height()],"source_rect":[0,0,texture.get_width(),texture.get_height()/2 if row[0]=="legacy-props" else texture.get_height()],"note":row[2]})

	## Рисует ту же композицию и прозрачность на другом фоне; белые элементы остаются частью предмета.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color(BACKGROUNDS[background]))
		draw_string(FONT,Vector2(30,36),"VPIPELINE-007 / "+page+" / "+background,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("10202b") if background=="light" else Color("fff3d6"))
		if page=="controls":
			for index in controls.size():
				var x := 35+(index%4)*280;var y := 100+(index/4)*260
				var id: String=controls[index]
				draw_texture_rect(textures[id],Rect2(x+32,y,192,192),false)
				draw_string(FONT,Vector2(x,y+220),id,HORIZONTAL_ALIGNMENT_LEFT,265,15,Color("10202b") if background=="light" else Color("fff3d6"))
		else:
			for index in 3:
				var row: Dictionary=sources[index];var texture: Texture2D=textures[row.id]
				var size: Vector2=texture.get_size();size*=minf(220/size.x,235/size.y)
				draw_texture_rect(texture,Rect2(Vector2(100+index*350,80)+(Vector2(220,235)-size)/2,size),false)
				draw_string(FONT,Vector2(90+index*350,340),row.id,HORIZONTAL_ALIGNMENT_LEFT,300,17,Color("10202b") if background=="light" else Color("fff3d6"))
			var atlas: Texture2D=textures["legacy-props"]
			draw_texture_rect_region(atlas,Rect2(96,392,960,240),Rect2(0,0,atlas.get_width(),atlas.get_height()/2.0))

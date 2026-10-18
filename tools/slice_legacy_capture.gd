extends SceneTree

const Assets:=preload("res://scripts/systems/visual_asset_system.gd")
const FONT:=preload("res://assets/game/fonts/ui_font.tres")
const BEFORE:=preload("res://docs/reports/visual-overhaul/vpipeline-008/inventory.json")
var output:=OS.get_environment("VSLICE_OUTPUT").trim_suffix("/")+"/"
var viewport:SubViewport
var gallery:Gallery

## Показывает сохранённые старые координаты и нынешний API в одном фиксированном GPU-viewport.
func _initialize() -> void:
	var profile:=OS.get_environment("VSLICE_PROFILE")
	if DisplayServer.get_name()=="headless" or output=="/" or DirAccess.dir_exists_absolute(output) or ProjectSettings.localize_path(output).begins_with("res://assets/") or not profile.begins_with("Codex-VPIPELINE-008-") or "/" in profile or "\\" in profile:quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	capture.call_deferred()

## Сравнивает только старые fallback-ресурсы, не выдавая их за выбранную графику обычного интерфейса.
func capture() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	gallery=Gallery.new();gallery.prepare();viewport.add_child(gallery)
	DirAccess.make_dir_recursive_absolute(output)
	var data:={"engine":Engine.get_version_info().string,"method":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"target":"fixed_gpu_subviewport","framebuffer":[1152,648],"profile":OS.get_user_data_dir().get_file(),"source_sha256":FileAccess.get_sha256("res://tools/slice_legacy_capture.gd"),"performance_eligible":false,"replay":"Recorded pre-change regions versus current API; not a previous game executable","frames":{},"pairs":gallery.metadata}
	for page in ["pirate","potion"]:
		gallery.page=page
		for background in ["dark","light"]:
			gallery.background=background
			for index in 12:gallery.queue_redraw();await process_frame;RenderingServer.force_draw(false)
			var name:String=page+"-"+background;var image:=viewport.get_texture().get_image()
			if image.get_size()!=Vector2i(1152,648) or image.save_png(output+"/"+name+".png")!=OK:viewport.free();quit(3);return
			data.frames[name]=FileAccess.get_sha256(output+"/"+name+".png")
	FileAccess.open(output+"capture.json",FileAccess.WRITE).store_string(JSON.stringify(data,"  ")+"\n")
	viewport.free();print("LEGACY SLICE CAPTURE: ",output);quit()

class Gallery extends Node2D:
	var page:="pirate"
	var background:="dark"
	var pairs:Array=[]
	var metadata:Array=[]

	## Получает исходную нарезку из фактического снимка до правки, новую — из действующих методов.
	func prepare() -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		for kind in Assets.PIRATE_ENEMY_ORDER:add("legacy/pirate_enemy/"+kind,"pirate",Assets.PIRATE_ENEMY_ATLAS,Assets.pirate_enemy_source(kind))
		for kind in Assets.PIRATE_ITEM_CELLS:add("legacy/icon/pirate/"+kind,"pirate",Assets.PIRATE_ITEM_ATLAS,Assets.safe_atlas_source(Assets.pirate_item_source(kind),12))
		for kind in Assets.POTION_CELLS:add("legacy/icon/potion/"+kind,"potion",Assets.POTION_ATLAS,Assets.safe_atlas_source(Assets.potion_source(kind),12))

	## Сохраняет точные координаты пары и неизменность исходного PNG для адресного review.
	func add(id:String,group:String,texture:Texture2D,source:Rect2) -> void:
		var old:Array=BEFORE.data.frames[id].rect
		var old_rect:=Rect2(old[0],old[1],old[2],old[3])
		pairs.append({"id":id,"group":group,"texture":texture,"before":old_rect,"after":source})
		metadata.append({"id":id,"group":group,"path":texture.resource_path,"sha256":FileAccess.get_sha256(texture.resource_path),"before":old,"after":[source.position.x,source.position.y,source.size.x,source.size.y]})

	## Рисует каждую пару с одним коэффициентом; слева старая область, справа целочисленная.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("19232b") if background=="dark" else Color("f1ead8"))
		var ink:=Color("fff3d6") if background=="dark" else Color("253137")
		draw_string(FONT,Vector2(24,28),"VPIPELINE-008 / legacy "+page+" / left=recorded, right=current",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
		var index:=0
		for pair in pairs:
			if pair.group!=page:continue
			var origin:=Vector2((index%4)*288,(index/4)*198+46);index+=1
			var factor:=minf(110.0/maxf(pair.before.size.x,pair.after.size.x),142.0/maxf(pair.before.size.y,pair.after.size.y))
			for phase in ["before","after"]:
				var source:Rect2=pair[phase];var size:Vector2=source.size*factor
				var position:=origin+Vector2(72 if phase=="before" else 210,142)-Vector2(size.x*0.5,size.y)
				draw_texture_rect_region(pair.texture,Rect2(position,size),source)
				draw_rect(Rect2(position,size).grow(1),Color("bc9d6f") if phase=="before" else Color("7faf82"),false,1)
			draw_string(FONT,origin+Vector2(4,164),String(pair.id).get_file(),HORIZONTAL_ALIGNMENT_LEFT,280,13,ink)

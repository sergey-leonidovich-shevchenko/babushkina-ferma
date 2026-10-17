extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vart-010/"
const Visual := preload("res://scripts/systems/visual_asset_system.gd")
var output := ""
var profile := ""

class IconCanvas extends Node2D:
	var study: Dictionary
	var textures: Dictionary
	var scene: Texture2D
	var background := "light"
	var variant := "a"
	var item := ""

	## Показывает готовые экранные размеры без увеличения интерфейса мировой камерой.
	func _draw() -> void:
		var ink:=Color("4a382e") if background=="light" else Color("fff3d8")
		draw_rect(Rect2(0,0,1152,648),Color("f4efdf") if background=="light" else Color("252e36"))
		if background=="game":
			draw_texture(scene,Vector2.ZERO)
			draw_rect(Rect2(0,0,1152,648),Color(0,0,0,.38))
		var title: String="VART-010 · "+study.variants[variant] if item.is_empty() else "VART-010 · "+_name(item)+" · сейчас / A / B"
		draw_string(ThemeDB.fallback_font,Vector2(30,36),title,HORIZONTAL_ALIGNMENT_LEFT,-1,23,ink)
		draw_string(ThemeDB.fallback_font,Vector2(30,68),"64 px — ячейка с количеством       160 px — превью       UI 1.0",HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
		if item.is_empty():
			for i in study.items.size():
				var id: String=study.items[i].id;var x: float=96+i*192
				_icon(variant+"-"+id,64,Vector2(x-32,112),ink,true)
				_icon(variant+"-"+id,160,Vector2(x-80,240),ink,false)
				draw_string(ThemeDB.fallback_font,Vector2(x-85,450),_name(id),HORIZONTAL_ALIGNMENT_CENTER,170,16,ink)
		else:
			for i in 3:
				var key: String=["old","a","b"][i]+"-"+item;var x: float=192+i*384
				draw_string(ThemeDB.fallback_font,Vector2(x-150,104),["Сейчас","A · спокойнее","B · фактурнее"][i],HORIZONTAL_ALIGNMENT_CENTER,300,20,ink)
				_icon(key,64,Vector2(x-32,138),ink,true)
				_icon(key,160,Vector2(x-80,278),ink,false)
		draw_string(ThemeDB.fallback_font,Vector2(30,548),"Новый рисунок — отдельный макет. Решение A/B хранится отдельно. В игру не импортирован.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)
		draw_string(ThemeDB.fallback_font,Vector2(30,588),"Одинаковые размеры и padding. Никаких названий в ячейке; число проверено на ×999.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)

	## Находит видимое русское имя предмета без изменения реестра игры.
	func _name(id: String) -> String:
		for entry: Dictionary in study.items:
			if entry.id==id:return entry.name
		return id

	## Рисует одну подготовленную PNG ровно 1:1 с прежней окраской текущего предмета.
	func _icon(key: String, pixels: int, at: Vector2, ink: Color, count: bool) -> void:
		var packet: Dictionary=textures[key+"-"+str(pixels)]
		draw_texture(packet.texture,at,packet.tint)
		if count:
			draw_style_box(_count_box(),Rect2(at+Vector2(25,49),Vector2(43,20)))
			draw_string(ThemeDB.fallback_font,at+Vector2(28,65),"×999",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff2cf"))

	## Отделяет число от рисунка компактной подложкой, а не обводкой предмета.
	func _count_box() -> StyleBoxFlat:
		var box:=StyleBoxFlat.new();box.bg_color=Color("493c30");box.set_corner_radius_all(4);return box

## Требует отдельный профиль и новый каталог; не создаёт игровую сцену и не читает слоты.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VART-010-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль");quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Экспортирует два независимых размера из каждого мастера до нативной съёмки.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):push_error("Нужна нативная графика");quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"icons.json"));var ids: Array=[];var textures: Dictionary={};var exports: Array=[];var sources: Dictionary={}
	DirAccess.make_dir_recursive_absolute(output.path_join("icons"))
	for item: Dictionary in data.items:ids.append(item.id)
	Visual.initialize_item_icons(ids)
	for entry: Dictionary in data.entries:
		var image:=_image(REPORT+entry.master);var r: Array=entry.source_rect;var region:=Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]));sources[REPORT+entry.master]=FileAccess.get_sha256(REPORT+entry.master)
		for size: int in [64,160]:
			var fitted:=_fit(image,region,size,int(data.padding[str(size)]));var file: String="icons/"+entry.id+"-"+str(size)+".png";fitted.save_png(output.path_join(file))
			textures[entry.id+"-"+str(size)]={"texture":ImageTexture.create_from_image(fitted),"tint":Color.WHITE}
			exports.append({"id":entry.id,"size":size,"file":file,"sha256":FileAccess.get_sha256(output.path_join(file)),"used_rect":_rect(fitted.get_used_rect())})
	var old: Array=[]
	for id: String in ids:
		for size: int in [64,160]:
			var packet:=Visual.item_draw_visual(id,size);var file: String="icons/old-"+id+"-"+str(size)+".png";packet.texture.get_image().save_png(output.path_join(file));textures["old-"+id+"-"+str(size)]=packet
			old.append({"id":id,"size":size,"file":file,"sha256":FileAccess.get_sha256(output.path_join(file)),"tint":packet.tint.to_html(),"provider":packet.provider})
		var descriptor:=Visual.draw_descriptor(id);sources[descriptor.path]=FileAccess.get_sha256(descriptor.path)
	sources["res://assets/game/items/ui/thumbnails.png"]=FileAccess.get_sha256("res://assets/game/items/ui/thumbnails.png")
	for id: String in ids:sources["res://assets/game/items/ui/preview/"+id+".png"]=FileAccess.get_sha256("res://assets/game/items/ui/preview/"+id+".png")
	var scene_path: String=REPORT+data.world_background;sources[scene_path]=FileAccess.get_sha256(scene_path)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.size_2d_override=viewport.size;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas:=IconCanvas.new();canvas.study=data;canvas.textures=textures;canvas.scene=ImageTexture.create_from_image(_image(scene_path));canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;viewport.add_child(canvas)
	root.size=viewport.size;root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.title="VART-010 · иконки 64/160";var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.size=Vector2(1152,648);root.add_child(preview)
	var frames: Array=[]
	for bg: String in ["light","dark","game"]:
		canvas.background=bg;canvas.item=""
		for variant: String in ["a","b"]:
			canvas.variant=variant
			if not await _frame(viewport,canvas,"catalog-"+variant+"-"+bg,frames):return
		for id: String in ids:
			canvas.item=id
			if not await _frame(viewport,canvas,"focus-"+id+"-"+bg,frames):return
	var t:=viewport.get_stretch_transform();var owners: Dictionary={}
	for path: String in ["res://scripts/systems/visual_asset_system.gd","res://scripts/presentation/prepared_item_icon_system.gd","res://scripts/presentation/item_icon_visual_system.gd"]:owners[path]=FileAccess.get_sha256(path)
	var proof:={"schema":1,"kind":"native-icon-study","native_gameplay":false,"performance_eligible":false,"target":[1152,648],"ui_scale":1.0,"projection":[[t.x.x,t.x.y],[t.y.x,t.y.y],[t.origin.x,t.origin.y]],"profile":profile,"display_server":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),"script_sha256":FileAccess.get_sha256("res://tools/visual_icons_capture.gd"),"profile_sha256":FileAccess.get_sha256(REPORT+"icons.json"),"sources":sources,"owners":owners,"exports":exports,"old":old,"frames":frames,"loads_inside_draw":0,"masters_used_for_ui":false}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(proof,"\t")+"\n");print("ICON STUDY: 12 masters, 24 exports, ",frames.size()," native frames");quit(0)

## Читает PNG без зависимости от импорта каталога макетов.
func _image(path: String) -> Image:
	var image:=Image.new();var error:=image.load_png_from_buffer(FileAccess.get_file_as_bytes(path));assert(error==OK);return image

## Вписывает исходник отдельно в 64 и 160 с сохранением пропорций и безопасного края.
func _fit(image: Image, region: Rect2i, pixels: int, padding: int) -> Image:
	var cropped:=image.get_region(region);var factor:=float(pixels-padding*2)/maxi(region.size.x,region.size.y);cropped.resize(maxi(1,roundi(region.size.x*factor)),maxi(1,roundi(region.size.y*factor)),Image.INTERPOLATE_LANCZOS)
	var fitted:=Image.create(pixels,pixels,false,Image.FORMAT_RGBA8);fitted.fill(Color.TRANSPARENT);fitted.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),(Vector2i(pixels,pixels)-cropped.get_size())/2);return fitted

## Сохраняет целый readback и повтор, отклоняя подмену физического размера.
func _frame(viewport: SubViewport, canvas: IconCanvas, id: String, frames: Array) -> bool:
	canvas.queue_redraw()
	for tick in 3:
		await process_frame
		RenderingServer.force_draw(false)
	var image:=viewport.get_texture().get_image();await process_frame
	RenderingServer.force_draw(false)
	if image.get_size()!=Vector2i(1152,648) or image.get_data()!=viewport.get_texture().get_image().get_data():push_error("Readback mismatch "+id);quit(2);return false
	var file:=id+".png";image.save_png(output.path_join(file));frames.append({"id":id,"file":file,"size":[1152,648],"repeat_equal":true,"sha256":FileAccess.get_sha256(output.path_join(file))});return true

## Хранит измеренную область в простом JSON, не принимая её за художественное одобрение.
func _rect(rect: Rect2i) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

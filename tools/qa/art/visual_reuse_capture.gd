extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vart-009/"
const Sources := preload("res://tools/qa/art/visual_reuse_sources.gd")
var output := ""
var profile := ""

class Reference extends Node2D:
	var texture: Texture2D
	var source: Rect2
	var destination: Rect2

	## Показывает принятый рисунок при общей проекции и его собственном измеренном масштабе.
	func _draw() -> void:
		if texture!=null:draw_texture_rect_region(texture,destination,source)

class AuditCanvas extends Node2D:
	var sample: Dictionary
	var background := Color("f4efdf")
	var heading := ""
	var ref_note := ""
	var hero: Dictionary
	var overview: Array=[]

	## Сравнивает один настоящий выбранный кадр с эталоном; обзор исходников имеет отдельную классификацию.
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,540),background)
		var ink:=Color("dfd2b3") if background.r<.3 else Color("483831")
		draw_string(ThemeDB.fallback_font,Vector2(24,28),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
		if not overview.is_empty():
			for i in overview.size():
				var image: Texture2D=overview[i].texture;var box:=Vector2(180,91);var size:=image.get_size()*minf(box.x/image.get_width(),box.y/image.get_height());var pos:=Vector2(6+(i%5)*192,44+(i/5)*122)
				draw_texture_rect(image,Rect2(pos+(box-size)*.5,size),false)
				draw_string(ThemeDB.fallback_font,pos+Vector2(0,105),String(overview[i].label),HORIZONTAL_ALIGNMENT_LEFT,184,9,ink)
			return
		for i in int(sample.repeat):
			for j in int(sample.repeat):
				var rect: Rect2=sample.destination;rect.position+=Vector2(240,432)+Vector2(i,j)*rect.size
				draw_texture_rect_region(sample.texture,rect,sample.source)
		var ruler: Rect2=preload("res://scripts/systems/hero_visual_system.gd").destination(Vector2(480,432),hero)
		draw_texture_rect_region(hero.texture,ruler,hero.source)
		draw_line(Vector2(24,432),Vector2(936,432),Color(ink,.2),1)
		draw_string(ThemeDB.fallback_font,Vector2(36,478),String(sample.note),HORIZONTAL_ALIGNMENT_LEFT,420,12,ink)
		draw_string(ThemeDB.fallback_font,Vector2(510,478),ref_note,HORIZONTAL_ALIGNMENT_LEFT,426,12,ink)
		draw_string(ThemeDB.fallback_font,Vector2(300,518),"Общая камера 1.2 · статичный образец · эталон не означает готовую замену",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)

## Создаёт только отдельный профиль и новый каталог; не читает игровое сохранение.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VART-009-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и отдельный профиль VART-009");quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Сохраняет 29 пар в нативном размере и обзоры всех файлов; источники владельцев снимаются до отрисовки.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):push_error("Нужна нативная графика");quit(2);return
	var view: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"view-profile.json"))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/game/world_sprite_manifest.json"))
	var modules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"../vart-008/modules.json"))
	DirAccess.make_dir_recursive_absolute(output.path_join("samples"))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.size_2d_override=Vector2i(960,540);viewport.size_2d_override_stretch=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var canvas:=AuditCanvas.new();canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.hero=Sources.Hero.walk_pose(Vector2.DOWN,0,false);canvas.hero.texture=Sources.Matte.clean_texture(canvas.hero.texture)
	viewport.add_child(canvas)
	var reference:=Reference.new();reference.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;viewport.add_child(reference)
	root.size=Vector2i(1152,648);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.title="VART-009 · аудит переиспользования"
	var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.size=Vector2(1152,648);root.add_child(preview)
	var frames: Array=[];var samples: Array=[];var paths: Dictionary={};var source_hashes: Dictionary={};var owner_hashes: Dictionary={}
	for entry: Dictionary in manifest.entries:
		var id: String=entry.id;var sample:=Sources.sample(id)
		if sample.is_empty() or sample.texture==null:push_error("Не найден образец "+id);quit(2);return
		canvas.sample=sample;canvas.heading=id+" · "+String(entry.family)
		var raw: Image=sample.texture.get_image();var source: Rect2=sample.source;var cut:=raw.get_region(Rect2i(source))
		var sample_path:=output.path_join("samples").path_join(id+".png");cut.save_png(sample_path)
		var ref: Dictionary=view.references[id];canvas.ref_note=ref.note
		var ref_data: Dictionary={}
		if ref.id=="hero-study":
			ref_data={"source":"../vart-006/density-a.png","rect":[139,78,232,496],"pivot":[113,478],"scale":81.0/461.0}
		else:
			for p: Dictionary in modules.parts:
				if p.id==ref.id:ref_data=p;break
			ref_data=ref_data.duplicate(true);ref_data.source="../vart-008/"+String(ref_data.source)
		var ref_path: String=REPORT+ref_data.source;var image:=Image.load_from_file(ref_path);image.generate_mipmaps();reference.texture=ImageTexture.create_from_image(image)
		var r: Array=ref_data.rect;reference.source=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]));var k: float=ref_data.scale
		var pivot:=Vector2(float(ref_data.pivot[0]),float(ref_data.pivot[1]));reference.destination=Rect2(Vector2(720,432)-pivot*k,reference.source.size*k)
		if ref.id in ["meadow","earth","water"]:reference.source=Rect2(reference.source.position,Vector2(256,256));reference.destination=Rect2(672,336,96,96)
		source_hashes[ref_path]=FileAccess.get_sha256(ref_path);owner_hashes[sample.owner]=FileAccess.get_sha256(sample.owner)
		var master: String=sample.master_path
		if master.is_empty():push_error("Нет происхождения "+id);quit(2);return
		source_hashes[master]=FileAccess.get_sha256(master)
		samples.append({"id":id,"master":master,"master_sha256":source_hashes[master],"region":_rect(sample.master_region),"destination":_rect(sample.destination),"repeat":sample.repeat,"world_size":sample.world_size,
			"owner":sample.owner,"note":sample.note,"file":"samples/"+id+".png","sha256":FileAccess.get_sha256(sample_path),"prepared_by_runtime":id in ["WS-018","WS-020"],"reference":ref.id,"reference_source":ref_path,"reference_region":_rect(reference.source),"reference_destination":_rect(reference.destination)})
		for bg: String in ["light","dark"]:
			canvas.background=Color("f4efdf" if bg=="light" else "252e36")
			if not await _frame(viewport,canvas,id+"-"+bg,"world-comparison" if sample.world_size else "archive-overview",frames):return
		for asset: Dictionary in entry.assets:paths[asset.path]=true
	canvas.sample={};reference.texture=null
	var ordered:=paths.keys();ordered.sort()
	for start in range(0,ordered.size(),20):
		canvas.overview=[];canvas.heading="Исходники целиком · обзор %d · не мировой масштаб"%(start/20+1);canvas.background=Color("252e36")
		for index in range(start,mini(start+20,ordered.size())):
			var path: String=ordered[index];var image:=Image.new();var decoded:=image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://"+path))
			if decoded!=OK:push_error("PNG decode "+path);quit(2);return
			canvas.overview.append({"texture":ImageTexture.create_from_image(image),"label":"%03d %s"%[index,path.get_file()]})
		if not await _frame(viewport,canvas,"sources-%02d"%(start/20+1),"source-overview",frames):return
	var t:=viewport.get_stretch_transform()
	var proof:={"schema":1,"kind":"native-reuse-audit","native_gameplay":false,"performance_eligible":false,"profile":profile,"target":[1152,648],"field":[960,540],"projection":[[t.x.x,t.x.y],[t.y.x,t.y.y],[t.origin.x,t.origin.y]],
		"view_profile_sha256":FileAccess.get_sha256(REPORT+"view-profile.json"),"manifest_sha256":FileAccess.get_sha256("res://assets/game/world_sprite_manifest.json"),"script_sha256":FileAccess.get_sha256("res://tools/qa/art/visual_reuse_capture.gd"),"adapter_sha256":FileAccess.get_sha256("res://tools/qa/art/visual_reuse_sources.gd"),
		"sources":source_hashes,"owners":owner_hashes,"samples":samples,"frames":frames,"overview_paths":ordered,"legacy_filter":"nearest","reference_filter":"linear_with_mipmaps","engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name()}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(proof,"\t")+"\n");print("REUSE CAPTURE: ",samples.size()," representatives, ",frames.size()," native frames");quit(0)

## Снимает стабильные настоящие пиксели без последующего изменения размера.
func _frame(viewport: SubViewport, canvas: AuditCanvas, id: String, kind: String, frames: Array) -> bool:
	canvas.queue_redraw()
	viewport.get_child(1).queue_redraw()
	for tick in 3:await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();await RenderingServer.frame_post_draw
	if image.get_size()!=Vector2i(1152,648) or image.get_data()!=viewport.get_texture().get_image().get_data():push_error("Readback mismatch "+id);quit(2);return false
	var path:=output.path_join(id+".png");image.save_png(path);frames.append({"id":id,"file":id+".png","kind":kind,"size":[1152,648],"repeat_equal":true,"sha256":FileAccess.get_sha256(path)});return true

## Сохраняет точные координаты источника и назначения в системе владельца.
func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

extends SceneTree

const REPORT := "res://docs/reports/visual-overhaul/vart-008/"
var output := ""
var profile := ""

class ModuleCanvas extends Node2D:

	var data: Dictionary
	var parts: Dictionary
	var textures: Dictionary
	var page := "foliage"
	var variant := "a"
	var mode := "front"
	var background := Color("f4efdf")
	var hud: Texture2D
	var hero: Texture2D

	## Рисует отдельную карточку либо участок из тех же нарезанных мастеров.
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,540),background)
		if page=="pilot": _pilot(); return
		if page=="foliage":
			var ids: Array=[]
			for part: Dictionary in data.parts:
				if part.kind=="clump":ids.append(part.id)
			for i in ids.size(): _sprite(ids[i],Vector2(96+(i%4)*120,150+(i/4)*120))
			_sprite("bush-hazel",Vector2(192,432));_sprite("bush-berry",Vector2(384,432));_sprite("tree",Vector2(720,324));_hero(Vector2(720,432))
			_label("8 пучков · 2 куста · дерево",Vector2(36,40));_label("Текущий герой — только масштаб",Vector2(600,478))
		elif page=="terrain":
			for i in 3:
				var id: String=["meadow","earth","water"][i];_material(Rect2(36+i*312,48,264,168),id);_label(id,Vector2(36+i*312,238))
			for i in 4:
				_sprite(["road-h","road-v","road-outer","road-inner"][i],Vector2(120+i*240,324))
				_sprite(["bank-h","bank-v","bank-outer","bank-inner"][i],Vector2(120+i*240,456))
			_label("Покрытия · прямые края · наружный и внутренний угол",Vector2(36,28))
		else:
			_sprite("facade-a",Vector2(192,336));_sprite("facade-b",Vector2(480,336));_bridge(Vector2(780,312));_hero(Vector2(780,432))
			_label("A · сланец",Vector2(96,372));_label("B · черепица",Vector2(384,372));_label("Настил / перила / опоры",Vector2(660,228))
			_sprite("bridge-rail",Vector2(780,120));_sprite("footing-a",Vector2(720,480));_sprite("footing-b",Vector2(840,480))
		draw_set_transform(Vector2.ZERO)

	## Разделяет покрашенную форму, контакт и условную солнечную проекцию.
	func _shadow(id: String, feet: Vector2) -> void:
		var p: Dictionary=parts[id];var rect:=_rect(p)
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				draw_set_transform_matrix(Transform2D(Vector2.RIGHT,Vector2(-.55,-.25),feet+Vector2(dx,dy)))
				draw_texture_rect(textures[id],rect,false,Color(0,0,0,.022))
		draw_set_transform(feet,0,Vector2(float(p.footprint[0])*.4,4))
		for ring in range(6,0,-1):draw_circle(Vector2.ZERO,ring/6.0,Color(0,0,0,.035))
		draw_set_transform(Vector2.ZERO)

	## Физическая опора внутри региона не меняется между вариантами просмотра.
	func _rect(p: Dictionary) -> Rect2:
		return Rect2(-Vector2(float(p.pivot[0]),float(p.pivot[1]))*float(p.scale),Vector2(float(p.rect[2]),float(p.rect[3]))*float(p.scale))

	## Не вращает предметы; отражение применяется только к пробным кромкам грунта.
	func _sprite(id: String, feet: Vector2, flip := Vector2.ONE) -> void:
		draw_set_transform(feet,0,flip);draw_texture_rect(textures[id],_rect(parts[id]),false);draw_set_transform(Vector2.ZERO)

	## Повторяет универсальный материал зеркальными ячейками без изменения исходного PNG.
	func _material(rect: Rect2, id: String) -> void:
		var tex: Texture2D=textures[id];var tile:=Vector2(tex.get_size())*.375
		for yy in range(int(floor(rect.position.y/tile.y)),int(ceil(rect.end.y/tile.y))):
			for xx in range(int(floor(rect.position.x/tile.x)),int(ceil(rect.end.x/tile.x))):
				var origin:=Vector2(xx,yy)*tile;var intersection:=rect.intersection(Rect2(origin,tile))
				if not intersection.has_area():continue
				var vertices:=PackedVector2Array([intersection.position,Vector2(intersection.end.x,intersection.position.y),intersection.end,Vector2(intersection.position.x,intersection.end.y)])
				var uvs:=PackedVector2Array()
				for v: Vector2 in vertices:
					var uv: Vector2=(v-origin)/tile
					if posmod(xx,2)==1:uv.x=1-uv.x
					if posmod(yy,2)==1:uv.y=1-uv.y
					uvs.append(uv)
				draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,tex)

	## Условная сборка моста сохраняет настил между задними и передними перилами.
	func _bridge(center: Vector2, hero_on_bridge := false) -> void:
		_sprite("footing-a",center+Vector2(-84,0));_sprite("footing-b",center+Vector2(84,0))
		_sprite("bridge-deck",center);_sprite("bridge-rail",center+Vector2(0,-18))
		if hero_on_bridge:_hero(center)
		_sprite("bridge-rail",center+Vector2(0,23))

	## Исторический кадр героя — контроль масштаба, не утверждение новой анимации.
	func _hero(feet: Vector2) -> void:
		var k: float=data.hero_reference.scale
		var pivot:=Vector2(float(data.hero_reference.pivot[0]),float(data.hero_reference.pivot[1]))
		draw_set_transform(feet);draw_texture_rect_region(hero,Rect2(-pivot*k,Vector2(192,192)*k),Rect2(0,0,192,192));draw_set_transform(Vector2.ZERO)

	## Подпись принадлежит витрине, а не игровому интерфейсу.
	func _label(value: String, pos: Vector2) -> void:
		draw_string(ThemeDB.fallback_font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("bca77d") if background.r<.3 else Color("483831"))

	## Собирает соседство модулей и два положения героя относительно опоры дерева.
	func _pilot() -> void:
		_material(Rect2(0,0,960,540),"meadow");_material(Rect2(744,0,120,540),"water")
		_material(Rect2(0,312,744,48),"earth");_material(Rect2(864,312,96,48),"earth");_material(Rect2(216,264,48,72),"earth")
		for x in range(48,961,120):
			if x>720 and x<900:continue
			var join: float=(float(parts["road-h"].join_source)-float(parts["road-h"].pivot[1]))*float(parts["road-h"].scale)
			_sprite("road-h",Vector2(x,312-join));_sprite("road-h",Vector2(x,360+join),Vector2(1,-1))
		for y in range(-15,601,75):
			_sprite("bank-v",Vector2(724,y));_sprite("bank-v",Vector2(884,y),Vector2(-1,1))
		for y in [268]:
			var join: float=(float(parts["road-v"].join_source)-float(parts["road-v"].pivot[0]))*float(parts["road-v"].scale)
			_sprite("road-v",Vector2(216-join,y));_sprite("road-v",Vector2(264+join,y),Vector2(-1,1))
		var house: String=data.variants[variant].facade
		_shadow(house,Vector2(240,288));_shadow("tree",Vector2(576,240));_shadow("bush-hazel",Vector2(420,456));_shadow("bush-berry",Vector2(636,456))
		_sprite(house,Vector2(240,288))
		_bridge(Vector2(804,336),mode=="bridge")
		var hero_feet:=Vector2(576,216 if mode=="back" else 264)
		if mode=="back":_hero(hero_feet)
		_sprite("tree",Vector2(576,240))
		if mode not in ["back","bridge"]:_hero(hero_feet)
		_sprite("bush-hazel",Vector2(420,456));_sprite("bush-berry",Vector2(636,456))
		var ids: Array=[]
		for p: Dictionary in data.parts:
			if p.kind=="clump":ids.append(p.id)
		for i in ids.size():
			_sprite(ids[i],Vector2(84+(i%4)*144,408+(i/4)*96))
		if mode=="grid":
			for x in range(0,961,24):draw_line(Vector2(x,0),Vector2(x,540),Color(1,1,1,.15))
			for y in range(0,541,24):draw_line(Vector2(0,y),Vector2(960,y),Color(1,1,1,.15))
			for r in [Rect2(120,192,240,96),Rect2(528,192,96,48),Rect2(708,312,192,48)]:draw_rect(r,Color(1,.9,.6,.8),false,1)
		if mode=="hud":draw_texture_rect(hud,Rect2(0,0,960,540),false)
		draw_set_transform(Vector2.ZERO)

## Изолирует вывод от сохранений и не перезаписывает прошлый протокол.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VART-008-") or "/" in profile or "\\" in profile:
		push_error("Нужен новый output и отдельный профиль VART-008");quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Нарезает регионы без художественной обработки, создаёт mipmaps один раз и снимает GPU-readback.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile):push_error("Нужна нативная графика");quit(2);return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(REPORT+"modules.json"))
	DirAccess.make_dir_recursive_absolute(output.path_join("sprites"))
	var canvas:=ModuleCanvas.new();canvas.data=data;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var images: Dictionary={};var sources: Dictionary={};var exports: Array=[];var decoded_bytes:=0
	for p: Dictionary in data.parts:
		if not images.has(p.source):images[p.source]=Image.load_from_file(REPORT+p.source);sources[p.source]=FileAccess.get_sha256(REPORT+p.source)
		var r: Array=p.rect;var cut: Image=images[p.source].get_region(Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3])))
		var path: String=output.path_join("sprites").path_join(p.id+".png");cut.save_png(path)
		if cut.generate_mipmaps()!=OK:push_error("Mipmap failure");quit(2);return
		decoded_bytes+=cut.get_data_size();canvas.textures[p.id]=ImageTexture.create_from_image(cut);canvas.parts[p.id]=p
		exports.append({"id":p.id,"file":"sprites/"+p.id+".png","sha256":FileAccess.get_sha256(path),"size":[cut.get_width(),cut.get_height()],"source":p.source,"rect":p.rect})
	var hero_path:=REPORT+"../vart-002/native/hero-current.png";canvas.hero=ImageTexture.create_from_image(Image.load_from_file(hero_path));sources["../vart-002/native/hero-current.png"]=FileAccess.get_sha256(hero_path)
	var hud_path:=REPORT+"../vart-002/native/plaza-hud.png";canvas.hud=ImageTexture.create_from_image(Image.load_from_file(hud_path));sources["../vart-002/native/plaza-hud.png"]=FileAccess.get_sha256(hud_path)
	var viewport:=SubViewport.new();viewport.size=Vector2i(1152,648);viewport.size_2d_override=Vector2i(960,540);viewport.size_2d_override_stretch=true;viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);viewport.add_child(canvas)
	root.title="VART-008 · эталонные модули";root.size=Vector2i(1152,648);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	var preview:=TextureRect.new();preview.texture=viewport.get_texture();preview.size=Vector2(1152,648);root.add_child(preview)
	var frames: Array=[]
	for page: String in ["foliage","terrain","structures"]:
		for bg: String in ["light","dark","grass"]:
			canvas.page=page;canvas.background=Color({"light":"f4efdf","dark":"252e36","grass":"6f8651"}[bg])
			if not await _frame(viewport,canvas,page+"-"+bg,frames):return
	for v: String in ["a","b"]:
		for mode: String in ["front","back","bridge","grid","hud"]:
			canvas.page="pilot";canvas.variant=v;canvas.mode=mode
			if not await _frame(viewport,canvas,"pilot-"+v+"-"+mode,frames):return
	var t:=viewport.get_stretch_transform()
	var proof:={"schema":1,"kind":"native-module-study","native_gameplay":false,"performance_eligible":false,"target":[1152,648],"field":[960,540],"projection":[[t.x.x,t.x.y],[t.y.x,t.y.y],[t.origin.x,t.origin.y]],
		"profile":profile,"profile_sha256":FileAccess.get_sha256(REPORT+"modules.json"),"script_sha256":FileAccess.get_sha256("res://tools/qa/art/visual_modules_capture.gd"),"sources":sources,"exports":exports,"frames":frames,
		"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"decoded_module_bytes_with_mips":decoded_bytes,"texture_loads_inside_draw":0,"texture_filter":"linear_with_mipmaps","hud_source":"VART-002 baseline snapshot, not current live HUD","material_repeat":"mirrored study cells, not production seamless autotile"}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(proof,"\t")+"\n");print("MODULE CAPTURE: 28 sprites, 19 native frames, repeated readback equal");quit(0)

## Принимает только настоящий размер Image и побайтно стабильный повтор кадра.
func _frame(viewport: SubViewport, canvas: ModuleCanvas, id: String, frames: Array) -> bool:
	canvas.queue_redraw()
	for tick in 3:await RenderingServer.frame_post_draw
	var image:=viewport.get_texture().get_image();await RenderingServer.frame_post_draw
	if image.get_size()!=Vector2i(1152,648) or image.get_data()!=viewport.get_texture().get_image().get_data():push_error("Readback mismatch");quit(2);return false
	var path:=output.path_join(id+".png")
	if image.save_png(path)!=OK:push_error("PNG failure");quit(2);return false
	frames.append({"id":id,"file":id+".png","sha256":FileAccess.get_sha256(path),"size":[1152,648],"repeat_equal":true});return true

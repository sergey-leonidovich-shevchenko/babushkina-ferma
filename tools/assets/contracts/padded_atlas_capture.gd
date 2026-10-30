extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Padded := preload("res://scripts/presentation/padded_atlas_system.gd")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
var output := OS.get_environment("VPADDING_OUTPUT")
var fixture := OS.get_environment("VPADDING_FIXTURE")
var game: Node
var gallery: Gallery
var faults: Array = []


## Изолирует нативное доказательство от профиля игрока и запрещает перезапись снимков.
func _initialize() -> void:
	var profile := OS.get_environment("VPADDING_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or fixture.is_empty() or not profile.begins_with("Codex-VPIPELINE-004-") or "/" in profile or "\\" in profile:
		push_error("Нужны новые output, fixture и профиль VPIPELINE-004"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true); ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()


## Снимает реальную комнату, шкаф и два фона трёх способов выборки при одинаковой камере.
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
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE; DirAccess.make_dir_recursive_absolute(output)
	await _redraw(); _save("room")
	var room_config := Points.snapshot(game,point)
	var room_pages := Padded.cache_info()
	game.player=Cabinet.POSITION
	if not Cabinet.open(game): faults.append("Cabinet did not open")
	await _redraw(); _save("cabinet"); Cabinet.close(game)
	var cabinet_pages := Padded.cache_info()
	game.hide(); gallery=Gallery.new(); gallery.prepare(fixture); root.add_child(gallery)
	for background in ["light","dark"]:
		gallery.background=background
		for mode in ["unsafe","padded","isolated"]:
			gallery.mode=mode; await _redraw(); _save(background+"-"+mode)
	var data := Points.snapshot(game,point)
	data.merge({"room_page_cache":room_pages,"cabinet_page_cache":cabinet_pages,"room_configuration":room_config,"errors":faults,"framebuffer":[1152,648],"engine":Engine.get_version_info().string,"version":ProjectSettings.get_setting("application/config/version"),"profile":OS.get_user_data_dir().get_file(),"sizes":[64,40,32,16,8,4],"performance_eligible":false,"source_sha256":{}})
	for path in ["assets/game/items/ui/padded/catalog.json","assets/game/visual_sampling.json","scripts/presentation/padded_atlas_system.gd","scripts/presentation/prepared_item_icon_system.gd","scripts/presentation/visual_sampling_system.gd","tools/padded_atlas_capture.gd"]: data.source_sha256[path]=FileAccess.get_sha256("res://"+("tools/assets/contracts/padded_atlas_capture.gd" if path=="tools/padded_atlas_capture.gd" else path))
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("PADDED CAPTURE: ",output); quit(0 if faults.is_empty() else 2)


## Дожидается настоящего readback независимо от перекрытия окна.
func _redraw() -> void:
	for index in 20:
		game.queue_redraw(); if gallery!=null: gallery.queue_redraw()
		await process_frame; RenderingServer.force_draw(false)


## Сохраняет целый нативный кадр без обрезки и постобработки.
func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_size()!=Points.SIZE or image.save_png(output.path_join(name+".png"))!=OK: faults.append("Invalid native frame: "+name)

class Gallery extends Node2D:
	const FONT := preload("res://assets/game/fonts/ui_font.tres")
	const KINDS := ["bread","healing_potion","iron_ore"]
	const SIZES := [64,40,32,16,8,4]
	var background := "light"
	var mode := "padded"
	var stress: Dictionary = {}
	var items: Dictionary = {}

	## Создаёт адресную обёртку только для изолированного диагностического источника.
	func sampled_image(image: Image, mipmaps: bool=false) -> CanvasTexture:
		if mipmaps: image.generate_mipmaps()
		var result := CanvasTexture.new(); result.diffuse_texture=ImageTexture.create_from_image(image)
		result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if mipmaps else CanvasItem.TEXTURE_FILTER_LINEAR
		result.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED; return result

	## Готовит негативный контроль с аппаратными mip, настоящий новый пакет и отдельные эталоны каждого кадра.
	func prepare(folder: String) -> void:
		texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var rectangles: Array = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("fixture.json")))
		var tight := sampled_image(Image.load_from_file(folder.path_join("tight.png")),true)
		var original := sampled_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/game/items/ui/thumbnails.png")),true)
		for size in SIZES:
			var level := Padded.level_for(size); var r: Array = rectangles[level]
			var page := Image.load_from_file(folder.path_join("level-%d.png"%level))
			var region := Rect2(r[0],r[1],r[2],r[3]); var clip := AtlasTexture.new(); clip.atlas=sampled_image(page); clip.region=region; clip.filter_clip=true
			stress[size]={"unsafe":AtlasTexture.new(),"padded":clip,"isolated":sampled_image(page.get_region(Rect2i(region)))}
			stress[size].unsafe.atlas=tight; stress[size].unsafe.region=Rect2(64,0,64,64); stress[size].unsafe.filter_clip=true
			items[size]={}
			for kind in KINDS:
				var frame := Padded.frame(kind,size)
				var cell: Array = preload("res://assets/game/items/ui/catalog.gd").DATA.entries[kind].cell
				var unsafe := AtlasTexture.new(); unsafe.atlas=original; unsafe.region=Rect2(cell[0],cell[1],64,64); unsafe.filter_clip=true
				items[size][kind]={"unsafe":unsafe,"padded":frame,"isolated":sampled_image(frame.get_image())}

	## Показывает цветной тест шва и три настоящие иконки в шести размерах без растягивания исходных доказательств.
	func _draw() -> void:
		var bg := Color("eee3c5") if background=="light" else Color("203a32")
		var ink := Color("493721") if background=="light" else Color("f6ebcf")
		draw_rect(Rect2(0,0,1152,648),bg)
		draw_string(FONT,Vector2(28,38),"VPIPELINE-004 · границы кадров и независимые уровни",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
		draw_string(FONT,Vector2(28,80),"Контроль: зелёный кадр между красным и синим",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
		for column in SIZES.size():
			var size: int = SIZES[column]; var x := 70.25+column*170
			draw_string(FONT,Vector2(x,125),str(size)+" px",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
			draw_texture_rect(stress[size][mode],Rect2(x,156.25,size,size),false)
			for row in KINDS.size(): draw_texture_rect(items[size][KINDS[row]][mode],Rect2(x,315.25+row*100,size,size),false)
		draw_string(FONT,Vector2(28,610),"Хлеб · зелье · руда. Позиции дробные; камера и размер кадра неизменны.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,ink)

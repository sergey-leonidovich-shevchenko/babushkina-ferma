extends SceneTree

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Visibility := preload("res://scripts/systems/world_visibility_system.gd")
const SIZE := Vector2i(1152,648)
const VARIANTS := [
	{"id":"current","field":Vector2i(1152,648),"zoom":1.0},
	{"id":"wide","field":Vector2i(1440,810),"zoom":0.8},
	{"id":"close","field":Vector2i(960,540),"zoom":1.2},
]
const SCENES := [
	{"id":"plaza","player":Vector2(1248,744)},
	{"id":"farm","player":Vector2(744,936)},
]
var folder := ""
var profile := ""
var faults := []
var rows := []

class HudOnly extends "res://scripts/game.gd":
	## Выводит штатный HUD отдельным проходом, сохраняя его исходный размер при другом поле обзора мира.
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO); RenderSystem.draw_screen(self,false)

class HeroSamples extends Node2D:
	var zoom := 1.0
	## Показывает настоящую позу в трёх направлениях с одинаковой точкой стоп и масштабом проекции.
	func _draw() -> void:
		for index in 3:
			draw_set_transform(Vector2(96+192*index,160),0,Vector2.ONE*zoom)
			Visual.draw_pose(self,Vector2.ZERO,Visual.walk_pose([Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT][index],0,false))

## Изолирует новые нативные макеты от слотов и настроек пользователя.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="): profile=arg.trim_prefix("--profile=")
	if folder.is_empty() or not profile.begins_with("Codex-VART-002-") or "/" in profile or "\\" in profile:
		push_error("Нужны новый output и изолированный profile VART-002"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает шесть проекций настоящего мира с общей камерой по центру и отдельным неизменным HUD.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_user_data_dir().ends_with(profile) or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны нативная графика и свежий профиль"); quit(2); return
	DirAccess.make_dir_recursive_absolute(folder)
	root.title="VART-002 · поле обзора"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO
	await create_timer(2).timeout; root.mode=Window.MODE_WINDOWED
	await create_timer(2).timeout; root.size=SIZE; root.grab_focus()
	await create_timer(2).timeout
	for scene in SCENES:
		var hud_view:=_viewport(SIZE,true)
		var hud:=_game(hud_view,scene,true)
		var hud_layer:=_layer(hud_view)
		for frame in 12: hud.queue_redraw(); await RenderingServer.frame_post_draw
		var hud_image:=hud_view.get_texture().get_image()
		if hud_image.save_png(folder.path_join(scene.id+"-hud.png"))!=OK: faults.append("HUD PNG")
		hud_layer.hide()
		for variant in VARIANTS:
			var world_view:=_viewport(variant.field,false)
			var game:=_game(world_view,scene,false)
			var field:Vector2=Vector2(variant.field)
			game.camera_offset=Vector2(scene.player)-field*0.5
			game.get_node("WorldBackground").position=-game.camera_offset
			var before_document:Dictionary=game.SaveSystem.snapshot(game)
			var before:=_physical(game)
			var layer:=_layer(world_view); layer.z_index=-1
			hud_layer.show()
			for frame in 12:
				game.queue_redraw(); hud.queue_redraw(); await RenderingServer.frame_post_draw
				if not _conditions(): faults.append("window/framebuffer/focus")
			var image:=root.get_texture().get_image()
			var name:String=scene.id+"-"+variant.id
			if image.get_size()!=SIZE or image.save_png(folder.path_join(name+".png"))!=OK: faults.append("PNG: "+name)
			hud_layer.hide(); await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_png(folder.path_join(name+"-world.png"))!=OK: faults.append("world PNG")
			var after:=_physical(game)
			var visible:Rect2=Visibility.visible_rect(game).grow(-Visibility.EDGE_MARGIN)
			var pose:=Visual.current_pose(game,Vector2.DOWN,false)
			var hero_rect:=Visual.destination(game.player,pose)
			var matrix:=world_view.get_stretch_transform()
			if before!=after:
				faults.append("physical state changed: "+name)
				FileAccess.open(folder.path_join(name+"-state-diff.json"),FileAccess.WRITE).store_string(JSON.stringify({"before":before_document,"after":game.SaveSystem.snapshot(game)},"\t"))
			if visible!=Rect2(game.camera_offset,field): faults.append("culling field: "+name)
			if matrix.get_scale().distance_to(Vector2.ONE*float(variant.zoom))>0.0001: faults.append("projection scale: "+name)
			if game.NavigationSystem.walkability_reason(game,game.player,-1,true,false)!="walkable": faults.append("blocked player: "+name)
			if (matrix*(game.player-game.camera_offset)).distance_to(Vector2(SIZE)*0.5)>0.001: faults.append("camera center: "+name)
			rows.append({"id":name,"scene":scene.id,"variant":variant.id,"image":name+".png","world_image":name+"-world.png","zoom":variant.zoom,"field":Points.pair(field),
				"player":Points.pair(game.player),"camera_center":Points.pair(scene.player),"camera_origin":Points.pair(game.camera_offset),"hero_canvas_feet":Points.pair(matrix*(game.player-game.camera_offset)),
				"hero_source":_rect(pose.source),"hero_pivot":Points.pair(pose.pivot),"hero_world_rect":_rect(hero_rect),"hero_projected_frame_size":Points.pair(hero_rect.size*float(variant.zoom)),
				"visible_world":_rect(visible),"logical_viewport":Points.pair(game.get_viewport_rect().size),"world_readback":Points.pair(world_view.get_texture().get_image().get_size()),
				"projection":[Points.pair(matrix.x),Points.pair(matrix.y),Points.pair(matrix.origin)],"physical_before":before,"physical_after":after,"conditions":_window_state()})
			print("SCALE CAPTURE: ",name)
			layer.free(); world_view.free(); await process_frame
		hud_layer.free(); hud_view.free(); await process_frame
	for variant in VARIANTS: await _hero_samples(variant)
	var report:={"schema":1,"kind":"native-fov-study","performance_eligible":false,"simulation_frozen":true,"profile":profile,"points":rows,"errors":faults,
		"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_driver_name(),"adapter":RenderingServer.get_video_adapter_name(),
		"compositing":"native SubViewport world projection + independent native HUD; no image resizing/cropping","hud_size":[1152,648],"disabled_effects":Reference.EFFECTS,"input_enabled":false}
	FileAccess.open(folder.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	for fault in faults: push_error(fault)
	quit(0 if faults.is_empty() else 2)

## Создаёт физический target 1152×648 с отдельным логическим полем мира для настоящего GPU-масштаба.
func _viewport(field: Vector2i, transparent: bool) -> SubViewport:
	var viewport:=SubViewport.new(); viewport.size=SIZE; viewport.size_2d_override=field; viewport.size_2d_override_stretch=true
	viewport.transparent_bg=transparent; viewport.disable_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport); return viewport

## Показывает нативную текстуру без повторного увеличения в окне базового размера.
func _layer(viewport: SubViewport) -> TextureRect:
	var layer:=TextureRect.new(); layer.texture=viewport.get_texture(); layer.size=Vector2(SIZE)
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; root.add_child(layer); return layer

## Создаёт одинаковую игровую сцену и детерминированную витрину моркови без расходования ресурсов игрока.
func _game(viewport: SubViewport, scene: Dictionary, hud_only: bool) -> Node2D:
	var game:=Points.create_game()
	if hud_only: game.set_script(HudOnly)
	viewport.add_child(game)
	var point:Dictionary=Points.registry().points[0].duplicate(true); point.player=Points.pair(scene.player)
	Points.configure(game,point)
	if scene.id=="farm":
		for cell in game.plots:
			var plot:Dictionary=game.plots[cell]; plot.tilled=true; plot.watered=true; plot.planted=true
			plot.stage=posmod(cell.x+cell.y,5); plot.growth=plot.stage*game.CropCatalogSystem.stage_duration("carrot")
	# Прогреваем настоящую навигацию до фиксации слепка состояния.
	game.NavigationSystem.walkability_reason(game,game.player,-1,true,false)
	game.SpellSystem.state(game)
	if hud_only: game.get_node("WorldBackground").hide()
	else: Reference.enable(game,false)
	return game

## Фиксирует реальное состояние физики и сохранения, чтобы проекция не могла незаметно уменьшить коллизию.
func _physical(game: Node) -> Dictionary:
	return {"player":Points.pair(game.player),"radius":game.PLAYER_RADIUS,"speed":game.speed,"energy":game.energy,"hp":game.player_hp,
		"save_sha256":JSON.stringify(game.SaveSystem.snapshot(game)).sha256_text(),"physics_processing":game.is_physics_processing()}

## Снимает прозрачные позы героя в трёх направлениях для просмотра на светлом и тёмном фоне.
func _hero_samples(variant: Dictionary) -> void:
	var view:=SubViewport.new(); view.size=Vector2i(576,192); view.transparent_bg=true; view.disable_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var canvas:=HeroSamples.new(); canvas.zoom=variant.zoom; view.add_child(canvas)
	for frame in 8: canvas.queue_redraw(); await RenderingServer.frame_post_draw
	if view.get_texture().get_image().save_png(folder.path_join("hero-"+variant.id+".png"))!=OK: faults.append("hero PNG")
	view.free(); await process_frame

## Отклоняет неподтверждённый размер, режим или потерю фокуса нативного окна.
func _conditions() -> bool:
	return DisplayServer.window_get_size()==SIZE and root.get_texture().get_image().get_size()==SIZE and DisplayServer.window_is_focused() and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED

## Сохраняет фактические условия без подмены размера Image размером ViewportTexture.
func _window_state() -> Dictionary:
	return {"window":Points.pair(DisplayServer.window_get_size()),"readback":Points.pair(root.get_texture().get_image().get_size()),"focused":DisplayServer.window_is_focused(),"mode":DisplayServer.window_get_mode()}

## Кодирует прямоугольник как четыре числовых компонента без округления измерений.
func _rect(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

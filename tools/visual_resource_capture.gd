extends SceneTree

const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Art := preload("res://scripts/presentation/house_furniture_visual_system.gd")
var output := OS.get_environment("VRESOURCE_OUTPUT")
var game: Node
var gallery: Node2D
var faults: Array = []

## Изолирует нативную проверку паспорта от профиля игрока и запрещает перезапись снимка.
func _initialize() -> void:
	var profile := OS.get_environment("VRESOURCE_PROFILE")
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VPIPELINE-002-") or "/" in profile or "\\" in profile:
		push_error("Нужны новые output и профиль VPIPELINE-002"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает настоящую комнату и три ракурса реальным игровым помощником отрисовки.
func _start() -> void:
	if DisplayServer.get_name()=="headless" or FileAccess.file_exists("user://farm-settings.cfg"):
		push_error("Нужны графический движок и свежий профиль"); quit(2); return
	var point: Dictionary
	for candidate in Points.registry().points:
		if candidate.location=="cottage_interior": point=candidate; break
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO; root.content_scale_factor=1.0
	game=Points.create_game(); root.add_child(game); current_scene=game; Points.configure(game,point); Reference.enable(game,true)
	faults.append_array(game.ContentRegistry.validate())
	if not faults.is_empty(): push_error(str(faults)); quit(2); return
	await create_timer(2.0).timeout
	root.mode=Window.MODE_WINDOWED; root.size=Points.SIZE
	DirAccess.make_dir_recursive_absolute(output)
	await _redraw(); _save("room")
	var rows := []
	for direction in [0,1,3]:
		var source := Art.source("rustic_table",direction)
		var bounds: Vector2 = game.FarmLifeVisualSystem.profile("rustic_table",direction).visual
		var target := Art.destination("rustic_table",Vector2.ZERO,bounds,direction)
		var texture := Art.texture("rustic_table",direction)
		rows.append({"direction":direction,"path":texture.resource_path,"pixels":[texture.get_width(),texture.get_height()],"source":[source.position.x,source.position.y,source.size.x,source.size.y],"logical_size":[bounds.x,bounds.y],"draw_size":[target.size.x,target.size.y],"footprint":Points.pair(game.FarmLifeVisualSystem.profile("rustic_table",direction).collision)})
	gallery=Gallery.new(); gallery.game=game; root.add_child(gallery)
	await _redraw(); _save("gallery")
	await _strip()
	var data := Points.snapshot(game,point)
	faults.append_array(Points.errors(game,point))
	data.merge({"rows":rows,"framebuffer":[root.size.x,root.size.y],"engine":Engine.get_version_info().string,"profile":OS.get_user_data_dir().get_file(),"filter":ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),"errors":faults,"performance_eligible":false})
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t")+"\n")
	print("RESOURCE CAPTURE: ",output); quit(0 if data.errors.is_empty() else 2)

## Выполняет настоящий readback даже когда окно не находится на переднем плане.
func _redraw() -> void:
	for index in 20:
		game.queue_redraw(); if gallery!=null: gallery.queue_redraw()
		await process_frame; RenderingServer.force_draw(false)

## Сохраняет только целый framebuffer требуемого размера.
func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_size()!=Points.SIZE or image.save_png(output.path_join(name+".png"))!=OK: faults.append("Invalid native frame: "+name)

## Снимает компактную нативную иллюстрацию Wiki отдельным viewport без изменения основного доказательства.
func _strip() -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(1152,220)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter=root.canvas_item_default_texture_filter
	root.add_child(viewport)
	var content := Gallery.new(); content.game=game; content.position.y=-260; viewport.add_child(content)
	await _redraw()
	var image := viewport.get_texture().get_image()
	if image.get_size()!=Vector2i(1152,220) or image.save_png(output.path_join("gallery-strip.png"))!=OK: faults.append("Invalid native strip")
	viewport.queue_free()

class Gallery extends Node2D:
	var game: Node

	## Показывает три реальных вида стола с одинаковой камерой, логическими рамками и точками опоры.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),Color("eee3c5"))
		draw_string(game.UI_FONT,Vector2(40,55),"VPIPELINE-002 · стабильный ID и три ракурса",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("493721"))
		for index in 3:
			var direction: int = [0,1,3][index]
			var position := Vector2(240+index*336,370)
			var bounds: Vector2 = game.FarmLifeVisualSystem.profile("rustic_table",direction).visual
			var target := Rect2(position-Vector2(bounds.x*0.5,bounds.y),bounds)
			draw_rect(target,Color("b19e74"),false,1.0)
			Art.draw(self,"rustic_table",position,bounds,direction)
			draw_line(position-Vector2(6,0),position+Vector2(6,0),Color("a85340"),1.0)
			draw_line(position-Vector2(0,6),position+Vector2(0,6),Color("a85340"),1.0)
			draw_string(game.UI_FONT,position+Vector2(-90,50),["Вниз","Влево","Вправо"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("493721"))

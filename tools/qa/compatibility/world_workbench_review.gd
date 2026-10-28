extends "res://tools/qa/compatibility/farm_cursor_review.gd"

const Art := preload("res://scripts/presentation/world_workbench_visual_system.gd")
var phase: String
var gallery: Node2D

## Создаёт клавиатурное событие для существующих проверок размещения и карты районов.
func key_event(keycode: Key, physical_keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new(); event.keycode=keycode; event.physical_keycode=physical_keycode; event.pressed=pressed; return event

## Проверяет существующие ремесленные сценарии либо снимает реальные верстаки в двух локациях.
func _initialize() -> void:
	if DisplayServer.get_name()=="headless":
		preload("res://tests/suites/front_facing_suite.gd").new(self).run()
		preload("res://tests/suites/village_regions_suite.gd").new(self).run()
		print("WORLD WORKBENCH REVIEW: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)
	else: _capture_workbenches.call_deferred()

## Использует отдельную сцену без пользовательских сохранений для одинаковых кадров до и после исправления.
func _capture_workbenches() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-World-Workbench-Review")
	var container := SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.selected_tool=game.Tool.HAND; game.settings_state.screen_shake_enabled=false
	phase=OS.get_environment("FARM_WORKBENCH_PHASE"); if phase.is_empty(): phase="before"
	game.current_location="overworld"; game.player=game.workbench_position+Vector2(0,96); game.facing=Vector2.UP
	game.sync_background_location(); game.update_camera(); await capture(phase+"-farm")
	game.current_location="village_workyard"; game.player=Vector2(1440,864)
	game.sync_background_location(); game.update_camera(); await capture(phase+"-workyard")
	if phase=="after":
		game.hide(); gallery=Node2D.new(); viewport.add_child(gallery); gallery.draw.connect(_draw_gallery)
		await capture("directions")
	print("WORLD WORKBENCH NATIVE: "+phase); quit()

## Сохраняет полный нативный кадр без обрезки и графической обработки.
func capture(label: String) -> void:
	var folder := "res://docs/reports/world-workbench-2026-10-14/"; DirAccess.make_dir_recursive_absolute(folder)
	for _frame in 4:
		game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
		if gallery!=null: gallery.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(folder+label+".png")!=OK: push_error("Не удалось сохранить "+label)

## Показывает три настоящих рабочих ракурса в игровом размере и увеличенном контрольном масштабе.
func _draw_gallery() -> void:
	gallery.draw_rect(Rect2(0,0,1152,648),Color("f4e5c6"))
	var font := ThemeDB.fallback_font
	gallery.draw_string(font,Vector2(32,44),"Верстак · согласованный ремесленный набор A",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("4b3526"))
	var directions := [0,1,3]; var labels := ["Вниз","Влево","Вправо"]
	for index in 3:
		var ground := Vector2(192+index*384,224)
		gallery.draw_string(font,ground+Vector2(-80,-104),labels[index],HORIZONTAL_ALIGNMENT_CENTER,160,20,Color("4b3526"))
		Art.draw(gallery,ground,directions[index])
		var enlarged := Art.destination(ground,directions[index]); enlarged.size*=2.5
		enlarged.position=Vector2(ground.x-enlarged.size.x/2,548-enlarged.size.y)
		gallery.draw_texture_rect(Art.texture(directions[index]),enlarged,false)

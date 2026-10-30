extends SceneTree

const Scene := preload("res://main.tscn")
const Loot := preload("res://scripts/systems/dropped_loot_system.gd")
var game:Node2D
var viewport:SubViewport
const FOLDER := "res://docs/reports/dropped-loot-2026-10-14/"

## Поднимает отдельный нативный стенд, не читая пользовательские слоты.
func _initialize() -> void:
	_start.call_deferred()

## Снимает движение и фактическое изменение счётчика без нажатия кнопки взаимодействия.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Dropped-Loot-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.current_location="cottage_interior"; game.player=Vector2(576,500)
	game.state.inventory.counts.stone=10; game.hotbar_slots[0]="stone"; game.selected_hotbar=0
	game.dropped_items=[{"kind":"stone","count":4,"location":game.current_location,"position":game.player-Vector2(80,0)}]
	game.sync_background_location(); game.update_camera(); DirAccess.make_dir_recursive_absolute(FOLDER)
	await capture("before"); Loot.update(game,0.08); await capture("attracting")
	if game.dropped_items.is_empty(): push_error("Добыча выдана до контакта"); quit(1); return
	Loot.update(game,0.25); await capture("collected")
	if not game.dropped_items.is_empty() or game.inventory_item_count("stone")!=14: push_error("Автоподбор не выдал точное количество"); quit(1); return
	print("DROPPED LOOT NATIVE: magnet moves icon, contact receives 10 + 4 = 14 without E"); quit()

## Сохраняет полный необработанный кадр нативного viewport после перерисовки.
func capture(label:String) -> void:
	for _frame in 4:
		game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(FOLDER+label+".png")!=OK: push_error("Не удалось сохранить "+label)

extends SceneTree

const Scene := preload("res://main.tscn")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
const Controls := preload("res://scripts/systems/dev_cabinet_input.gd")
const Render := preload("res://scripts/presentation/dev_cabinet_renderer.gd")
var game:Node2D
var viewport:SubViewport
var failed:=0

## Создаёт отдельный графический стенд для настоящих кадров шкафа снабжения.
func _initialize() -> void:
	_start.call_deferred()

## Снимает физический шкаф, все категории, поиск, выдачу, увеличенный текст и отключение перед релизом.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Dev-Cabinet-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION; game.sync_background_location(); game.update_camera()
	await capture("house")
	if not game.perform_context_action() or not Cabinet.active(game): failed+=1; push_error("Не удалось открыть шкаф обычным действием")
	await capture("all")
	Cabinet.select_tab(game,1); Controls.query(game,"plank")
	Controls.pointer(game,Render.take_rect(2).get_center())
	if game.inventory_item_count("plank")!=100 or int(Cabinet.state(game).stock.plank)!=899: failed+=1; push_error("Неверное количество после выдачи 100 досок")
	await capture("craft-search")
	Controls.query(game,""); Cabinet.select_tab(game,3); await capture("alchemy")
	game.LocaleSystem.current="de"; game.settings_state.text_scale=1.2; Cabinet.select_tab(game,2); await capture("food-de-120")
	game.LocaleSystem.current="ru"; game.settings_state.text_scale=1; Controls.query(game,"no_such_item"); await capture("empty-search")
	Cabinet.close(game); ProjectSettings.set_setting(Cabinet.SETTING,false); await capture("disabled")
	ProjectSettings.set_setting(Cabinet.SETTING,true)
	print("DEV CABINET CAPTURE: "+("PASS" if failed==0 else "FAIL")); quit(0 if failed==0 else 1)

## Сохраняет исходный кадр GPU без изменения масштаба и проверяет успешную запись.
func capture(label: String) -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	for _frame in 8: game.queue_redraw(); await process_frame; RenderingServer.force_draw()
	var image:=viewport.get_texture().get_image()
	if image.get_size()!=Vector2i(1152,648) or image.save_png("res://docs/reports/dev-cabinet-2026-10-13-"+label+".png")!=OK: failed+=1
	print("DEV CABINET FRAME: "+label)

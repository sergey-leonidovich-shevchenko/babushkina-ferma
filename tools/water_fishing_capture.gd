extends SceneTree

const Scene := preload("res://main.tscn")
const Rod := preload("res://scripts/systems/fishing_system.gd")
var game: Node2D
var viewport: SubViewport
const FOLDER := "res://docs/reports/water-2026-10/fishing-11/"

## Откладывает создание нативной сцены до готовности графического окна.
func _initialize() -> void:
	start.call_deferred()

## Снимает реальные игровые состояния в фиксированном кадре, не выдавая остановленную симуляцию за замер FPS.
func start() -> void:
	if DisplayServer.get_name()=="headless": push_error("Нужен нативный renderer"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Water-Fishing-Capture")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()); DirAccess.make_dir_recursive_absolute(FOLDER)
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game)
	game.set_physics_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	game.audio_enabled=false; game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.FarmLifeSystem.state(game).first_day=6; game.FarmLifeSystem.state(game).cutscene=""
	game.FirstChapterSystem.state(game).completed=true; game.has_fishing_rod=true
	game.enemy_nodes.clear(); game.slime_alive=false; game.hazard_nodes.clear(); game.state.world.estate.event=""
	var fixtures: Array=[
		["home-horizontal","overworld",Vector2(144,396)],
		["home-vertical","overworld",Vector2(900,720)],
		["home-pond","overworld",Vector2(1992,888)],
		["home-bridge","overworld",Vector2(864,456)],
		["district-west","village_river",Vector2(864,696)],
		["district-east","village_river",Vector2(1152,696)]]
	var report: Array=[]
	for fixture in fixtures:
		Rod.cancel(game); game.current_location=fixture[1]; game.player=fixture[2]; game.sync_background_location(); game.update_camera()
		game.discovery_current.clear(); game.message=""; game.action_held=true
		if not Rod.use_rod(game): push_error("Не начался заброс "+fixture[0]); quit(1); return
		game.state.fishing.cast_power=0.6; game.action_held=false; Rod.update(game,0.016); game.HeroActionSystem.update(game,1)
		if game.state.fishing.phase!="waiting": push_error("Не выпущен поплавок "+fixture[0]); quit(1); return
		await capture(fixture[0]+"-waiting")
		game.state.fishing.phase="bite"; game.state.fishing.timer=0.9; game.state.fishing.visual_time=0.3
		await capture(fixture[0]+"-bite")
		if fixture[0]=="district-west":
			game.settings_state.reduced_motion=true; await capture("district-west-reduced-bite"); game.settings_state.reduced_motion=false
		report.append({"case":fixture[0],"location":game.current_location,"hero":[game.player.x,game.player.y],"bobber":[game.state.fishing.cast_target.x,game.state.fishing.cast_target.y],"direction":str(game.get_meta("fish_visual_direction")),"water":game.state.fishing.water_kind})
	FileAccess.open(FOLDER+"capture.json",FileAccess.WRITE).store_string(JSON.stringify({"render_pixels":[1152,648],"simulation":"stopped for deterministic native visual capture; not a performance measurement","cases":report},"\t")+"\n")
	print("WATER FISHING CAPTURE: ",report.size()," native cases"); quit()

## Сохраняет целый framebuffer без обрезки или изменения пикселей.
func capture(label: String) -> void:
	for frame in 5:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	if viewport.get_texture().get_image().save_png(FOLDER+label+".png")!=OK: push_error("Не записан кадр "+label)

extends SceneTree

const OUT := "/Users/sergeyshevchenko/my farm/docs/concepts/farmyard-2026-10/v2/"

class ReviewGame extends "res://scripts/game.gd":
	## Отключает автоматическую загрузку настроек и сохранений на изолированном визуальном стенде.
	func _ready() -> void:
		pass

## Снимает фактический двор после подготовки игрового дерева.
func _initialize() -> void:
	capture.call_deferred()

## Использует одинаковое зерно, камеру и освещение для сравнения и показывает отдельный ночной кадр.
func capture() -> void:
	var stage := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	for mode in ["yard","overview","night"]:
		if stage=="before" and mode=="night": continue
		var viewport:=SubViewport.new(); viewport.size=Vector2i(2400,1368) if mode=="overview" else Vector2i(1152,648)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game:=preload("res://main.tscn").instantiate(); game.set_script(ReviewGame)
		game.world_loot_seed=20261011; game.audio_enabled=false
		game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
		viewport.add_child(game); game.set_process(false); game.set_physics_process(false)
		game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.message=""; game.discovery_current.clear(); game.discovery_timer=0
		game.current_location="overworld"; game.day=1; game.game_minutes=1260 if mode=="night" else 720
		game.state.world.weather="clear"; game.state.world.weather_day=1; game.state.world.estate.event=""
		game.FarmLifeSystem.state(game).cutscene=""; game.player=Vector2(948,1104)
		game.sync_background_location(); game.camera_offset=Vector2.ZERO if mode=="overview" else Vector2(300,720)
		game.get_node("WorldBackground").position=-game.camera_offset
		game.set_meta("capture_first_level_clean",true); game.queue_redraw()
		for _frame in 8: await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(OUT+stage+"-"+mode+".png")==OK)
		viewport.queue_free(); await process_frame
	quit()

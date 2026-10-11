extends SceneTree

const OUT := "res://docs/reports/five-priorities-2026-10-11/village/"

class ReviewGame extends "res://scripts/game.gd":
	## Снимает фиксированный мир без загрузки настроек и случайного зерна мировой добычи.
	func _ready() -> void:
		pass

## Снимает фактический тесный коридор и общий план перед изменением геометрии.
func _initialize() -> void:
	capture.call_deferred()

## Использует игровую сцену и неизменные координаты камеры для честного сравнения до и после.
func capture() -> void:
	var stage := "before"
	if "--after" in OS.get_cmdline_user_args(): stage="after"
	for name in ["guild","overview"]:
		var viewport := SubViewport.new(); viewport.size=Vector2i(1152,648) if name=="guild" else Vector2i(2400,1200)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game := preload("res://main.tscn").instantiate(); game.set_script(ReviewGame)
		game.world_loot_seed=20261011; game.audio_enabled=false
		game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
		viewport.add_child(game)
		game.set_process(false); game.set_physics_process(false)
		game.language_screen=false; game.title_screen=false; game.current_location="overworld"
		game.day=1; game.game_minutes=720; game.tutorial_visible=false; game.discovery_current.clear(); game.discovery_timer=0; game.message=""
		game.state.world.estate.event=""; game.FarmLifeSystem.state(game).cutscene=""
		game.state.world.weather="clear"; game.state.world.weather_day=1
		game.player=Vector2(1992,432); game.sync_background_location()
		game.camera_offset=Vector2(1248,120) if name=="guild" else Vector2.ZERO
		game.get_node("WorldBackground").position=-game.camera_offset
		game.set_meta("capture_first_level_clean",true); game.queue_redraw()
		for _frame in 8: await RenderingServer.frame_post_draw
		print("VILLAGE ",stage," ",name,": ",viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+stage+"-"+name+".png")))
		viewport.queue_free(); await process_frame
	if stage=="after": await comparison()
	quit()

## Складывает исходные игровые кадры рядом, сохраняя их размер и общую камеру.
func comparison() -> void:
	var viewport := SubViewport.new(); viewport.size=Vector2i(2304,696); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var textures: Array[Texture2D] = []
	for kind in ["before","after"]: textures.append(ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(OUT+kind+"-guild.png"))))
	var board := Node2D.new(); viewport.add_child(board)
	board.draw.connect(func():
		board.draw_rect(Rect2(0,0,2304,696),Color("14251f"))
		for index in 2:
			board.draw_texture(textures[index],Vector2(index*1152,48))
			board.draw_string(ThemeDB.fallback_font,Vector2(index*1152+24,32),"БЫЛО: проход 36 px" if index==0 else "СТАЛО: проход 84 px · фонарь вне дороги",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("e8ecd7"))
	)
	board.queue_redraw()
	for frame in 8: await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"comparison.png"))==OK)
	viewport.queue_free(); await process_frame

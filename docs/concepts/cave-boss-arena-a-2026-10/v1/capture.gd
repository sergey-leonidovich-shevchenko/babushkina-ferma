extends SceneTree

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")
const Data := preload("res://scripts/systems/cave_boss_arena_data.gd")
const OUT := "res://docs/concepts/cave-boss-arena-a-2026-10/v1/"

## Снимает выбранную арену через настоящую игровую сцену.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет общий план, пробуждение, бой и открытый выход после победы.
func capture() -> void:
	for scenario in ["overview","sleeping","phase1","phase3","victory"]: await shot(scenario)
	await comparison()
	quit()

## Захватывает согласованный кадр после завершения реальной отрисовки Godot.
func shot(scenario: String) -> void:
	seed(20261011)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2400,1350) if scenario=="overview" else Vector2i(1152,648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var game := preload("res://main.tscn").instantiate(); viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	Boss.configure_preview(game); game.player = Data.CENTER+Vector2(-216,24)
	game.discovery_current.clear(); game.discovery_timer = 0.0; game.message = ""; game.set_meta("capture_hud_clean",true)
	if scenario in ["sleeping","overview"]: game.player = Data.ALTAR+Vector2(72,24)
	else:
		game.player = Data.ALTAR+Vector2(0,72); Arena.activate(game); game.player = Data.CENTER+Vector2(-216,24)
		var index := Boss.index(game)
		if scenario=="phase1": Boss.Attacks.begin(game,"slam",game.enemy_nodes[index]); Boss.Attacks.update(game,index,0.68)
		elif scenario=="phase3":
			game.CombatSystem.apply_damage(game,index,88)
			Boss.Attacks.begin(game,"cross",game.enemy_nodes[index]); Boss.Attacks.update(game,index,0.68)
			Boss.Minions.summon(game,["skeleton","zombie","vampire"])
			for minion in game.state.world.cave_boss.minions: minion.emerge = 0.0
		else:
			game.CombatSystem.apply_damage(game,index,200); game.player = Data.CHEST+Vector2(0,72)
	game.message = ""; game.sync_background_location(); game.update_camera()
	if scenario=="overview":
		game.camera_offset = Vector2(0,-72); game.get_node("WorldBackground").position = -game.camera_offset
		game.set_meta("capture_first_level_clean",true)
	game.queue_redraw()
	for _frame in 8: await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+scenario+".png"))
	print("ARENA CAPTURE: ",scenario," result=",error)
	viewport.queue_free(); await process_frame

## Собирает два игровых скриншота в сравнительный лист без изменения самих кадров.
func comparison() -> void:
	var viewport := SubViewport.new(); viewport.size = Vector2i(2304,696)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var canvas := Node2D.new(); viewport.add_child(canvas)
	var textures: Array[Texture2D] = []
	for filename in ["before.png","phase1.png"]: textures.append(ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(OUT+filename))))
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0,0,2304,696),Color("141820"))
		for index in 2:
			canvas.draw_texture(textures[index],Vector2(index*1152,48))
			canvas.draw_string(ThemeDB.fallback_font,Vector2(index*1152+24,33),"БЫЛО" if index==0 else "СТАЛО — А: СЕРДЦЕ ГЛУБИН",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("d6d9cc"))
	)
	canvas.queue_redraw()
	for _frame in 8: await RenderingServer.frame_post_draw
	print("ARENA COMPARISON: ",viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"comparison.png")))
	viewport.queue_free(); await process_frame

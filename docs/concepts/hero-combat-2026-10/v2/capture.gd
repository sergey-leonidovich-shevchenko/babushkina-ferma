extends SceneTree

const OUT := "res://docs/concepts/hero-combat-2026-10/v2/"
const Combat := preload("res://scripts/systems/hero_combat_visual_system.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")

class Board extends Node2D:
	## Показывает реальные игровые кадры с общей линией стоп, а не отдельный художественный макет.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,1300),Color("18241e"))
		var row := 0
		for kind in ["blade","spear","bow"]:
			for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
				var y := 110+row*98
				draw_string(ThemeDB.fallback_font,Vector2(20,y-24),kind+" "+str(direction),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d5d8bd"))
				for column in 4:
					var ground := Vector2(360+column*210,y)
					draw_line(ground-Vector2(50,0),ground+Vector2(50,0),Color("6c7861"))
					Visual.draw_pose(self,ground,Combat.pose(kind,direction,[0.05,0.3,0.68,0.95][column]))
				row += 1

## Запускает съёмку после готовности графического дерева.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет покадровую витрину и три кадра настоящей сцены с новым телом героя.
func capture() -> void:
	Visual.warmup()
	var viewport := SubViewport.new(); viewport.size=Vector2i(1152,1300)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	viewport.add_child(Board.new())
	await save(viewport,"frames.png")
	viewport.queue_free(); await process_frame
	for pair in [["blade","forest_sword"],["spear","iron_spear"],["bow","bow"]]:
		viewport=SubViewport.new(); viewport.size=Vector2i(1152,648)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game := preload("res://main.tscn").instantiate(); viewport.add_child(game)
		game.set_process(false); game.set_physics_process(false)
		game.CaveBossSystem.configure_preview(game); preload("res://scripts/systems/cave_boss_arena_system.gd").activate(game)
		game.player=Vector2(1320,720); game.facing=Vector2.RIGHT; game.equipped_weapon=pair[1]
		game.WeaponSystem.begin_attack(game,true)
		game.player_attack_timer=game.WeaponSystem.attack_duration(game)*0.32
		game.message=""; game.tutorial_visible=false; game.sync_background_location(); game.update_camera(); game.queue_redraw()
		await save(viewport,pair[0]+"-ingame.png")
		viewport.queue_free(); await process_frame
	quit()

## Ждёт фактическую отрисовку и сохраняет исходный GPU-кадр без внешней обработки.
func save(viewport: SubViewport, filename: String) -> void:
	for _frame in 8: await RenderingServer.frame_post_draw
	print("HERO CAPTURE ",filename,": ",viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+filename)))

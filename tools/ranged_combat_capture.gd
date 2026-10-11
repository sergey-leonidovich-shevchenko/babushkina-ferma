extends SceneTree

const OUT := "res://docs/concepts/skeleton-2026-10-12/v2/"

class ReviewGame extends "res://scripts/game.gd":
	## Сохраняет пользовательские настройки и слоты вне изолированного визуального стенда.
	func _ready() -> void:
		pass

	## Добавляет подпись проверяемого сценария к настоящему игровому кадру.
	func _draw() -> void:
		if get_meta("review_mode","")=="poses":
			draw_set_transform(Vector2.ZERO)
			draw_texture_rect(preload("res://assets/game/tiles/cave-floor.png"),Rect2(0,0,1152,1024),true)
			for enemy in enemy_nodes: AnimationRenderer.draw_enemy(self,enemy)
		else: super._draw()
		draw_set_transform(Vector2.ZERO)
		draw_ui_string(UI_FONT,Vector2(24,42),String(get_meta("review_label","")),HORIZONTAL_ALIGNMENT_LEFT,1000,20,Color("fff0bd"))

## Начинает нативную проверку после подготовки главного окна Godot.
func _initialize() -> void:
	capture.call_deferred()

## Проверяет промах и попадание в реальной пещере, затем показывает всю сетку направлений скелета.
func capture() -> void:
	for mode in ["miss","hit","poses"]:
		var viewport:=SubViewport.new(); viewport.size=Vector2i(1152,648) if mode!="poses" else Vector2i(1152,1024)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var game:=preload("res://main.tscn").instantiate(); game.set_script(ReviewGame)
		game.world_loot_seed=20261012; game.audio_enabled=false
		game.GameBootstrap._initialize_services(game); game.GameBootstrap._initialize_world(game); game.GameBootstrap._initialize_runtime_systems(game)
		viewport.add_child(game); game.set_process(false); game.set_physics_process(false)
		game.title_screen=false; game.language_screen=false; game.tutorial_visible=false; game.message=""; game.discovery_current.clear(); game.discovery_timer=0
		game.FarmLifeSystem.state(game).cutscene=""; game.FirstChapterSystem.state(game).completed=true
		game.current_location="cave"; game.player=Vector2(1080,520)
		var enemy: Dictionary=game.CombatSystem.default_enemies().filter(func(value): return value.kind=="skeleton")[0]
		enemy.position=Vector2(880,520); enemy.location="cave"; enemy.level=2; enemy.direction=Vector2.RIGHT; enemy.action_target=game.player; enemy.action_kind="shoot"
		game.enemy_nodes=[enemy]; game.set_meta("capture_first_level_clean",true)
		game.set_meta("review_mode",mode)
		game.sync_background_location(); game.camera_offset=Vector2(432,240) if mode!="poses" else Vector2.ZERO
		game.get_node("WorldBackground").position=-game.camera_offset
		if mode=="poses":
			game.enemy_nodes=[]; game.player=Vector2(2300,1100)
			for row in 8:
				for column in 6:
					var actor:=enemy.duplicate(true); actor.position=Vector2(104+column*184,170+row*112); actor.direction=Vector2(-sin(row*TAU/8),cos(row*TAU/8))
					actor.visual_state="idle" if column<3 else "attack"; actor.visual_time=(column%3+0.2)*game.AnimationSystem.ENEMY_ATTACK_DURATION/3.0 if column>=3 else float(column)/game.EnemyAnimationLibrary.WALK_FPS; actor.moving=column<3
					game.enemy_nodes.append(actor)
			game.set_meta("review_label","Скелет: 8 направлений × 3 шага и 3 стадии выстрела")
		else:
			if mode=="miss": game.player+=Vector2(0,80)
			game.CombatSystem.Projectiles.launch(game,enemy); game.CombatSystem.Projectiles.update(game,0.45)
			assert((game.player_hp==100)==(mode=="miss"))
			game.set_meta("review_label",("Промах: уход с линии стрелы" if mode=="miss" else "Попадание: контакт со снарядом")+" · HP %d"%game.player_hp)
			print("RANGED CAPTURE: %s hp=%d shots=%d"%[mode,game.player_hp,game.CombatSystem.Projectiles.state(game).size()])
		game.queue_redraw()
		for frame in 8: await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+mode+".png"))==OK)
		viewport.queue_free(); await process_frame
	quit()

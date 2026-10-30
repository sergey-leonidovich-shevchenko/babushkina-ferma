extends "res://tools/qa/compatibility/paper_theme_capture.gd"

class ReviewGame extends "res://scripts/game.gd":
	## Добавляет выбранный рисунок только в отдельный макет, не изменяя игровые ресурсы хранителя.
	func _draw() -> void:
		super._draw()
		if not has_meta("guardian_concept"): return
		var drawing:Dictionary=get_meta("guardian_concept")
		var source:Rect2=drawing.source; var height:=96.0; var size:=source.size*(height/source.size.y)
		draw_set_transform(-camera_offset)
		draw_texture_rect_region(drawing.texture,Rect2(Vector2(990,480)-size*Vector2(0.5,1),size),source)
		draw_set_transform(Vector2.ZERO)
		preload("res://scripts/presentation/moon_theme.gd").panel(self,Rect2(348,94,456,40))
		draw_ui_string(UI_FONT,Vector2(360,119),String(drawing.label),HORIZONTAL_ALIGNMENT_CENTER,432,15,Color("463c2b"))

## Снимает исправленный рисунок, состояния боя и отдельные художественные макеты без слотов пользователя.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Depth-Guardian-20261014")
	folder="res://docs/concepts/depth-guardian-2026-10-14/v1/"
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport); current_scene=container
	for label in ["whole","attack","hurt","death","bestiary","concept-a","concept-b"]:
		if is_instance_valid(game): game.free()
		game=Scene.instantiate(); game.set_script(ReviewGame); game.set_meta("capture_windowed",true); viewport.add_child(game)
		game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
		configure("bestiary" if label=="bestiary" else "hud")
		if label!="bestiary":
			game.current_location="cave"; game.player=Vector2(1080,520)
			var enemy:Dictionary=game.CombatSystem.default_enemies().filter(func(value): return value.kind=="cave_guardian")[0].duplicate(true)
			enemy.position=Vector2(990,480); enemy.home=enemy.position; enemy.location="cave"; enemy.level=2; enemy.direction=Vector2.RIGHT; enemy.action_target=game.player
			enemy.hurt_direction=Vector2.LEFT; game.enemy_nodes=[enemy]; game.hazard_nodes.clear()
			if label.begins_with("concept"):
				game.enemy_nodes.clear()
				var variant:String=String(label).right(1)
				var source:=Rect2(70,12,498,484) if variant=="a" else Rect2(22,8,542,500)
				game.set_meta("guardian_concept",{"texture":ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(folder+"sources/"+variant+"-board.png"))),"source":source,"label":"Макет "+variant.to_upper()+" · рисунок ещё не подключён в игру"})
			game.sync_background_location(); game.update_camera()
			enemy.visual_state=label if label in ["attack","hurt","death"] else "idle"
			enemy.visual_time=game.AnimationSystem.ENEMY_ATTACK_DURATION*0.5 if label=="attack" else 0.4
			if label=="death": enemy.alive=false
		for _frame in 5:
			game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
			await process_frame; RenderingServer.force_draw()
		if viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder+label+".png"))!=OK: push_error("Не сохранён кадр хранителя "+label)
		print("GUARDIAN FRAME: "+label)
	print("GUARDIAN CAPTURE: PASS"); quit()

extends "res://tools/paper_theme_capture.gd"

const OUTPUT:="res://docs/reports/skeleton-aim-2026-10-14/"

class ReviewGame extends "res://scripts/game.gd":
	## Показывает исправленные направления настоящим рендерером либо подписывает реальный полёт стрелы.
	func _draw() -> void:
		if has_meta("aim_matrix"):
			_draw_matrix(); return
		super._draw()
		if not has_meta("aim_label"): return
		draw_set_transform(Vector2.ZERO)
		var style:=preload("res://scripts/presentation/moon_theme.gd")
		style.panel(self,Rect2(300,94,552,44))
		style.text(self,Rect2(312,101,528,30),String(get_meta("aim_label")),14,style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)

	## Сравнивает старый ряд с тремя исправленными фазами на восьми направлениях без редактирования PNG.
	func _draw_matrix() -> void:
		var style:=preload("res://scripts/presentation/moon_theme.gd")
		draw_set_transform(Vector2.ZERO); draw_rect(Rect2(0,0,1152,1100),style.BACKGROUND)
		style.title(self,Rect2(24,20,1104,40),"Скелет · направление лука и три фазы выстрела",24)
		for entry in [[220,"Было: выпуск"],[430,"Натяжение"],[650,"Выпуск"],[870,"После выстрела"]]:
			style.text(self,Rect2(entry[0],62,150,28),entry[1],13,style.TEXT,HORIZONTAL_ALIGNMENT_CENTER)
		var labels:=["Вниз","Влево-вниз","Влево","Влево-вверх","Вверх","Вправо-вверх","Вправо","Вправо-вниз"]
		for row in 8:
			var y:=184+row*118; var direction:=Vector2(-sin(row*TAU/8),cos(row*TAU/8))
			if row==1: style.panel(self,Rect2(16,y-92,1120,112),style.SELECTED)
			style.text(self,Rect2(24,y-57,144,24),labels[row],13)
			var arrow_origin:=Vector2(166,y-42)
			draw_line(arrow_origin-direction*9,arrow_origin+direction*12,style.ACCENT,2)
			var tip:=arrow_origin+direction*12; var normal:=direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([tip,tip-direction*7+normal*4,tip-direction*7-normal*4]),style.ACCENT)
			var old_position:=Vector2(295,y); var size:=CreatureVisualProfileSystem.enemy_size(3)
			draw_texture_rect_region(EnemyAnimationLibrary.SKELETON_ACTIONS,CreatureVisualProfileSystem.actor_rect(old_position,size),EnemyAnimationLibrary.source_rect("skeleton",direction,1))
			for column in 3:
				var enemy:Dictionary=enemy_nodes[0].duplicate(true)
				enemy.position=Vector2(505+column*220,y); enemy.level=3; enemy.direction=Vector2.RIGHT
				enemy.action_target=enemy.position+direction*180; enemy.visual_state="attack"; enemy.visual_time=[0.05,0.5,0.95][column]*AnimationSystem.ENEMY_ATTACK_DURATION
				AnimationRenderer.draw_enemy(self,enemy)

## Снимает направление вниз-влево, противоположную диагональ, уход с линии и витрину всех ракурсов в отдельном профиле.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Skeleton-Aim-20261014")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport); current_scene=container
	for label in ["south-west","north-east","evaded","all-directions"]:
		if is_instance_valid(game): game.free()
		viewport.size=Vector2i(1152,1100) if label=="all-directions" else Vector2i(1152,648)
		game=Scene.instantiate(); game.set_script(ReviewGame); game.set_meta("capture_windowed",true); viewport.add_child(game)
		game.set_process(false); game.set_physics_process(false); game.audio_enabled=false; configure("hud")
		game.current_location="cave"
		var enemy:Dictionary=game.CombatSystem.default_enemies().filter(func(value): return value.kind=="skeleton")[0].duplicate(true)
		enemy.location="cave"; enemy.position=Vector2(1080,480); enemy.home=enemy.position; enemy.level=2
		var direction:=Vector2(1,-1) if label=="north-east" else Vector2(-1,1)
		var target:Vector2=enemy.position+direction*100
		game.player=enemy.position+Vector2(230,0) if label=="evaded" else target
		game.enemy_nodes=[enemy]; game.hazard_nodes.clear(); game.sync_background_location(); game.update_camera()
		enemy.action_target=target; enemy.action_kind="shoot"; enemy.direction=Vector2.RIGHT; enemy.visual_state="attack"; enemy.visual_time=0.43
		if label=="all-directions": game.set_meta("aim_matrix",true)
		else:
			game.CombatSystem.Projectiles.launch(game,enemy,0.12)
			game.set_meta("aim_label","Цель влево-вниз · герой ушёл вправо" if label=="evaded" else ("Выстрел влево-вниз" if label=="south-west" else "Выстрел вправо-вверх"))
		for _frame in 5:
			game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
			await process_frame; RenderingServer.force_draw()
		if viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+String(label)+".png"))!=OK: push_error("Не сохранён кадр прицеливания "+String(label))
		print("SKELETON AIM FRAME: "+String(label))
	print("SKELETON AIM CAPTURE: PASS"); quit()

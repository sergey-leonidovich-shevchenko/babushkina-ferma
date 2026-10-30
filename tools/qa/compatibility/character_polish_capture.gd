extends SceneTree

const OUT := "res://docs/concepts/character-polish-2026-10-12/"

class ReviewGame extends "res://scripts/game.gd":
	## Не загружает пользовательские настройки и слоты для контрольного листа персонажей.
	func _ready() -> void:
		pass
	## Рисует семь настоящих персонажей без увеличения и отмечает их логическую точку стоп.
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(0,0,1152,648),Color("445b4b"))
		var names := ["ГЕРОЙ","БАБУШКА","ГИЛЬДИЯ","ТРАВНИЦА","МИЛА","БОРИСЛАВ","ЛУНА"]
		for column in 7: draw_ui_string(UI_FONT,Vector2(50+column*155,34),names[column],HORIZONTAL_ALIGNMENT_CENTER,140,15,Color("efe1b9"))
		for row in 4:
			var direction: Vector2=[Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP][row]
			for column in 7:
				var ground := Vector2(120+column*155,165+row*142)
				draw_rect(Rect2(ground-Vector2(66,115),Vector2(132,135)),Color("e2d2b3"))
				draw_line(ground-Vector2(52,0),ground+Vector2(52,0),Color("3378a0"),1)
				draw_circle(ground,2,Color("d36c33"))
				if column==0: DirectionalCharacterSystem.draw_hero(self,ground,direction,true)
				elif column<4: DirectionalCharacterSystem.draw_npc(self,column-1,ground,direction,true)
				else: DirectionalCharacterSystem.draw_companion(self,["mila","borislav","luna"][column-4],ground,direction,true)

## Начинает нативный сравнительный лист после готовности окна.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет фактическую отрисовку и исходное имя до или после изменений без пользовательских файлов.
func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var game:=preload("res://main.tscn").instantiate(); game.set_script(ReviewGame); game.audio_enabled=false; game.world_loot_seed=20261012
	game.GameBootstrap._initialize_services(game); viewport.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.camera_offset=Vector2.ZERO; game.walk_animation_time=0.125; game.set_meta(game.PlayerSystem.WALK_TIME_META,0.125)
	game.queue_redraw()
	for frame in 8: await RenderingServer.frame_post_draw
	var name := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))==OK)
	quit()

extends SceneTree

const OUT := "res://docs/concepts/character-polish-2026-10-12/"

class ReviewGame extends "res://scripts/game.gd":
	## Сохраняет пользовательские данные вне стенда очистки внешнего цветного канта.
	func _ready() -> void:
		pass
	## Показывает реальные события деревни и портал на светлом фоне для проверки прозрачных краёв.
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO); draw_rect(Rect2(0,0,1152,648),Color("293d33"))
		for column in 4:
			var center:=Vector2(170+column*270,370)
			draw_rect(Rect2(center-Vector2(120,240),Vector2(240,380)),Color("eddfbe"))
			draw_ui_string(UI_FONT,center+Vector2(-110,-265),["ЯРМАРКА","ПРАЗДНИК","ТЕЛЕГА","ПОРТАЛ"][column],HORIZONTAL_ALIGNMENT_CENTER,220,19,Color("f0ddb2"))
			if column<3: WorldPolishRenderer.draw_cell(self,column,1,Rect2(center-Vector2(72,72),Vector2(144,144)))
			else: EnvironmentVisualSystem.draw(self,"moon_portal",center)

## Запускает нативную проверку после готовности окна.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет сравнительный кадр прозрачности без чтения настроек или слотов пользователя.
func capture() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var game:=preload("res://main.tscn").instantiate(); game.set_script(ReviewGame); game.audio_enabled=false; game.world_loot_seed=20261012
	game.GameBootstrap._initialize_services(game); viewport.add_child(game); game.set_process(false); game.set_physics_process(false); game.camera_offset=Vector2.ZERO
	game.queue_redraw()
	for frame in 8: await RenderingServer.frame_post_draw
	var name:="props-after" if "--after" in OS.get_cmdline_user_args() else "props-before"
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))==OK)
	quit()

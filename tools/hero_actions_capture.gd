extends SceneTree

const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Actions := preload("res://scripts/systems/hero_action_visual_system.gd")
const OUT := "res://docs/concepts/hero-actions-2026-10-12/v2/"

class PoseCanvas extends Node2D:
	var kind := "pickaxe"
	## Показывает реальные игровые кадры и общую линию стоп без увеличения малых спрайтов.
	func _draw() -> void:
		draw_rect(Rect2(0,0,720,640),Color("25332d"))
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(30,32),kind.to_upper()+" / READY - WINDUP - CONTACT - RECOVERY",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("efd9a6"))
		var directions := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
		for row in 4:
			draw_string(font,Vector2(8,123+row*145),["DOWN","LEFT","RIGHT","UP"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("cbbd9c"))
			for column in 4:
				var ground := Vector2(158+column*160,176+row*145)
				draw_rect(Rect2(ground-Vector2(70,130),Vector2(140,140)),Color("354c40"))
				draw_line(ground-Vector2(40,0),ground+Vector2(40,0),Color("819684"),1)
				draw_circle(ground,2,Color("efbd62"))
				Visual.draw_pose(self,ground,Actions.pose(kind,directions[row],[0.05,0.3,0.68,0.95][column]))

## Запускает нативную проверку малых кадров после готовности окна.
func _initialize() -> void:
	capture.call_deferred()

## Сохраняет шесть листов настоящей игровой отрисовки без чтения пользовательских сохранений.
func capture() -> void:
	root.size = Vector2i(720,640); root.content_scale_size = Vector2i(720,640)
	Actions.warmup()
	var canvas := PoseCanvas.new(); root.add_child(canvas)
	for kind in Actions.catalog():
		canvas.kind = kind; canvas.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+kind+"-native.png")) == OK)
	quit()

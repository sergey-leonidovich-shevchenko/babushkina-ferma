extends SceneTree

const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const OUTPUT := "res://assets/generated/level_drafts/hero_four_direction_review.png"

class PoseCanvas extends Node2D:
	## Рисует контактный лист тем же production-рендерером, который используется в игровой сцене.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("233630"))
		var font := ThemeDB.fallback_font
		draw_string(font,Vector2(32,35),"HERO / FOUR DIRECTIONS / FIXED FOOT PIVOT",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("f0dba5"))
		draw_string(font,Vector2(158,66),"WALK",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c8b998"))
		draw_string(font,Vector2(763,66),"HOE: READY / WINDUP / IMPACT / RECOVERY",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c8b998"))
		var directions := [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]
		var phases := [0.05,0.3,0.55,0.9]
		for row in 4:
			draw_string(font,Vector2(18,160+row*154),["DOWN","LEFT","RIGHT","UP"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("d8c9a6"))
			for column in 8:
				var ground := Vector2(157+column*148,193+row*154)
				draw_rect(Rect2(ground-Vector2(62,112),Vector2(124,128)),Color("344b40"))
				draw_line(ground-Vector2(36,0),ground+Vector2(36,0),Color("738576"),1)
				draw_circle(ground,2,Color("eeb465"))
				var pose: Dictionary = Visual.walk_pose(directions[row],column/8.0,true) if column<4 else Visual.hoe_pose(directions[row],phases[column-4])
				Visual.draw_pose(self,ground,pose)


## Готовит отдельный проверочный viewport, не загружая и не перезаписывая сохранения игрока.
func _initialize() -> void:
	_run.call_deferred()


## Сохраняет реально отрисованный контактный лист после подготовки прозрачных краёв спрайтов.
func _run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	Visual.warmup()
	var canvas:=PoseCanvas.new()
	root.add_child(canvas)
	await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	print("HERO POSE PREVIEW: ",error)
	quit(0 if error==OK else 1)

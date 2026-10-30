extends SceneTree

const Background := preload("res://scripts/world_background.gd")
var background: Node2D
var cases: Array[Dictionary]=[]

## Сравнивает нативные пиксели исходного грунта и GPU-кеша, включая смену погоды и сезона.
func _initialize() -> void:
	_start.call_deferred()

## Создаёт изолированный фон без героя, сохранений и анимированных слоёв.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1152,648)
	background=Background.new(); root.add_child(background)
	background.position=Vector2(-360,-360)
	for environment in [["spring","clear"],["summer","rain"],["winter","snow"]]:
		background.set_environment(environment[0],environment[1])
		background.set_meta("terrain_direct",true); background.queue_redraw()
		for _frame in 8: await RenderingServer.frame_post_draw
		var direct: Image=root.get_texture().get_image()
		background.set_meta("terrain_direct",false); background.queue_redraw()
		for _frame in 8: await RenderingServer.frame_post_draw
		var cached: Image=root.get_texture().get_image()
		var a:=direct.get_data(); var b:=cached.get_data(); var changed:=0
		var maximum:=0; var difference_sum:=0
		for index in a.size():
			var difference:=absi(int(a[index])-int(b[index])); difference_sum+=difference
			maximum=maxi(maximum,difference)
			if absi(int(a[index])-int(b[index]))>1: changed+=1
		cases.append({"season":environment[0],"weather":environment[1],"channels_over_one":changed,"channels":a.size(),"mean_channel_difference":float(difference_sum)/a.size(),"maximum_difference":maximum,"cache_ready":background.terrain_ready})
		direct.save_png("res://docs/reports/performance-2026-10-12/terrain-%s-direct.png"%environment[0])
		cached.save_png("res://docs/reports/performance-2026-10-12/terrain-%s-cached.png"%environment[0])
	var path:="res://docs/reports/performance-2026-10-12/terrain-cache-pixels.json"
	var output:=FileAccess.open(path,FileAccess.WRITE); output.store_string(JSON.stringify(cases,"  ")+"\n")
	print("TERRAIN CACHE REVIEW: "+JSON.stringify(cases))
	# Второй framebuffer округляет цвет и субпиксельные края: допускается до 0.15% каналов с ошибкой >1 и средняя ошибка меньше одной ступени из 255.
	quit(0 if cases.all(func(entry): return entry.cache_ready and float(entry.channels_over_one)/entry.channels<=0.0015 and entry.mean_channel_difference<1.0) else 1)

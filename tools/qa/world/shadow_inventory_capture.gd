extends SceneTree

const Points:=preload("res://tools/visual_camera_points.gd")
const Observer:=preload("res://tools/render_order_game.gd")
const Canvas:=preload("res://tools/qa/world/shadow_inventory_canvas.gd")
const WorldSpace:=preload("res://scripts/systems/world_projection_system.gd")
var output:=""
var profile:=""
var window_size:=Vector2i(1152,648)
var game:Node2D
var targets:=[]
var canvases:=[]
var previews:=[]
var rows:=[]
var errors:=[]

## Требует новый QA-профиль и свежий каталог; пользовательские слоты не используются.
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg.begins_with("--profile="):profile=arg.trim_prefix("--profile=")
		elif arg=="--wide":window_size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or not profile.begins_with("Codex-VSHADOW-001-") or "/" in profile or DisplayServer.get_name()=="headless":quit(2);return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name",profile)
	_start.call_deferred()

## Снимает настоящую игру и отдельные контакты при двух часах, одном и нескольких предметах.
func _start()->void:
	DirAccess.make_dir_recursive_absolute(output)
	game=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
	Points.configure(game,Points.registry().points[0]);WorldSpace.set_reference_zoom(game,1.2)
	root.mode=Window.MODE_WINDOWED;root.size=window_size;root.title="VSHADOW-001 | Existing shadow ownership";root.show();root.grab_focus()
	await _settle(1500);root.mode=Window.MODE_WINDOWED;root.size=window_size
	for mode in ["shadow","plain","body"]:
		var target:=SubViewport.new();target.size=Vector2i(768,256);target.transparent_bg=true;target.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(target)
		var canvas:=Canvas.new();canvas.mode=mode;target.add_child(canvas);targets.append(target);canvases.append(canvas)
		var preview:=Sprite2D.new();preview.texture=target.get_texture();preview.centered=false;preview.position=Vector2(192,50 if mode=="shadow" else 340);preview.visible=false;root.add_child(preview);previews.append(preview)
	for minutes in [720.0,1140.0]:
		game.game_minutes=minutes
		for group in Canvas.GROUPS:
			var id:String=str(int(minutes))+"-"+group
			game.show()
			for preview in previews:preview.hide()
			game.observe_draw=false
			for i in 3:game.queue_redraw();await RenderingServer.frame_post_draw
			var before:Dictionary=game.SaveSystem.snapshot(game);game.draw_records.clear();game.observe_draw=true
			for i in 2:game.queue_redraw();await RenderingServer.frame_post_draw
			game.observe_draw=false
			var image:=root.get_texture().get_image();image.save_png(output.path_join(id+"-game.png"))
			var actual:={"minutes":minutes,"world":"overworld","camera":Points.pair(game.camera_offset),"player":Points.pair(game.player),"zoom":WorldSpace.zoom(game),"before":before,"after":game.SaveSystem.snapshot(game),"draws":game.draw_records.duplicate(true)}
			game.hide()
			for i in canvases.size():canvases[i].group=group;canvases[i].minutes=minutes;canvases[i].observe=false
			for i in 3:
				for canvas in canvases:canvas.queue_redraw()
				await RenderingServer.frame_post_draw
			for canvas in canvases:canvas.records.clear();canvas.observe=true
			for i in 2:
				for canvas in canvases:canvas.queue_redraw()
				await RenderingServer.frame_post_draw
			var samples:=[]
			for i in canvases.size():
				var canvas:Node2D=canvases[i];canvas.observe=false
				var target_image:Image=targets[i].get_texture().get_image();target_image.save_png(output.path_join(id+"-"+canvas.mode+".png"))
				samples.append({"mode":canvas.mode,"size":Points.pair(target_image.get_size()),"records":canvas.records.duplicate(true)})
			previews[0].show();previews[1].show()
			for i in 2:await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(id+"-window.png"))
			var data:={"id":id,"group":group,"minutes":minutes,"window":Points.pair(DisplayServer.window_get_size()),"logical":Points.pair(root.get_visible_rect().size),"visible":root.visible,"focused":DisplayServer.window_is_focused(),"game":actual,"samples":samples}
			rows.append(data)
			if data.window!=Points.pair(window_size) or not data.visible or actual.before!=actual.after or actual.draws.size()!=2:errors.append(id+": native game evidence failed")
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VSHADOW-001","profile":profile,"display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"static_only":true,"dynamic_solar_implemented":false,"performance_eligible":false,"rows":rows,"errors":errors})+"\n")
	print("SHADOW INVENTORY NATIVE: ",rows.size()," cases; ",errors);quit(0 if errors.is_empty() else 2)

## Даёт оконному серверу создать поверхности без прокрутки симуляции.
func _settle(ms:int)->void:
	var until:=Time.get_ticks_msec()+ms
	while Time.get_ticks_msec()<until:game.queue_redraw();await process_frame

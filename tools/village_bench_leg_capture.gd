extends SceneTree

const Bench := preload("res://scripts/presentation/village_bench_visual.gd")
const OLD := "docs/reports/visual-overhaul/vprop-002/native/after/inputs/assets/game/locations/overworld/benches/"
var output := ""
var window_size := Vector2i(1152,648)
var board: Sheet

class Sheet extends Node2D:
	var old_profile: Dictionary
	var old_textures := []
	var background := Color("f4ecd9")
	var callbacks := 0
	var observe := false

	## Показывает старые и новые настоящие ресурсы при одинаковых 120%, без изменения игры.
	func _draw() -> void:
		draw_rect(Rect2(0,0,1152,648),background)
		var ink := Color("e9ddc5") if background.r<0.3 else Color("493d2e")
		draw_string(ThemeDB.fallback_font,Vector2(48,42),"VPROP-002 · four visible legs · camera 120%",HORIZONTAL_ALIGNMENT_LEFT,-1,22,ink)
		for row in 2:
			draw_string(ThemeDB.fallback_font,Vector2(48,100+row*270),"BEFORE" if row==0 else "AFTER",HORIZONTAL_ALIGNMENT_LEFT,-1,18,ink)
			for i in 3:
				var side: int=[0,1,3][i]
				var name: String=Bench.Facing.NAMES[side]
				var ground:=Vector2(240+i*288,200+row*225)
				draw_set_transform(Vector2.ZERO,0,Vector2(1.2,1.2))
				if row==0:
					var v:Dictionary=old_profile.views[name]
					var size:=Vector2(v.pixels[0],v.pixels[1])*0.25
					var anchor:=Vector2(v.anchor[0],v.anchor[1])*0.25
					draw_texture_rect(old_textures[i],Rect2(ground-anchor,size),false)
				else:
					Bench.draw_shadow(self,ground,side)
					Bench.draw(self,ground,side)
				draw_string(ThemeDB.fallback_font,ground+Vector2(-24,35),name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,ink)
				draw_set_transform(Vector2.ZERO)
		if observe:callbacks+=1

## Принимает только отдельный свежий QA-каталог и не читает пользовательские сохранения.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VPROP-002-legs-"+str(Time.get_ticks_usec()))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		elif arg=="--wide":window_size=Vector2i(1280,720)
	if output.is_empty() or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name()=="headless":quit(2);return
	_start.call_deferred()

## Снимает два контрастных фона реального CanvasItem с текущей импортированной графикой.
func _start() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.mode=Window.MODE_WINDOWED;root.size=window_size;root.title="VPROP-002 | Four visible legs"
	root.content_scale_size=Vector2i(1152,648);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	board=Sheet.new();board.old_profile=JSON.parse_string(FileAccess.get_file_as_string("res://"+OLD+"profile.json"))
	for side in ["south","west","east"]:
		var image:=Image.load_from_file(ProjectSettings.globalize_path("res://"+OLD+"bench_"+side+"_v1.png"))
		board.old_textures.append(ImageTexture.create_from_image(image))
	root.add_child(board);root.show();root.grab_focus()
	var until:=Time.get_ticks_msec()+1500
	while Time.get_ticks_msec()<until:board.queue_redraw();await process_frame
	root.mode=Window.MODE_WINDOWED;root.size=window_size
	var records:=[]
	for tone in ["light","dark"]:
		board.background=Color("f4ecd9") if tone=="light" else Color("252b2a")
		board.observe=false
		for i in 4:board.queue_redraw();await RenderingServer.frame_post_draw
		board.callbacks=0;board.observe=true
		for i in 2:board.queue_redraw();await RenderingServer.frame_post_draw
		board.observe=false
		var image:=root.get_texture().get_image();image.save_png(output.path_join(tone+".png"))
		records.append({"background":tone,"window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y],"image":[image.get_width(),image.get_height()],"callbacks":board.callbacks,"focused":DisplayServer.window_is_focused()})
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VPROP-002","revision":"four-visible-legs","display":DisplayServer.get_name(),"engine":Engine.get_version_info().string,"zoom":1.2,"performance_eligible":false,"records":records})+"\n")
	print("BENCH LEG CAPTURE: ",records);quit()

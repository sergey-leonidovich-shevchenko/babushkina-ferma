extends SceneTree
const Points:=preload("res://tools/visual_camera_points.gd")
const Observer:=preload("res://tools/render_order_game.gd")
var output:=""
## Снимает прежний production-ветер при одинаковой камере и управляемых визуальных часах.
func _initialize()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 if output.is_empty() or DirAccess.dir_exists_absolute(output) or DisplayServer.get_name()=="headless":quit(2);return
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true);ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VFOLIAGE-003-baseline-"+str(Time.get_ticks_usec()))
 _start.call_deferred()
## Записывает реальные draw, исходное полное состояние и физические размеры окна, не читая чужие сохранения.
func _start()->void:
 DirAccess.make_dir_recursive_absolute(output)
 var game:=Points.create_game();game.set_script(Observer);game.world_loot_seed=Points.SEED;root.add_child(game);current_scene=game
 Points.configure(game,Points.registry().points[0]);game.WorkshopSystem.state(game,"pottery");game.settings_state.reduced_motion=false
 game.set_meta(&"camera_reference_zoom",1.2);game.player=Vector2(1944,648);game.camera_offset=game.player-Vector2(480,270)
 root.title="VFOLIAGE-003 | baseline";root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1152,648);root.show();root.grab_focus()
 for i in 30:game.queue_redraw();await RenderingServer.frame_post_draw
 var before:=JSON.stringify(game.SaveSystem.snapshot(game));var rows:=[]
 game.observe_draw=true
 for i in 25:
  game.set_meta(&"village_live_ground_seconds",float(i)/6.0)
  game.draw_records.clear()
  for frame in 2:game.queue_redraw();await RenderingServer.frame_post_draw
  var file:="frame-%02d.png"%i;root.get_texture().get_image().save_png(output.path_join(file))
  rows.append({"file":file,"seconds":float(i)/6.0,"draws":game.draw_records.size(),"snapshot_equal":JSON.stringify(game.SaveSystem.snapshot(game))==before,"visible":root.visible,"window":Points.pair(DisplayServer.window_get_size())})
 FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify({"task":"VFOLIAGE-003","stage":"baseline","display":DisplayServer.get_name(),"state":before,"camera":Points.pair(game.camera_offset),"rows":rows})+"\n")
 quit()

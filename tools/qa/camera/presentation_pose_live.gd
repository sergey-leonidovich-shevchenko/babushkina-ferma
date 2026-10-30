extends SceneTree
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
var output := ""
var game: Node

class Recorder extends Node:
	var game: Node
	var owner_tree: SceneTree
	var output := ""
	var rows := []
	var errors := []
	## Наблюдает реальный idle callback после игрового _process, не назначая фазу вручную.
	func _process(_delta: float) -> void:
		if not game.has_meta(Pose.META): return
		var value: Dictionary = game.get_meta(Pose.META)
		var alpha := Engine.get_physics_interpolation_fraction()
		var expected := Vector2(value.previous).lerp(value.current,alpha)
		var ground := Pose.ground(game)
		if ground.distance_to(expected)>0.001: errors.append("idle phase mismatch")
		if game.camera_offset!=game.CameraSystem.offset_for_position(game,ground): errors.append("idle camera mismatch")
		rows.append({"alpha":alpha,"previous":Points.pair(value.previous),"player":Points.pair(game.player),"ground":Points.pair(ground),"camera":Points.pair(game.camera_offset),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames()})
		if rows.size()<240: return
		var repeated := 0
		for index in range(1,rows.size()):
			if rows[index].player==rows[index-1].player and rows[index].ground!=rows[index-1].ground: repeated+=1
		if repeated<10: errors.append("no observed sub-tick presentation")
		FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"task":"VCAMERA-003","kind":"automatic-headless-callbacks","native":false,"drawing_visible":game.visible,"performance_eligible":false,"physics_hz":Engine.physics_ticks_per_second,"max_process_hz":Engine.max_fps,"rows":rows,"sub_tick_frames":repeated,"errors":errors})+"\n")
		print("LIVE CALLBACKS: ",rows.size(),"; sub-tick ",repeated,"; ",errors)
		owner_tree.quit(0 if errors.is_empty() else 2)

## Готовит отдельный профиль и запрещает перезаписывать прежний след автоматического цикла.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if output.is_empty() or FileAccess.file_exists(output): push_error("Need new live output"); quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-VCAMERA-003-Live-"+str(OS.get_process_id()))
	_start.call_deferred()

## Включает настоящие callbacks сцены; ручной GameLoop и назначенная фаза здесь не используются.
func _start() -> void:
	game=Points.create_game(); root.add_child(game); current_scene=game
	Points.configure(game,Points.registry().points[0]); game.player=Vector2(562.25,672.25); game.speed=18; game.update_camera()
	game.hide() # Headless проверяет callbacks, а не стоимость команд отрисовки.
	game.move_right_held=true; game.move_down_held=true
	Engine.physics_ticks_per_second=60; Engine.max_fps=120
	game.set_physics_process(true); game.set_process(true)
	var recorder := Recorder.new(); recorder.game=game; recorder.owner_tree=self; recorder.output=output; recorder.process_priority=100
	root.add_child(recorder)

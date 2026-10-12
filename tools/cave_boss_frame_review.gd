extends "res://tools/runtime_frame_review.gd"

const Boss := preload("res://scripts/systems/cave_boss_system.gd")
const Arena := preload("res://scripts/systems/cave_boss_arena_system.gd")
const Minions := preload("res://scripts/systems/cave_boss_minion_system.gd")
var damage_received := 0
var peak_shots := 0
var peak_minions := 0
var attack_ids: Dictionary = {}


## Прогревает реальный HUD и арену третьей стадии с четырьмя существами без записи сохранений.
func _start() -> void:
	super._start()
	if game == null: return
	Boss.configure_preview(game)
	game.enemy_nodes[Boss.index(game)].hp = 32
	Arena.activate(game)
	Minions.summon(game, ["skeleton", "zombie", "vampire", "zombie"])
	game.tutorial_visible = false
	profile_town = true
	route = [Vector2(1320,504),Vector2(1776,504),Vector2(1848,816),Vector2(1320,888)]
	route_origin = game.player
	game.sync_background_location(); game.update_camera()


## Ведёт героя настоящими клавишами; лечение только стенда позволяет измерить все атаки без поражения.
func _drive_route() -> void:
	if not started or frames <= WARMUP_FRAMES: return
	if not simulation_started:
		simulation_started = true; seed(WORLD_SEED); game.set_physics_process(true)
	damage_received += maxi(0, game.player_max_hp - game.player_hp)
	game.player_hp = game.player_max_hp
	game.tutorial_visible = false
	var state: Dictionary = game.state.world.cave_boss
	peak_shots = maxi(peak_shots, state.projectiles.size())
	peak_minions = maxi(peak_minions, Minions.living_count(game))
	if not state.attack.is_empty(): attack_ids[state.attack.id] = true
	route_ticks += 1
	game.benchmark_elapsed = float(route_ticks) / Engine.physics_ticks_per_second
	if game.player.distance_to(route[route_index]) < 12:
		route_origin = game.player; route_index = (route_index + 1) % route.size()
	var direction := route_origin.direction_to(route[route_index])
	var along := clampf((Vector2(game.player)-route_origin).dot(direction)+18,0,route_origin.distance_to(route[route_index]))
	var steering: Vector2 = route_origin + direction * along - game.player
	_key(KEY_A,steering.x < -1.5); _key(KEY_D,steering.x > 1.5)
	_key(KEY_W,steering.y < -1.5); _key(KEY_S,steering.y > 1.5)


## Публикует сырые кадры, CPU-счётчики, проверку сохранений и фактическую нагрузку боя.
func _finish() -> void:
	started = false; _release_keys()
	var unchanged := true
	for path in save_fingerprints:
		unchanged = unchanged and save_fingerprints[path] == (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent")
	var mode := "f10" if game.DebugOverlaySystem.active(game) else "normal"
	var result := {"schema":1,"mode":mode,"seed":WORLD_SEED,"gpu":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"window_size":[root.size.x,root.size.y],"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps,"physics_hz":Engine.physics_ticks_per_second,"warmup_frames":WARMUP_FRAMES,"sample_frames":frame_ms.size(),"render_frame":_statistics(frame_ms),"monitors":monitor_frames,"user_saves_unchanged":unchanged,"phase":game.state.world.cave_boss.phase,"peak_minions":peak_minions,"peak_projectiles":peak_shots,"attacks":attack_ids.keys(),"damage_received":damage_received,"simulation_seconds":game.benchmark_elapsed,"note":"Physical keyboard input and real collisions; no attacks on boss; benchmark-only healing each physics tick keeps the ordinary AI active."}
	var directory := "res://docs/reports"
	result.frame_intervals_ms=frame_ms
	result.drawn_frames_including_warmup=Engine.get_frames_drawn()-drawn_start
	result.process_frames_including_warmup=frames
	result.low_processor_usage=OS.low_processor_usage_mode
	result.draw_intervals_ms=draw_intervals_ms
	if not draw_intervals_ms.is_empty(): result.draw_frame=_statistics(draw_intervals_ms)
	result.window_focused=DisplayServer.window_is_focused()
	if game.has_meta("cpu_samples"): result.cpu_samples=game.get_meta("cpu_samples")
	result.window_mode=DisplayServer.window_get_mode()
	result.display_window_size=[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]
	result.screen_size=[DisplayServer.screen_get_size().x,DisplayServer.screen_get_size().y]
	result.pacing_policy=pacing_policy()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report-dir="): directory = argument.trim_prefix("--report-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var output := FileAccess.open(directory.path_join("native_boss_%s.json" % mode),FileAccess.WRITE)
	if output == null: quit(2); return
	output.store_string(JSON.stringify(result,"  ")+"\n"); output.close()
	print("BOSS FRAME REVIEW: ", JSON.stringify({"mode":mode,"statistics":result.render_frame,"minions":peak_minions,"shots":peak_shots,"attacks":result.attacks,"saves_unchanged":unchanged}))
	quit(0 if unchanged and peak_minions == 4 and attack_ids.size() == 4 else 1)

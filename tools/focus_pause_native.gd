extends SceneTree

const Scene := preload("res://main.tscn")
const Focus := preload("res://scripts/systems/focus_pause_system.gd")
var game:Node
var checks:Array=[]
const FOLDER := "res://docs/reports/safe-2026-10/focus/"

## Создаёт собственное окно и отдельный профиль, сохраняя пользовательские настройки игры.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-SAFE-Focus-Native")
	start.call_deferred()

## Проверяет настоящее сворачивание окна и сохранение ручной паузы; это приёмка ввода, а не FPS.
func start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); root.add_child(game); current_scene=game
	game.set_physics_process(false); game.language_screen=false; game.title_screen=false; game.tutorial_visible=false
	game.settings_state.pause_on_focus_loss=true; game.menu_state.pause_open=false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=60; OS.low_processor_usage_mode=false
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	root.grab_focus(); await create_timer(0.4).timeout
	game.MenuSystem.open_settings(game,false); game.menu_state.settings_selected=game.MenuSystem.SETTING_ITEMS.find("pause_on_focus_loss")
	game.queue_redraw(); await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER+"settings.png")
	game.menu_state.settings_open=false
	print("NATIVE FOCUS: ready")
	var minutes:float=game.game_minutes; var energy:float=game.energy
	root.mode=Window.MODE_MINIMIZED; await create_timer(0.5).timeout
	print("NATIVE FOCUS: minimized")
	game._physics_process(5)
	print("NATIVE FOCUS: simulated while minimized")
	checks.append({"case":"native_minimized","mode":DisplayServer.window_get_mode(),"focused":root.has_focus(),"blocked":Focus.blocked(game),"passed":DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_MINIMIZED and Focus.blocked(game) and game.game_minutes==minutes and game.energy==energy})
	root.mode=Window.MODE_WINDOWED; DisplayServer.window_move_to_foreground(); root.grab_focus()
	print("NATIVE FOCUS: requested restore")
	await create_timer(0.5).timeout
	print("NATIVE FOCUS: restored mode ",DisplayServer.window_get_mode())
	game._physics_process(0.25)
	var focused:=DisplayServer.window_is_focused()
	checks.append({"case":"native_restore_respects_actual_focus","focused":focused,"blocked":Focus.blocked(game),"passed":Focus.blocked(game)==not focused and ((game.game_minutes>minutes) if focused else game.game_minutes==minutes)})
	game.menu_state.pause_open=true
	root.mode=Window.MODE_MINIMIZED; await create_timer(0.3).timeout
	root.mode=Window.MODE_WINDOWED; DisplayServer.window_move_to_foreground(); root.grab_focus(); await create_timer(0.4).timeout
	print("NATIVE FOCUS: manual pause restored")
	checks.append({"case":"native_restore_manual_pause","focused":DisplayServer.window_is_focused(),"blocked":Focus.blocked(game),"passed":game.menu_state.pause_open})
	game.menu_state.pause_open=false; game.settings_state.pause_on_focus_loss=false; game._physics_process(0.25)
	checks.append({"case":"native_explicit_background_opt_out","focused":DisplayServer.window_is_focused(),"passed":not Focus.blocked(game) and game.game_minutes>minutes})
	var passed:=checks.all(func(check): return bool(check.passed))
	FileAccess.open(FOLDER+"native.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"protocol":"native minimize/restore and UI capture; manual simulation steps; not FPS","checks":checks},"  ")+"\n")
	print("NATIVE FOCUS: ",JSON.stringify(checks)); quit(0 if passed else 1)

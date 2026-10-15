extends "res://tools/dev_cabinet_review.gd"

const Scene := preload("res://main.tscn")
const FOLDER := "res://docs/reports/safe-2026-10/lifecycle/"

## Проверяет те же события в настоящих игровых сценах и нативном viewport без пользовательских слотов.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-SAFE-Lifecycle-Native")
	start.call_deferred()

## Создаёт сцену с настоящим фоном и viewport; автоматические физические шаги отключены для точных границ.
func make_game() -> Node:
	var game:=Scene.instantiate(); game.set_meta("capture_windowed",true); root.add_child(game)
	game.set_physics_process(false); game.language_screen=false; game.title_screen=false; game.audio_enabled=false
	game.settings_state.pause_on_focus_loss=false; game.LocaleSystem.set_locale("ru")
	return game

## Запускает матрицу клавиатуры, геймпада, мыши и тача и сохраняет спокойный кадр после обычной двери.
func start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); root.size=Vector2i(1152,648)
	preload("res://tests/suites/action_lifecycle_suite.gd").new(self).run()
	var game:=make_game(); game.HeroActionSystem.begin(game,"chop",game.player)
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.state.player.profile.created=true; game.FirstChapterSystem.state(game).completed=true; game.tutorial_visible=false
	game.BuildingSystem.enter(game,"cottage"); game.update_camera(); game.queue_redraw()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); OS.low_processor_usage_mode=false
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(FOLDER+"after-door.png")
	FileAccess.open(FOLDER+"native.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"display_server":DisplayServer.get_name(),"passed":passed,"failed":failed,"protocol":"generated keyboard/controller/mouse/touch InputEvents in native scenes and viewport; manual simulation steps; no physical-device or FPS claim","pause_on_focus_loss":false},"  ")+"\n")
	game.free(); print("NATIVE LIFECYCLE: %d passed, %d failed"%[passed,failed]); quit(0 if failed==0 else 1)

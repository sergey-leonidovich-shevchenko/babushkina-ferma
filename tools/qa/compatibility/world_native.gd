extends "res://tools/qa/compatibility/action_lifecycle_native.gd"

const WORLD_FOLDER := "res://docs/reports/world-2026-10/native/"

## Снимает интерфейсы мира в настоящем окне, изолируя слоты и настройки пользователя.
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-WORLD-Native")
	start_world.call_deferred()

## Проверяет читаемость краткой цели и не выдаёт остановленный кадр за измерение производительности.
func start_world() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_FOLDER))
	root.size = Vector2i(1152,648); DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	OS.low_processor_usage_mode = false
	var game := make_game(); game.tutorial_visible = false; game.state.player.profile.created = true
	game.state.player.adventure_ui.creation_open = false
	var life: Dictionary = game.FarmLifeSystem.state(game); life.first_day = 6; life.cutscene = ""; life.cutscene_timer = 0
	game.FirstChapterSystem.state(game).stage = 6; game.player = game.FirstChapterSystem.REPAIR_POSITION + Vector2(-90,24)
	game.quest_log_open = true
	game.update_camera(); game.UiFeedbackSystem.update(game,1); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(WORLD_FOLDER+"chapter-objective.png")
	game.quest_log_open = false; game.current_location = "village_garden"; game.player = Vector2(1008,1008)
	game.sync_background_location(); game.update_camera(); game.UiFeedbackSystem.update(game,1); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(WORLD_FOLDER+"home-wayfinding.png")
	game.current_location = "cottage_interior"; game.game_minutes = 23*60
	game.NpcMovementSystem.initialize(game); game.NpcMovementSystem.update(game,0)
	game.mission_states.side_seed = game.QuestSystem.ACTIVE; game.FirstChapterSystem.state(game).stage = 5
	game.quest_log_open = true; game.set_meta("journal_group","side"); game.queue_redraw()
	await process_frame; RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(WORLD_FOLDER+"npc-journal.png")
	game.free(); quit()

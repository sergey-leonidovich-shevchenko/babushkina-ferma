extends SceneTree

const Scene := preload("res://main.tscn")
const Preview := preload("res://tools/compact_dialogue_preview.gd")
var game:Node2D
var viewport:SubViewport

## Снимает варианты диалога в отдельном каталоге пользователя без правки игровых ресурсов.
func _initialize() -> void:
	_start.call_deferred()

## Сохраняет исходный кадр и два точных макета на одинаковом игровом фоне.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Compact-Dialogue-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_script(Preview); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.current_location="cottage_interior"; game.home_chest_owned=true
	game.player=Vector2(576,400); game.sync_background_location(); game.update_camera()
	game.AdventurePolishSystem.open_quest_dialogue(game,"varvara")
	game.state.player.adventure_ui.dialogue.text="Поймай пять рыб для рабочих, ремонтирующих мост."
	game.state.player.adventure_ui.dialogue.title="Уха для переправы"; game.state.player.adventure_ui.dialogue.revealed=999
	var runtime:=OS.get_environment("FARM_DIALOGUE_REVIEW_MODE")=="runtime"
	var folder:="res://docs/reports/compact-dialogue-2026-10-14/" if runtime else "res://docs/concepts/compact-dialogue-2026-10-14/v1/"
	DirAccess.make_dir_recursive_absolute(folder)
	for variant in (["runtime"] if runtime else ["before","a","b"]):
		game.set_meta("dialogue_review_variant",variant)
		for _frame in 5: await frame()
		if viewport.get_texture().get_image().save_png(folder+variant+".png")!=OK: push_error("Не удалось сохранить вариант диалога: "+variant)
	print("COMPACT DIALOGUE PREVIEWS: before, A, B"); quit()

## Дожидается полной перерисовки нативного графического сервера с чистым интерфейсом.
func frame() -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.queue_redraw()
	await process_frame; RenderingServer.force_draw()

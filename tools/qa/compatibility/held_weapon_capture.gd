extends SceneTree

const Scene := preload("res://main.tscn")
const FOLDER := "res://docs/reports/held-weapon-2026-10-14/"
var game: Node2D
var viewport: SubViewport

## Поднимает отдельный нативный стенд без загрузки пользовательского сохранения.
func _initialize() -> void:
	_start.call_deferred()

## Снимает экипированный топор в покое и ходьбе, затем проверяет его настоящие полные позы действия.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Held-Weapon-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	game.FarmLifeSystem.state(game).cutscene=""; game.current_location="overworld"; game.player=Vector2(1152,720)
	game.facing=Vector2.LEFT; game.equipped_weapon="axe"; game.selected_hotbar=0; game.hotbar_slots[0]="hoe"
	game.player_attack_timer=0; game.player_attack_cooldown=0; game.settings_state.screen_shake_enabled=false
	game.sync_background_location(); game.update_camera(); DirAccess.make_dir_recursive_absolute(FOLDER)
	var phase:=OS.get_environment("FARM_HELD_WEAPON_PHASE"); if phase.is_empty(): phase="before"
	await capture(phase+"-idle")
	game.move_left_held=true; game.PlayerSystem.record_motion(game,Vector2(-8,0)); game.set_meta(game.PlayerSystem.WALK_TIME_META,0.25)
	await capture(phase+"-walk")
	if phase=="after":
		game.clear_movement_keys(); game.HeroActionSystem.begin(game,"chop",game.player+Vector2.LEFT*40); game.HeroActionSystem.update(game,0.24)
		await capture("after-chop"); game.HeroActionSystem.update(game,1)
		game.WeaponSystem.begin_attack(game,true); game.WeaponSystem.update(game,0.4)
		await capture("after-attack"); game.WeaponSystem.update(game,1)
		await capture("after-finished")
	print("HELD WEAPON NATIVE: "+phase); quit()

## Сохраняет полный кадр после стабилизации рисунка без масштабирования или растровых правок.
func capture(label: String) -> void:
	for _frame in 4:
		game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(FOLDER+label+".png")!=OK: push_error("Не удалось сохранить "+label)

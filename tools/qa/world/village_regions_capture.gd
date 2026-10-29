extends SceneTree

const Scene := preload("res://main.tscn")
const Data := preload("res://scripts/systems/village_region_data.gd")
const Map := preload("res://scripts/presentation/village_region_map_renderer.gd")
var game:Node2D
var viewport:SubViewport
var failed:=0

## Запускает отдельный нативный стенд настоящей сети деревенских районов.
func _initialize() -> void:
	_start.call_deferred()

## Снимает каждую отдельную карту, обычный кадр героя, схему проходов и ночного жителя в гильдии.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Village-Regions-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_process(false); game.set_physics_process(false); game.audio_enabled=false; game.settings_state.screen_shake_enabled=false
	game.language_screen=false; game.title_screen=false; game.LocaleSystem.current="ru"; game.day=1; game.game_minutes=720
	game.state.world.weather_day=game.day; game.state.world.weather="clear"
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.NpcMovementSystem.initialize(game); game.NpcMovementSystem.update(game,0)
	for area in Data.IDS:
		game.current_location=area
		var hero:Vector2=game.VillageLayoutSystem.MapData.START if area=="overworld" else (Data.NPC_POINTS.get(Data.NPC_AREAS.find_key(area),Vector2(1008,696))+Vector2(84,72))
		game.player=hero; game.sync_background_location(); game.update_camera()
		await capture(area+"-gameplay",Vector2i(1152,648))
		if Data.added(area):
			game.set_meta("capture_first_level_clean",true); viewport.size=Vector2i(Data.SIZE)
			game.camera_offset=Vector2.ZERO; game.get_node("WorldBackground").position=Vector2.ZERO
			await capture(area+"-overview",Vector2i(Data.SIZE))
			game.remove_meta("capture_first_level_clean"); viewport.size=Vector2i(1152,648); game.update_camera()
	game.current_location="overworld"; game.player=game.VillageLayoutSystem.MapData.START; game.sync_background_location(); game.update_camera()
	game.WorldMapSystem.toggle(game); game.world_guide_page=0
	await capture("district-map",Vector2i(1152,648))
	Map.toggle(game); await capture("world-map",Vector2i(1152,648)); Map.toggle(game)
	game.LocaleSystem.current="de"; game.settings_state.text_scale=1.2; await capture("district-map-de-120",Vector2i(1152,648))
	game.world_map_open=false; game.LocaleSystem.current="ru"; game.settings_state.text_scale=1
	game.current_location="guild_interior"; game.game_minutes=23*60; game.NpcMovementSystem.update(game,0)
	game.player=Vector2(576,500); game.sync_background_location(); game.update_camera(); await capture("night-guild",Vector2i(1152,648))
	print("VILLAGE REGIONS CAPTURE: "+("PASS" if failed==0 else "FAIL")); quit(0 if failed==0 else 1)

## Сохраняет исходные кадры с точным размером viewport, не масштабируя спрайты или итоговое изображение.
func capture(label: String, size: Vector2i) -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	for _frame in 8: game.queue_redraw(); game.get_node("WorldBackground").queue_redraw(); await process_frame; RenderingServer.force_draw()
	var image:=viewport.get_texture().get_image()
	if image.get_size()!=size or image.save_png("res://docs/reports/village-regions-2026-10-13-"+label+".png")!=OK: failed+=1; push_error("Не удалось сохранить районный кадр "+label)
	print("VILLAGE REGIONS FRAME: "+label)

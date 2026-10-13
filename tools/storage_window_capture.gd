extends SceneTree

const Scene := preload("res://main.tscn")
const Cabinet := preload("res://scripts/systems/dev_cabinet_system.gd")
var game:Node2D
var viewport:SubViewport
var phase:String
var folder:String
var metrics:Dictionary={}

## Запускает нативный стенд с отдельным пользовательским каталогом и неизменёнными игровыми текстурами.
func _initialize() -> void:
	_start.call_deferred()

## Сравнивает первый кадр шкафа и повторные кадры на одинаковом наполненном рюкзаке.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Storage-Grid-Review")
	phase=OS.get_environment("FARM_STORAGE_REVIEW_PHASE").strip_edges().validate_filename()
	if phase.is_empty(): phase="after"
	folder="res://docs/reports/storage-grid-2026-10-13/"
	DirAccess.make_dir_recursive_absolute(folder)
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location="cottage_interior"; game.player=Cabinet.POSITION; game.sync_background_location(); game.update_camera()
	for kind in game.InventorySystem.ITEM_DATA:
		var count:int=game.inventory_item_count(kind)
		if count>0: game.change_inventory_count(kind,-count)
	for entry in [["plank",80],["milk",8],["carrot",30],["stone",12],["egg",5],["apple",20],["honey",9],["sunflower",6],["field_mint",11]]: game.change_inventory_count(entry[0],entry[1])
	for _frame in 8: await frame()
	var started:=Time.get_ticks_usec()
	if not Cabinet.open(game): push_error("Не удалось открыть шкаф стенда"); quit(1); return
	await frame(); metrics.first_cabinet_frame_ms=(Time.get_ticks_usec()-started)/1000.0
	var values:Array[float]=[]
	for _frame in 40:
		started=Time.get_ticks_usec(); await frame(); values.append((Time.get_ticks_usec()-started)/1000.0)
	values.sort(); metrics.cabinet_frame_median_ms=values[20]; metrics.cabinet_frame_p95_ms=values[37]
	await capture("cabinet")
	if phase!="before":
		Cabinet.state(game).selected=Cabinet.items(game).find("sunflower"); await capture("sunflower")
	Cabinet.close(game); game.home_chest_owned=true; game.home_chest_counts={"plank":22,"milk":4,"honey":2,"stone":120,"apple":5}; game.StorageSystem.open(game)
	await capture("chest")
	game.storage_open=false; game.LocaleSystem.current="de"; game.settings_state.text_scale=1.2; Cabinet.open(game); await capture("de-120")
	var file:=FileAccess.open(folder+phase+"-metrics.json",FileAccess.WRITE); file.store_string(JSON.stringify(metrics,"\t")); file.close()
	print("STORAGE WINDOW METRICS: "+JSON.stringify(metrics)); quit()

## Снимает полную перерисовку отдельного viewport вместе с завершением работы графического сервера.
func frame() -> void:
	game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.queue_redraw()
	await process_frame; RenderingServer.force_draw()

## Сохраняет нативный кадр без изменения пикселей и проверяет успешную запись.
func capture(label: String) -> void:
	for _frame in 4: await frame()
	if viewport.get_texture().get_image().save_png(folder+phase+"-"+label+".png")!=OK: push_error("Не удалось сохранить кадр "+label)

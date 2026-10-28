extends SceneTree

const Scene := preload("res://main.tscn")
const Workshop := preload("res://scripts/systems/workshop_system.gd")
const Research := preload("res://scripts/systems/research_system.gd")
var game:Node2D
var viewport:SubViewport
var errors:=0

## Готовит нативный графический стенд с независимой пользовательской папкой и фиксированным размером.
func _initialize() -> void:
	_start.call_deferred()

## Снимает все уровни четырёх семейств, очередь распила, обжиг и отдельное топливо стеклодува.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Workshops-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false; game.LocaleSystem.current="ru"
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	for level in range(1,4):
		Research.state(game).level=level
		for station in Workshop.Data.STATIONS: Workshop.state(game,station).level=level
		for station in Workshop.Data.STATIONS:
			move_to(station); await capture(station+"-level"+str(level))
	move_to("sawmill"); Workshop.state(game,"sawmill").level=1; game.change_inventory_count("log",1); game.open_crafting("sawmill"); select("sawmill:planks")
	game.CraftingSystem.craft(game,game.crafting_selected); await capture("sawmill-queued")
	game.crafting_open=false; Workshop.update(game,8); game.open_crafting("sawmill"); await capture("sawmill-finished")
	move_to("pottery"); game.change_inventory_count("wet_clay",2); game.open_crafting("pottery"); select("pottery:pot")
	game.CraftingSystem.craft(game,game.crafting_selected); game.crafting_open=false; Workshop.update(game,30)
	game.current_location="forge_interior"; game.player=game.FurnaceSystem.STATION; game.sync_background_location(); game.update_camera(); game.open_crafting("furnace"); select("kiln:pot")
	game.FurnaceSystem.state(game).level=3; game.change_inventory_count("coal",2); game.FurnaceSystem.state(game).fuel="coal"; game.FurnaceSystem.load_fuel(game)
	game.CraftingSystem.craft(game,game.crafting_selected); await capture("pottery-firing")
	move_to("glassblowing"); game.change_inventory_count("clear_glass",6); game.change_inventory_count("arcane_dust",3); game.energy=12
	Workshop.state(game,"glassblowing").fuel="coal"; game.open_crafting("glassblowing"); Workshop.load_fuel(game); select("glassblowing:lens")
	game.CraftingSystem.craft_many(game,game.crafting_selected,3); await capture("glass-lens-queue")
	game.settings_state.text_scale=1.2; game.LocaleSystem.current="de"; await capture("glass-de-120")
	print("WORKSHOPS CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Переключает настоящую комнату и камеру, сохраняя рабочую точку на свободном полу перед станком.
func move_to(station: String) -> void:
	game.crafting_open=false; game.tutorial_visible=false; game.message=""; game.hud_message_timer=0
	game.current_location=Workshop.Data.STATIONS[station].location; game.player=Workshop.Data.STATIONS[station].point
	game.sync_background_location(); game.update_camera()

## Выбирает общую технологию по постоянному идентификатору, а не текущему порядковому номеру.
func select(id: String) -> void:
	game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")==id)

## Дожидается GPU и сохраняет только фактический кадр заданного нативного размера без ресайза.
func capture(label: String) -> void:
	game.tutorial_visible=false
	for _frame in 8:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw()
	var frame:=viewport.get_texture().get_image()
	if frame.get_size()!=Vector2i(1152,648): errors+=1; push_error("Неверный размер кадра станка")
	if frame.save_png("res://docs/reports/workshops-2026-10-12-"+label+".png")!=OK: errors+=1
	print("WORKSHOPS FRAME: "+label)

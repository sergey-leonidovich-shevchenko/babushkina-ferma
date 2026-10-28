extends SceneTree

const Scene := preload("res://main.tscn")
const Furnace := preload("res://scripts/systems/furnace_system.gd")
var game:Node2D
var viewport:SubViewport
var errors:=0

## Создаёт отдельную визуальную модель печи без пользовательских сохранений.
func _initialize() -> void:
	_start.call_deferred()

## Показывает прежний спрайт печи, остановку без топлива, улучшения, очередь и завершённые изделия.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Furnace-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.LocaleSystem.current="ru"
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0.0
	game.current_location="forge_interior"; game.player=Furnace.STATION; game.sync_background_location(); game.update_camera()
	game.message=""; game.hud_message_timer=0.0; await capture("room")
	for kind in ["iron_ore","metal_scrap","sand","coal","trash","wood","glass","steel","metal","stone"]: game.change_inventory_count(kind,30)
	game.coins=1000; game.CraftingSystem.open(game,"furnace"); select("ore"); game.CraftingSystem.craft(game,game.crafting_selected)
	game.tutorial_visible=false; await capture("level1-waiting")
	Furnace.upgrade(game); game.tutorial_visible=false; game.settings_state.text_scale=1.2
	await capture("level2-upgrade")
	Furnace.upgrade(game); Furnace.state(game).fuel="coal"; Furnace.load_fuel(game); Furnace.load_fuel(game)
	select("glass"); game.CraftingSystem.craft(game,game.crafting_selected); select("charcoal"); game.CraftingSystem.craft(game,game.crafting_selected)
	game.tutorial_visible=false; game.LocaleSystem.current="de"; await capture("level3-de-120")
	game.crafting_open=false; Furnace.update(game,100.0); game.LocaleSystem.current="ru"; game.open_inventory()
	game.tutorial_visible=false; game.inventory_selected=game.inventory_slots.find("glass"); await capture("finished")
	print("FURNACE CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Выбирает конкретную технологию по ID, сохраняя различие трёх металлических выходов.
func select(id: String) -> void:
	game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="furnace:"+id)

## Сохраняет кадр настоящего renderer после прогрева только в каталог отчётов.
func capture(label: String) -> void:
	for _frame in 8:
		game.queue_redraw(); await RenderingServer.frame_post_draw
	var frame:=viewport.get_texture().get_image()
	if frame.get_size()!=Vector2i(1152,648): errors+=1; push_error("Контрольный viewport изменил размер: "+str(frame.get_size()))
	if frame.save_png("res://docs/reports/furnace-2026-10-12-"+label+".png")!=OK: errors+=1

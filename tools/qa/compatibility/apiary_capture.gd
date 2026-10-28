extends SceneTree

const Scene := preload("res://main.tscn")
const Basement := preload("res://scripts/systems/basement_system.gd")
const Build := preload("res://scripts/systems/basement_construction_system.gd")
const Controls := preload("res://scripts/systems/basement_input_system.gd")
const Stations := preload("res://scripts/systems/basement_station_system.gd")
var game:Node2D
var viewport:SubViewport
var errors:=0

## Готовит отдельный нативный стенд, не открывая пользовательские сохранения.
func _initialize() -> void:
	_start.call_deferred()

## Снимает пасеку A, три уровня, производство, гнездо и переработку сот в алхимии.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Apiary-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false; game.LocaleSystem.current="ru"
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	var Apiary=preload("res://scripts/systems/apiary_system.gd"); var ControlsApiary=preload("res://scripts/systems/apiary_input_system.gd")
	game.current_location="overworld"; game.player=Vector2(360,1272); game.sync_background_location(); game.update_camera(); await capture("empty-plots")
	for index in 3:
		game.player=Apiary.Data.SITES[index]+Vector2(0,48); Apiary.interact(game,"life:apiary:"+str(index))
		var item:Dictionary=Apiary.state(game).hives[index]
		for tier in index+1:
			var cost:Dictionary=Apiary.Data.COSTS[int(item.level)]; game.coins=1000; game.energy=12
			for kind in cost.inputs: game.change_inventory_count(kind,int(cost.inputs[kind]))
			if not Apiary.construct(game): errors+=1
		game.change_inventory_count("bees",1); Apiary.populate(game); ControlsApiary.close(game)
	game.day+=3; Apiary.update(game); game.player=Vector2(360,1272); game.update_camera(); await capture("three-levels")
	game.player=Apiary.Data.SITES[2]+Vector2(0,48); Apiary.interact(game,"life:apiary:2"); await capture("hive3-ru")
	game.settings_state.text_scale=1.2; game.LocaleSystem.current="de"; await capture("hive3-de-120")
	game.settings_state.text_scale=1; game.LocaleSystem.current="ru"; ControlsApiary.close(game)
	var wild:Dictionary=Apiary.Data.WILD[0]; game.player=wild.position+Vector2(0,48); game.update_camera(); await capture("wild-nest")
	game.current_location="cottage_interior"; game.player=game.CraftingSystem.Alchemy.STATION; game.sync_background_location(); game.update_camera(); game.CraftingSystem.open(game,"alchemy")
	game.change_inventory_count("honeycomb",2); var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:honey"); game.crafting_selected=index
	await capture("comb-separation")
	game.CraftingSystem.craft(game,index); game.talent_levels.craft_alchemy=1; game.CraftingSystem.Alchemy.state(game).xp=120
	for mix in Apiary.Data.MIXES:
		for kind in mix[1]: game.change_inventory_count(kind,int(mix[1][kind]))
		game.CraftingSystem.craft(game,game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:"+String(mix[0])))
	game.crafting_selected=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.get("id","")=="alchemy:propolis_balm")
	await capture("propolis-ointment")
	print("APIARY CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Сохраняет фактический кадр GPU без изменения размеров и проверяет успех записи.
func capture(label: String) -> void:
	game.tutorial_visible=false; game.message=""; game.hud_message_timer=0
	for _frame in 8:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw()
	var frame:=viewport.get_texture().get_image()
	if frame.get_size()!=Vector2i(1152,648): errors+=1; push_error("Неверный размер кадра подвала")
	if frame.save_png("res://docs/reports/apiary-2026-10-13-"+label+".png")!=OK: errors+=1
	print("APIARY FRAME: "+label)

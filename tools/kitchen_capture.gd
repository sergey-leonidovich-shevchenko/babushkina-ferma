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

## Снимает кухню A, настоящие стройки, ракурсы трёх уровней, очередь, огонь и заготовки.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Kitchen-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false; game.LocaleSystem.current="ru"
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location=Basement.Data.LOCATION; game.sync_background_location()
	var kitchens:Array=[]
	for direction in 4: kitchens.append(place("cauldron",14+direction*10,10,direction))
	game.player=Vector2(840,660); game.update_camera(); await capture("materials")
	for item in kitchens:
		game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); game.energy=12; Stations.interact(game,item.id); Build.update_hold(game,5)
	game.HeroActionSystem.update(game,1); game.player=Vector2(840,660); game.update_camera(); await capture("four-directions-level1")
	for tier in [2,3]:
		for item in kitchens: upgrade(item)
		game.HeroActionSystem.update(game,1); game.player=Vector2(840,660); game.update_camera(); await capture("four-directions-level"+str(tier))
	var kitchen:Dictionary=kitchens[0]
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(kitchen)); Stations.interact(game,kitchen.id); game.energy=12
	var Kitchen=preload("res://scripts/systems/kitchen_system.gd")
	for kind in ["mushroom_pie","vegetable_casserole","baked_potato"]:
		var index:int=game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output==kind)
		var recipe:Dictionary=game.CraftingSystem.RECIPES[index]
		for material in recipe.inputs: game.change_inventory_count(material,int(recipe.inputs[material]))
		if not game.CraftingSystem.craft(game,index): errors+=1; push_error("Не удалось поставить блюдо в очередь: "+kind)
		game.crafting_selected=index
	game.update_camera(); await capture("queue-waiting")
	game.change_inventory_count("charcoal",3); kitchen.production.fuel="charcoal"; Kitchen.load_fuel(game)
	game.settings_state.text_scale=1.2; game.LocaleSystem.current="de"; await capture("queue-de-120")
	game.settings_state.text_scale=1; game.LocaleSystem.current="ru"; await capture("queue-ru")
	game.crafting_open=false; Kitchen.advance(game,kitchen.production,0.25); game.player=Vector2(590,650); game.update_camera(); await capture("working-flame")
	Kitchen.advance(game,kitchen.production,0.125); await capture("working-flame-next")
	Kitchen.advance(game,kitchen.production,100)
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(kitchen)); Stations.interact(game,kitchen.id)
	game.change_inventory_count("wheat",2); game.CraftingSystem.craft(game,game.CraftingSystem.RECIPES.find_custom(func(recipe): return recipe.output=="flour"))
	game.set_meta("kitchen_filter","hot"); Kitchen.cycle_filter(game); await capture("cold-preparation")
	print("KITCHEN CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

## Размещает реальный первый уровень с оплатой у чертежа, выдавая только тестовые материалы.
func place(kind: String, x: int, y: int, direction: int=0) -> Dictionary:
	game.player=Basement.Data.BOARD; Basement.open(game); Basement.ui(game).tab=0; Basement.ui(game).selected=Basement.Data.STATIONS.keys().find(kind); Controls.execute(game)
	for material in Basement.Data.STATIONS[kind].inputs: game.change_inventory_count(material,int(Basement.Data.STATIONS[kind].inputs[material]))
	if not Build.build(game,{"kind":kind,"x":x,"y":y,"direction":direction}): errors+=1; push_error("Не удалось разместить "+kind+": "+game.message); return {}
	return Basement.state(game).objects.back()

## Повышает выбранный экземпляр оплатой чертежа и реальной посекундной работой.
func upgrade(item: Dictionary) -> void:
	game.player=Basement.Data.BOARD; Basement.open(game); game.coins=1000
	var cost:=Basement.Data.upgrade_cost(item.kind,item.level)
	for material in cost.inputs: game.change_inventory_count(material,int(cost.inputs[material]))
	if not Build.upgrade(game,item.id): errors+=1; return
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); Stations.interact(game,item.id)
	for second in int(item.duration): game.energy=int(item.energy); Build.update_hold(game,1)

## Сохраняет фактический кадр GPU без изменения размеров и проверяет успех записи.
func capture(label: String) -> void:
	game.tutorial_visible=false; game.message=""; game.hud_message_timer=0
	for _frame in 8:
		game.queue_redraw(); await process_frame; RenderingServer.force_draw()
	var frame:=viewport.get_texture().get_image()
	if frame.get_size()!=Vector2i(1152,648): errors+=1; push_error("Неверный размер кадра подвала")
	if frame.save_png("res://docs/reports/kitchen-2026-10-13-"+label+".png")!=OK: errors+=1
	print("KITCHEN FRAME: "+label)

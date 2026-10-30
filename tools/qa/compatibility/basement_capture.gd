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

## Снимает утверждённый подвал, реальные стройки, четыре ракурса и три раздела чертежа.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Basement-Visual-Review")
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport)
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game); current_scene=container
	game.set_physics_process(false); game.set_process(false); game.audio_enabled=false; game.LocaleSystem.current="ru"
	game.language_screen=false; game.title_screen=false; game.tutorial_visible=false; game.discovery_current={}; game.message=""; game.hud_message_timer=0
	var life:Dictionary=game.FarmLifeSystem.state(game); life.first_day=6; life.cutscene=""; life.cutscene_timer=0
	game.current_location="cottage_interior"; game.player=Vector2(850,494); game.update_camera(); await capture("house-stairs")
	game.current_location=Basement.Data.LOCATION; game.player=Basement.Data.BOARD; game.sync_background_location(); game.update_camera(); await capture("empty")
	Basement.open(game); Basement.ui(game).selected=2; await capture("blueprint-build")
	Controls.execute(game); await capture("placement")
	Basement.close(game)
	var items:Array=[]; var index:=0
	for kind in Basement.Data.STATIONS:
		items.append(place(kind,10+(index%5)*8,8+(index/5)*8)); index+=1
	game.player=Basement.Data.BOARD; game.update_camera(); await capture("materials")
	var pottery:Dictionary=items[2]
	game.player=Basement.Layout.center(Basement.Layout.approach_cell(pottery)); Stations.interact(game,pottery.id); Build.update_hold(game,2.5)
	game.HeroActionSystem.update(game,0.23); game.update_camera(); await capture("hammer-progress")
	Basement.ui(game).holding=0
	for item in items:
		game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); game.energy=12; Stations.interact(game,item.id); Build.update_hold(game,5)
	game.HeroActionSystem.update(game,1); game.player=Vector2(800,580); game.update_camera(); await capture("ready")
	game.player=Basement.Data.BOARD; game.update_camera()
	Basement.open(game); Basement.ui(game).tab=1; Basement.ui(game).selected=2; await capture("blueprint-upgrade")
	Basement.ui(game).tab=2; await capture("blueprint-dismantle")
	game.settings_state.text_scale=1.2; game.LocaleSystem.current="de"; await capture("blueprint-de-120")
	game.LocaleSystem.current="ru"; game.settings_state.text_scale=1; Basement.close(game)
	Basement.open(game); Basement.ui(game).tab=0; Basement.ui(game).selected=2; Controls.execute(game); Basement.ui(game).x=10; Basement.ui(game).y=8; await capture("blocked-overlap")
	Basement.close(game); Basement.state(game).objects.clear()
	for direction in 4:
		var item:=place("sawmill",12+direction*8,10,direction)
		game.player=Basement.Layout.center(Basement.Layout.approach_cell(item)); game.energy=12; Stations.interact(game,item.id); Build.update_hold(game,5)
	game.HeroActionSystem.update(game,1); game.player=Vector2(756,636); game.update_camera(); await capture("four-directions")
	for tier in [2,3]:
		for item in Basement.state(game).objects:
			upgrade(item)
		game.HeroActionSystem.update(game,1); game.player=Vector2(756,636); game.update_camera(); await capture("four-directions-level"+str(tier))
	print("BASEMENT CAPTURE: "+("PASS" if errors==0 else "FAIL")); quit(0 if errors==0 else 1)

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
	if frame.save_png("res://docs/reports/basement-2026-10-12-"+label+".png")!=OK: errors+=1
	print("BASEMENT FRAME: "+label)

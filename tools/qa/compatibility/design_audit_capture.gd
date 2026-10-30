extends "res://tools/qa/compatibility/paper_theme_capture.gd"

const Regions := preload("res://scripts/systems/village_region_data.gd")
const Rooms := preload("res://scripts/systems/cave_room_data.gd")

## Снимает все игровые локации и семейства интерфейса в отдельном профиле без сохранений пользователя.
func _start() -> void:
	if DisplayServer.get_name()=="headless": quit(2); return
	OS.low_processor_usage_mode=false
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","Codex-Design-Audit-20261014")
	var phase:=OS.get_environment("FARM_DESIGN_PHASE"); if phase.is_empty(): phase="before"
	folder="/private/tmp/moon-valley-design-audit/"+phase+"/"; DirAccess.make_dir_recursive_absolute(folder)
	var container:=SubViewportContainer.new(); root.add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(1152,648); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; container.add_child(viewport); current_scene=container
	var areas:Array=preload("res://scripts/systems/world_system.gd").LOCATIONS.duplicate()
	areas.append("moon_glade")
	for area in Regions.IDS+Rooms.IDS:
		if area not in areas: areas.append(area)
	areas.append_array(preload("res://scripts/systems/building_system.gd").INTERIORS.keys())
	for area in areas:
		if not _wanted("world-"+area): continue
		_reset(); configure("hud"); game.current_location=area
		if game.BuildingSystem.is_interior(area): game.player=game.BuildingSystem.INTERIORS[area].spawn-Vector2(0,96)
		elif Regions.added(area): game.player=Regions.NPC_POINTS.get(Regions.NPC_AREAS.find_key(area),Vector2(1104,744))+Vector2(72,72)
		elif Rooms.is_cave(area): game.player=Vector2(1200,600)
		else: game.player=Vector2(1248,744)
		game.day=1; game.game_minutes=720; game.state.world.weather_day=1; game.state.world.weather="clear"
		game.sync_background_location(); game.update_camera(); await _frame("world-"+area)
	if _wanted("detail-crops"):
		_reset(); configure("hud"); game.current_location="overworld"; game.day=1
		game.player=Vector2(game.FARM_ORIGIN)+Vector2(144,192); game.selected_tool=game.Tool.HAND
		for index in 8:
			var cell:=Vector2i(index%4,index/4); var plot:Dictionary=game.plots[cell]
			plot.tilled=true; plot.planted=true; plot.watered=false; plot.crop_kind="carrot"; plot.growth=3; plot.stage=1; plot.stage_flash=0
		game.sync_background_location(); game.update_camera(); await _frame("detail-crops")
	for label in ["inventory","cabinet","storage","crafting","kitchen","alchemy","study","furnace","shop","forge","quest-log","talent-tree","world-map","calendar","bestiary","recipes","compendium","creation","dialogue","dialogue-long","basement","basement-placement","apiary","contracts","fishing","pause","settings","language","title","inventory-de-120","cabinet-de-120"]:
		if not _wanted("ui-"+label): continue
		_reset(); configure(label); await _frame("ui-"+label)
	print("DESIGN AUDIT CAPTURE: "+phase); quit()

## Ограничивает повторную съёмку исправленными экранами при заданном списке имён.
func _wanted(label:String) -> bool:
	var only:=OS.get_environment("FARM_DESIGN_ONLY")
	return only.is_empty() or label in only.split(",")

## Пересоздаёт сцену, чтобы окна и эффекты предыдущего кадра не попадали в следующий.
func _reset() -> void:
	if is_instance_valid(game): game.free()
	game=Scene.instantiate(); game.set_meta("capture_windowed",true); viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.audio_enabled=false

## Сохраняет полный нативный кадр после прогрева фона без обработки пикселей.
func _frame(label:String) -> void:
	for _index in 5:
		game.message=""; game.tutorial_visible=false; game.discovery_current={}; game.queue_redraw()
		await process_frame; RenderingServer.force_draw()
	if viewport.get_texture().get_image().save_png(folder+label+".png")!=OK: push_error("Не удалось снять "+label)
	print("DESIGN AUDIT FRAME: "+label)

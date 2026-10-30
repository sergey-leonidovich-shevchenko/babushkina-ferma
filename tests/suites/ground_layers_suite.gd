extends RefCounted

const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Clock := preload("res://scripts/presentation/village_ground_clock.gd")

## Проверяет часы, обратимый проход и границы первой карты без выдачи headless за нативную графику.
static func run(context: SceneTree) -> void:
	test_transient_clock(context)
	test_clock_suspension(context)
	test_layer_lifecycle(context)

## Создаёт фиксированную настоящую сцену без вступления и без доступа к обычным пользовательским данным.
static func fixture() -> Node:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	game.settings_state.reduced_motion=false
	return game

## Сценарий: мир обновляется, затем часы декора читаются многократно и слот сохраняется.
## Исходное состояние: первая карта, остановленная автоматическая симуляция и отсутствие визуальных метаданных.
## Ожидаемый результат: чтение чистое, разрешённый такт двигает часы, а snapshot и игровые данные не зависят от фазы.
static func test_transient_clock(context: SceneTree) -> void:
	var game:=fixture(); var saved:Dictionary=game.SaveSystem.snapshot(game)
	context.expect(Clock.seconds(game)==0.0 and not game.has_meta(Clock.META),"reading ground clock is pure")
	Clock.advance(game,0.25); Clock.advance(game,0.75)
	context.expect(Clock.seconds(game)==1.0 and saved==game.SaveSystem.snapshot(game),"visual phase is transient and leaves full save unchanged")
	for bad in [0.0,-1.0,NAN,INF]: Clock.advance(game,bad)
	context.expect(Clock.seconds(game)==1.0,"invalid visual delta never poisons phase")
	game.GameLoop.physics_process(game,0.02)
	context.expect(is_equal_approx(Clock.seconds(game),1.02),"real production world tick advances decorative clock")
	game.free()

## Сценарий: игрок открывает паузу, рюкзак, редактор, теряет фокус либо покидает карту.
## Исходное состояние: собственные часы равны одной секунде; настройки и меню переключаются последовательно.
## Ожидаемый результат: время не накапливает долг, возвращение продолжает прежнюю фазу, режим эталона неподвижен.
static func test_clock_suspension(context: SceneTree) -> void:
	var game:=fixture(); Clock.advance(game,1.0)
	game.MenuSystem.open_pause(game); Clock.advance(game,5.0)
	context.expect(Clock.seconds(game)==1.0,"manual pause freezes decorative phase")
	game.MenuSystem.resume(game); game.inventory_open=true; Clock.advance(game,5.0); game.inventory_open=false
	context.expect(Clock.seconds(game)==1.0,"inventory freezes decorative phase")
	game.settings_state.pause_on_focus_loss=true; game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT); Clock.advance(game,5.0)
	context.expect(Clock.seconds(game)==1.0,"focus suspension freezes decorative phase")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN); game.settings_state.pause_on_focus_loss=false
	game.current_location="cottage_interior"; Clock.advance(game,5.0); game.current_location="overworld"
	context.expect(Clock.seconds(game)==1.0,"other map does not advance first-map phase")
	game.settings_state.reduced_motion=true; Clock.advance(game,5.0); game.settings_state.reduced_motion=false
	context.expect(Clock.seconds(game)==1.0,"reduced motion retains current phase")
	game.set_meta(&"level_editor",{"active":true}); Clock.advance(game,5.0); game.remove_meta(&"level_editor")
	context.expect(Clock.seconds(game)==1.0,"manual editor does not advance ground phase")
	game.set_meta(&"visual_reference_hud",true); Clock.advance(game,5.0); game.remove_meta(&"visual_reference_hud")
	context.expect(Clock.seconds(game)==1.0,"reference capture remains independent of decorative time")
	Clock.advance(game,0.25)
	context.expect(Clock.seconds(game)==1.25,"resume has no catch-up from suspended intervals")
	game.free()

## Сценарий: фон переключает карту, сезон, прямой fallback и обратимый монолитный проход.
## Исходное состояние: настоящие два CanvasItem и прежний offscreen-кеш; headless не создаёт render target.
## Ожидаемый результат: слои имеют общий transform и прежний порядок, скрыты вне overworld, переключения не портят слот.
static func test_layer_lifecycle(context: SceneTree) -> void:
	var game:=fixture(); var bg:Node=game.get_node("WorldBackground"); bg._ready()
	var saved:Dictionary=game.SaveSystem.snapshot(game)
	context.expect(not bg.water_layer.visible and bg.cover_layer.visible and not bg.water_layer.cover and bg.cover_layer.cover,"cold headless fallback keeps surface hidden until actual cache completion")
	context.expect(bg.water_layer.show_behind_parent and bg.water_layer.get_parent()==bg and bg.cover_layer.get_parent()==bg.terrain_canvas,"surface inherits background projection below cached cover")
	bg.set_ground_split(false)
	context.expect(not bg.water_layer.visible and not bg.cover_layer.visible,"legacy pipeline cannot double-draw surface or cover")
	bg.set_ground_split(true); bg.set_location("cottage_interior")
	context.expect(not bg.water_layer.visible and not bg.cover_layer.visible,"interior hides both first-map passes immediately")
	bg.set_location("village_river")
	context.expect(not bg.water_layer.visible and not bg.cover_layer.visible,"other village map retains its prior pipeline")
	bg.set_location("overworld"); bg.set_environment("winter","snow")
	context.expect(bg.ground_split and bg.water_layer.visible==bg.terrain_ready and bg.water_layer.season=="winter" and bg.cover_layer.weather=="snow","return and environment synchronize retained layers")
	bg.set_meta("terrain_direct",true); bg._sync_ground_layers()
	context.expect(not bg.water_layer.visible and bg.cover_layer.visible and bg.cutout_layer.visible,"direct fallback hides surface while keeping future cached coverage complete")
	bg.set_meta("terrain_direct",false); bg._sync_ground_layers()
	context.expect(saved==game.SaveSystem.snapshot(game),"layer lifecycle leaves all saved gameplay unchanged")
	var bounded:=true
	for polygon in preload("res://scripts/systems/village_terrain_renderer.gd").surface_polygons(true):
		for point in polygon:
			if point.x<0.0 or point.y<0.0 or point.x>2400.0 or point.y>1368.0: bounded=false
	context.expect(bounded,"live water retains offscreen cache world clipping for manual editor camera")
	game.free()

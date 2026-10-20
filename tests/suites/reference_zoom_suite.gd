extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")
const WorldProjection := preload("res://scripts/systems/world_projection_system.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const Visibility := preload("res://scripts/systems/world_visibility_system.gd")

## Проверяет реальную камеру, обратный ввод, физические данные и границы первого приближённого мира.
static func run(context: SceneTree) -> void:
	test_projection_and_input(context)
	test_nested_transforms(context)
	test_scope_pause_and_rollback(context)
	test_published_editor_return(context)
	test_two_line_label_bounds(context)

## Создаёт настоящий runtime, затем снимает только явный 100% override исторической фикстуры.
static func fixture() -> Node:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	game.remove_meta(WorldProjection.OVERRIDE); game.update_camera(); Pose.reset(game)
	return game

## Сценарий: три физических окна, обе стороны клетки и порога камеры, все края карты.
## Исходное состояние: штатная первая карта и оба явных профиля масштаба.
## Ожидаемый результат: поле 960×540, стопа в центре, ввод после stretch возвращает прежнюю мировую клетку.
static func test_projection_and_input(context: SceneTree) -> void:
	var game:=fixture()
	context.expect(WorldProjection.zoom(game)==1.2,"normal overworld uses the selected 120% without a test-only activation")
	var document:=JSON.stringify(game.SaveSystem.snapshot(game))
	for amount in [1.0,1.2]:
		context.expect(WorldProjection.set_reference_zoom(game,amount),"explicit accepted reference profile")
		var field:Vector2=Vector2(1152,648)/float(amount)
		context.expect(WorldProjection.field_size(game).is_equal_approx(field),"whole-world field follows the profile")
		for position in [Vector2(40.25,672.25),Vector2(479.875,672.25),Vector2(480.125,672.25),Vector2(600.25,700.25),Vector2(2359.75,1287.75)]:
			game.player=position; game.update_camera(); Pose.reset(game)
			var expected:=Vector2(clampf(position.x-field.x/2,0,2400-field.x),clampf(position.y-field.y/2,0,1368-field.y))
			context.expect(game.camera_offset.is_equal_approx(expected),"camera clamps using the actual world field")
			var view:=WorldProjection.view_rect(game)
			context.expect(view.size.is_equal_approx(field) and view.position.is_equal_approx(expected),"culling and camera use one world rectangle")
			context.expect(Visibility.visible_rect(game).grow(-Visibility.EDGE_MARGIN).is_equal_approx(view),"visibility keeps its margin in world units")
			var background:Node2D=game.get_node("WorldBackground")
			context.expect(background.scale.is_equal_approx(Vector2.ONE*amount) and background.position.is_equal_approx(-expected*amount),"separate terrain layer has the same scale and offset")
			for size in [Vector2(1152,648),Vector2(1920,1080),Vector2(2304,1296)]:
				for world in [Vector2(0.125,720.125),Vector2(23.875,720.125),Vector2(24.125,720.125),Vector2(2399.875,1367.875)]:
					var screen:=WorldProjection.world_to_screen(game,world)
					var window:Vector2=game.UiScaleSystem.design_to_screen(screen,size)
					var restored:=WorldProjection.screen_to_world(game,game.UiScaleSystem.screen_to_design(window,size))
					context.expect(restored.distance_to(world)<0.001,"single window/Retina transform round-trips through zoom")
					context.expect(game.FenceSystem.target_cell(game,restored)==game.FenceSystem.target_cell(game,world),"zoom does not move the interaction cell")
			context.expect(game.PLAYER_RADIUS==18 and game.speed==210,"scale never resizes collision or physical speed")
	game.player=Points.vector(JSON.parse_string(document).player)
	context.expect(JSON.stringify(game.SaveSystem.snapshot(game))==document,"camera profile does not enter the player save")
	game.free()

## Сценарий: спрайт животного, отражённое оружие и повёрнутый предмет меняют локальную матрицу.
## Исходное состояние: первая карта 120%, локальные вращения и отражение спрайта.
## Ожидаемый результат: вложенный draw-transform не сбрасывает мировой масштаб или смещение камеры.
static func test_nested_transforms(context: SceneTree) -> void:
	var game:=fixture(); game.player=Vector2(900.25,700.25); game.update_camera()
	for rotation in [0.0,PI/2,-0.6]:
		for scale in [Vector2.ONE,Vector2(-1,1),Vector2(1,0.3)]:
			var origin:=Vector2(970.25,680.75)
			var local:=Transform2D(rotation,scale,0.0,origin)
			var matrix:=WorldProjection.transform(game,local)
			for point in [Vector2.ZERO,Vector2(16,-30)]:
				var expected:Vector2=(local*point-game.camera_offset)*1.2
				context.expect((matrix*point).distance_to(expected)<0.001,"local rotation/mirror is composed before world projection")
	var hud:Rect2=game.HudLayoutSystem.HOTBAR_RESERVED_RECT
	context.expect(hud.end.y==648 and game.CameraSystem.playfield_rect(game).size.x==1152,"HUD design geometry remains unscaled")
	var label:=preload("res://scripts/presentation/world_label_renderer.gd").bounds(game,game.player+Vector2(1000,1000),"Проверка")
	var projected:=Rect2(WorldProjection.world_to_screen(game,label.position),label.size*1.2)
	context.expect(game.CameraSystem.playfield_rect(game).encloses(projected),"world labels remain inside the same unscaled HUD safe area")
	game.free()

## Сценарий: перенос, пауза, ручной редактор, неподдерживаемый зум и возврат к 100%.
## Исходное состояние: штатные карты, сохранённая отображаемая поза и отдельное состояние редактора.
## Ожидаемый результат: нет сжатия ниже 100%, изменения других карт или следа прежней камеры.
static func test_scope_pause_and_rollback(context: SceneTree) -> void:
	var game:=fixture()
	for point in Points.registry().points:
		game.current_location=point.location
		context.expect(WorldProjection.zoom(game)==(1.2 if point.location=="overworld" else 1.0),"only first overworld changes: "+point.location)
	game.current_location="overworld"; game.player=Vector2(600.25,700.25); game.update_camera(); Pose.reset(game)
	for bad in [0.0,0.8,1.1,1.4,NAN,INF]:
		context.expect(not WorldProjection.set_reference_zoom(game,bad) and WorldProjection.zoom(game)==1.2,"unsupported zoom cannot shrink foliage or bypass the accepted limits")
	Pose.begin_tick(game); game.player+=Vector2.ONE*0.1; Pose.end_tick(game,1.0/60); Pose.present(game,0.5)
	context.expect(WorldProjection.world_to_screen(game,Pose.ground(game)).is_equal_approx(Vector2(576,324)),"interpolated visible foot remains centered at 120%")
	game.menu_state.pause_open=true
	var frozen:Vector2=game.camera_offset; Pose.present(game,0.9)
	context.expect(game.camera_offset==frozen,"pause does not reproject the frozen frame")
	game.menu_state.pause_open=false
	var manual_camera:Vector2=game.camera_offset
	game.LevelEditorSystem.toggle(game)
	context.expect(WorldProjection.zoom(game)==1.0,"manual editor keeps its own 100% field and pointer contract")
	var background:Node2D=game.get_node("WorldBackground")
	context.expect(background.scale==Vector2.ONE and background.position==-manual_camera,"opening F12 immediately resets the terrain projection even while simulation is suspended")
	context.expect(game.camera_offset==manual_camera,"changing projection does not overwrite the manually owned camera")
	game.LevelEditorSystem.pan_camera(game,Vector2(7,-3))
	context.expect(game.camera_offset==manual_camera+Vector2(7,-3) and background.position==-game.camera_offset,"manual panning keeps the terrain and input in the same 100% projection")
	manual_camera=game.camera_offset
	game.LevelEditorSystem.toggle(game)
	context.expect(background.scale==Vector2.ONE*1.2 and background.position.is_equal_approx(-manual_camera*1.2),"closing F12 immediately restores the terrain projection")
	game.set_meta("published_level_runtime",{"active":true})
	context.expect(WorldProjection.zoom(game)==1.0,"published editor preview preserves its authored reference projection")
	game.set_meta("published_level_runtime",{"active":false})
	context.expect(WorldProjection.set_reference_zoom(game,1.0),"explicit rollback remains available")
	game.update_camera()
	context.expect(game.get_node("WorldBackground").scale==Vector2.ONE and WorldProjection.field_size(game)==Vector2(1152,648),"rollback resets terrain and world without a restart")
	game.free()

## Сценарий: настоящий запуск авторского preview и возврат в ручной F12.
## Исходное состояние: первая карта 120%, редактор 100%, сохранённая ручная камера и точка SPAWN.
## Ожидаемый результат: после возврата фон сразу использует 100%, камера возвращается без следующего физического такта.
static func test_published_editor_return(context: SceneTree) -> void:
	var game:=fixture()
	var editor:Dictionary=game.LevelEditorSystem.default_state(game)
	editor.active=true; editor.objects=[{"runtime_role":"spawn","position":Vector2(576,720)}]
	game.set_meta(game.LevelEditorSystem.META_KEY,editor)
	game.camera_offset=Vector2(321.25,123.25); WorldProjection.sync_background(game)
	context.expect(game.PublishedLevelSystem.start_playtest(game,editor,{"level_name":"zoom-reference"}),"real editor preview starts with a valid spawn")
	context.expect(WorldProjection.zoom(game)==1.0 and game.get_node("WorldBackground").scale==Vector2.ONE,"published preview keeps the authored terrain scale")
	context.expect(game.PublishedLevelSystem.finish_playtest(game,false),"real preview returns to the editor")
	var background:Node2D=game.get_node("WorldBackground")
	context.expect(game.camera_offset==Vector2(321.25,123.25) and background.scale==Vector2.ONE and background.position==-game.camera_offset,"return restores both the manual camera and 100% background immediately")
	game.free()

## Сценарий: одно- и двухстрочные подписи у четырёх углов при обоих масштабах.
## Исходное состояние: текст и дополнительная строка принадлежат миру, панели HUD — экрану.
## Ожидаемый результат: вся карточка после проекции остаётся в безопасной области без наложения на HUD.
static func test_two_line_label_bounds(context: SceneTree) -> void:
	var game:=fixture()
	for amount in [1.0,1.2]:
		WorldProjection.set_reference_zoom(game,amount); game.update_camera()
		var safe:Rect2=game.CameraSystem.playfield_rect(game).grow(-8)
		for anchor in [Vector2(-1000,-1000),Vector2(3400,-1000),Vector2(-1000,2368),Vector2(3400,2368)]:
			for extra in [0.0,22.0]:
				var rect:=preload("res://scripts/presentation/world_label_renderer.gd").bounds(game,anchor,"Переход в деревню",200,extra)
				var projected:=Rect2(WorldProjection.world_to_screen(game,rect.position),rect.size*float(amount))
				context.expect(safe.grow(0.001).encloses(projected),"the complete sign card stays inside the screen HUD safe area")
	game.free()

extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")
const Legacy := preload("res://docs/reports/visual-overhaul/vcamera-002/legacy_camera_system.gd")
const Actor := preload("res://scripts/systems/animation_renderer.gd")
const Scale := preload("res://scripts/systems/ui_scale_system.gd")

## Проверяет дробную проекцию и прежний контроль на настоящих картах, не подменяя нативное видео.
static func run(context: SceneTree) -> void:
	test_existing_maps(context)
	test_slow_tracking(context)
	test_boundaries_and_input(context)

## Сценарий: дробная опора на всех прежних точках, включая маленькие комнаты и большие залы.
## Исходное состояние: отдельные тестовые экземпляры без пользовательских слотов.
## Ожидаемый результат: прежнее округление воспроизводится точно, изменяется только квантование камеры.
static func test_existing_maps(context: SceneTree) -> void:
	for point in Points.registry().points:
		var game:=Points.create_game(); game._ready(); Points.configure(game,point)
		game.player+=Vector2(0.125,0.375)
		var before:Vector2=game.player; var minutes:float=game.game_minutes
		var candidate:Vector2=game.CameraSystem.target_offset(game)
		var legacy:Vector2=Legacy.target_offset(game)
		context.expect(candidate.round()==legacy,"legacy snapshot equals rounded candidate: "+point.id)
		context.expect(candidate.distance_to(legacy)<=0.708,"quantization stays within half a pixel per axis: "+point.id)
		context.expect(game.player==before and game.game_minutes==minutes,"camera calculation does not change gameplay: "+point.id)
		game.update_camera()
		context.expect(game.get_node("WorldBackground").position==-candidate,"background and world share the fractional offset: "+point.id)
		context.expect((Actor.player_ground(game)-candidate+game.camera_offset).is_equal_approx(before),"rendered feet restore physical position: "+point.id)
		game.free()

## Сценарий: медленная диагональ в зоне свободного слежения.
## Исходное состояние: дробный шаг меньше пикселя, старый CameraSystem сохранён отдельным исходником.
## Ожидаемый результат: опора остаётся в центре без задержки, прежнее целое квантование обнаруживается.
static func test_slow_tracking(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var old_min:=Vector2.INF; var old_max:=-Vector2.INF
	for frame in 121:
		game.player=Vector2(600.125,700.125)+Vector2.ONE*(18.0/sqrt(2.0)/60.0)*frame
		game.update_camera()
		var canvas:Vector2=Actor.player_ground(game)-game.camera_offset
		var old_canvas:Vector2=game.player-Legacy.target_offset(game)
		old_min=old_min.min(old_canvas); old_max=old_max.max(old_canvas)
		context.expect(canvas.is_equal_approx(Vector2(576,324)),"subpixel tracking holds the same physical feet at the center")
		context.expect(game.get_node("WorldBackground").position==-game.camera_offset,"slow background follows the identical projection")
		context.expect(game.camera_offset==game.CameraSystem.target_offset(game),"tracking has no temporal lag or hidden smoothing state")
	context.expect((old_max-old_min).x>0.9 and (old_max-old_min).y>0.9,"control exposes the old quantization instead of accepting both implementations")
	game.free()

## Сценарий: края карты и обе стороны границ сетки при трёх форматах окна.
## Исходное состояние: действующая физическая геометрия, единый логический холст и дробная камера.
## Ожидаемый результат: фон не выходит за карту, ввод преобразуется один раз и выбирает прежнюю клетку.
static func test_boundaries_and_input(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	for position in [Vector2(40,672.25),Vector2(575.875,672.25),Vector2(576.125,672.25),Vector2(2360,1288)]:
		game.player=position; game.update_camera()
		var expected:=Vector2(clampf(position.x-576,0,1248),clampf(position.y-324,0,720))
		context.expect(game.camera_offset==expected,"fractional follow respects both world bounds and threshold sides")
		for size in [Vector2(1152,648),Vector2(1920,1080),Vector2(2304,1296)]:
			for world in [Vector2(0.125,720.125),Vector2(23.875,720.125),Vector2(24.125,720.125),Vector2(2399.875,1287.875)]:
				var canvas:Vector2=world-game.camera_offset
				var window:=Scale.design_to_screen(canvas,size)
				var restored:Vector2=Scale.screen_to_design(window,size)+game.camera_offset
				context.expect(restored.distance_to(world)<0.001,"edge pointer survives fractional camera and window scale")
				context.expect(game.FenceSystem.target_cell(game,restored)==game.FenceSystem.target_cell(game,world),"edge pointer retains its containing interaction cell")
	game.free()

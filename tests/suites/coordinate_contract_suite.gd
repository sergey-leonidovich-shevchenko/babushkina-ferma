extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")
const AnimationRenderer := preload("res://scripts/systems/animation_renderer.gd")
const Visual := preload("res://scripts/systems/hero_visual_system.gd")
const Scale := preload("res://scripts/systems/ui_scale_system.gd")
const Basement := preload("res://scripts/systems/basement_layout_system.gd")

## Проверяет привязку стоп, независимость физики от окна и обе стороны перехода к клеткам.
static func run(context: SceneTree) -> void:
	test_fractional_feet_match_physics(context)
	test_every_map_uses_the_same_camera_origin(context)
	test_scaled_pointer_preserves_cell_boundaries(context)
	test_camera_clamps_and_centers_rooms(context)

## Сценарий: герой стоит в дробной позиции и меняет кадры ходьбы и работы мотыгой.
## Исходное состояние: физическая позиция между целыми пикселями и четыре основных направления.
## Ожидаемый результат: измеренная точка стоп точно совпадает с физикой, а прежнее округление обнаруживается.
static func test_fractional_feet_match_physics(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	for position in [Vector2(575.49,672.49),Vector2(576.51,672.51),Vector2(624.125,719.875)]:
		game.player=position; game.update_camera()
		var ground:=AnimationRenderer.player_ground(game)
		context.expect(ground==position,"renderer preserves fractional physical feet")
		context.expect(ground!=position.round(),"fractional fixture detects old separate rounding")
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
			for frame in 4:
				for pose in [Visual.walk_pose(direction,frame/8.0,true),Visual.hoe_pose(direction,(frame+0.1)/4.0)]:
					var rect:=Visual.destination(ground,pose)
					var foot:=rect.position+Vector2(pose.pivot)*float(pose.scale)
					context.expect(foot.is_equal_approx(position),"walk/tool pivot agrees with physics")
					context.expect((foot+game.PresentationSystem.world_offset(game)).is_equal_approx(position-game.camera_offset),"rendered feet and interaction origin share canvas")
	game.free()

## Сценарий: все тридцать карт применяют штатную камеру к герою и отдельному фоновому узлу.
## Исходное состояние: прежние закреплённые точки и дробное смещение героя без изменения масштаба мира.
## Ожидаемый результат: камера и фон согласованы, обратное преобразование восстанавливает мировую точку.
static func test_every_map_uses_the_same_camera_origin(context: SceneTree) -> void:
	for point in Points.registry().points:
		var game:=Points.create_game(); game._ready(); Points.configure(game,point)
		game.player+=Vector2(0.375,0.625); game.update_camera()
		var canvas:Vector2=AnimationRenderer.player_ground(game)+game.PresentationSystem.world_offset(game)
		context.expect((canvas+game.camera_offset).is_equal_approx(game.player),"world/canvas round trip: "+point.id)
		context.expect(game.get_node("WorldBackground").position==-game.camera_offset,"background follows same camera: "+point.id)
		context.expect(game.camera_offset==game.CameraSystem.target_offset(game),"current camera policy retained: "+point.id)
		game.free()

## Сценарий: указатель проходит по обеим сторонам границ разных сеток при пяти размерах окна.
## Исходное состояние: камера с дробным смещением, полноэкранный холст и форматы с полями.
## Ожидаемый результат: обратный масштаб применяется один раз; клетка, подвал и редактор сохраняют цель.
static func test_scaled_pointer_preserves_cell_boundaries(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	game.camera_offset=Vector2(143.25,281.75)
	var sizes:=[Vector2(1152,648),Vector2(1920,1080),Vector2(2304,1296),Vector2(1024,768),Vector2(2560,1080)]
	for size in sizes:
		var layout:=Scale.viewport_layout(size)
		context.expect(absf(Vector2(layout.content_size).x/Vector2(layout.content_size).y-16.0/9.0)<0.0001,"uniform scale preserves proportions")
		for world in [Vector2(479.99,719.99),Vector2(480.01,720.01),Vector2(-0.01,24.01),Vector2(480,720)]:
			var canvas:Vector2=world-game.camera_offset
			var window:=Scale.design_to_screen(canvas,size)
			var restored:Vector2=Scale.screen_to_design(window,size)+game.camera_offset
			context.expect(restored.distance_to(world)<0.001,"window/canvas/world precision")
			context.expect(game.FenceSystem.target_cell(game,restored)==game.FenceSystem.target_cell(game,world),"24 px fence cell survives scale")
			context.expect(game.WorldFarmingSystem.cell_at(restored)==game.WorldFarmingSystem.cell_at(world),"48 px farm cell survives scale")
			context.expect(Basement.cell(restored)==Basement.cell(world),"offset basement grid survives scale")
			for grid in [12,24,48,96]:
				context.expect(game.LevelEditorSystem.grid_cell({"grid":grid},restored)==game.LevelEditorSystem.grid_cell({"grid":grid},world),"editor grid survives scale")
		if size.x>1152:
			var correct:=Scale.design_to_screen(Vector2(576,324),size)
			context.expect((Scale.screen_to_design(correct/2.0,size)-Vector2(576,324)).length()>100,"extra Retina division is rejected")
	game.free()

## Сценарий: герой пересекает предел слежения и посещает маленькую комнату.
## Исходное состояние: настоящие границы улицы, фиксированная логическая область и окно другого размера в расчётах.
## Ожидаемый результат: камера зажата по карте, маленькая комната центрируется, отрицательная камера допустима.
static func test_camera_clamps_and_centers_rooms(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	for x in [40.25,575.75,576.25,1200.25,2360.25]:
		game.player=Vector2(x,672.25); game.update_camera()
		context.expect(game.camera_offset.x==clampf(x-576,0,1248),"outdoor clamp preserves fractional projection")
	game.current_location="cottage_interior"; game.player=Vector2(576,470); game.update_camera()
	var room:Rect2=game.BuildingSystem.interior(game.current_location).room
	var field:Rect2=game.CameraSystem.playfield_rect(game)
	context.expect((room.get_center()-game.camera_offset).distance_to(field.get_center())<=0.71,"small room centered in free HUD field")
	var first:Vector2=game.camera_offset; game.player+=Vector2(20,0); game.update_camera()
	context.expect(game.camera_offset==first,"small room does not chase hero")
	game.free()

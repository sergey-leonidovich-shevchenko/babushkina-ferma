extends RefCounted

const Points := preload("res://tools/visual_camera_points.gd")
const Reference := preload("res://scripts/presentation/visual_reference_mode.gd")
const Ambient := preload("res://scripts/systems/village_ambient_renderer.gd")

## Проверяет отсутствие игровых побочных эффектов и неподвижность декоративного слоя.
static func run(context: SceneTree) -> void:
	test_reference_is_transient(context)
	test_ambient_pose(context)

## Сценарий: эталон включается с HUD, без HUD, затем отключается и переносится на другую карту.
## Исходное состояние: настоящая новая деревня с закреплённой камерой и сохранённым снимком состояния.
## Ожидаемый результат: меняется только отрисовка, сохранение и камера неизменны, другие карты не затронуты.
static func test_reference_is_transient(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); var point:Dictionary=Points.registry().points[0]
	Points.configure(game,point)
	# Проверка проходимости лениво создаёт реестр оград; завершаем подготовку до контрольного снимка.
	context.expect(Points.errors(game,point).is_empty(),"reference fixture is valid before snapshot")
	var original:=JSON.stringify(game.SaveSystem.snapshot(game)); var camera:Vector2=game.camera_offset
	context.expect(Reference.effects_enabled(game) and Reference.hud_visible(game) and not game.has_meta(Reference.META),"ordinary rendering untouched")
	for hud in [true,false,true]:
		context.expect(Reference.enable(game,hud) and not Reference.effects_enabled(game),"reference disables decorative passes")
		context.expect(Reference.hud_visible(game)==hud,"reference selects requested HUD")
		context.expect(JSON.stringify(game.SaveSystem.snapshot(game))==original and game.camera_offset==camera,"reference never changes save or camera")
		context.expect(Points.errors(game,point).is_empty(),"reference preserves full camera contract")
	Reference.disable(game); Reference.disable(game)
	context.expect(not game.has_meta(Reference.META) and Reference.effects_enabled(game) and Reference.hud_visible(game),"disable restores ordinary renderer idempotently")
	Reference.enable(game,false); game.current_location="cottage_interior"
	context.expect(not Reference.active(game) and Reference.hud_visible(game) and Reference.effects_enabled(game),"reference cannot leak rendering override to another map")
	Reference.disable(game)
	context.expect(not Reference.enable(game,false) and not game.has_meta(Reference.META),"unsupported map rejects activation atomically")
	game.free()

## Сценарий: системное время меняется при одинаковых координатах растения.
## Исходное состояние: камыши, цветы и кувшинки с различными фазами; обычный и эталонный режимы.
## Ожидаемый результат: эталон неподвижен, а обычная формула движения и прозрачности сохранена точно.
static func test_ambient_pose(context: SceneTree) -> void:
	var position:=Vector2(422,311)
	for kind in ["water_lilies","reeds","flowers"]:
		for phase in [0.0,1.3,4.8]:
			for time in [0.0,2.5,60.0,86400.0]:
				var still:=Ambient.ground_pose(kind,position,phase,time,false)
				context.expect(still.position==position and is_equal_approx(still.alpha,0.82),"static flora independent of time and phase")
				var live:=Ambient.ground_pose(kind,position,phase,time)
				var sway:=sin(time+phase)*(0.018 if kind!="water_lilies" else 0.008)
				var expected:=position+Vector2(sway*30.0,sin(time*0.55+phase)*1.2)
				context.expect(live.position==expected and is_equal_approx(live.alpha,0.82+sin(time*0.7+phase)*0.08),"ordinary flora preserves original formula")

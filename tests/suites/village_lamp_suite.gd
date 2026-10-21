extends RefCounted

const Lamp := preload("res://scripts/presentation/village_lamp_visual.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const Rules := preload("res://tools/ground_seasons_fixture.gd")

## Проверяет независимый корпус, измеренный источник и повторное использование двух общих meshes.
static func run(ctx: SceneTree) -> void:
	# Подготовка: дробная опора выявляет округление и растяжение отдельных направлений.
	var ground:=Vector2(720.25,612.5);var paths:=[]
	for side in [0,1,3]:
		# Действие: читаем корпус и оба независимых кешированных слоя.
		var view:=Lamp.view(side);var rect:=Lamp.destination(ground,side);paths.append(view.path)
		# Проверка: источник совпадает с тем же пикселем PNG, который описан в паспорте.
		ctx.expect(rect.size.is_equal_approx(view.source.size*0.25),"lamp uniform source density: "+str(side))
		ctx.expect((rect.position+rect.size*view.pivot).is_equal_approx(ground),"lamp fractional ground pivot: "+str(side))
		ctx.expect(rect.has_point(Lamp.emitter(ground,side)),"lamp emitter lies inside body: "+str(side))
		ctx.expect(Lamp.glow_mesh(side)==Lamp.glow_mesh(0),"all facings share one glow mesh: "+str(side))
		ctx.expect(Lamp.shadow(side)==Lamp.shadow(0),"all facings share one base shadow: "+str(side))
		ctx.expect(Lamp.glow_mesh(side).get_surface_count()==1,"single glow surface: "+str(side))
		ctx.expect(Lamp.approach(ground,side)!=ground,"single visible working side: "+str(side))
	ctx.expect(paths[0]!=paths[1] and paths[1]!=paths[2] and paths[0]!=paths[2],"three independent unlit body PNGs")
	ctx.expect(Lamp.destination(ground,2)==Lamp.destination(ground,0),"legacy back direction aliases front")
	# Действие: выбираем существующие времена календаря по обе стороны границ суток.
	for sample in [[0.0,1.0],[300.0,1.0],[360.0,0.5],[420.0,0.0],[720.0,0.0],[1080.0,0.0],[1140.0,0.5],[1200.0,1.0],[1320.0,1.0]]:
		ctx.expect(is_equal_approx(Lamp.intensity(sample[0]),sample[1]),"lamp follows existing calendar ramp: "+str(sample[0]))
	for boundary in [300.0,420.0,1080.0,1200.0]:
		ctx.expect(absf(Lamp.intensity(boundary-0.0001)-Lamp.intensity(boundary+0.0001))<0.00001,"lamp has continuous dawn/dusk boundary: "+str(boundary))
	retention(ctx)

## Удерживает полный мир и проход, затем проверяет настоящую физическую паузу и возобновление часов.
static func retention(ctx: SceneTree) -> void:
	# Подготовка: реальная изолированная сцена с прогретыми правилами земли.
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	var navigation:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	# Действие: многократное разрешение геометрии не выполняет игровое обновление.
	for i in 24:
		Lamp.destination(Vector2(i*24,600),i%4);Lamp.emitter(Vector2.ZERO,i%4);Lamp.glow_mesh(i%4);Lamp.shadow(i%4)
	# Проверка: графика не меняет сохранение или правила движения.
	ctx.expect(before==game.SaveSystem.snapshot(game),"lamp caches preserve full saved world")
	ctx.expect(navigation==Rules.rules(game),"lamp caches preserve 1200 rules and eight bridge moves")
	for prop in Layout.PROP_PLACEMENTS:
		if prop.kind=="lamp":ctx.expect(Layout.prop_collision_rect(prop).size==Vector2(24,24),"installed lamp keeps 24x24 solid")
	game.game_minutes=1140.0;game.menu_state.pause_open=true
	var strength:=Lamp.intensity(game.game_minutes)
	# Действие: настоящий вход физического игрового цикла получает прошедшую секунду при паузе.
	game._physics_process(1.0)
	ctx.expect(game.game_minutes==1140.0 and Lamp.intensity(game.game_minutes)==strength,"pause freezes existing clock and glow strength")
	game.menu_state.pause_open=false;game._physics_process(1.0)
	ctx.expect(game.game_minutes>1140.0 and Lamp.intensity(game.game_minutes)>strength,"resume advances the same calendar-driven light")
	game.free()

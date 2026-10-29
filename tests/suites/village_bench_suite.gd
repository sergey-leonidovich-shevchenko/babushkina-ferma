extends RefCounted

const Bench := preload("res://scripts/presentation/village_bench_visual.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const Rules := preload("res://tools/qa/ground/ground_seasons_fixture.gd")

## Проверяет три одинаково масштабируемых ракурса и настоящие четыре точки опоры.
static func run(ctx: SceneTree) -> void:
	# Подготовка: берём дробную опору, чтобы заметить скрытое округление и растяжение.
	var ground:=Vector2(720.25,612.5)
	# Действие: разрешаем три отдельных PNG и их общую кешированную тень.
	var paths:=[]
	for side in [0,1,3]:
		var view:=Bench.view(side);var rect:=Bench.destination(ground,side);var contacts:=Bench.contacts(ground,side)
		paths.append(view.path)
		# Проверка: стороны не зеркалятся на лету и не теряют четыре ножки.
		ctx.expect(rect.size.is_equal_approx(view.source.size*0.25),"bench has uniform four-source-pixel scale: "+str(side))
		ctx.expect((rect.position+rect.size*view.pivot).is_equal_approx(ground),"bench preserves fractional ground anchor: "+str(side))
		ctx.expect(contacts.size()==4,"bench has four distinct contact points: "+str(side))
		ctx.expect(Bench.shadow(side)==Bench.shadow(side),"bench shadow mesh is reused: "+str(side))
		ctx.expect(Bench.shadow(side).get_surface_count()==1,"bench uses one contact/cast mesh: "+str(side))
		ctx.expect(Bench.approach(ground,side)!=ground,"bench has one seat-side approach: "+str(side))
	ctx.expect(paths[0]!=paths[1] and paths[1]!=paths[2] and paths[0]!=paths[2],"three bench views use separate resources")
	ctx.expect(Bench.destination(ground,2)==Bench.destination(ground,0),"legacy north bench maps to front")
	retention(ctx)

## Удерживает прежние коллизии, полный мир, 1200 правил земли и восемь движений у мостов.
static func retention(ctx: SceneTree) -> void:
	# Подготовка: создаём реальную изолированную сцену и снимок всего сохранения.
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	var navigation:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	# Действие: многократно читаем геометрию, контакты и общие meshes без вызова draw вне CanvasItem.
	for i in 24:
		var side:int=[0,1,3][i%3];Bench.destination(Vector2(i*24,600),side);Bench.contacts(Vector2.ZERO,side);Bench.shadow(side)
	# Проверка: графические данные не меняют проходы, предметы, физику и настройки.
	ctx.expect(before==game.SaveSystem.snapshot(game),"bench visual preparation preserves full saved world")
	ctx.expect(navigation==Rules.rules(game),"bench visual preparation preserves 1200 rules and eight bridge motions")
	for prop in Layout.PROP_PLACEMENTS:
		if prop.kind=="bench":ctx.expect(Layout.prop_collision_rect(prop).size==Vector2(72,24),"installed bench preserves previous solid foundation")
	game.free()

extends RefCounted

const Street := preload("res://scripts/presentation/village_street_visual.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Points := preload("res://tools/visual_camera_points.gd")
const Rules := preload("res://tools/ground_seasons_fixture.gd")

## Сравнивает плотность, опору, отдельные PNG и повторное использование тени шести ракурсов.
static func run(ctx: SceneTree) -> void:
	# Подготовка: дробная мировая опора выявляет скрытое округление или разный масштаб осей.
	var ground:=Vector2(720.25,612.5)
	for kind in ["well","cart"]:
		var paths:=[]
		# Действие: разрешаем три самостоятельных изображения и геометрию тени.
		for side in [0,1,3]:
			var view:=Street.view(kind,side);var rect:=Street.destination(kind,ground,side)
			paths.append(view.path)
			# Проверка: кадр масштабируется равномерно и совмещается с измеренным контактом.
			ctx.expect(rect.size.is_equal_approx(view.source.size*0.25),"street uniform source density: "+kind+str(side))
			ctx.expect((rect.position+rect.size*view.pivot).is_equal_approx(ground),"street fractional pivot: "+kind+str(side))
			ctx.expect(Street.contacts(kind,ground,side).size()==(1 if kind=="well" else 2),"stone/wheel contact projections: "+kind+str(side))
			ctx.expect(Street.shadow(kind,side)==Street.shadow(kind,side),"street shadow mesh reused: "+kind+str(side))
			ctx.expect(Street.shadow(kind,side).get_surface_count()==1,"single street shadow mesh: "+kind+str(side))
			ctx.expect(Street.approach(kind,ground,side)!=ground,"single working-side approach: "+kind+str(side))
		ctx.expect(paths[0]!=paths[1] and paths[1]!=paths[2] and paths[0]!=paths[2],"street views have independent textures: "+kind)
		ctx.expect(Street.destination(kind,ground,2)==Street.destination(kind,ground,0),"street legacy north aliases front: "+kind)
	retention(ctx)

## Сохраняет мир, 1200 правил, мосты, прежние твёрдые основания и настоящую продажу моркови.
static func retention(ctx: SceneTree) -> void:
	# Подготовка: изолированная реальная сцена и прогретые правила земли.
	var game:=Points.create_game();game._ready();Points.configure(game,Points.registry().points[0])
	var navigation:=Rules.rules(game);var before:Dictionary=game.SaveSystem.snapshot(game)
	# Действие: повторно читаем новые виды и тени, не вызывая draw вне CanvasItem.
	for kind in ["well","cart"]:
		for i in 24:
			var side:int=[0,1,3][i%3];Street.destination(kind,Vector2(i*24,600),side);Street.contacts(kind,Vector2.ZERO,side);Street.shadow(kind,side)
	# Проверка: графическая подготовка не трогает правила мира или сохранения.
	ctx.expect(before==game.SaveSystem.snapshot(game),"street visual lookup preserves full save")
	ctx.expect(navigation==Rules.rules(game),"street visual lookup preserves 1200 rules and eight bridge moves")
	for prop in Layout.PROP_PLACEMENTS:
		if prop.kind=="well":ctx.expect(Layout.prop_collision_rect(prop).size==Vector2(72,48),"well keeps original 72x48 solid")
		if prop.kind=="bench":ctx.expect(Layout.prop_collision_rect(prop).size==Vector2(72,24),"neighbor bench solid unchanged")
	ctx.expect(game.BuildingSystem.SELL_CRATE_RECT==Rect2(1482,549,60,54),"trade crate keeps actual solid rectangle")
	ctx.expect(not game.NavigationSystem.is_walkable(game,game.BuildingSystem.SELL_CRATE_RECT.get_center()),"trade crate remains solid to navigation")
	# Действие: подходим к прежней точке продажи и продаём один реальный предмет.
	game.player=game.BuildingSystem.SELL_CRATE_POSITION+Vector2(0,58)
	ctx.expect(game.nearest_interaction()=="crate","existing trade point reachable from front")
	game.shop_selected=1;game.carrots=1;game.coins=20
	ctx.expect(game.sell_selected_product(),"existing carrot sale succeeds with new cart visuals")
	ctx.expect(game.carrots==0 and game.coins==28,"sale consumes one carrot and grants canonical eight coins")
	game.free()

extends RefCounted

const Soil := preload("res://scripts/presentation/garden_soil.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")
const Rules := preload("res://tests/suites/axial_road_suite.gd")

## Проверяет границы почвы, сохранность обработки и ограниченность графического кеша.
static func run(context: SceneTree) -> void:
	test_surface_and_cache(context)
	test_geometry_stays_inside_farm(context)
	test_neighbor_contact(context)
	test_cultivation_and_rollback(context)

## Сценарий: материал и геометрия многократно используются в одной сессии.
## Исходное состояние: подготовлены основа и тридцать домашних клеток с двумя тонами влажности.
## Ожидаемый результат: ресурсы не пересоздаются, размер ограничен, вода меняет яркость без капли.
static func test_surface_and_cache(context: SceneTree) -> void:
	Soil.warmup(); var base: ArrayMesh=Soil._base; var plots:=Soil._plots.duplicate()
	for i in 100: Soil.warmup()
	context.expect(Soil._base==base and Soil._plots==plots and plots.size()==30,"garden retains exactly one base and thirty plot meshes after repeated use")
	context.expect(Soil.SOURCE.get_size()==Vector2(512,512) and Soil.SOURCE.get_image().has_mipmaps(),"soil material is bounded to 512px with mipmaps")
	context.expect(Soil.texture()==Soil.texture() and Soil.texture().texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS and Soil.texture().texture_repeat==CanvasItem.TEXTURE_REPEAT_DISABLED,"soil retains an isolated filtered sampler")
	context.expect(Soil.WET.r<Soil.DRY.r*.7 and Soil.WET.g<Soil.DRY.g*.7 and Soil.WET.b<Soil.DRY.b*.7,"wet loam is darker in every channel instead of relying on hue or a drop icon")

## Сценарий: почва встречается с дорогой, травой и краем разрешённого огорода.
## Исходное состояние: все тридцать ячеек и контрольные точки за каждой стороной участка.
## Ожидаемый результат: геометрия и мягкая альфа остаются внутри осевой сетки; борозды идут горизонтально.
static func test_geometry_stays_inside_farm(context: SceneTree) -> void:
	var valid:=true; var total:=0; var soft:=0
	for cell: Vector2i in Soil._plots:
		var rect:=Rect2(Soil.FARM.position+Vector2(cell)*48.0,Vector2(48,48))
		var mesh: ArrayMesh=Soil._plots[cell]; var arrays:=mesh.surface_get_arrays(0)
		if Soil.cell_for(rect)!=cell or mesh.get_surface_count()!=1: valid=false
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point: Vector2=arrays[Mesh.ARRAY_VERTEX][i]; var color: Color=arrays[Mesh.ARRAY_COLOR][i]
			if point.x<rect.position.x or point.y<rect.position.y or point.x>rect.end.x or point.y>rect.end.y or color.a<0 or color.a>1: valid=false
			if color.a>0 and color.a<1: soft+=1
		total+=arrays[Mesh.ARRAY_VERTEX].size()
	context.expect(valid and total==18750 and soft>100,"all worked-cell geometry has smooth bounded alpha inside the exact thirty cells")
	for rect in [Rect2(Soil.FARM.position-Vector2(48,0),Vector2(48,48)),Rect2(Soil.FARM.end,Vector2(48,48)),Rect2(Soil.FARM.position,Vector2(24,48)),Rect2(Soil.FARM.position+Vector2(1,0),Vector2(48,48))]:
		context.expect(Soil.cell_for(rect)==Vector2i(-1,-1),"decorative, misaligned or outside soil cannot allocate a new cell")
	for point in [Soil.FARM.position-Vector2(1,0),Soil.FARM.end+Vector2(1,0),Soil.FARM.position+Vector2(0,50),Soil.FARM.end-Vector2(50,0)]:
		context.expect(Soil.coverage(point,Soil.FARM,false)==0,"garden feather never paints beyond an exact boundary")
	for x in [160.0,192.0,240.0,384.0]:
		context.expect(Soil.furrow(Vector2(x,832),true)<.85 and Soil.furrow(Vector2(x,840),true)>.99,"shallow furrow stays on the same horizontal row")

## Сценарий: одинаково политые соседи образуют цельную землю, а неполитый сосед остаётся различимым.
## Исходное состояние: настоящие словари тридцати грядок с разными комбинациями обработки и воды.
## Ожидаемый результат: внутренний край закрыт без светлой сетки, другая влажность и внешняя граница сохраняют переход.
static func test_neighbor_contact(context: SceneTree) -> void:
	var cell:=Vector2i(2,2); var plot:={"tilled":true,"watered":true}
	var neighbors:={cell+Vector2i.LEFT:{"tilled":true,"watered":true},cell+Vector2i.RIGHT:{"tilled":true,"watered":false},cell+Vector2i.UP:{"tilled":false,"watered":true},cell+Vector2i.DOWN:{"tilled":true,"watered":true}}
	var mask:=Soil.contacts(cell,plot,neighbors); var rect:=Rect2(Soil.FARM.position+Vector2(cell)*48.0,Vector2(48,48))
	context.expect(mask==9,"only equally watered worked neighbors remove the internal edge")
	context.expect(Soil.coverage(rect.position+Vector2(0,24),rect,true,mask)==1 and Soil.coverage(rect.position+Vector2(24,48),rect,true,mask)==1,"matching wet cells meet with full coverage rather than a bright gap")
	context.expect(Soil.coverage(rect.position+Vector2(48,24),rect,true,mask)==0 and Soil.coverage(rect.position+Vector2(24,0),rect,true,mask)==0,"different water state and unworked soil retain a soft boundary")
	context.expect(Soil.coverage(rect.position-Vector2(1,0),rect,true,15)==0,"even a fully connected cell cannot paint outside its own rectangle")
	var dry:={"tilled":true,"watered":false}
	context.expect(Soil.contacts(cell,dry,neighbors)==2,"contact follows current watering rather than retaining an obsolete wet state")

## Сценарий: герой обрабатывает грядку с новым рисунком и откатывает оформление.
## Исходное состояние: штатная сцена, домашняя клетка, семена, вода и снимок всех игровых правил.
## Ожидаемый результат: старый и новый флаг дают тот же полный цикл; дороги, проходы, сохранение и чужие карты неизменны.
static func test_cultivation_and_rollback(context: SceneTree) -> void:
	for enabled in [false,true]:
		var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
		var bg: Node=game.get_node("WorldBackground"); bg._ready(); bg.set_soft_garden(enabled)
		var rules:=Rules._rules(game); var motions:=Rules._motions(game)
		game.player=Soil.FARM.position+Vector2(24,24)-Vector2(42,0); game.facing=Vector2.RIGHT
		var plot: Dictionary=game.plots[Vector2i.ZERO]; var energy: int=game.energy
		game.selected_tool=game.Tool.HOE; game.use_selected_tool()
		context.expect(plot.tilled and game.energy==energy-1,"hoe remains on the home grid with the same stamina cost: "+str(enabled))
		game.selected_tool=game.Tool.SEEDS; game.use_selected_tool(); game.selected_tool=game.Tool.WATER; game.use_selected_tool()
		game.FarmSystem.update(game,game.STAGE_DURATION*2.1)
		context.expect(plot.stage==2 and not plot.watered,"first growth stage requests the same second watering: "+str(enabled))
		game.use_selected_tool(); game.FarmSystem.update(game,game.STAGE_DURATION*2.1); var carrots: int=game.carrots
		game.selected_tool=game.Tool.HAND; game.use_selected_tool()
		context.expect(game.carrots>carrots and not plot.planted and plot.tilled and game.state.world.world_plots.is_empty(),"harvest retains cultivated soil without extra cells: "+str(enabled))
		var saved: Dictionary=game.SaveSystem.snapshot(game); bg.set_soft_garden(not enabled)
		context.expect(saved==game.SaveSystem.snapshot(game) and rules==Rules._rules(game) and motions==Rules._motions(game),"visual rollback preserves complete save, 1200 ground rules and eight bridge motions")
		game.current_location="forest"; context.expect(not Soil.enabled(game),"other maps retain their previous soil path")
		game.free()

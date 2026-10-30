extends RefCounted

const Revision := preload("res://scripts/presentation/terrain_local_revision.gd")
const Points := preload("res://tools/qa/camera/visual_camera_points.gd")

## Проверяет локальную очередь, приоритет полной смены и сохранность существующих игровых правил.
static func run(context: SceneTree) -> void:
	test_local_and_global_revisions(context)
	test_queue_bounds_and_invalid_input(context)
	test_active_requests_and_ownership(context)
	test_gameplay_keeps_local_soil(context)

## Сценарий: меняется одна секция, затем сезон или общий профиль карты.
## Исходное состояние: пустой ограниченный реестр и две далёкие области первой карты.
## Ожидаемый результат: соседняя секция сохраняет ревизию, полная смена явно заменяет локальную очередь.
static func test_local_and_global_revisions(context: SceneTree) -> void:
	var state:=Revision.new(); state.begin_full(); state.complete()
	var neighbor:=state.at(Vector2(1800,1100)); var a:=Rect2(144,816,48,48)
	context.expect(state.request(a) and state.pending==[a] and state.at(a.get_center())>neighbor,"one cell marks only its local section")
	context.expect(state.at(Vector2(1800,1100))==neighbor,"distant ground revision stays unchanged")
	context.expect(state.take()==a and not state.take().has_area(),"only one render region can be active")
	state.complete(); context.expect(state.local_paints==1 and state.full_paints==1 and state.last_completed==a,"completion distinguishes actual local and full passes")
	state.request(Rect2(1200,600,24,24)); state.begin_full()
	context.expect(state.pending.is_empty() and not state.active.has_area() and state.full_pending and state.at(Vector2(1800,1100))==state.revision,"global profile supersedes every queued local region")
	state.request(a); context.expect(state.pending.is_empty(),"in-flight full refresh already covers local input")
	state.complete(); context.expect(state.full_paints==2 and state.local_paints==1,"covered input cannot fabricate an extra local pass")

## Сценарий: приходят испорченные координаты, внешние прямоугольники и слишком много участков.
## Исходное состояние: ограниченная первая карта и очередь не более тридцати двух непересекающихся областей.
## Ожидаемый результат: ошибки не меняют состояние, дробные края округляются наружу, память ограничена.
static func test_queue_bounds_and_invalid_input(context: SceneTree) -> void:
	var state:=Revision.new(); var empty:=state.snapshot()
	for rect in [Rect2(-40,-40,20,20),Rect2(3000,3000,48,48),Rect2(0,0,0,24),Rect2(0,0,-1,24),Rect2(Vector2(NAN,0),Vector2(24,24)),Rect2(Vector2.ZERO,Vector2(INF,24))]:
		context.expect(not state.request(rect) and empty==state.snapshot(),"invalid or external region cannot invalidate retained pixels")
	context.expect(Revision.clipped(Rect2(-.2,1360.2,24,24))==Rect2(0,1360,24,8),"edge clipping is finite and rounds outward")
	for i in Revision.MAX_PENDING: context.expect(state.request(Rect2(i*48,400,24,24)),"bounded disjoint request accepted")
	var before:=state.snapshot(); context.expect(not state.request(Rect2(2000,600,24,24)) and before==state.snapshot(),"overflow is explicit and cannot silently discard queued work")
	state.begin_full(); state.complete(); state.request(Rect2(Vector2.ZERO,Revision.WORLD))
	context.expect(state.sections.size()==60 and state.pending.size()==1,"whole-map bookkeeping has exactly sixty fixed section IDs")
	context.expect(state.at(Vector2(NAN,0))==-1 and state.at(Vector2(2400,1368))==-1,"bad diagnostic coordinates cannot allocate section entries")

## Сценарий: новый запрос приходит во время прохода, а диагностический код меняет полученные данные.
## Исходное состояние: активная область, пересекающаяся цепочка и независимый далёкий участок.
## Ожидаемый результат: последнее изменение не теряется, слияние не захватывает далёкий участок, копии безопасны.
static func test_active_requests_and_ownership(context: SceneTree) -> void:
	var state:=Revision.new(); var a:=Rect2(144,816,48,48); state.request(a); state.take(); state.request(a)
	context.expect(state.pending==[a],"write during an active pass remains queued rather than being lost")
	state.complete(); context.expect(state.take()==a,"latest write receives its own completion")
	state.complete(); state.request(Rect2(0,0,24,24)); state.request(Rect2(48,0,24,24)); state.request(Rect2(1200,600,24,24)); state.request(Rect2(24,0,24,24))
	context.expect(state.pending.size()==2 and state.pending.has(Rect2(0,0,72,24)) and state.pending.has(Rect2(1200,600,24,24)),"touching chain coalesces transitively while distant region stays separate")
	var count:=state.sections.size(); var copy:=state.snapshot(); copy.sections.clear(); copy.pending.clear()
	context.expect(state.sections.size()==count and state.pending.size()==2,"diagnostics do not own the live revision registry")
	for i in 100: state.snapshot()
	context.expect(state.sections.size()==count and state.pending.size()==2,"repeated reads do not grow history or queue")

## Сценарий: герой обрабатывает и поливает прежнюю грядку, визуальный профиль откатывается и карта меняется.
## Исходное состояние: штатная сцена без render target в headless и полный сохранённый снимок игровых правил.
## Ожидаемый результат: локальное API не меняет данные, вспашку, движение, расход сил или чужую карту.
static func test_gameplay_keeps_local_soil(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0]); var bg:Node=game.get_node("WorldBackground"); bg._ready()
	var checks:=preload("res://tests/suites/axial_road_suite.gd"); var rules:=checks._rules(game); var motion:=checks._motions(game)
	var saved:Dictionary=game.SaveSystem.snapshot(game)
	context.expect(bg.invalidate_terrain_rect(Rect2(144,816,48,48)) and saved==game.SaveSystem.snapshot(game),"local visual invalidation does not write into saved gameplay")
	context.expect(not bg.invalidate_terrain_rect(Rect2(5000,5000,48,48)),"background rejects region outside its map")
	bg.local_terrain_updates=false; bg.set_soft_garden(false); bg.set_soft_garden(true)
	context.expect(saved==game.SaveSystem.snapshot(game) and rules==checks._rules(game) and motion==checks._motions(game),"full fallback preserves full save, 1200 ground rules and eight bridge movements")
	game.player=Vector2(game.FARM_ORIGIN)+Vector2(24,24)-Vector2(42,0); game.facing=Vector2.RIGHT
	var energy:int=game.energy; game.selected_tool=game.Tool.HOE; game.use_selected_tool()
	context.expect(game.plots[Vector2i.ZERO].tilled and game.energy==energy-1,"real hoe still updates one original home cell with the same energy cost")
	game.selected_tool=game.Tool.SEEDS; game.use_selected_tool(); game.selected_tool=game.Tool.WATER; game.use_selected_tool()
	context.expect(game.plots[Vector2i.ZERO].watered,"real watering keeps its original model operation")
	bg.set_location("forest"); context.expect(not bg.invalidate_terrain_rect(Rect2(144,816,48,48)),"local first-map API cannot alter another location")
	game.free()

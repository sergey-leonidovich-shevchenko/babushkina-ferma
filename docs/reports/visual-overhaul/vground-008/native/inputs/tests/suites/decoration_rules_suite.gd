extends RefCounted

const Rules := preload("res://scripts/presentation/village_decoration_rules.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const Points := preload("res://tools/visual_camera_points.gd")

## Проверяет весь след декора, ручной приоритет, ограниченность и сохранность игровой геометрии.
static func run(context: SceneTree) -> void:
	test_protected_footprints(context)
	test_plan_is_bounded_and_independent(context)
	test_full_legacy_seed(context)
	test_gameplay_and_manual_data_unchanged(context)

## Сценарий: трава пытается появиться у дверей, служб, грядок, мостов, воды и ручных цветов.
## Исходное состояние: настоящие координаты деревни и прямоугольники с пересечением только краем.
## Ожидаемый результат: весь запрещённый след отклоняется, а свободная земля остаётся доступной.
static func test_protected_footprints(context: SceneTree) -> void:
	for point: Vector2 in [Map.COTTAGE_DOOR,Map.SHOP_DOOR,Map.GUILD_DOOR,Map.CAVE_ENTRANCE,Map.WORKBENCH,Map.WELL,Map.SELL_CRATE,Map.REPAIR,Vector2(Map.FARM_ORIGIN)+Vector2(96,96)]:
		context.expect(Rules.reason(Rect2(point-Vector2(5,1),Vector2(10,8)))!="allowed","protected door, approach or farm rejects procedural seed: "+str(point))
	for bridge: Rect2 in Map.BRIDGES:
		context.expect(Rules.reason(Rect2(bridge.get_center()-Vector2(3,3),Vector2(6,6)))!="allowed","bridge is excluded even though its deck is walkable")
	for point: Vector2 in Map.FLOWERS:
		context.expect(Rules.reason(Rect2(point-Vector2(2,2),Vector2(4,4)))!="allowed","authored flower patch keeps priority over random grass")
	var water_rect:=Rect2(40,220,120,140)
	var corners_dry:=true
	for corner in [water_rect.position,water_rect.end,Vector2(water_rect.end.x,water_rect.position.y),Vector2(water_rect.position.x,water_rect.end.y)]:
		if Geometry2D.is_point_in_polygon(corner,Map.river_polygon()): corners_dry=false
	context.expect(corners_dry and Geometry2D.is_point_in_polygon(water_rect.get_center(),Map.river_polygon()),"water fixture has four dry corners and a wet middle")
	context.expect(Rules.reason(water_rect)=="water","water crossing the middle of a sprite is rejected even if corner-only sampling would miss it")
	var free:=Rect2(1680,1120,10,8)
	context.expect(Rules.reason(free)=="allowed","free dry ground remains available instead of banning all procedural decoration")
	context.expect(Rules.reason(free,[Rect2(1692,1118,8,16)])=="manual","sprite margin protects a neighboring hand-placed element")
	context.expect(Rules.reason(free,[Rect2(1800,1200,24,24)])=="allowed","a distant manual edit does not erase valid decorative ground")
	for rect in [Rect2(-2,300,10,8),Rect2(300,300,0,8),Rect2(300,300,-1,8),Rect2(300,300,257,8),Rect2(Vector2(INF,0),Vector2(10,8))]:
		context.expect(Rules.reason(rect) in ["boundary","invalid"],"invalid or out-of-world footprint fails before geometry")

## Сценарий: вызывающий код меняет результат планировщика или передаёт слишком много данных.
## Исходное состояние: независимые кандидаты, ручная зона и сохранённый встроенный план.
## Ожидаемый результат: исходники и кеш не меняются, превышение лимита и повреждённая запись дают явный отказ.
static func test_plan_is_bounded_and_independent(context: SceneTree) -> void:
	var candidate:={"id":"free","rect":Rect2(1680,1120,10,8)}; var candidates:=[candidate]; var manual:=[Rect2(1800,1200,24,24)]
	var before:=candidates.duplicate(true); var reservations:=manual.duplicate(true)
	var plan:=Rules.plan(candidates,manual); plan.accepted[0].id="changed"
	context.expect(candidates==before and manual==reservations,"planner never mutates authored input or returns its mutable entries")
	var base:=Rules.legacy_plan(); var expected:=base.duplicate(true); base.accepted.clear(); base.rejected.clear()
	context.expect(Rules.legacy_plan()==expected,"caller cannot overwrite the retained legacy plan")
	var oversized:=[]; oversized.resize(Rules.LIMIT+1)
	context.expect(Rules.plan(oversized).error=="limit" and Rules.plan([],oversized).error=="limit","candidate and manual lists both have a hard bound")
	context.expect(Rules.plan([candidate,{}]).error=="invalid_candidate" and Rules.plan([candidate,{}]).accepted.is_empty(),"malformed candidate rejects the plan atomically")
	context.expect(Rules.reason(candidate.rect,[Rect2(0,0,-1,24)])=="invalid_manual","corrupt reservation fails closed")

## Сценарий: старый детерминированный посев проходит фильтр целиком.
## Исходное состояние: все исходные травинки, осевые дороги и два водоёма первой карты.
## Ожидаемый результат: порядок и результат стабильны, каждая сохранённая травинка безопасна, часть посева явно отклонена.
static func test_full_legacy_seed(context: SceneTree) -> void:
	var candidates:=Rules.legacy_candidates(); var plan:=Rules.legacy_plan(); var safe:=true
	context.expect(candidates.size()>200 and candidates.size()<=Rules.LIMIT and plan==Rules.plan(candidates),"one retained plan covers the entire unchanged deterministic seed")
	context.expect(not plan.accepted.is_empty() and not plan.rejected.is_empty() and plan.accepted.size()+plan.rejected.size()==candidates.size(),"filter reports every accepted and rejected candidate")
	for row in plan.accepted:
		if Rules.reason(row.rect)!="allowed": safe=false
	context.expect(safe,"every retained complete footprint is outside all protected areas")
	var zones:=Rules.exclusions(); var count:=zones.size(); zones.clear()
	context.expect(Rules.exclusions().size()==count and count<256,"diagnostic caller cannot clear the bounded exclusion map")

## Сценарий: ограничитель декора используется на настоящей карте с ручными объектами и сохранением.
## Исходное состояние: штатная сцена, полные игровые правила и копии ручных размещений.
## Ожидаемый результат: посев не пишет в мир, RNG, ручные элементы, навигацию, грядки или движение у мостов.
static func test_gameplay_and_manual_data_unchanged(context: SceneTree) -> void:
	var game:=Points.create_game(); game._ready(); Points.configure(game,Points.registry().points[0])
	var checker:=preload("res://tests/suites/axial_road_suite.gd"); var rules:=checker._rules(game); var motion:=checker._motions(game)
	var saved: Dictionary=game.SaveSystem.snapshot(game); var flowers:=Map.FLOWERS.duplicate(); var props:=preload("res://scripts/systems/village_layout_system.gd").PROP_PLACEMENTS.duplicate(true)
	var ambient:=preload("res://scripts/systems/village_ambient_renderer.gd").PLACEMENTS.duplicate(true)
	for i in 100: Rules.legacy_plan()
	context.expect(saved==game.SaveSystem.snapshot(game),"decoration planning preserves full game snapshot including RNG and manual level documents")
	context.expect(Map.FLOWERS==flowers and preload("res://scripts/systems/village_layout_system.gd").PROP_PLACEMENTS==props and preload("res://scripts/systems/village_ambient_renderer.gd").PLACEMENTS==ambient,"authored flowers, props and living accents remain byte-for-byte equivalent data")
	context.expect(rules==checker._rules(game) and motion==checker._motions(game),"1200 ground rules and eight real bridge movements remain unchanged")
	game.free()

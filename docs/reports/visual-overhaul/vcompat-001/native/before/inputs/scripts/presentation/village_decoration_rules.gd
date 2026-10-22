extends RefCounted

const Map := preload("res://scripts/systems/village_map_data.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Regions := preload("res://scripts/systems/village_region_data.gd")
const Buildings := preload("res://scripts/systems/building_system.gd")
const Ambient := preload("res://scripts/systems/village_ambient_renderer.gd")
const LIMIT := 512
const MARGIN := 4.0
static var _zones: Array = []
static var _water: Array = []
static var _legacy: Dictionary = {}

## Читает существующие ручные размещения, не перемещая их и не превращая декор в коллизию.
static func _prepare() -> void:
	if not _zones.is_empty(): return
	for id in Buildings.buildings_at("overworld"):
		_add("door",id,Buildings.door_rect(id).grow(12))
		var door: Vector2=Buildings.BUILDINGS[id].door
		_add("approach",id,Rect2(door-Vector2(36,12),Vector2(72,108)))
		_add("manual",id,Buildings.destination_rect(id))
	_add("door","cave",Rect2(Map.CAVE_ENTRANCE-Vector2(36,24),Vector2(72,108)))
	for point in [Map.WORKBENCH,Map.SHOP_STALL,Map.SELL_CRATE,Map.WELL,Map.REPAIR,Map.GRANDMOTHER]:
		_add("approach",str(point),Rect2(point-Vector2(48,36),Vector2(96,108)))
	for point: Vector2 in preload("res://scripts/systems/apiary_data.gd").SITES: _add("approach","apiary",Rect2(point-Vector2(48,36),Vector2(96,108)))
	for prop in Layout.PROP_PLACEMENTS:
		_add("manual",String(prop.kind),Layout.prop_rect(prop))
	_add("farm","home",Rect2(Vector2(Map.FARM_ORIGIN),Vector2(288,240)))
	for gate in Buildings.farm_gate_rects(): _add("approach","farm-gate",gate.grow(24))
	for fence in Buildings.farm_fence_rects(): _add("manual","farm-fence",fence.grow(4))
	for pen in preload("res://scripts/systems/livestock_data.gd").PENS.values(): _add("approach","animal-pen",Rect2(pen.rect).grow(12))
	_add("approach","animal-walkway",preload("res://scripts/systems/livestock_data.gd").WALKWAY)
	for bridge: Rect2 in Map.BRIDGES: _add("bridge","deck-and-ends",Rect2(bridge.get_center()-Vector2(72,132),Vector2(144,264)))
	for path in Map.routes()+Regions.routes("overworld"):
		for i in range(1,path.size()):
			var a: Vector2=path[i-1]; var b: Vector2=path[i]
			_add("road","axial-path",Rect2(a.min(b),(b-a).abs()).grow(Map.PATH_HALF_WIDTH+8.0))
	for point: Vector2 in Map.FLOWERS: _add("manual","flower",Ambient.destination_rect(point))
	for placement in Ambient.PLACEMENTS: _add("manual",String(placement.kind),Ambient.destination_rect(placement.position).grow(2))
	for point: Vector2 in Map.TREES+Map.BORDER_TREES: _add("manual","tree-base",Rect2(point-Vector2(30,20),Vector2(60,48)))
	for point: Vector2 in Map.FORAGE.values()+Map.RESOURCES.values()+Map.NPCS.values(): _add("manual","resource-or-resident",Rect2(point-Vector2(36,24),Vector2(72,72)))
	for polygon in [Map.river_polygon(),Map.pond_polygon()]: _water.append({"points":polygon,"bounds":_bounds(polygon)})

## Добавляет копию осевой зоны в единственный ограниченный чертеж исключений.
static func _add(reason: String, id: String, rect: Rect2) -> void:
	_zones.append({"reason":reason,"id":id,"rect":rect})

## Вычисляет охватывающий прямоугольник только для быстрого предварительного отсечения точной воды.
static func _bounds(points: PackedVector2Array) -> Rect2:
	var result:=Rect2(points[0],Vector2.ZERO)
	for point in points: result=result.expand(point)
	return result

## Отклоняет испорченный размер до геометрических операций и выделения большого набора кандидатов.
static func valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.has_area() and rect.size.x<=256 and rect.size.y<=256

## Проверяет весь видимый след с небольшим запасом, включая воду между углами и чужие ручные элементы.
static func reason(rect: Rect2, manual: Array = []) -> String:
	if not valid_rect(rect): return "invalid"
	if manual.size()>LIMIT: return "invalid_manual"
	for reservation in manual:
		if not reservation is Rect2 or not reservation.position.is_finite() or not reservation.size.is_finite() or not reservation.has_area(): return "invalid_manual"
	var footprint:=rect.grow(MARGIN)
	if not Rect2(Vector2.ZERO,Map.WORLD_SIZE).encloses(footprint): return "boundary"
	_prepare()
	for zone in _zones:
		if footprint.intersects(zone.rect,true): return zone.reason
	var polygon:=PackedVector2Array([footprint.position,Vector2(footprint.end.x,footprint.position.y),footprint.end,Vector2(footprint.position.x,footprint.end.y)])
	for body in _water:
		if footprint.intersects(body.bounds,true) and not Geometry2D.intersect_polygons(polygon,body.points).is_empty(): return "water"
	for reservation: Rect2 in manual:
		if footprint.intersects(reservation,true): return "manual"
	return "allowed"

## Возвращает независимый ограниченный план: решения не изменяют исходные кандидаты или ручные прямоугольники.
static func plan(candidates: Array, manual: Array = []) -> Dictionary:
	var result:={"accepted":[],"rejected":[],"error":""}
	if candidates.size()>LIMIT or manual.size()>LIMIT: result.error="limit"; return result
	for candidate in candidates:
		if not candidate is Dictionary or not candidate.get("rect") is Rect2:
			result.error="invalid_candidate"; result.accepted.clear(); result.rejected.clear(); return result
		var row: Dictionary=candidate.duplicate(true); row.reason=reason(row.rect,manual)
		if row.reason=="allowed": result.accepted.append(row)
		else: result.rejected.append(row)
	return result

## Сохраняет детерминированный посев старого запасного метода без RNG и без добавления его в основную сцену.
static func legacy_candidates() -> Array:
	var result:=[]
	for y in range(130,1140,84):
		for x in range(48+(y*7)%73,int(Map.WORLD_SIZE.x),108):
			var point:=Vector2(x,y)
			result.append({"position":point,"rect":Rect2(point-Vector2(5,1),Vector2(10,8))})
	return result

## Удерживает один план встроенного посева; погода, кадры и время сессии не увеличивают кеш.
static func legacy_plan() -> Dictionary:
	if _legacy.is_empty(): _legacy=plan(legacy_candidates())
	return _legacy.duplicate(true)

## Рисует прежние травинки только в разрешённых местах; обычная модульная сцена этот запасной посев не вызывает.
static func draw_legacy(canvas: CanvasItem, guarded: bool = true) -> void:
	if _legacy.is_empty(): _legacy=plan(legacy_candidates())
	var candidates: Array=_legacy.accepted if guarded else legacy_candidates()
	for candidate in candidates:
		var point: Vector2=candidate.position
		canvas.draw_line(point+Vector2(-4,5),point,Color("4f7e3d"),2)
		canvas.draw_line(point+Vector2(4,5),point,Color("4f7e3d"),2)

## Показывает независимые диагностические данные без выдачи изменяемого реестра в игровой код.
static func exclusions() -> Array:
	_prepare()
	return _zones.duplicate(true)

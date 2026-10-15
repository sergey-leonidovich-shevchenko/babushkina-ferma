extends RefCounted

const Data := preload("res://scripts/systems/water_layout_data.gd")
const Topology := preload("res://scripts/systems/water_topology.gd")
const CACHE_LIMIT := 2
static var _cache: Dictionary = {}
static var _order: Array[String] = []
static var _empty: RefCounted
static var _errors: Dictionary = {}

## Возвращает общий неизменяемый план активной карты, удерживая не больше двух встроенных карт.
static func geometry(location: String) -> RefCounted:
	if not Data.PROFILE_KINDS.has(location):
		if _empty==null: _empty=Topology.new(); _empty.seal()
		return _empty
	if _cache.has(location):
		_order.erase(location); _order.append(location)
		return _cache[location]
	var result:=_build(location)
	if result==null: _errors[location]="invalid_static_water_data"; return null
	result.seal(); _cache[location]=result; _order.append(location)
	while _order.size()>CACHE_LIMIT: _cache.erase(_order.pop_front())
	return result

## Проверяет поверхность независимо от настила; неизвестная сухая карта не создаёт клетки.
static func has_surface(location: String, point: Vector2) -> bool:
	var plan:=geometry(location)
	return plan!=null and plan.has_surface(point)

## Проверяет физику всех встроенных водоёмов; ошибка известного плана закрывает проход.
static func blocks(location: String, point: Vector2, radius: float) -> bool:
	var plan:=geometry(location)
	return plan==null or plan.blocks_movement(point,radius)

## Возвращает числовые счётчики без ссылок на планы, сцены и GPU-ресурсы.
static func statistics() -> Dictionary:
	var cells:=0; var chunks:=0
	for plan in _cache.values(): cells+=plan.cell_count(); chunks+=plan.chunk_count()
	return {"locations":_order.duplicate(),"cells":cells,"chunks":chunks,"errors":_errors.duplicate(),"limit":CACHE_LIMIT}

## Отпускает только собственные ссылки; активный renderer может продолжать владеть тем же планом.
static func clear_cache() -> void:
	_cache.clear(); _order.clear(); _errors.clear()

## Собирает каждую карту из общих данных и явно задаёт физический смысл декоративной воды.
static func _build(location: String) -> RefCounted:
	var size:=Data.HOME_SIZE if location=="overworld" else (Vector2(2040,1200) if location=="village_river" else Vector2(2400,1200))
	var plan:=Topology.new(Rect2(Vector2.ZERO,size)); var ok:=true
	match location:
		"overworld":
			var river:=plan.add_body("river"); var pond:=plan.add_body("pond","earth",true,0.35)
			ok=plan.add_path(Data.HOME_RIVER,Data.HOME_HALF_WIDTH*2,river)
			for rect in Data.HOME_POND_RECTS: ok=plan.add_rect(rect,pond) and ok
			for rect in Data.HOME_BRIDGES: ok=plan.add_bridge(rect) and ok
		"village_river":
			ok=plan.add_rect(Data.VILLAGE_WATER,plan.add_body("river","stone"),Vector2i.DOWN)
			for rect in Data.VILLAGE_BRIDGES: ok=plan.add_bridge(rect) and ok
		"cave_lake":
			var lake:=plan.add_body("lake","cave",true,0.75)
			for pool in Data.CAVE_POOLS.cave_lake:
				for rect in Data.stepped_pool(pool): ok=plan.add_rect(rect,lake) and ok
		"moon_glade":
			var moon:=plan.add_body("decorative","cave",false,0.35)
			for rect in Data.MOON_RECTS: ok=plan.add_rect(rect,moon) and ok
		"pirate_ship": ok=plan.add_rect(Rect2(0,0,2400,1200),plan.add_body("sea","earth",false),Vector2i.RIGHT)
	return plan if ok else null

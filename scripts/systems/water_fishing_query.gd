extends RefCounted

const Water := preload("res://scripts/systems/water_map_registry.gd")
const RANGE := 194.0

## Ищет ближайшую открытую воду; кэш принадлежит герою и не удерживает сцены или карты.
static func nearest(game: Node) -> Vector2:
	if game.current_location not in ["overworld","village_river"]: return Vector2.INF
	var key: Array=[game.current_location,game.player]
	var cache: Dictionary=game.get_meta("water_fishing_nearest",{})
	if cache.get("key",[])==key: return cache.point
	var plan:=Water.geometry(game.current_location)
	var point: Vector2=plan.nearest_surface(game.player,RANGE,["river","pond"]) if plan!=null else Vector2.INF
	game.set_meta("water_fishing_nearest",{"key":key,"point":point})
	return point

## Выбирает точку по направлению к воде, не перебрасывая поплавок через противоположный берег.
static func target(game: Node) -> Vector2:
	var near:=nearest(game)
	if not near.is_finite(): return Vector2.INF
	var plan:=Water.geometry(game.current_location)
	var direction: Vector2=game.player.direction_to(near)
	if direction.is_zero_approx(): direction=Vector2.LEFT
	var distance: float=clampf(68.0+game.state.fishing.cast_power*126.0,game.player.distance_to(near),RANGE)
	var found:=near
	for step in range(1,ceili(distance-game.player.distance_to(near))+1):
		var point: Vector2=near+direction*step
		if point.distance_to(game.player)>distance or not plan.has_surface(point) or plan.on_bridge(point): break
		found=point
	return found

## Возвращает неподвижный поплавок после заброса, а до заброса вычисляет только предварительную точку.
static func bobber(game: Node) -> Vector2:
	var state=game.state.fishing
	if state.cast_location==game.current_location and state.cast_target.is_finite(): return state.cast_target
	return target(game)

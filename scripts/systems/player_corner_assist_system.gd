extends RefCounted

const MAX_OFFSET := 12.0
const LOOK_AHEAD := 12.0
const PROBE_STEP := 3.0
const SWEEP_STEP := 2.0
const SIDE_SPEED := 0.7
const FAILED_PROBE_META := &"player_corner_failed_probe"
const FAILURE_CACHE_MS := 90
const SOLID_REASONS := ["tree", "forage", "resource", "scenic_prop", "biome_prop", "event_prop", "building", "furniture", "storage", "world_prop", "loot", "fence", "player_fence", "cave_prop", "cave_wall", "published_collision", "debug_obstacle"]


## Помогает только намеренному прямому шагу у твёрдого края; удар, вода и живой противник не выбирают обход.
static func resolve(game: Node, motion: Vector2) -> Vector2:
	if not is_cardinal(motion): return Vector2.ZERO
	var origin: Vector2 = game.player
	var direction := motion.normalized()
	var reason: String = game.NavigationSystem.walkability_reason(game, origin + motion)
	if not SOLID_REASONS.has(reason): return Vector2.ZERO
	var now := Time.get_ticks_msec()
	var failed: Dictionary = game.get_meta(FAILED_PROBE_META, {})
	if failed.get("position") == origin and failed.get("direction") == direction and failed.get("location") == game.current_location and now < int(failed.get("until", 0)):
		return Vector2.ZERO
	var walkable := func(point: Vector2) -> bool: return game.NavigationSystem.is_walkable(game, point)
	var result := assisted_step(origin, motion, walkable)
	if result.is_zero_approx():
		game.set_meta(FAILED_PROBE_META, {"position": origin, "direction": direction, "location": game.current_location, "until": now + FAILURE_CACHE_MS})
	return result


## Ограничивает помощь одной осью: диагональное управление уже содержит выбранное игроком направление обхода.
static func is_cardinal(motion: Vector2) -> bool:
	return not motion.is_zero_approx() and (is_zero_approx(motion.x) or is_zero_approx(motion.y))


## Ищет ближайший свободный край не дальше половины малой клетки и возвращает только безопасный шаг текущего кадра.
static func assisted_step(origin: Vector2, motion: Vector2, walkable: Callable) -> Vector2:
	if not is_cardinal(motion) or not walkable.call(origin): return Vector2.ZERO
	var forward := motion.normalized()
	var tangent := Vector2(-forward.y, forward.x)
	var offset := find_edge(origin, forward, tangent, walkable)
	if is_zero_approx(offset): return Vector2.ZERO
	var side := tangent * signf(offset)
	var diagonal := (forward + side * SIDE_SPEED).normalized() * motion.length()
	if segment_clear(origin, diagonal, walkable): return diagonal
	var lateral := side * minf(absf(offset), motion.length() * SIDE_SPEED)
	return lateral if segment_clear(origin, lateral, walkable) else Vector2.ZERO


## Проверяет оба края симметрично; одинаковые проходы с двух сторон не превращает в произвольный автопилот.
static func find_edge(origin: Vector2, forward: Vector2, tangent: Vector2, walkable: Callable) -> float:
	for index in range(1, int(MAX_OFFSET / PROBE_STEP) + 1):
		var distance := index * PROBE_STEP
		var positive := edge_is_clear(origin, forward, tangent * distance, walkable)
		var negative := edge_is_clear(origin, forward, -tangent * distance, walkable)
		if positive and negative: return 0.0
		if positive: return distance
		if negative: return -distance
	return 0.0


## Требует свободный боковой коридор и проход вперёд, а не единственную точку за тонкой стеной.
static func edge_is_clear(origin: Vector2, forward: Vector2, lateral: Vector2, walkable: Callable) -> bool:
	var endpoint := origin + lateral
	if not walkable.call(endpoint + forward * LOOK_AHEAD): return false
	return segment_clear(origin, lateral, walkable) and segment_clear(endpoint, forward * LOOK_AHEAD, walkable)


## Проверяет весь короткий отрезок с шагом до двух пикселей, не позволяя перескочить препятствие между концами.
static func segment_clear(origin: Vector2, motion: Vector2, walkable: Callable) -> bool:
	var count := maxi(1, ceili(motion.length() / SWEEP_STEP))
	for index in range(1, count + 1):
		if not walkable.call(origin + motion * (float(index) / count)): return false
	return true

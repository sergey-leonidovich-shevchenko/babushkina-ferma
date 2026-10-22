extends RefCounted

const GridBuildSystem := preload("res://scripts/systems/debug_grid_build_system.gd")


## Ставит старые и новые позиции врагов в очередь, оставляя опубликованные маркеры видимыми до готовности замены.
static func begin(game: Node, state: Dictionary) -> void:
	var current: Array[Vector2i] = game.DebugOverlaySystem.dynamic_cells(game, int(state.grid_size))
	var pending: Array[Vector2i] = []
	var seen := {}
	for key in state.get("dynamic_cells", []) + current:
		if seen.has(key) or not state.cache_cells.has(key): continue
		seen[key] = true; pending.append(key)
	state.dynamic_build = {"location": game.current_location, "generation": state.cache_generation, "size": state.grid_size, "farming": state.farming, "pending": pending, "seen": seen, "cursor": 0, "replacements": {}}
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)


## Запрещает применять отложенные результаты к другой локации, размеру сетки или новому полному поколению.
static func is_current(game: Node, state: Dictionary) -> bool:
	var build: Dictionary = state.get("dynamic_build", {})
	return not build.is_empty() and build.location == game.current_location and build.generation == state.cache_generation and build.size == state.grid_size and build.farming == state.farming and not bool(state.cache_invalidated) and state.get("grid_build", {}).is_empty()


## Выполняет только один ограниченный пакет и не заменяет часть видимых маркеров недостроенным набором.
static func advance(game: Node) -> void:
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	if not is_current(game, state):
		state.dynamic_build = {}; game.set_meta(game.DebugOverlaySystem.META_KEY, state)
		return
	var build: Dictionary = state.dynamic_build
	var deadline := Time.get_ticks_usec() + GridBuildSystem.FRAME_BUDGET_USEC
	var processed := 0
	while int(build.cursor) < build.pending.size():
		var key: Vector2i = build.pending[build.cursor]
		build.replacements[key] = game.DebugOverlaySystem.classify_cell(game, key.x, key.y, int(build.size), bool(build.farming))
		build.cursor += 1; processed += 1
		if processed >= GridBuildSystem.MAX_CELLS_PER_FRAME or Time.get_ticks_usec() >= deadline: break
	state.dynamic_build = build
	if int(build.cursor) >= build.pending.size(): _finish_or_extend(game, state, build)
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)


## Догоняет врагов, ушедших в новые клетки за время расчёта, и атомарно публикует полный актуальный набор.
static func _finish_or_extend(game: Node, state: Dictionary, build: Dictionary) -> void:
	var current: Array[Vector2i] = game.DebugOverlaySystem.dynamic_cells(game, int(build.size))
	for key in current:
		if build.seen.has(key) or not state.cache_cells.has(key): continue
		build.seen[key] = true; build.pending.append(key)
	if int(build.cursor) < build.pending.size():
		state.dynamic_build = build
		return
	state.cache_cells.merge(build.replacements, true)
	state.dynamic_cells = current
	state.dynamic_build = {}
	state.refresh_left = game.DebugOverlaySystem.REFRESH_INTERVAL

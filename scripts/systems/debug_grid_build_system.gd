extends RefCounted

const FRAME_BUDGET_USEC := 3000
const MAX_CELLS_PER_FRAME := 128


## Готовит очередь новой области, сохраняя подходящие клетки предыдущего кэша без повторной навигации.
static func begin(game: Node, state: Dictionary, bounds: Rect2, size: int, farming: bool) -> void:
	var reusable: bool = state.cache_location == game.current_location and int(state.get("cache_grid_size", 0)) == size and bool(state.get("cache_farming", false)) == farming and not bool(state.get("cache_invalidated", false))
	var previous: Dictionary = state.get("cache_cells", {}) if reusable else {}
	var pending: Array[Vector2i] = []
	var cells := {}
	for y in range(int(bounds.position.y), int(bounds.end.y), size):
		for x in range(int(bounds.position.x), int(bounds.end.x), size):
			var key := Vector2i(x, y)
			if previous.has(key): cells[key] = previous[key]
			else: pending.append(key)
	state.grid_build = {"location": game.current_location, "bounds": bounds, "size": size, "farming": farming, "cells": cells, "pending": pending, "cursor": 0}
	state.dynamic_build = {}
	state.cache_invalidated = false
	if not reusable:
		state.cache = []; state.cache_cells = {}; state.counts = {}
		state.cache_rect = bounds; state.cache_columns = 0; state.cache_rows = 0
		state.grid_texture = null; state.grid_texture_signature = ""
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)


## Проверяет, соответствует ли незавершённая работа текущей локации, масштабу и режиму сетки.
static func pending_is_current(game: Node, state: Dictionary) -> bool:
	var build: Dictionary = state.get("grid_build", {})
	return not build.is_empty() and build.location == game.current_location and int(build.size) == int(state.grid_size) and bool(build.farming) == bool(state.farming) and not bool(state.cache_invalidated)


## Рассчитывает ограниченный пакет реальных коллизий, оставляя остальное время кадра управлению и отрисовке.
static func advance(game: Node) -> void:
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	if not pending_is_current(game, state): return
	var build: Dictionary = state.grid_build
	var deadline := Time.get_ticks_usec() + FRAME_BUDGET_USEC
	var processed := 0
	while int(build.cursor) < build.pending.size():
		var key: Vector2i = build.pending[build.cursor]
		build.cells[key] = game.DebugOverlaySystem.classify_cell(game, key.x, key.y, int(build.size), bool(build.farming))
		build.cursor += 1; processed += 1
		if processed >= MAX_CELLS_PER_FRAME or Time.get_ticks_usec() >= deadline: break
	state.grid_build = build
	if int(build.cursor) >= build.pending.size(): _publish(game, state, build)
	game.set_meta(game.DebugOverlaySystem.META_KEY, state)


## Публикует только полностью рассчитанное поколение, чтобы неизвестные клетки не выдавались за проходимые.
static func _publish(game: Node, state: Dictionary, build: Dictionary) -> void:
	var cache: Array = []
	var counts := {}
	var bounds: Rect2 = build.bounds
	var size := int(build.size)
	for y in range(int(bounds.position.y), int(bounds.end.y), size):
		for x in range(int(bounds.position.x), int(bounds.end.x), size):
			var cell: Dictionary = build.cells[Vector2i(x, y)]
			cache.append(cell)
			counts[cell.reason] = int(counts.get(cell.reason, 0)) + 1
	state.cache = cache; state.counts = counts; state.cache_cells = build.cells
	state.cache_location = build.location; state.cache_rect = bounds; state.cache_camera = game.camera_offset
	state.cache_columns = int(bounds.size.x) / size; state.cache_rows = int(bounds.size.y) / size
	state.cache_grid_size = size; state.cache_farming = build.farming
	state.dynamic_cells = game.DebugOverlaySystem.dynamic_cells(game, size)
	state.cache_generation = int(state.get("cache_generation", 0)) + 1
	state.grid_texture = null; state.grid_texture_signature = ""; state.grid_build = {}
	state.dynamic_build = {}
	state.refresh_left = game.DebugOverlaySystem.REFRESH_INTERVAL


## Возвращает долю фонового расчёта для видимой подписи, не выполняя дополнительных проверок коллизий.
static func progress(state: Dictionary) -> float:
	var build: Dictionary = state.get("grid_build", {})
	if build.is_empty(): return 1.0
	return float(build.cursor) / maxf(build.pending.size(), 1)

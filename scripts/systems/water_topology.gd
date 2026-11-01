extends RefCounted

const CELL := 24
const CHUNK := 16
const MAX_CELLS := 65536
const MAX_BODIES := 256
const MAX_BRIDGES := 256
const MAX_QUERY_RADIUS := 1024.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONALS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)
]
var cache_builds := 0
var visual_builds := 0
var last_error := ""
var _bounds := Rect2()
var _bounds_valid := true
var _cells: Dictionary[Vector2i, int] = {}
var _flows: Dictionary[Vector2i, Vector2i] = {}
var _bodies: Array[Dictionary] = []
var _bridges: Array[Rect2] = []
var _revision := 0
var _chunks_revision := -1
var _chunks: Dictionary[Vector2i, Array] = {}
var _dirty_chunks: Dictionary[Vector2i, bool] = {}
var _visual_revision := -1
var _visual_regions: Array[Dictionary] = []
var _surface_polygons: Array[PackedVector2Array] = []
var _shore_spans: Array[Dictionary] = []
var _sealed := false


## Назначает необязательные границы плана, не создавая изображений и узлов сцены.
func _init(bounds: Rect2 = Rect2()) -> void:
	_bounds = bounds
	if bounds != Rect2() and not _valid_rect(bounds):
		_bounds_valid = false
		last_error = "invalid_bounds"


## Регистрирует смысл водоёма независимо от цвета, направления и выбранного renderer.
func add_body(
	kind: String, bank: String = "earth", blocking: bool = true, depth: float = 0.6
) -> int:
	if (
		_sealed
		or _bodies.size() >= MAX_BODIES
		or kind not in ["river", "pond", "lake", "sea", "decorative"]
		or bank not in ["earth", "stone", "cave"]
		or not is_finite(depth)
	):
		last_error = "invalid_body"
		return -1
	_bodies.append({"kind": kind, "bank": bank, "blocking": blocking, "depth": clampf(depth, 0, 1)})
	return _bodies.size() - 1


## Возвращает независимое описание водоёма без права случайно изменить исходный план.
func _body(index: int) -> Dictionary:
	return _bodies[index].duplicate(true) if index >= 0 and index < _bodies.size() else {}


## Добавляет прямоугольный участок транзакционно, сохраняя только кардинальное течение.
func add_rect(rect: Rect2, body_id: int, flow: Vector2i = Vector2i.ZERO) -> bool:
	if _sealed or not _valid_rect(rect) or not _valid_flow(flow) or not _valid_body(body_id):
		last_error = "invalid_rect"
		return false
	var pending: Dictionary[Vector2i, Vector2i] = {}
	if not _collect(rect, flow, pending):
		return false
	return _commit(pending, body_id)


## Проверяет всю ось до изменения плана.
## Наклонный или вырожденный отрезок не оставляет половину реки.
func add_path(points: Array, width: int, body_id: int) -> bool:
	if _sealed or points.size() < 2 or width <= 0 or width % CELL != 0 or not _valid_body(body_id):
		last_error = "invalid_path"
		return false
	var half := width * 0.5
	var normalized: Array[Vector2] = []
	for value: Variant in points:
		if value is Vector2:
			normalized.append(value)
		elif value is Vector2i:
			var grid_point: Vector2i = value
			normalized.append(Vector2(grid_point))
		else:
			last_error = "invalid_point"
			return false
		var point: Vector2 = normalized[-1]
		if not point.is_finite() or not _aligned(point - Vector2.ONE * half):
			last_error = "off_grid_path"
			return false
	for index in range(1, normalized.size()):
		var difference: Vector2 = normalized[index] - normalized[index - 1]
		if (
			difference == Vector2.ZERO
			or not (is_zero_approx(difference.x) or is_zero_approx(difference.y))
		):
			last_error = "diagonal_path"
			return false
	var pending: Dictionary[Vector2i, Vector2i] = {}
	for index in range(1, normalized.size()):
		var start: Vector2 = normalized[index - 1]
		var finish: Vector2 = normalized[index]
		var minimum := (
			Vector2(minf(start.x, finish.x), minf(start.y, finish.y)) - Vector2.ONE * half
		)
		var maximum := (
			Vector2(maxf(start.x, finish.x), maxf(start.y, finish.y)) + Vector2.ONE * half
		)
		if not _collect(
			Rect2(minimum, maximum - minimum), Vector2i(start.direction_to(finish)), pending
		):
			return false
	return _commit(pending, body_id)


## Добавляет только согласованный с сеткой настил, не стирая находящуюся под ним воду.
func add_bridge(rect: Rect2) -> bool:
	if (
		_sealed
		or not _valid_rect(rect)
		or not _bounds_valid
		or rect.get_area() / float(CELL * CELL) > MAX_CELLS
		or (_bridges.size() >= MAX_BRIDGES and rect not in _bridges)
	):
		last_error = "invalid_bridge"
		return false
	if rect not in _bridges:
		_bridges.append(rect)
		_revision += 1
		_mark_bridge(rect)
	return true


## Удаляет участок воды одной ревизией, сохраняя прочие водоёмы и исходное значение при ошибке.
func erase_rect(rect: Rect2) -> bool:
	if _sealed or not _valid_rect(rect) or not _bounds_valid:
		last_error = "invalid_erase"
		return false
	var pending: Dictionary[Vector2i, Vector2i] = {}
	if not _collect(rect, Vector2i.ZERO, pending):
		return false
	var changed := false
	for cell: Vector2i in pending:
		if _cells.erase(cell):
			changed = true
			_mark_dirty(cell)
			var key := _chunk_key(cell)
			var chunk: Array = _chunks[key]
			chunk.erase(cell)
			if chunk.is_empty():
				_chunks.erase(key)
		_flows.erase(cell)
	if changed:
		_revision += 1
	last_error = ""
	return true


## Убирает настил без изменения водного плана под ним и инвалидирует производные состояния.
func remove_bridge(rect: Rect2) -> bool:
	if _sealed:
		return false
	var index := _bridges.find(rect)
	if index < 0:
		return false
	_bridges.remove_at(index)
	_revision += 1
	_mark_bridge(rect)
	return true


## Запрещает изменение общих встроенных планов; редактор оставляет собственные планы изменяемыми.
func seal() -> void:
	_sealed = true
	_dirty_chunks.clear()


## Возвращает актуальную ревизию без сравнения содержимого всей карты на каждом кадре.
func _revision_id() -> int:
	return _revision


## Возвращает количество реальных клеток без учёта перекрытий нескольких участков.
func cell_count() -> int:
	return _cells.size()


## Возвращает число пространственных групп без клонирования всех их клеток.
func chunk_count() -> int:
	return _chunks.size()


## Даёт renderer индекс данных одной клетки без полной копии водного плана.
func _cell_body_id(cell: Vector2i) -> int:
	return _cells.get(cell, -1)


## Читает поток клетки напрямую при однократной сборке её вершин.
func _cell_flow(cell: Vector2i) -> Vector2i:
	return _flows.get(cell, Vector2i.ZERO)


## Выдаёт снимок для разовой сборки рендера; изменение снимка не портит навигацию.
func cells() -> Dictionary:
	return _cells.duplicate()


## Проверяет геометрическую поверхность, включая видимую и скрытую под мостом воду.
func has_surface(point: Vector2) -> bool:
	return point.is_finite() and _cells.has(Vector2i((point / CELL).floor()))


## Определяет смысл воды по метаданным клетки, не читая цвет PNG.
func kind_at(point: Vector2) -> String:
	if not has_surface(point):
		return ""
	var metadata: Dictionary = _bodies[_cell_body_id(Vector2i((point / CELL).floor()))]
	var kind: String = metadata.kind
	return kind


## Возвращает явно заданный поток либо покой; направление камеры его не меняет.
func flow_at(point: Vector2) -> Vector2i:
	return (
		_flows.get(Vector2i((point / CELL).floor()), Vector2i.ZERO)
		if point.is_finite()
		else Vector2i.ZERO
	)


## Проверяет настил отдельно от поверхности, учитывая полный круг тела у боковой кромки.
func on_bridge(point: Vector2, radius: float = 0.0) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius < 0:
		return false
	for bridge in _bridges:
		if (
			bridge.has_point(point)
			and (
				radius == 0
				or bridge.encloses(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2))
			)
		):
			return true
	return false


## Блокирует круг на воде с точной проверкой угла и исключением безопасного настила.
func blocks_movement(point: Vector2, radius: float = 0.0) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius < 0 or radius > MAX_QUERY_RADIUS:
		return true
	if on_bridge(point, radius):
		return false
	var low := Vector2i(((point - Vector2.ONE * radius) / CELL).floor())
	var high := Vector2i(((point + Vector2.ONE * radius) / CELL).floor())
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			var metadata: Dictionary = _bodies[_cell_body_id(cell)] if _cells.has(cell) else {}
			var blocking: bool = metadata.get("blocking", false)
			if not _cells.has(cell) or not blocking:
				continue
			var rect := Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL)
			# Настил и клетки кратны CELL: исключается вода под телом, а не сухая часть круга у торца.
			var covered := false
			for bridge in _bridges:
				if Rect2(bridge).encloses(rect):
					covered = true
					break
			if covered:
				continue
			if radius == 0:
				return true
			var closest := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y)
			)
			if point.distance_squared_to(closest) < radius * radius:
				return true
	return false


## Находит доступную воду в ограниченном радиусе без полного обхода всех клеток карты.
func nearest_surface(
	point: Vector2, distance_limit: float, kinds: Array = [], exclude_bridges: bool = true
) -> Vector2:
	if (
		not point.is_finite()
		or not is_finite(distance_limit)
		or distance_limit < 0
		or distance_limit > MAX_QUERY_RADIUS
	):
		return Vector2.INF
	var low := Vector2i(((point - Vector2.ONE * distance_limit) / CELL).floor())
	var high := Vector2i(((point + Vector2.ONE * distance_limit) / CELL).floor())
	var nearest := Vector2.INF
	var squared := distance_limit * distance_limit
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if (
				not _cells.has(cell)
				or (not kinds.is_empty() and _bodies[_cell_body_id(cell)].kind not in kinds)
			):
				continue
			var rect := Rect2(Vector2(cell) * CELL + Vector2.ONE * 2, Vector2.ONE * (CELL - 4))
			var candidate := Vector2(
				clampf(point.x, rect.position.x, rect.end.x),
				clampf(point.y, rect.position.y, rect.end.y)
			)
			if exclude_bridges and on_bridge(candidate):
				continue
			var found := point.distance_squared_to(candidate)
			if found <= squared and (found < squared or not nearest.is_finite()):
				nearest = candidate
				squared = found
	return nearest


## Вычисляет четырёхсвязное соседство; контакт двумя углами не образует русло.
func neighbor_mask(cell: Vector2i) -> int:
	return _mask(cell, DIRECTIONS)


## Сохраняет информацию о вогнутых береговых углах без разрешения диагональной оси.
func diagonal_mask(cell: Vector2i) -> int:
	return _mask(cell, DIAGONALS)


## Разбивает клетки на группы один раз на ревизию и возвращает независимый снимок для renderer.
func _chunks_snapshot() -> Dictionary:
	if _chunks_revision != _revision:
		_chunks_revision = _revision
		cache_builds += 1
	return _chunks.duplicate(true)


## Выдаёт только клетки одной группы, чтобы редактирование не сканировало всю карту.
func chunk_cells(key: Vector2i) -> Array:
	var chunk: Array = _chunks.get(key, [])
	return chunk.duplicate()


## Передаёт изменённые группы и соседние кромки renderer один раз на пакет правок.
func take_dirty_chunks() -> Array:
	var result := _dirty_chunks.keys()
	_dirty_chunks.clear()
	return result


## Возвращает стороны контура с постоянным порядком направлений и нормалями к суше.
func _shore_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in _cells:
		var point := Vector2(cell) * CELL
		var corners := [
			point, point + Vector2(CELL, 0), point + Vector2(CELL, CELL), point + Vector2(0, CELL)
		]
		for side in 4:
			if not _cells.has(cell + DIRECTIONS[side]):
				result.append(
					{
						"cell": cell,
						"side": side,
						"start": corners[side],
						"finish": corners[(side + 1) % 4],
						"normal": DIRECTIONS[side],
						"body": _cells[cell]
					}
				)
	return result


## Возвращает один кешированный снимок покрытия, глубины, поверхности и берега.
## Снимок доступен renderer через WaterMapRegistry и не должен изменяться потребителем.
func _visual_snapshot() -> Dictionary:
	_ensure_visual_cache()
	return {
		"revision": _visual_revision,
		"regions": _visual_regions,
		"polygons": _surface_polygons,
		"shore_spans": _shore_spans,
	}


## Строит производную визуальную маску только при изменении ревизии топологии.
func _ensure_visual_cache() -> void:
	if _visual_revision == _revision:
		return
	_visual_revision = _revision
	visual_builds += 1
	_visual_regions = _build_visual_regions()
	_shore_spans = _build_shore_spans()


## Сжимает клетки одинакового водоёма сначала по строкам, затем по совпадающим вертикальным полосам.
func _build_visual_regions() -> Array[Dictionary]:
	var rows: Dictionary[Vector2i, Array] = {}
	for cell: Vector2i in _cells:
		var key := Vector2i(_cells[cell], cell.y)
		if not rows.has(key):
			rows[key] = []
		var row: Array = rows[key]
		row.append(cell.x)
	var row_spans: Array[Dictionary] = []
	for key: Vector2i in rows:
		var values: Array = rows[key]
		values.sort()
		if values.is_empty():
			continue
		var first: int = values[0]
		var last := first
		for index in range(1, values.size()):
			var value: int = values[index]
			if value == last + 1:
				last = value
				continue
			row_spans.append(
				{"body": key.x, "x0": first, "x1": last + 1, "y0": key.y, "y1": key.y + 1}
			)
			first = value
			last = value
		row_spans.append({"body": key.x, "x0": first, "x1": last + 1, "y0": key.y, "y1": key.y + 1})
	row_spans.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.body != b.body:
				return a.body < b.body
			if a.y0 != b.y0:
				return a.y0 < b.y0
			if a.x0 != b.x0:
				return a.x0 < b.x0
			return a.x1 < b.x1
	)
	var merged: Array[Dictionary] = []
	var active: Dictionary[String, int] = {}
	for span: Dictionary in row_spans:
		var key: String = "%d:%d:%d" % [span.body, span.x0, span.x1]
		var previous: int = active.get(key, -1)
		var previous_y1: int = merged[previous].y1 if previous >= 0 else -1
		var span_y0: int = span.y0
		if previous >= 0 and previous_y1 == span_y0:
			merged[previous].y1 = span.y1
		else:
			active[key] = merged.size()
			merged.append(span.duplicate())
	var by_body: Dictionary[int, Array] = {}
	for span: Dictionary in merged:
		var body_id: int = span.body
		if not by_body.has(body_id):
			by_body[body_id] = []
		var body_rects: Array = by_body[body_id]
		var x0: int = span.x0
		var x1: int = span.x1
		var y0: int = span.y0
		var y1: int = span.y1
		body_rects.append(Rect2(Vector2(x0, y0) * CELL, Vector2(x1 - x0, y1 - y0) * CELL))
	var ids: Array = by_body.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	var all_rects: Array[Rect2] = []
	for body_id: int in ids:
		var metadata: Dictionary = _bodies[body_id]
		var rects: Array[Rect2] = []
		for rect: Rect2 in by_body[body_id]:
			rects.append(rect)
			all_rects.append(rect)
		result.append(
			{
				"body": body_id,
				"kind": metadata.kind,
				"bank": metadata.bank,
				"blocking": metadata.blocking,
				"depth": metadata.depth,
				"rects": rects,
				"polygons": _merge_rects(rects)
			}
		)
	_surface_polygons = _merge_rects(all_rects)
	return result


## Объединяет осевые прямоугольники один раз, сохраняя раздельные несвязанные водоёмы.
func _merge_rects(rects: Array[Rect2]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for rect: Rect2 in rects:
		result.append(
			PackedVector2Array(
				[
					rect.position,
					Vector2(rect.end.x, rect.position.y),
					rect.end,
					Vector2(rect.position.x, rect.end.y)
				]
			)
		)
	var changed := true
	while changed:
		changed = false
		for first in range(result.size()):
			for second in range(first + 1, result.size()):
				var merged := Geometry2D.merge_polygons(result[first], result[second])
				if merged.size() != 1:
					continue
				result[first] = merged[0]
				result.remove_at(second)
				changed = true
				break
			if changed:
				break
	return result


## Сжимает единичные стороны контура без диагонального соединения разных берегов.
func _build_shore_spans() -> Array[Dictionary]:
	var groups: Dictionary[Vector3i, Array] = {}
	for edge: Dictionary in _shore_edges():
		var side: int = edge.side
		var start: Vector2 = edge.start
		var finish: Vector2 = edge.finish
		var fixed := roundi((start.y if side in [0, 2] else start.x) / CELL)
		var varying := (
			roundi(minf(start.x, finish.x) / CELL)
			if side in [0, 2]
			else roundi(minf(start.y, finish.y) / CELL)
		)
		var body: int = edge.body
		var key := Vector3i(body, side, fixed)
		if not groups.has(key):
			groups[key] = []
		var group: Array = groups[key]
		group.append(varying)
	var keys: Array = groups.keys()
	keys.sort_custom(
		func(a: Vector3i, b: Vector3i) -> bool:
			if a.x != b.x:
				return a.x < b.x
			if a.y != b.y:
				return a.y < b.y
			return a.z < b.z
	)
	var result: Array[Dictionary] = []
	for key: Vector3i in keys:
		var values: Array = groups[key]
		values.sort()
		if values.is_empty():
			continue
		var first: int = values[0]
		var last := first
		for index in range(1, values.size() + 1):
			var next: int = values[index] if index < values.size() else last
			var flush := index == values.size() or next != last + 1
			if not flush:
				last = next
				continue
			var start := (
				Vector2(first * CELL, key.z * CELL)
				if key.y in [0, 2]
				else Vector2(key.z * CELL, first * CELL)
			)
			var finish := (
				Vector2((last + 1) * CELL, key.z * CELL)
				if key.y in [0, 2]
				else Vector2(key.z * CELL, (last + 1) * CELL)
			)
			var metadata: Dictionary = _bodies[key.x]
			result.append(
				{
					"body": key.x,
					"side": key.y,
					"start": start,
					"finish": finish,
					"normal": DIRECTIONS[key.y],
					"bank": metadata.bank,
					"depth": metadata.depth
				}
			)
			if index < values.size():
				first = next
				last = first
	return result


## Собирает клетки будущей операции отдельно, прежде чем разрешить её применение.
func _collect(rect: Rect2, direction: Vector2i, pending: Dictionary[Vector2i, Vector2i]) -> bool:
	var clipped := rect.intersection(_bounds) if _bounds.has_area() else rect
	if not clipped.has_area():
		return true
	if clipped.get_area() / float(CELL * CELL) > MAX_CELLS:
		last_error = "cell_limit"
		return false
	for y in range(int(clipped.position.y / CELL), int(clipped.end.y / CELL)):
		for x in range(int(clipped.position.x / CELL), int(clipped.end.x / CELL)):
			var cell := Vector2i(x, y)
			if not pending.has(cell) and pending.size() >= MAX_CELLS:
				last_error = "cell_limit"
				return false
			pending[cell] = direction
	return true


## Проверяет предел памяти и применяет операцию целиком, не оставляя частичного водоёма.
func _commit(pending: Dictionary[Vector2i, Vector2i], body_id: int) -> bool:
	var additions := 0
	for cell: Vector2i in pending:
		if not _cells.has(cell):
			additions += 1
	if _cells.size() + additions > MAX_CELLS:
		last_error = "cell_limit"
		return false
	var changed := false
	for cell: Vector2i in pending:
		if _cells.get(cell, -1) != body_id or _flows.get(cell, Vector2i(99, 99)) != pending[cell]:
			changed = true
			_mark_dirty(cell)
		if not _cells.has(cell):
			var key := _chunk_key(cell)
			if not _chunks.has(key):
				_chunks[key] = []
			var chunk: Array = _chunks[key]
			chunk.append(cell)
		_cells[cell] = body_id
		_flows[cell] = pending[cell]
	if changed:
		_revision += 1
	last_error = ""
	return true


## Помечает только затронутую группу и соседей, которым принадлежит изменённый угол берега.
func _mark_dirty(cell: Vector2i) -> void:
	var minimum := _chunk_key(cell - Vector2i.ONE)
	var maximum := _chunk_key(cell + Vector2i.ONE)
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			_dirty_chunks[Vector2i(x, y)] = true


## Инвалидирует область изменённого настила без пересоздания водной поверхности.
func _mark_bridge(rect: Rect2) -> void:
	var pending: Dictionary[Vector2i, Vector2i] = {}
	_collect(rect, Vector2i.ZERO, pending)
	for cell: Vector2i in pending:
		_mark_dirty(cell)


## Использует математический пол и для отрицательных координат редакторского черновика.
func _chunk_key(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / CHUNK), floori(float(cell.y) / CHUNK))


## Проверяет происхождение индекса водоёма до изменения набора клеток.
func _valid_body(index: int) -> bool:
	return index >= 0 and index < _bodies.size() and _bounds_valid


## Ограничивает поток четырьмя осями либо стоячей водой.
func _valid_flow(value: Vector2i) -> bool:
	return value == Vector2i.ZERO or value in DIRECTIONS


## Требует прямую привязку границ к базовому тайлу и конечные положительные размеры.
func _valid_rect(rect: Rect2) -> bool:
	return (
		rect.position.is_finite()
		and rect.size.is_finite()
		and rect.size.x > 0
		and rect.size.y > 0
		and _aligned(rect.position)
		and _aligned(rect.size)
	)


## Сравнивает координаты с сеткой без округления ошибочных входных данных.
func _aligned(value: Vector2) -> bool:
	var snapped := value.snapped(Vector2.ONE * CELL)
	return absf(value.x - snapped.x) < 0.001 and absf(value.y - snapped.y) < 0.001


## Собирает битовую маску только из уже существующих соседей выбранного плана.
func _mask(cell: Vector2i, offsets: Array) -> int:
	var result := 0
	for index in offsets.size():
		if _cells.has(cell + offsets[index]):
			result |= 1 << index
	return result

extends RefCounted

const CELL := 24
const CHUNK := 16
const MAX_CELLS := 65536
const MAX_BODIES := 256
const MAX_BRIDGES := 256
const MAX_QUERY_RADIUS := 1024.0
const DIRECTIONS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const DIAGONALS := [Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
var _bounds := Rect2()
var _bounds_valid := true
var _cells: Dictionary = {}
var _flows: Dictionary = {}
var _bodies: Array[Dictionary] = []
var _bridges: Array[Rect2] = []
var _revision := 0
var _chunks_revision := -1
var _chunks: Dictionary = {}
var _dirty_chunks: Dictionary = {}
var cache_builds := 0
var last_error := ""
var _sealed := false

## Назначает необязательные границы плана, не создавая изображений и узлов сцены.
func _init(bounds: Rect2 = Rect2()) -> void:
	_bounds=bounds
	if bounds!=Rect2() and not _valid_rect(bounds): _bounds_valid=false; last_error="invalid_bounds"

## Регистрирует смысл водоёма независимо от цвета, направления и выбранного renderer.
func add_body(kind: String, bank: String="earth", blocking: bool=true, depth: float=0.6) -> int:
	if _sealed or _bodies.size()>=MAX_BODIES or kind not in ["river","pond","lake","sea","decorative"] or bank not in ["earth","stone","cave"] or not is_finite(depth): last_error="invalid_body"; return -1
	_bodies.append({"kind":kind,"bank":bank,"blocking":blocking,"depth":clampf(depth,0,1)})
	return _bodies.size()-1

## Возвращает независимое описание водоёма без права случайно изменить исходный план.
func body(index: int) -> Dictionary:
	return _bodies[index].duplicate(true) if index>=0 and index<_bodies.size() else {}

## Добавляет прямоугольный участок транзакционно, сохраняя только кардинальное течение.
func add_rect(rect: Rect2, body_id: int, flow: Vector2i=Vector2i.ZERO) -> bool:
	if _sealed or not _valid_rect(rect) or not _valid_flow(flow) or not _valid_body(body_id): last_error="invalid_rect"; return false
	var pending := {}
	if not _collect(rect,flow,pending): return false
	return _commit(pending,body_id)

## Проверяет всю ось до изменения плана; наклонный или вырожденный отрезок не оставляет половину реки.
func add_path(points: Array, width: int, body_id: int) -> bool:
	if _sealed or points.size()<2 or width<=0 or width%CELL!=0 or not _valid_body(body_id): last_error="invalid_path"; return false
	var half := width*0.5
	for value in points:
		if not (value is Vector2 or value is Vector2i): last_error="invalid_point"; return false
		var point: Vector2=value
		if not point.is_finite() or not _aligned(point-Vector2.ONE*half): last_error="off_grid_path"; return false
	for index in range(1,points.size()):
		var difference: Vector2=Vector2(points[index])-Vector2(points[index-1])
		if difference==Vector2.ZERO or not (is_zero_approx(difference.x) or is_zero_approx(difference.y)): last_error="diagonal_path"; return false
	var pending := {}
	for index in range(1,points.size()):
		var start: Vector2=points[index-1]; var finish: Vector2=points[index]
		var minimum := Vector2(minf(start.x,finish.x),minf(start.y,finish.y))-Vector2.ONE*half
		var maximum := Vector2(maxf(start.x,finish.x),maxf(start.y,finish.y))+Vector2.ONE*half
		if not _collect(Rect2(minimum,maximum-minimum),Vector2i(start.direction_to(finish)),pending): return false
	return _commit(pending,body_id)

## Добавляет только согласованный с сеткой настил, не стирая находящуюся под ним воду.
func add_bridge(rect: Rect2) -> bool:
	if _sealed or not _valid_rect(rect) or not _bounds_valid or rect.get_area()/float(CELL*CELL)>MAX_CELLS or (_bridges.size()>=MAX_BRIDGES and rect not in _bridges): last_error="invalid_bridge"; return false
	if rect not in _bridges:
		_bridges.append(rect); _revision+=1; _mark_bridge(rect)
	return true

## Удаляет участок воды одной ревизией, сохраняя прочие водоёмы и исходное значение при ошибке.
func erase_rect(rect: Rect2) -> bool:
	if _sealed or not _valid_rect(rect) or not _bounds_valid: last_error="invalid_erase"; return false
	var pending := {}
	if not _collect(rect,Vector2i.ZERO,pending): return false
	var changed := false
	for cell in pending:
		if _cells.erase(cell):
			changed=true; _mark_dirty(cell)
			var key := _chunk_key(cell); _chunks[key].erase(cell)
			if _chunks[key].is_empty(): _chunks.erase(key)
		_flows.erase(cell)
	if changed: _revision+=1
	last_error=""
	return true

## Убирает настил без изменения водного плана под ним и инвалидирует производные состояния.
func remove_bridge(rect: Rect2) -> bool:
	if _sealed: return false
	var index := _bridges.find(rect)
	if index<0: return false
	_bridges.remove_at(index); _revision+=1; _mark_bridge(rect)
	return true

## Запрещает изменение общих встроенных планов; редактор оставляет собственные планы изменяемыми.
func seal() -> void:
	_sealed=true; _dirty_chunks.clear()

## Возвращает актуальную ревизию без сравнения содержимого всей карты на каждом кадре.
func revision() -> int:
	return _revision

## Возвращает количество реальных клеток без учёта перекрытий нескольких участков.
func cell_count() -> int:
	return _cells.size()

## Возвращает число пространственных групп без клонирования всех их клеток.
func chunk_count() -> int:
	return _chunks.size()

## Даёт renderer индекс данных одной клетки без полной копии водного плана.
func cell_body_id(cell: Vector2i) -> int:
	return int(_cells.get(cell,-1))

## Читает поток клетки напрямую при однократной сборке её вершин.
func cell_flow(cell: Vector2i) -> Vector2i:
	return _flows.get(cell,Vector2i.ZERO)

## Выдаёт снимок для разовой сборки рендера; изменение снимка не портит навигацию.
func cells() -> Dictionary:
	return _cells.duplicate()

## Проверяет геометрическую поверхность, включая видимую и скрытую под мостом воду.
func has_surface(point: Vector2) -> bool:
	return point.is_finite() and _cells.has(Vector2i((point/CELL).floor()))

## Определяет смысл воды по метаданным клетки, не читая цвет PNG.
func kind_at(point: Vector2) -> String:
	if not has_surface(point): return ""
	return String(_bodies[int(_cells[Vector2i((point/CELL).floor())])].kind)

## Возвращает явно заданный поток либо покой; направление камеры его не меняет.
func flow_at(point: Vector2) -> Vector2i:
	return _flows.get(Vector2i((point/CELL).floor()),Vector2i.ZERO) if point.is_finite() else Vector2i.ZERO

## Проверяет настил отдельно от поверхности, учитывая полный круг тела у боковой кромки.
func on_bridge(point: Vector2, radius: float=0.0) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius<0: return false
	for bridge in _bridges:
		if bridge.has_point(point) and (radius==0 or bridge.encloses(Rect2(point-Vector2.ONE*radius,Vector2.ONE*radius*2))): return true
	return false

## Блокирует круг на воде с точной проверкой угла и исключением безопасного настила.
func blocks_movement(point: Vector2, radius: float=0.0) -> bool:
	if not point.is_finite() or not is_finite(radius) or radius<0 or radius>MAX_QUERY_RADIUS: return true
	if on_bridge(point,radius): return false
	var low := Vector2i(((point-Vector2.ONE*radius)/CELL).floor())
	var high := Vector2i(((point+Vector2.ONE*radius)/CELL).floor())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			if not _cells.has(cell) or not bool(_bodies[int(_cells[cell])].blocking): continue
			var rect := Rect2(Vector2(cell)*CELL,Vector2.ONE*CELL)
			# Настил и клетки кратны CELL: исключается вода под телом, а не сухая часть круга у торца.
			var covered:=false
			for bridge in _bridges:
				if Rect2(bridge).encloses(rect): covered=true; break
			if covered: continue
			if radius==0: return true
			var closest := Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
			if point.distance_squared_to(closest)<radius*radius: return true
	return false

## Находит доступную воду в ограниченном радиусе без полного обхода всех клеток карты.
func nearest_surface(point: Vector2, distance_limit: float, kinds: Array=[], exclude_bridges: bool=true) -> Vector2:
	if not point.is_finite() or not is_finite(distance_limit) or distance_limit<0 or distance_limit>MAX_QUERY_RADIUS: return Vector2.INF
	var low := Vector2i(((point-Vector2.ONE*distance_limit)/CELL).floor())
	var high := Vector2i(((point+Vector2.ONE*distance_limit)/CELL).floor())
	var nearest := Vector2.INF; var squared := distance_limit*distance_limit
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell := Vector2i(x,y)
			if not _cells.has(cell) or (not kinds.is_empty() and _bodies[int(_cells[cell])].kind not in kinds): continue
			var rect := Rect2(Vector2(cell)*CELL+Vector2.ONE*2,Vector2.ONE*(CELL-4))
			var candidate := Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
			if exclude_bridges and on_bridge(candidate): continue
			var found := point.distance_squared_to(candidate)
			if found<=squared and (found<squared or not nearest.is_finite()): nearest=candidate; squared=found
	return nearest

## Вычисляет четырёхсвязное соседство; контакт двумя углами не образует русло.
func neighbor_mask(cell: Vector2i) -> int:
	return _mask(cell,DIRECTIONS)

## Сохраняет информацию о вогнутых береговых углах без разрешения диагональной оси.
func diagonal_mask(cell: Vector2i) -> int:
	return _mask(cell,DIAGONALS)

## Разбивает клетки на группы один раз на ревизию и возвращает независимый снимок для renderer.
func chunks() -> Dictionary:
	if _chunks_revision!=_revision:
		_chunks_revision=_revision; cache_builds+=1
	return _chunks.duplicate(true)

## Выдаёт только клетки одной группы, чтобы редактирование не сканировало всю карту.
func chunk_cells(key: Vector2i) -> Array:
	return _chunks.get(key,[]).duplicate()

## Передаёт изменённые группы и соседние кромки renderer один раз на пакет правок.
func take_dirty_chunks() -> Array:
	var result := _dirty_chunks.keys(); _dirty_chunks.clear()
	return result

## Возвращает стороны контура с постоянным порядком направлений и нормалями к суше.
func shore_edges() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for cell in _cells:
		var point := Vector2(cell)*CELL
		var corners := [point,point+Vector2(CELL,0),point+Vector2(CELL,CELL),point+Vector2(0,CELL)]
		for side in 4:
			if not _cells.has(cell+DIRECTIONS[side]): result.append({"cell":cell,"side":side,"start":corners[side],"finish":corners[(side+1)%4],"normal":DIRECTIONS[side],"body":int(_cells[cell])})
	return result

## Собирает клетки будущей операции отдельно, прежде чем разрешить её применение.
func _collect(rect: Rect2, direction: Vector2i, pending: Dictionary) -> bool:
	var clipped := rect.intersection(_bounds) if _bounds.has_area() else rect
	if not clipped.has_area(): return true
	if clipped.get_area()/float(CELL*CELL)>MAX_CELLS: last_error="cell_limit"; return false
	for y in range(int(clipped.position.y/CELL),int(clipped.end.y/CELL)):
		for x in range(int(clipped.position.x/CELL),int(clipped.end.x/CELL)):
			var cell := Vector2i(x,y)
			if not pending.has(cell) and pending.size()>=MAX_CELLS: last_error="cell_limit"; return false
			pending[cell]=direction
	return true

## Проверяет предел памяти и применяет операцию целиком, не оставляя частичного водоёма.
func _commit(pending: Dictionary, body_id: int) -> bool:
	var additions := 0
	for cell in pending:
		if not _cells.has(cell): additions+=1
	if _cells.size()+additions>MAX_CELLS: last_error="cell_limit"; return false
	var changed := false
	for cell in pending:
		if _cells.get(cell,-1)!=body_id or _flows.get(cell,Vector2i(99,99))!=pending[cell]: changed=true; _mark_dirty(cell)
		if not _cells.has(cell):
			var key := _chunk_key(cell)
			if not _chunks.has(key): _chunks[key]=[]
			_chunks[key].append(cell)
		_cells[cell]=body_id; _flows[cell]=pending[cell]
	if changed: _revision+=1
	last_error=""
	return true

## Помечает только затронутую группу и соседей, которым принадлежит изменённый угол берега.
func _mark_dirty(cell: Vector2i) -> void:
	var minimum := _chunk_key(cell-Vector2i.ONE); var maximum := _chunk_key(cell+Vector2i.ONE)
	for y in range(minimum.y,maximum.y+1):
		for x in range(minimum.x,maximum.x+1): _dirty_chunks[Vector2i(x,y)]=true

## Инвалидирует область изменённого настила без пересоздания водной поверхности.
func _mark_bridge(rect: Rect2) -> void:
	var pending := {}; _collect(rect,Vector2i.ZERO,pending)
	for cell in pending: _mark_dirty(cell)

## Использует математический пол и для отрицательных координат редакторского черновика.
func _chunk_key(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x)/CHUNK),floori(float(cell.y)/CHUNK))

## Проверяет происхождение индекса водоёма до изменения набора клеток.
func _valid_body(index: int) -> bool:
	return index>=0 and index<_bodies.size() and _bounds_valid

## Ограничивает поток четырьмя осями либо стоячей водой.
func _valid_flow(value: Vector2i) -> bool:
	return value==Vector2i.ZERO or value in DIRECTIONS

## Требует прямую привязку границ к базовому тайлу и конечные положительные размеры.
func _valid_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x>0 and rect.size.y>0 and _aligned(rect.position) and _aligned(rect.size)

## Сравнивает координаты с сеткой без округления ошибочных входных данных.
func _aligned(value: Vector2) -> bool:
	var snapped := value.snapped(Vector2.ONE*CELL)
	return absf(value.x-snapped.x)<0.001 and absf(value.y-snapped.y)<0.001

## Собирает битовую маску только из уже существующих соседей выбранного плана.
func _mask(cell: Vector2i, offsets: Array) -> int:
	var result := 0
	for index in offsets.size():
		if _cells.has(cell+offsets[index]): result|=1<<index
	return result

extends RefCounted

const Layout := preload("res://scripts/systems/water_layout_data.gd")
const STEP := 8
const PRECISION := 16.0
const CROSS_ORIGIN := 128.0

static var _field: Dictionary = {}


class Reach:
	var bounds: Rect2
	var origin: Vector2
	var direction: Vector2
	var outgoing := Vector2.ZERO
	var distance: float

	## Переводит мировую точку в расстояние по руслу и поперечное смещение.
	func coordinates(point: Vector2) -> Vector2:
		var offset := point - origin
		if outgoing == Vector2.ZERO:
			return Vector2(distance + offset.dot(direction), direction.cross(offset))
		var radius := float(Layout.HOME_HALF_WIDTH)
		var angle := atan2(maxf(0.0, offset.dot(direction)), maxf(0.0, -offset.dot(outgoing)))
		var sideways := signf(direction.cross(outgoing)) * (radius - offset.length())
		return Vector2(distance + radius * angle, sideways)


## Возвращает один общий атлас координат для владельцев рендера первой карты.
static func field() -> Dictionary:
	if _field.is_empty():
		_field = _pack(_reaches())
	return _field


## Подрезает осевые участки на радиус поворота и заполняет стыки четвертями окружности.
static func _reaches() -> Array[Reach]:
	var points := Layout.HOME_RIVER
	var half := float(Layout.HOME_HALF_WIDTH)
	var distance := 0.0
	var result: Array[Reach] = []
	for index in points.size() - 1:
		var start: Vector2 = points[index]
		var end: Vector2 = points[index + 1]
		var direction := start.direction_to(end)
		var last := index == points.size() - 2
		var straight := Reach.new()
		straight.origin = start + direction * (half if index > 0 else -half)
		var finish := end + direction * (half if last else -half)
		var normal := Vector2(absf(direction.y), absf(direction.x)) * half
		straight.bounds = _rect(straight.origin - normal, finish + normal)
		straight.direction = direction
		straight.distance = distance
		result.append(straight)
		distance += straight.origin.distance_to(finish)
		if last:
			break
		var next: Vector2 = points[index + 2]
		var bend := Reach.new()
		bend.direction = direction
		bend.outgoing = end.direction_to(next)
		bend.origin = finish + bend.outgoing * half
		bend.bounds = _rect(bend.origin, bend.origin + (direction - bend.outgoing) * (2.0 * half))
		bend.distance = distance
		result.append(bend)
		distance += half * PI * 0.5
	return result


## Собирает прямоугольник из противоположных углов независимо от знака направления.
static func _rect(a: Vector2, b: Vector2) -> Rect2:
	var lower := a.min(b)
	return Rect2(lower, a.max(b) - lower)


## Упаковывает две 16-битные координаты, оставляя поле за краем для линейной фильтрации.
static func _pack(reaches: Array[Reach]) -> Dictionary:
	var bounds := reaches[0].bounds
	for reach in reaches:
		bounds = bounds.merge(reach.bounds)
	bounds = bounds.grow(STEP)
	var size := Vector2i(bounds.size / STEP)
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y * 4)
	var nearest := PackedFloat32Array()
	nearest.resize(size.x * size.y)
	nearest.fill(INF)
	for reach in reaches:
		_write_reach(reach, bounds, size, bytes, nearest)
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
	return {
		"texture": ImageTexture.create_from_image(image),
		"bounds": Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y),
	}


## Дорисовывает полосу в один отсчёт снаружи. На стыке приоритет у ближайшего участка.
static func _write_reach(
	reach: Reach, bounds: Rect2, size: Vector2i, bytes: PackedByteArray, nearest: PackedFloat32Array
) -> void:
	var start := Vector2i(((reach.bounds.position - bounds.position) / STEP).floor()) - Vector2i.ONE
	var end := Vector2i(((reach.bounds.end - bounds.position) / STEP).ceil()) + Vector2i.ONE
	for y in range(start.y, end.y):
		for x in range(start.x, end.x):
			var point := bounds.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * STEP
			var clamped := point.clamp(reach.bounds.position, reach.bounds.end)
			var separation := point.distance_squared_to(clamped)
			var index := y * size.x + x
			if separation >= nearest[index]:
				continue
			nearest[index] = separation
			var coords := reach.coordinates(point)
			var along := clampi(roundi((coords.x + STEP) * PRECISION), 0, 65535)
			var across := clampi(roundi((coords.y + CROSS_ORIGIN) * PRECISION), 0, 65535)
			var pixel := index * 4
			bytes[pixel] = along >> 8
			bytes[pixel + 1] = along & 255
			bytes[pixel + 2] = across >> 8
			bytes[pixel + 3] = across & 255

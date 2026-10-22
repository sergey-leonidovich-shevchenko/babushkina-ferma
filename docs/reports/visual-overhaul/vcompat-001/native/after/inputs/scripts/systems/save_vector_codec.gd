extends RefCounted


## Кодирует и восстанавливает координаты ловушек, мебели и снарядов в отделённой копии сохранения.
static func transform(data: Dictionary, restore: bool = false) -> void:
	var fishing: Variant = data.get("fishing", {})
	if fishing is Dictionary: _records(fishing.get("traps", []), ["position"], restore)
	var estate: Variant = data.get("estate", {})
	if not estate is Dictionary: return
	var expansion: Variant = estate.get("expansion", {})
	if not expansion is Dictionary: return
	_records(expansion.get("furniture", []), ["position"], restore)
	_records(expansion.get("projectiles", []), ["from", "to"], restore)


## Меняет только известные координатные поля, оставляя остальные массивы и значения без преобразований.
static func _records(records: Variant, keys: Array, restore: bool) -> void:
	if not records is Array: return
	for record in records:
		if not record is Dictionary: continue
		for key in keys:
			if not record.has(key): continue
			var point: Variant = _point(record[key])
			if point is Array and point.size() == 2:
				record[key] = Vector2(point[0], point[1]) if restore else point


## Читает новый числовой массив и старую строку вектора, которую прежний JSON-сериализатор записывал неявно.
static func _point(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if not value is String: return value
	var expression := RegEx.new()
	expression.compile("^\\(\\s*([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?)\\s*,\\s*([+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?)\\s*\\)$")
	var parsed := expression.search(value)
	return [float(parsed.get_string(1)), float(parsed.get_string(2))] if parsed else value

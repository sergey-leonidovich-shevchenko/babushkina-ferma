extends RefCounted

const MAX_ENTRIES := 512
const MAX_FONTS := 32
const MAX_TEXT_LENGTH := 2048
static var _entries: Dictionary = {}
static var _order: Array = []
static var _next_slot := 0
static var _fonts: Dictionary = {}
static var _hits := 0
static var _misses := 0


## Кеширует только чистый результат прежнего подбора кегля; состояние игры и размеры контейнера не сохраняются отдельно.
static func fitted_size(font: Font, text: String, width: float, height: float, requested: int, scale: float, multiline: bool = false) -> int:
	var key := _key(font, "multiline" if multiline else "line", text, width, height, requested, 6, scale)
	if not key.is_empty() and _entries.has(key):
		_hits += 1
		return _entries[key]
	_misses += 1
	var size := maxi(1, roundi(requested * scale))
	if width > 0.0 and (not multiline or height > 0.0):
		if multiline:
			while size > 6 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y > height: size -= 1
		else:
			while size > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: size -= 1
	_store(key, size)
	return size


## Вписывает одну строку по полной высоте шрифта с fallback; метрики конкретных глифов не заменяют высоту базовой линии.
static func fitted_line_size(font: Font, text: String, width: float, height: float, requested: int, scale: float) -> int:
	var key := _key(font, "bounded_line", text, width, height, requested, 6, scale)
	if not key.is_empty() and _entries.has(key):
		_hits += 1
		return _entries[key]
	_misses += 1
	var size := maxi(1, roundi(requested * scale))
	while size > 6 and ((width > 0.0 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width) or (height > 0.0 and font.get_height(size) > height)):
		size -= 1
	_store(key, size)
	return size


## Повторяет прежние уменьшение и многоточие дословно; наружу выдаёт копию маленького результата, защищая кеш от изменений вызывающего кода.
static func fitted_label(font: Font, label: String, width: float, preferred: int, minimum: int) -> Dictionary:
	var key := _key(font, "label", label, width, 0.0, preferred, minimum, 1.0)
	if not key.is_empty() and _entries.has(key):
		_hits += 1
		return (_entries[key] as Dictionary).duplicate()
	_misses += 1
	var size := preferred; var text := label
	while size > minimum and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: size -= 1
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		var result := {"text":text, "size":size}
		_store(key, result)
		return result.duplicate()
	while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: text = text.left(text.length() - 1)
	var result := {"text":text + "…", "size":size}
	_store(key, result)
	return result.duplicate()


## Формирует точный ключ без округления ширины, высоты или масштаба; слишком длинные диагностические строки не занимают постоянную память.
static func _key(font: Font, mode: String, text: String, width: float, height: float, requested: int, minimum: int, scale: float) -> Array:
	if font == null or text.length() > MAX_TEXT_LENGTH: return []
	var id := font.get_instance_id()
	if not _fonts.has(id): _watch_font(font)
	var record: Dictionary = _fonts[id]
	return [id, record.version, record.rids, mode, text, width, height, requested, minimum, scale]


## Наблюдает за Resource.changed и запоминает действительные TextServer RID; слабая ссылка не удерживает временный шрифт в памяти.
static func _watch_font(font: Font) -> void:
	if _fonts.size() >= MAX_FONTS: clear()
	var id := font.get_instance_id()
	_fonts[id] = {"reference":weakref(font), "rids":font.get_rids(), "version":0}
	font.changed.connect(_font_changed.bind(id))


## Инвалидирует только результаты изменившегося шрифта; замена гарнитуры, spacing или fallback не использует старые метрики.
static func _font_changed(id: int) -> void:
	if not _fonts.has(id): return
	for key in _entries.keys():
		if int(key[0]) == id: _entries.erase(key)
	var font: Font = _fonts[id].reference.get_ref()
	if font == null:
		_fonts.erase(id)
		return
	_fonts[id].version = int(_fonts[id].version) + 1
	_fonts[id].rids = font.get_rids()


## Ограничивает таблицу кольцом FIFO: новые секунды часов или значения F10 не увеличивают кеш бесконечно и не очищают всё одним рывком.
static func _store(key: Array, value: Variant) -> void:
	if key.is_empty(): return
	if _order.size() < MAX_ENTRIES:
		_order.append(key)
	else:
		_entries.erase(_order[_next_slot])
		_order[_next_slot] = key
		_next_slot = (_next_slot + 1) % MAX_ENTRIES
	_entries[key] = value


## Освобождает чистые метрики и подписки; используется при лимите временных гарнитур и в изолированных регрессиях.
static func clear() -> void:
	for id in _fonts:
		var font: Font = _fonts[id].reference.get_ref()
		if font != null and font.changed.is_connected(_font_changed.bind(id)): font.changed.disconnect(_font_changed.bind(id))
	_fonts.clear(); _entries.clear(); _order.clear(); _next_slot = 0; _hits = 0; _misses = 0


## Возвращает копию счётчиков для проверки попаданий и постоянного верхнего предела, не раскрывая изменяемые записи.
static func statistics() -> Dictionary:
	return {"entries":_entries.size(), "slots":_order.size(), "fonts":_fonts.size(), "hits":_hits, "misses":_misses}

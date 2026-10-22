extends RefCounted

var limit: int
var _entries: Dictionary = {}
var _slots: Array = []
var _free: Array[int] = []
var _scan := 0
var _replacement := 0
var _hits := 0
var _misses := 0
var _removed := 0

## Задаёт постоянную вместимость производного кеша без сильного удержания исходных ресурсов.
func _init(capacity: int = 256) -> void:
	limit = maxi(1, capacity)

## Проверяет настоящего владельца, исключая совпадение повторно использованного идентификатора ресурса.
func fetch(owner: RefCounted, key: Variant) -> Variant:
	var entry: Dictionary = _entries.get(key, {})
	if not entry.is_empty() and entry.owner.get_ref() == owner:
		_hits += 1
		return owner if entry.identity else entry.value
	_misses += 1
	return null

## Сохраняет производный результат в свободную ячейку или вытесняет одну старую запись при заполнении.
func store(owner: RefCounted, key: Variant, value: Variant) -> void:
	var slot: int
	if _entries.has(key): slot = _entries[key].slot
	elif not _free.is_empty(): slot = _free.pop_back()
	elif _slots.size() < limit: slot = _slots.size(); _slots.append(null)
	else:
		slot = _replacement; _replacement = (_replacement+1)%limit
		_entries.erase(_slots[slot])
	var identity: bool = value is RefCounted and value == owner
	_slots[slot] = key
	_entries[key] = {"owner":weakref(owner), "identity":identity, "value":null if identity else value, "slot":slot}

## Проверяет ровно одну ячейку и отпускает результат только после исчезновения его исходного владельца.
func prune_one() -> int:
	if _slots.is_empty(): return 0
	var slot := _scan%_slots.size(); _scan = (slot+1)%_slots.size()
	var key: Variant = _slots[slot]
	if key == null: return 0
	if _entries[key].owner.get_ref() != null: return 0
	_entries.erase(key); _slots[slot] = null; _free.append(slot); _removed += 1
	return 1

## Возвращает число живых записей без создания копии всех ключей.
func size() -> int:
	return _entries.size()

## Даёт длину ограниченного кольца для одного постепенного обхода.
func scan_size() -> int:
	return _slots.size()

## Возвращает компактные счётчики без раскрытия ссылок на ресурсы.
func statistics() -> Dictionary:
	return {"entries":size(), "slots":scan_size(), "limit":limit, "hits":_hits, "misses":_misses, "removed":_removed}

## Освобождает только производные данные в изолированном тесте или при явном сбросе источников.
func clear() -> void:
	_entries.clear(); _slots.clear(); _free.clear(); _scan=0; _replacement=0
	_hits=0; _misses=0; _removed=0

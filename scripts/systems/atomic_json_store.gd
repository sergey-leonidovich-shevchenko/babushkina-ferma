extends RefCounted

const MAX_VALUE_DEPTH := 64

## Читает только полный JSON-словарь; ошибки доступа и синтаксиса возвращают пустой документ.
static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	return json.data if error == OK and json.data is Dictionary else {}

## Записывает проверенный документ атомарной заменой; локальная инъекция используется только изолированными тестами.
static func write(path: String, data: Dictionary, validator: Callable = Callable(), keep_backup: bool = false, fault: Callable = Callable()) -> bool:
	if not _stage(path,data,validator,fault,"primary"): return false
	if keep_backup and FileAccess.file_exists(path):
		var previous := read(path)
		if not previous.is_empty() and (not validator.is_valid() or validator.call(previous)):
			var backup := path + ".bak"
			if not _stage(backup,previous,validator,fault,"backup") or not _point(fault,"backup.before_replace",backup) or not _replace(backup):
				_discard(path); _discard(backup); return false
			if not _point(fault,"backup.after_replace",backup): _discard(path); return false
	if not _point(fault,"primary.before_replace",path) or not _replace(path):
		_discard(path); return false
	# После атомарного переименования запись уже подтверждена: отказ наблюдателя не превращает успех в повторяемую ошибку.
	_point(fault,"primary.after_replace",path)
	return true

## Проверяет весь временный документ; каждая граница допускает управляемый отказ без глобального состояния.
static func _stage(path: String, data: Dictionary, validator: Callable, fault: Callable, phase: String) -> bool:
	if not _point(fault,phase+".before_stage",path): return false
	# JSON.stringify превращает GPU/объектные ссылки в строки; такой документ нельзя подтверждать или ротировать.
	if _has_runtime_reference(data): return false
	var temporary := path + ".tmp"
	var text := JSON.stringify(data, "  ")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	if not _point(fault,phase+".after_open",path): file.close(); _discard(path); return false
	file.store_string(text)
	if not _point(fault,phase+".after_write",path): file.close(); _discard(path); return false
	file.flush()
	var error := file.get_error()
	file.close()
	if not _point(fault,phase+".after_flush",path) or error != OK or FileAccess.get_file_as_string(temporary) != text:
		_discard(path); return false
	var checked := read(temporary)
	if checked.is_empty() or (validator.is_valid() and not validator.call(checked)) or not _point(fault,phase+".after_validate",path):
		_discard(path); return false
	return true

## Не допускает ссылки любого уровня или циклический кеш до открытия файла; прежние координатные значения не меняет.
static func _has_runtime_reference(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_VALUE_DEPTH: return true
	if typeof(value) in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]: return true
	if value is Dictionary:
		for key in value:
			if _has_runtime_reference(key,depth+1) or _has_runtime_reference(value[key],depth+1): return true
	elif value is Array:
		for item in value:
			if _has_runtime_reference(item,depth+1): return true
	return false

## Передаёт конкретную границу только явно переданному наблюдателю; обычная запись не хранит тестовых флагов.
static func _point(fault: Callable, checkpoint: String, path: String) -> bool:
	return not fault.is_valid() or bool(fault.call(checkpoint,path))

## Заменяет существующий файл одним переименованием, не создавая окна без основного документа.
static func _replace(path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

## Убирает временный файл после отказа, сохраняя каталог с совпавшим именем.
static func _discard(path: String) -> void:
	var temporary := path + ".tmp"
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))

extends RefCounted


## Читает только полный JSON-словарь; ошибки доступа и синтаксиса возвращают пустой документ.
static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	return json.data if error == OK and json.data is Dictionary else {}


## Записывает проверенный документ заменой соседнего временного файла, сохраняя исправную предыдущую версию.
static func write(path: String, data: Dictionary, validator: Callable = Callable(), keep_backup: bool = false) -> bool:
	if not _stage(path, data, validator): return false
	if keep_backup and FileAccess.file_exists(path):
		var previous := read(path)
		# Повреждённый основной файл никогда не заменяет уже имеющийся исправный резерв.
		if not previous.is_empty() and (not validator.is_valid() or validator.call(previous)):
			var backup := path + ".bak"
			if not _stage(backup, previous, validator) or not _replace(backup):
				_discard(path); _discard(backup)
				return false
	if not _replace(path):
		_discard(path)
		return false
	return true


## Проверяет запись, сброс буфера, прочитанный текст и прикладную схему до замены целевого файла.
static func _stage(path: String, data: Dictionary, validator: Callable) -> bool:
	var temporary := path + ".tmp"
	var text := JSON.stringify(data, "  ")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file: return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_string(temporary) != text:
		_discard(path)
		return false
	var checked := read(temporary)
	if checked.is_empty() or (validator.is_valid() and not validator.call(checked)):
		_discard(path)
		return false
	return true


## Заменяет существующий файл одним переименованием, не создавая окна без основного документа.
static func _replace(path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK


## Убирает временный файл после отказа, не удаляя каталог с совпавшим именем.
static func _discard(path: String) -> void:
	var temporary := path + ".tmp"
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))

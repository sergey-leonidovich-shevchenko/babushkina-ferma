extends RefCounted

const IMAGE_EXTENSIONS := [".png", ".webp"]


## Рекурсивно собирает только пригодные для размещения игровые растры и добавляет правила привязки.
static func scan(root: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_scan_directory(root,result)
	result.sort_custom(func(left: Dictionary,right: Dictionary): return "%s:%s" % [left.category,left.name] < "%s:%s" % [right.category,right.name])
	return result


## Ищет описание выбранного ресурса без повторного обхода файловой системы.
static func find(entries: Array[Dictionary], path: String) -> Dictionary:
	for entry in entries:
		if String(entry.path) == path: return entry
	return metadata(path)


## Возвращает стабильные настройки слоя, якоря и коллизии по назначению ресурса.
static func metadata(path: String) -> Dictionary:
	var lower := path.to_lower()
	var category := category_for_path(path)
	var ground := category == "terrain" or "/editor/water/" in lower
	var bottom := category in ["buildings","vegetation","characters","enemies","decor"]
	return {
		"path":path,
		"name":path.get_file().get_basename().replace("_"," ").replace("-"," "),
		"category":category,
		"anchor":"tile" if ground else ("bottom" if bottom else "center"),
		"layer":"ground" if ground else "objects",
		"collision":category in ["buildings","vegetation"],
		"slice_size":0,
	}


## Определяет пользовательскую группу спрайта по стабильной структуре каталогов проекта.
static func category_for_path(path: String) -> String:
	var lower := path.to_lower()
	if "/tiles/" in lower: return "terrain"
	if "/buildings/" in lower: return "buildings"
	if "/characters/" in lower: return "characters"
	if "/enemies/" in lower or "/wildlife/" in lower: return "enemies"
	if "/items/" in lower or "/resources/" in lower or "/world_loot/" in lower: return "items"
	if "/farming/" in lower: return "farming"
	if "/fishing/" in lower: return "fishing"
	if "/ui/" in lower: return "ui"
	if "/environment/" in lower and ("tree" in lower or "plant" in lower or "mushroom" in lower or "orchard" in lower): return "vegetation"
	if "/environment/" in lower or "/world_polish/" in lower or "/expansion_pack/" in lower: return "decor"
	return "other"


## Обходит одну папку и пропускает мастера, превью и служебные листы, которые нельзя ставить целиком.
static func _scan_directory(path: String, result: Array[Dictionary]) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir() and not entry.begins_with("."):
			if entry.to_lower() != "source": _scan_directory(child,result)
		elif _is_placeable_image(entry):
			result.append(metadata(child))
		entry = directory.get_next()
	directory.list_dir_end()


## Проверяет расширение и исключает контрольные изображения из пользовательского каталога.
static func _is_placeable_image(filename: String) -> bool:
	var lower := filename.to_lower()
	if "preview" in lower or "master" in lower: return false
	return IMAGE_EXTENSIONS.any(func(extension: String): return lower.ends_with(extension))

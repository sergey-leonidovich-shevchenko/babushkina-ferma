extends RefCounted

const PATH := "user://level_editor_preferences.json"


## Загружает только пользовательское избранное конструктора, не смешивая его с документом уровня.
static func load_favorites(preferences_path: String = PATH) -> Array[String]:
	var result: Array[String] = []
	var file:=FileAccess.open(preferences_path,FileAccess.READ)
	if file==null: return result
	var parsed=JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return result
	for favorite_path in parsed.get("favorites",[]):
		var value:=String(favorite_path)
		if ResourceLoader.exists(value) and value not in result: result.append(value)
	result.sort()
	return result


## Сохраняет отсортированный список избранных ресурсов в отдельный JSON настроек редактора.
static func save_favorites(favorites: Array, preferences_path: String = PATH) -> bool:
	var normalized: Array[String] = []
	for favorite_path in favorites:
		var value:=String(favorite_path)
		if ResourceLoader.exists(value) and value not in normalized: normalized.append(value)
	normalized.sort()
	var file:=FileAccess.open(preferences_path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"format":"babushkina-ferma-level-editor-preferences","version":1,"favorites":normalized},"  "))
	file.close()
	return true


## Переключает один ресурс в избранном, сохраняет настройки и возвращает новое состояние отметки.
static func toggle_favorite(favorites: Array, asset_path: String, preferences_path: String = PATH) -> bool:
	if asset_path in favorites: favorites.erase(asset_path)
	else: favorites.append(asset_path)
	save_favorites(favorites,preferences_path)
	return asset_path in favorites

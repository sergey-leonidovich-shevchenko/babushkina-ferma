extends RefCounted

const ValidationSystem := preload("res://scripts/systems/level_editor_validation_system.gd")
const FORMAT_VERSION := 4
const PROJECT_DIRECTORY := "res://level_designs"
const USER_DIRECTORY := "user://level_designs"

## Формирует JSON-совместимый документ со всеми дизайнерскими решениями и комментариями автора.
static func document(state: Dictionary) -> Dictionary:
	ValidationSystem.rebuild_autotile_masks(state)
	var objects := []
	for object in state.objects:
		var source: Rect2 = object.source
		objects.append({
			"id": object.id,
			"asset_path": object.asset_path,
			"name": object.name,
			"notes": object.notes,
			"position": [object.position.x, object.position.y],
			"size": [object.size.x, object.size.y],
			"source": [] if source.size == Vector2.ZERO else [source.position.x, source.position.y, source.size.x, source.size.y],
			"anchor": String(object.get("anchor", "center")),
			"layer": object.layer,
			"collision": object.collision,
			"rotation": object.rotation,
			"flip_x": object.flip_x,
			"flip_y": object.flip_y,
			"scale": clampf(float(object.get("scale", 1.0)), 0.25, 4.0),
			"autotile_mask": int(object.get("autotile_mask", 0)),
			"autotile_family": String(object.get("autotile_family", "")),
			"unique_key": String(object.get("unique_key", "")),
			"catalog_category": String(object.get("catalog_category", "other")),
			"surface_kind": String(object.get("surface_kind", "")),
			"transition_masks": object.get("transition_masks", {}).duplicate(true),
			"reference": object.reference,
			"runtime_id": object.runtime_id,
			"original_position": [object.original_position.x, object.original_position.y],
			"hidden": object.hidden,
		})
	return {
		"format": "babushkina-ferma-level-draft",
		"version": FORMAT_VERSION,
		"level_name": state.level_name,
		"level_notes": state.level_notes,
		"base_location": state.base_location,
		"grid": state.grid,
		"validation": ValidationSystem.validate(state),
		"objects": objects,
	}

## Запускает полный аудит карты и сохраняет подробный отчёт для панели конструктора.
static func validate_draft(state: Dictionary) -> Dictionary:
	ValidationSystem.rebuild_autotile_masks(state)
	var report: Dictionary = ValidationSystem.validate(state)
	state.validation = report
	state.status = ValidationSystem.summary(report)
	return report

## Записывает черновик в пользовательскую папку или экспортирует JSON и запрашивает PNG-превью.
static func save_draft(state: Dictionary, export_to_project: bool) -> bool:
	var report := validate_draft(state)
	if export_to_project and not bool(report.valid):
		state.status = "Экспорт отменён · исправь %d ошибок" % report.errors.size()
		return false
	var directory := PROJECT_DIRECTORY if export_to_project else USER_DIRECTORY
	var absolute := ProjectSettings.globalize_path(directory)
	DirAccess.make_dir_recursive_absolute(absolute)
	var slug := slugify(String(state.level_name))
	var path := directory.path_join(slug + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		state.status = "Ошибка записи: %s" % path
		return false
	file.store_string(JSON.stringify(document(state), "  "))
	file.close()
	state.status = "Экспорт: %s" % path if export_to_project else "Сохранено: %s" % path
	if export_to_project:
		state.export_png = PROJECT_DIRECTORY.path_join(slug + ".png")
		state.capture_pending = 2
		state.panel_hidden = true
	return true

## Возвращает безопасное имя файла из пользовательского названия уровня.
static func slugify(value: String) -> String:
	var result := value.to_lower().strip_edges().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(character, "-")
	return result if not result.is_empty() else "untitled_level"

## Собирает доступные файлы черновиков из пользовательской и проектной папок без дубликатов.
static func draft_files() -> Array[String]:
	var result: Array[String] = []
	for root in [USER_DIRECTORY, PROJECT_DIRECTORY]:
		var directory := DirAccess.open(root)
		if directory == null: continue
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir() and entry.ends_with(".json"):
				result.append(root.path_join(entry))
			entry = directory.get_next()
		directory.list_dir_end()
	result.sort()
	return result

## Загружает следующий сохранённый черновик по кругу для быстрого сравнения вариантов.
static func load_next_draft(game: Node, state: Dictionary) -> bool:
	var files := draft_files()
	if files.is_empty():
		state.status = "Сохранённых черновиков нет"
		return false
	state.draft_cursor = posmod(int(state.draft_cursor) + 1, files.size())
	return load_draft(game, state, files[state.draft_cursor])

## Читает и проверяет документ конструктора, восстанавливая объекты и базовую локацию.
static func load_draft(game: Node, state: Dictionary, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		state.status = "Не удалось открыть %s" % path
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("format", "") != "babushkina-ferma-level-draft":
		state.status = "Неверный формат черновика"
		return false
	_push_history(state)
	state.objects = []
	state.level_name = String(parsed.get("level_name", "untitled_level"))
	state.level_notes = String(parsed.get("level_notes", ""))
	state.base_location = String(parsed.get("base_location", game.current_location))
	state.grid = int(parsed.get("grid", 24))
	state.next_id = 1
	for saved in parsed.get("objects", []):
		state.objects.append(_restore_object(saved, state.next_id))
		state.next_id = maxi(int(state.next_id), int(saved.get("id", 0)) + 1)
	ValidationSystem.rebuild_autotile_masks(state)
	state.validation = ValidationSystem.validate(state)
	state.selected = -1
	state.status = "Загружено: %s · %d объектов" % [path, state.objects.size()]
	if game.WorldSystem.NAMES.has(state.base_location):
		game.current_location = state.base_location
		game.sync_background_location()
	return true

## Восстанавливает один объект черновика из сериализованного JSON-представления.
static func _restore_object(saved: Dictionary, next_id: int) -> Dictionary:
	var source_data: Array = saved.get("source", [])
	var source := Rect2() if source_data.size() != 4 else Rect2(source_data[0], source_data[1], source_data[2], source_data[3])
	var position := Vector2(saved.position[0], saved.position[1])
	var original_data: Array = saved.get("original_position", [position.x, position.y])
	return {
		"id": int(saved.get("id", next_id)),
		"asset_path": String(saved.get("asset_path", "")),
		"name": String(saved.get("name", "Объект")),
		"notes": String(saved.get("notes", "")),
		"position": position,
		"size": Vector2(saved.size[0], saved.size[1]),
		"source": source,
		"anchor": String(saved.get("anchor", "center")),
		"layer": String(saved.get("layer", "objects")),
		"collision": bool(saved.get("collision", false)),
		"rotation": float(saved.get("rotation", 0.0)),
		"flip_x": bool(saved.get("flip_x", false)),
		"flip_y": bool(saved.get("flip_y", false)),
		"autotile_mask": int(saved.get("autotile_mask", 0)),
		"autotile_family": String(saved.get("autotile_family", "")),
		"unique_key": String(saved.get("unique_key", "")),
		"catalog_category": String(saved.get("catalog_category", "other")),
		"surface_kind": String(saved.get("surface_kind", "")),
		"transition_masks": saved.get("transition_masks", {}).duplicate(true),
		"reference": bool(saved.get("reference", false)),
		"runtime_id": String(saved.get("runtime_id", "")),
		"original_position": Vector2(original_data[0], original_data[1]),
		"hidden": bool(saved.get("hidden", false)),
		"scale": float(saved.get("scale", 1.0)),
	}

## Сохраняет текущий снимок перед загрузкой другого черновика и очищает redo-стек.
static func _push_history(state: Dictionary) -> void:
	var history: Array = state.history
	history.append({
		"objects": state.objects.duplicate(true),
		"level_name": state.level_name,
		"level_notes": state.level_notes,
		"next_id": state.next_id,
	})
	if history.size() > 40:
		history.pop_front()
	state.history = history
	state.future = []

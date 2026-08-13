extends RefCounted

const TEST_SAVE_PATH := "user://farm-refactor-test.json"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
static func run(context: SceneTree) -> void:
	test_typed_state_is_the_source_of_truth(context)
	test_inventory_state_is_data_driven(context)
	test_input_actions_are_centralized(context)
	test_content_references_are_valid(context)
	test_composition_root_and_test_runner_stay_small(context)
	test_save_v2_migration_and_backup(context)
	test_presentation_calculations_are_pure(context)
	test_generation_pipeline_is_portable_and_git_clean(context)
	test_world_sprite_manifest_tracks_grid_migration(context)
	test_all_methods_have_russian_documentation(context)


## Сценарий: фасад игры читает и изменяет данные только через типизированные состояния героя, мира и инвентаря.
## Исходное состояние: новый экземпляр игры и значения позиции, здоровья и дня, заданные самим сценарием.
## Ожидаемый результат: изменения фасада сразу видны в состоянии и наоборот, без рассинхронизированных копий.
static func test_typed_state_is_the_source_of_truth(context: SceneTree) -> void:
	var game: Node = context.make_game()
	game.player = Vector2(701, 419)
	game.player_hp = 73
	game.day = 8
	context.expect(game.state.player.position == Vector2(701, 419), "typed PlayerState owns the facade position")
	context.expect(game.state.player.hp == 73, "typed PlayerState owns RPG resources")
	context.expect(game.state.world.day == 8, "typed WorldState owns calendar data")
	game.state.player.hp = 61
	context.expect(game.player_hp == 61, "legacy scene facade reads the typed state without a copied value")
	game.free()


## Сценарий: зарегистрированный ресурс проходит через общее состояние инвентаря без отдельной ветки в игровом фасаде.
## Исходное состояние: новый экземпляр игры со стандартным каталогом и нулевым количеством волокна.
## Ожидаемый результат: известный предмет меняется и экспортируется, а неизвестный идентификатор отклоняется.
static func test_inventory_state_is_data_driven(context: SceneTree) -> void:
	var game: Node = context.make_game()
	context.expect(game.change_inventory_count("fiber", 4), "registered item count changes without a game facade match branch")
	context.expect(game.inventory_item_count("fiber") == 4 and game.state.inventory.count("fiber") == 4, "inventory facade and InventoryState share one count")
	context.expect(not game.change_inventory_count("unknown_item", 1), "unregistered item ids are rejected at the state boundary")
	var exported: Dictionary = game.export_inventory_counts()
	context.expect(exported.size() == game.state.inventory.counts.size() and exported.fiber == 4, "inventory export is generated from one catalog")
	game.free()


## Сценарий: все переназначаемые игровые команды регистрируются через единый каталог системы ввода.
## Исходное состояние: новый экземпляр игры после выполнения стандартной регистрации действий.
## Ожидаемый результат: каждое действие существует в карте ввода, включая движение и использование предмета.
static func test_input_actions_are_centralized(context: SceneTree) -> void:
	var game: Node = context.make_game()
	for action in game.InputSystem.ACTION_BINDINGS:
		context.expect(InputMap.has_action(action), "InputMap registers action: %s" % action)
	context.expect(game.InputSystem.ACTION_BINDINGS.has("move_left") and game.InputSystem.ACTION_BINDINGS.has("use_item"), "movement and tool use share a rebindable action catalog")
	game.free()


## Сценарий: все идентификаторы рецептов, добычи, заданий, магазинов и точек появления разрешаются через реестр контента.
## Исходное состояние: новая игра со всеми встроенными таблицами данных и стандартными объектами мира.
## Ожидаемый результат: реестр не сообщает ошибок, а враги и растения принадлежат профильным системам.
static func test_content_references_are_valid(context: SceneTree) -> void:
	var game: Node = context.make_game()
	var errors: Array[String] = game.ContentRegistry.validate()
	context.expect(errors.is_empty(), "recipes loot quests spawns shops and tutorials reference valid catalog ids: %s" % [errors])
	context.expect(game.enemy_nodes.size() == game.CombatSystem.SPAWNS.size() and game.hazard_nodes.size() == game.EnvironmentHazardSystem.SPAWNS.size() and game.food_nodes == game.ForageSystem.SPAWNS, "feature systems own their default content instead of game.gd")
	game.free()


## Сценарий: композиционный корень, отрисовщики и запуск тестов сохраняют ограниченные ответственности и размеры.
## Исходное состояние: исходные тексты ключевых модулей читаются напрямую без запуска игровой сцены.
## Ожидаемый результат: отрисовка и мышиный ввод делегированы, а количество исполняемых строк не превышает лимиты.
static func test_composition_root_and_test_runner_stay_small(context: SceneTree) -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	var renderer_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	var interface_source := FileAccess.get_file_as_string("res://scripts/systems/interface_renderer.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/systems/input_system.gd")
	var inventory_input_source := FileAccess.get_file_as_string("res://scripts/systems/inventory_input_system.gd")
	var runner_source := FileAccess.get_file_as_string("res://tests/test_game.gd")
	context.expect(not game_source.contains("func draw_") and renderer_source.contains("func draw_world"), "composition root delegates all drawing to the renderer layer")
	context.expect(_code_line_count(game_source) <= 1100 and _code_line_count(renderer_source) <= 700, "composition and renderer stay below enforced size limits")
	context.expect(renderer_source.contains("InterfaceRenderer.draw(self)") and _code_line_count(interface_source) <= 300, "HUD and inventory rendering live in a bounded interface module")
	context.expect(inventory_input_source.contains("func handle_mouse") and not input_source.contains("func handle_inventory_mouse") and not game_source.contains("func handle_inventory_mouse"), "inventory pointer behavior belongs to its dedicated input system")
	context.expect(_code_line_count(runner_source) < 80 and runner_source.contains("CoreSuite.new(self).run()"), "test entry point only orchestrates bounded suites")


## Сценарий: старая схема сохранения мигрирует, а повреждённый основной файл заменяется последней корректной копией.
## Исходное состояние: чистые тестовые пути, новый снимок второй версии и подготовленная копия первой версии.
## Ожидаемый результат: обе версии загружаются, атомарная запись создаёт резерв, а повреждение не теряет прогресс.
static func test_save_v2_migration_and_backup(context: SceneTree) -> void:
	_cleanup_save_files()
	var game: Node = context.make_game()
	var snapshot: Dictionary = game.SaveSystem.snapshot(game)
	context.expect(snapshot.version == 2 and snapshot.state_schema == "aggregate-v2", "new snapshots use typed-state save schema v2")
	var legacy := snapshot.duplicate(true)
	legacy.version = 1
	legacy.erase("state_schema")
	game.coins = 1
	context.expect(game.SaveSystem.apply(game, legacy) and game.coins == snapshot.coins, "v1 snapshot migrates to v2 before applying")
	game.coins = 91
	context.expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "first save is written through a validated temporary file")
	game.coins = 77
	context.expect(game.SaveSystem.save_at(game, TEST_SAVE_PATH), "second atomic save succeeds and keeps the previous backup")
	var corrupt := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	corrupt.store_string("{broken json")
	corrupt.close()
	var restored: Node = context.make_game()
	context.expect(game.SaveSystem.load_at(restored, TEST_SAVE_PATH), "loader falls back to the last valid backup")
	context.expect(restored.coins == 91, "backup restores the previous complete save instead of partial data")
	game.free()
	restored.free()
	_cleanup_save_files()


## Сценарий: расчёты представления возвращают одинаковые кадры и прямоугольники для одинаковых входных данных.
## Исходное состояние: новый экземпляр игры и фиксированные значения времени, числа кадров и расположения карточки.
## Ожидаемый результат: кадры корректно зацикливаются, неверные параметры безопасны, а раскладка имеет одного владельца.
static func test_presentation_calculations_are_pure(context: SceneTree) -> void:
	var game: Node = context.make_game()
	context.expect(game.PresentationSystem.animation_frame(560, 4, 140) == 0, "animation frame calculation wraps deterministically")
	context.expect(game.PresentationSystem.animation_frame(10, 0, 0) == 0, "animation frame calculation handles invalid content data")
	context.expect(game.PresentationSystem.discovery_card_rect() == game.discovery_card_rect(), "discovery layout has one presentation owner")
	game.free()


## Сценарий: генераторы уровня работают после клонирования, а воспроизводимые черновики не раздувают Git.
## Исходное состояние: читаются исходники двух генераторов и правила игнорирования локальных результатов.
## Ожидаемый результат: абсолютных пользовательских путей нет, master разрешён, тысячи нарезанных тайлов игнорируются.
static func test_generation_pipeline_is_portable_and_git_clean(context: SceneTree) -> void:
	var concept_source := FileAccess.get_file_as_string("res://scripts/generate_level_concepts.py")
	var split_source := FileAccess.get_file_as_string("res://scripts/split_fairytale_level_tiles.py")
	var ignore_source := FileAccess.get_file_as_string("res://.gitignore")
	var portable := not concept_source.contains("/Users/") and not split_source.contains("/Users/") and concept_source.contains("Path(__file__).resolve()")
	var clean := ignore_source.contains("/assets/generated/level_drafts/*") and ignore_source.contains("!/assets/generated/level_drafts/first_level_fairytale_master_v1.png")
	context.expect(portable and clean, "level generation is clone-portable and excludes reproducible tile drafts from Git")


## Сценарий: каждое семейство мировых изображений учтено в постоянном аудите миграции на базовую сетку.
## Исходное состояние: машинный манифест содержит фактические и целевые размеры, статус и приоритет всех известных семейств.
## Ожидаемый результат: сетка совпадает с SpatialGridSystem, идентификаторы уникальны, а очередь долга имеет зафиксированный объём.
static func test_world_sprite_manifest_tracks_grid_migration(context: SceneTree) -> void:
	var source := FileAccess.get_file_as_string("res://assets/game/world_sprite_manifest.json")
	var manifest: Dictionary = JSON.parse_string(source)
	var entries: Array = manifest.get("entries", [])
	var ids: Dictionary = {}
	var priorities := {"P1": 0, "P2": 0, "P3": 0}
	var complete_count := 0
	for entry_value in entries:
		var entry: Dictionary = entry_value
		var entry_id := String(entry.get("id", ""))
		ids[entry_id] = true
		var priority := String(entry.get("priority", ""))
		priorities[priority] = int(priorities.get(priority, 0)) + 1
		if entry.get("status") == "compliant":
			complete_count += 1
		context.expect(not entry.get("assets", []).is_empty() and not entry.get("runtime_sizes", []).is_empty() and not entry.get("target_modules", []).is_empty(), "%s records sources actual sizes and target modules" % entry_id)
		context.expect(not String(entry.get("anchor", "")).is_empty() and not String(entry.get("collision", "")).is_empty() and not String(entry.get("done_when", "")).is_empty(), "%s records geometry and completion criteria" % entry_id)
	context.expect(int(manifest.get("base_cell", 0)) == 24, "world sprite audit uses the shared 24 px base cell")
	context.expect(entries.size() == 23 and ids.size() == entries.size(), "world sprite audit keeps all 23 ids unique")
	context.expect(complete_count == 2 and priorities.P1 == 7 and priorities.P2 == 13 and priorities.P3 == 3, "migration queue counts remain explicit and reviewable")


## Сценарий: каждый метод в игровых и тестовых сценариях имеет непосредственно над объявлением русскую документацию.
## Исходное состояние: рекурсивно собран список всех файлов сценариев в каталогах игры и тестов.
## Ожидаемый результат: перед каждым объявлением метода есть документирующий комментарий с кириллицей.
static func test_all_methods_have_russian_documentation(context: SceneTree) -> void:
	var errors: Array[String] = []
	for root in ["res://scripts", "res://tests"]:
		for path in _collect_gd_files(root):
			errors.append_array(_documentation_errors(path))
	context.expect(errors.is_empty(), "every GDScript method has adjacent Russian documentation: %s" % [errors])


## Рекурсивно собирает пути всех файлов сценариев внутри указанного каталога проекта.
static func _collect_gd_files(root: String) -> Array[String]:
	var result: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root.path_join(entry)
		if directory.current_is_dir() and not entry.begins_with("."):
			result.append_array(_collect_gd_files(path))
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
	return result


## Возвращает перечень методов файла, у которых отсутствует соседняя русская документация.
static func _documentation_errors(path: String) -> Array[String]:
	var result: Array[String] = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for index in lines.size():
		var declaration := String(lines[index]).strip_edges()
		if not declaration.begins_with("func ") and not declaration.begins_with("static func "):
			continue
		var previous := index - 1
		while previous >= 0 and String(lines[previous]).strip_edges().is_empty():
			previous -= 1
		var documentation := String(lines[previous]).strip_edges() if previous >= 0 else ""
		if not documentation.begins_with("##") or not _contains_cyrillic(documentation):
			result.append("%s:%d" % [path, index + 1])
	return result


## Проверяет наличие хотя бы одной русской буквы в документирующей строке.
static func _contains_cyrillic(value: String) -> bool:
	for index in value.length():
		var code := value.unicode_at(index)
		if (code >= 0x0410 and code <= 0x044F) or code in [0x0401, 0x0451]:
			return true
	return false


## Считает только исполняемые строки, чтобы документация не влияла на архитектурные лимиты модулей.
static func _code_line_count(source: String) -> int:
	var result := 0
	for line in source.split("\n"):
		var stripped := String(line).strip_edges()
		if not stripped.is_empty() and not stripped.begins_with("#"):
			result += 1
	return result


## Удаляет временные тестовые данные, не затрагивая пользовательское сохранение.
static func _cleanup_save_files() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH + suffix))

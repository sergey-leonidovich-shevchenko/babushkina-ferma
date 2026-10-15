extends "res://tests/suites/suite_base.gd"

const Save := preload("res://scripts/systems/save_system.gd")
const Store := preload("res://scripts/systems/atomic_json_store.gd")
const PATH := "user://test-atomic-save.json"


## Запускает проверки исправного резерва и сохранности документов при отказах файловой системы.
func run() -> void:
	preload("res://tests/suites/atomic_fault_suite.gd").new(context).run()
	test_corrupt_primary_never_replaces_good_backup()
	test_failed_staging_and_backup_promotion_preserve_progress()
	test_failed_primary_promotion_preserves_destination()
	test_draft_overwrite_is_transactional()


## Сценарий: после повреждения основного слота пользователь повторно сохраняет текущую игру.
## Исходное состояние: резерв содержит 91 монету; повреждения включают синтаксис и неверную вложенную структуру.
## Ожидаемый результат: новые данные записаны, резерв остаётся исправным и восстанавливается при следующем повреждении.
func test_corrupt_primary_never_replaces_good_backup() -> void:
	var game := make_game()
	game.coins = 91
	expect(Save.save_at(game, PATH), "first atomic save succeeds")
	game.coins = 77
	expect(Save.save_at(game, PATH), "existing file is replaced and previous progress backed up")
	var backup := FileAccess.get_file_as_string(PATH + ".bak")
	for structural in [false, true]:
		var broken := Save.snapshot(game)
		broken.player = [1]
		_raw(PATH, JSON.stringify(broken) if structural else "{broken")
		game.coins = 55
		expect(Save.save_at(game, PATH), "saving over corrupted primary succeeds")
		expect(FileAccess.get_file_as_string(PATH + ".bak") == backup, "corrupted primary never replaces good backup")
		_raw(PATH, "{broken again")
		expect(Save.load_at(game, PATH) and game.coins == 91, "preserved backup still recovers original progress")
	_cleanup()
	game.free()


## Сценарий: запись временного файла или замена резервной копии недоступны.
## Исходное состояние: существующие основной и резерв содержат известный текст, временный путь занят непустым каталогом.
## Ожидаемый результат: сохранение сообщает отказ, оба исходных файла и каталог остаются неизменными.
func test_failed_staging_and_backup_promotion_preserve_progress() -> void:
	var game := make_game()
	game.coins = 111; Save.save_at(game, PATH)
	game.coins = 222; Save.save_at(game, PATH)
	var primary := FileAccess.get_file_as_string(PATH)
	var backup := FileAccess.get_file_as_string(PATH + ".bak")
	game.coins = 333
	for blocked in [PATH + ".tmp", PATH + ".bak.tmp"]:
		_block(blocked)
		expect(not Save.save_at(game, PATH), "blocked temporary path reports failure: %s" % blocked)
		expect(FileAccess.get_file_as_string(PATH) == primary and FileAccess.get_file_as_string(PATH + ".bak") == backup, "staging failure preserves both existing files")
		expect(FileAccess.file_exists(blocked + "/sentinel"), "failed save never removes blocking directory")
		_unblock(blocked)
	# Замена резерва тоже может отказать после успешной записи обоих временных файлов.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ".bak"))
	_block(PATH + ".bak")
	expect(not Save.save_at(game, PATH), "backup rename failure prevents primary replacement")
	expect(FileAccess.get_file_as_string(PATH) == primary and FileAccess.file_exists(PATH + ".bak/sentinel"), "failed backup promotion preserves primary and destination")
	expect(not FileAccess.file_exists(PATH + ".tmp") and not FileAccess.file_exists(PATH + ".bak.tmp"), "failed promotion cleans staged files")
	_unblock(PATH + ".bak")
	_cleanup()
	game.free()


## Сценарий: целевое имя документа занято непустым каталогом и переименование невозможно.
## Исходное состояние: корректный временный JSON уже можно записать рядом с каталогом.
## Ожидаемый результат: хранилище возвращает отказ, каталог цел и временный файл удалён.
func test_failed_primary_promotion_preserves_destination() -> void:
	_block(PATH)
	expect(not Store.write(PATH, {"value":1}), "primary rename failure reports failure")
	expect(FileAccess.file_exists(PATH + "/sentinel") and not FileAccess.file_exists(PATH + ".tmp"), "rename failure preserves destination and cleans temporary file")
	_unblock(PATH)


## Сценарий: дизайнер сохраняет обновлённый черновик поверх существующего файла.
## Исходное состояние: отдельный черновик уже записан, затем его временный путь блокируется каталогом.
## Ожидаемый результат: отказ сохраняет первый документ, а после устранения препятствия новая версия заменяет его полностью.
func test_draft_overwrite_is_transactional() -> void:
	var game := make_game()
	var state: Dictionary = game.LevelEditorSystem.default_state(game)
	state.level_name = "atomic draft suite"
	var path := "user://level_designs/atomic_draft_suite.json"
	expect(game.LevelEditorSystem.save_draft(game, state, false), "initial isolated draft saves")
	var original := FileAccess.get_file_as_string(path)
	_block(path + ".tmp")
	state.grid = 12
	expect(not game.LevelEditorSystem.save_draft(game, state, false) and FileAccess.get_file_as_string(path) == original, "failed draft overwrite preserves original document")
	_unblock(path + ".tmp")
	expect(game.LevelEditorSystem.save_draft(game, state, false) and int(Store.read(path).grid) == 12, "draft replacement succeeds after removing obstacle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.free()


## Создаёт непустой каталог, имитирующий отказ записи или переименования без изменения прав пользователя.
func _block(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	_raw(path + "/sentinel", "preserve")


## Удаляет только изолированный каталог-препятствие текущего теста.
func _unblock(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/sentinel"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Записывает точный текст в тестовый путь для подготовки повреждений.
func _raw(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()


## Удаляет только файлы отдельного тестового слота.
func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(PATH + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

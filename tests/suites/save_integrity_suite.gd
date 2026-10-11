extends "res://tests/suites/suite_base.gd"

const Save := preload("res://scripts/systems/save_system.gd")
const PATH := "user://test-save-integrity.json"


## Запускает проверки целостности загрузки и совместимости координат постоянных объектов.
func run() -> void:
	test_rejects_malformed_state_without_mutation()
	test_structural_corruption_falls_back_to_backup()
	test_legacy_and_json_vector_round_trip()
	test_legacy_defaults_remain_playable_after_loading()


## Сценарий: синтаксически корректное сохранение содержит неправильный тип или неполную запись.
## Исходное состояние: отдельная игра содержит прогресс, а повреждения охватывают корень и вложенные группы.
## Ожидаемый результат: загрузчик возвращает отказ и оставляет полную копию живого состояния прежней.
func test_rejects_malformed_state_without_mutation() -> void:
	var game := make_game()
	game.coins = 913
	var baseline := Save.snapshot(game)
	var corruptions := [
		[["version"], null], [["version"], 1.5], [["player"], [1]], [["player"], [INF, 0]],
		[["coins"], {}], [["counts", "wood"], "many"], [["hotbar"], []], [["slots"], [null]],
		[["profile"], []], [["profile", "relationships"], {"miron":[]}], [["profile", "quest_memory"], {"miron":null}],
		[["progression", "levels"], null], [["effects", "speed"], NAN], [["fishing", "traps"], [{"location":"overworld"}]],
		[["companions", "active"], [false]], [["estate", "expansion", "animals"], {"hen":null}],
		[["estate", "qualities"], {"carrot":7}], [["moon_glade", "echoes"], null], [["castle_campaign", "clues"], ["yes"]],
		[["plots"], [{}]], [["world_plots"], [null]], [["trees"], [{"health":1}]], [["forage"], [{"active":false}]],
		[["enemies"], [{"hp":2,"alive":true,"position":[1]}]], [["hazards"], [null]],
		[["wildlife"], [{"hp":2,"alive":true,"position":"bad"}]], [["containers"], [{}]], [["drops"], [{"kind":"wood","count":1}]],
	]
	for corruption in corruptions:
		var data := baseline.duplicate(true)
		var cursor: Dictionary = data
		var keys: Array = corruption[0]
		for index in keys.size() - 1: cursor = cursor[keys[index]]
		cursor[keys[-1]] = corruption[1]
		expect(not Save.apply(game, data), "malformed save rejected: %s" % str(keys))
		expect(Save.snapshot(game) == baseline, "failed load preserves entire state: %s" % str(keys))
	var missing := baseline.duplicate(true)
	missing.erase("player")
	expect(not Save.apply(game, missing) and Save.snapshot(game) == baseline, "missing mandatory field never mutates state")
	game.free()


## Сценарий: основной JSON имеет верную версию, но повреждённую вложенную запись.
## Исходное состояние: резервная копия содержит известные монеты; оба неверных файла проверяются отдельно.
## Ожидаемый результат: исправный резерв восстанавливается, а отказ обоих файлов ничего не меняет.
func test_structural_corruption_falls_back_to_backup() -> void:
	var game := make_game()
	game.coins = 314
	var valid := Save.snapshot(game)
	var broken := valid.duplicate(true)
	broken.coins = 999
	broken.enemies = [{"hp":1,"alive":true,"position":[1]}]
	_write(PATH, broken)
	_write(PATH + ".bak", valid)
	game.coins = 10
	expect(Save.load_at(game, PATH) and game.coins == 314, "structurally invalid primary falls back to good backup")
	_write(PATH + ".bak", broken)
	var before := Save.snapshot(game)
	expect(not Save.load_at(game, PATH), "both structurally invalid files report failure")
	expect(Save.snapshot(game) == before, "both invalid files leave live world untouched")
	_cleanup()
	game.free()


## Сценарий: мебель, крабовая ловушка и снаряд проходят настоящую JSON-сериализацию и старую миграцию.
## Исходное состояние: координаты объектов представлены игровыми векторами; старая версия записывала их строками.
## Ожидаемый результат: новый файл содержит числовые пары, обе формы восстанавливают векторы, отсутствие новых групп допустимо.
func test_legacy_and_json_vector_round_trip() -> void:
	var game := make_game()
	game.state.fishing.traps = [{"location":"overworld","position":Vector2(864, 512),"ready_day":3}]
	var expansion: Dictionary = game.FarmLifeSystem.state(game)
	expansion.furniture = [{"kind":"rustic_table","position":Vector2(256, 320)}]
	expansion.projectiles = [{"from":Vector2(30, 40),"to":Vector2(50, 60),"progress":0.2,"kind":"bow"}]
	var data: Dictionary = JSON.parse_string(JSON.stringify(Save.snapshot(game)))
	expect(data.fishing.traps[0].position == [864.0, 512.0], "trap uses explicit JSON numeric coordinates")
	expect(Save.apply(game, data), "complete JSON round trip loads")
	expect(game.state.fishing.traps[0].position == Vector2(864, 512), "trap position returns to runtime vector")
	expect(game.state.world.estate.expansion.furniture[0].position == Vector2(256, 320), "furniture position survives JSON")
	expect(game.state.world.estate.expansion.projectiles[0].to == Vector2(50, 60), "projectile destination survives JSON")
	data.fishing.traps[0].position = "(864, 512)"
	data.estate.expansion.furniture[0].position = "(256, 320)"
	data.estate.expansion.projectiles[0].from = "(3e1, 40)"
	expect(Save.apply(game, data), "legacy vector strings load without losing objects")
	data.fishing.traps[0].position = "(864, broken)"
	expect(not Save.apply(game, data), "malformed legacy vector fails before state mutation")
	data = Save.snapshot(game)
	data.version = 1
	data.erase("state_schema")
	for key in Save.ValidationSystem.OPTIONAL: data.erase(key)
	expect(Save.apply(game, data), "version one without later feature groups remains compatible")
	game.free()


## Сценарий: старый слот не содержит все ячейки экипировки и память домашних животных.
## Исходное состояние: усадьба уже открыла хлев, но сохранение содержит пустые словари новых подсистем.
## Ожидаемый результат: загрузка восстанавливает ячейки, сохраняет имеющийся предмет, движение и кормление работают.
func test_legacy_defaults_remain_playable_after_loading() -> void:
	var game := make_game()
	var data := Save.snapshot(game)
	data.equipment = {"head":"iron_helmet"}
	data.estate.level = 3
	data.estate.expansion.erase("animals")
	expect(Save.apply(game, data), "legacy partial equipment and absent animal memory load safely")
	expect(game.equipment.head == "iron_helmet" and game.equipment.has_all(["body", "legs", "hands", "ring", "offhand"]), "missing equipment slots default without losing equipped item")
	expect(game.InventorySystem.speed_multiplier(game) >= 1.0 and game.InventorySystem.damage_bonus(game) >= 0, "loaded legacy equipment supports movement and combat")
	game.change_inventory_count("wheat", 1)
	expect(game.FarmLifeSystem.interact(game, "life:trough"), "legacy farm can feed animals after loading")
	var animals: Dictionary = game.FarmLifeSystem.state(game).animals
	expect(animals.size() == 6 and animals.values().all(func(animal): return int(animal.fed_day) == game.day), "all six missing animal records initialize and receive feed")
	var before := animals.duplicate(true)
	data = Save.snapshot(game)
	expect(Save.apply(game, data) and game.FarmLifeSystem.state(game).animals == before, "existing animal progress survives another load")
	game.free()


## Записывает изолированный документ теста, не обращаясь к сохранению пользователя.
func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Удаляет только файлы текущего тестового слота после выполнения сценария.
func _cleanup() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

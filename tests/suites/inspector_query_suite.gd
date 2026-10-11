extends "res://tests/suites/suite_base.gd"

const Inspector := preload("res://scripts/systems/debug_object_inspector_system.gd")


class DropFixture extends Node:
	var dropped_items: Array[Dictionary] = []
	var current_location := "overworld"
	var name_queries := 0

	## Считает обращения к подробному каталогу предметов без зависимости от полной игры.
	func inventory_item_name(kind: String) -> String:
		name_queries += 1
		return "Предмет %s" % kind


## Запускает проверки точечного запроса инспектора и экономного чтения подробностей.
func run() -> void:
	test_point_query_matches_full_catalog()
	test_distant_drops_do_not_request_details()


## Сценарий: курсор проходит через объекты и границы их спрайтов в деревне, биомах и интерьерах.
## Исходное состояние: полный каталог содержит текущие состояния объектов, включая музей и статические ограды.
## Ожидаемый результат: точечный запрос возвращает ровно те же записи и подробности, что фильтрация полного каталога.
func test_point_query_matches_full_catalog() -> void:
	var game := make_game(); game.state.world.estate.level = 3
	for location in ["overworld", "cottage_interior", "guild_interior", "cave", "cursed", "forest", "rocky", "ruins"]:
		game.current_location = location
		var catalog: Array[Dictionary] = Inspector.candidates(game)
		var probes: Array[Vector2] = [Vector2(-500, -500), game.player, Vector2(780, 270)]
		for record in catalog:
			var bounds: Rect2 = record.bounds
			probes.append(bounds.get_center())
			probes.append(bounds.position)
			probes.append(bounds.end)
		var matches := true
		for probe in probes:
			var expected: Array[Dictionary] = []
			for record in catalog:
				if (record.bounds as Rect2).has_point(probe): expected.append(record)
			if Inspector.candidates(game, probe) != expected:
				matches = false
				break
		expect(matches and not catalog.is_empty(), "point inspector preserves bounds, ordering and live details in %s" % location)
	game.free()


## Сценарий: среди пятисот предметов только один находится под курсором.
## Исходное состояние: каталог фиксирует чтение имён; пятьсот местных предметов разнесены, один чужой лежит под тем же курсором.
## Ожидаемый результат: точечный запрос читает имя одного местного предмета, полный возвращает пятьсот; чужой предмет не читается.
func test_distant_drops_do_not_request_details() -> void:
	var fixture := DropFixture.new()
	for index in 500:
		fixture.dropped_items.append({"kind":"wood", "position":Vector2(index * 80, 300), "count":index + 1})
	fixture.dropped_items.append({"kind":"stone", "position":Vector2(200 * 80, 300), "count":1, "location":"cave_fungal"})
	var picked: Array[Dictionary] = []
	Inspector.append_drops(fixture, picked, Vector2(200 * 80, 300))
	expect(picked.size() == 1 and picked[0].id == "drop:200:wood" and picked[0].details.has("количество 201"), "point inspector identifies the sole drop and its actual count")
	expect(fixture.name_queries == 1, "point inspector requests item details only for the selected drop")
	fixture.name_queries = 0
	var catalog: Array[Dictionary] = []
	Inspector.append_drops(fixture, catalog)
	expect(catalog.size() == 500 and fixture.name_queries == 500, "unfiltered inspector retains complete catalog semantics")
	fixture.free()

extends "res://tests/suites/suite_base.gd"

const Signs := preload("res://scripts/systems/village_wayfinding_system.gd")
const Regions := preload("res://scripts/systems/village_region_system.gd")

## Проверяет направление всех ориентиров и реальные свободные обратные входы.
func run() -> void:
	test_each_wayfinding_route_reaches_its_landmark()
	test_all_arrivals_and_localized_signs()
	test_blocked_arrival_relocates_or_rejects_atomically()

## Сценарий: игрок следует одному и тому же ориентиру из любого района без миникарты.
## Исходное состояние: шесть районов и четыре существующих места назначения.
## Ожидаемый результат: каждый маршрут конечен, ведёт по настоящим портам и не образует петель.
func test_each_wayfinding_route_reaches_its_landmark() -> void:
	for source in Signs.Data.IDS:
		for place in Signs.PLACES:
			var target: String = Signs.PLACES[place]; var current: String = source; var visited := {}
			for step in 6:
				if current == target: break
				expect(not visited.has(current), "wayfinding never loops: " + source + " / " + place)
				visited[current] = true
				var port: String = Signs.next_port(current,target)
				var links: Array = Signs.Data.passages(current).filter(func(link): return link.port == port)
				expect(links.size() == 1, "a recommended direction names one real road")
				if links.size() != 1: break
				current = links[0].target
			expect(current == target, "following landmark reaches " + place + " from " + source)
	expect(Signs.next_port("unknown","overworld").is_empty() and Signs.next_port("overworld","overworld").is_empty(), "invalid or current destinations need no invented arrow")

## Сценарий: все указатели читаются на шести языках, а переход и возвращение сохраняют запасы.
## Исходное состояние: реальные карты, фасады и вода, обычный герой без отладочных изменений мира.
## Ожидаемый результат: появление всегда на земле, обратная дорога точна, подписи осевые и не содержат ID.
func test_all_arrivals_and_localized_signs() -> void:
	var game := make_game(); var initial: Dictionary = game.export_inventory_counts()
	for source in Signs.Data.IDS:
		for link in Signs.Data.passages(source):
			game.current_location = source; game.player = link.position
			expect(Regions.travel(game,link.port) and game.current_location == link.target, "real signed road reaches its declared district")
			expect(game.NavigationSystem.is_walkable(game,game.player), "signed arrival is on actual free ground: " + source + "/" + link.port + " -> " + link.target + " / " + game.NavigationSystem.walkability_reason(game,game.player))
			game.player = Signs.Data.port_position(link.target,link.arrival)
			expect(Regions.travel(game,link.arrival) and game.current_location == source, "the same signed route returns to its exact source")
			for locale in game.LocaleSystem.LOCALES:
				game.LocaleSystem.current = locale
				var title: String = Signs.title(game,link); var tags: String = Signs.tags(game,link.port)
				expect(title.begins_with(Signs.ARROWS[link.port]) and not title.contains("village_") and not title.contains("overworld"), "sign uses cardinal arrow and localized name in " + locale)
				expect(tags.split(" · ").size() <= 2, "compact route labels remain bounded")
				if link.target == "overworld": expect(title.contains(Signs.word(game,"farm")), "home road names the farm explicitly")
	expect(game.export_inventory_counts() == initial, "reading and following signs never changes supplies")
	game.free()

## Сценарий: сундук занял обычную точку появления, затем весь ограниченный подход перекрыт контейнерами.
## Исходное состояние: герой у рынка, запасы и положение исходной стороны записаны.
## Ожидаемый результат: сначала выбирается свободное место рядом, при полном перекрытии переход отменяется без потерь.
func test_blocked_arrival_relocates_or_rejects_atomically() -> void:
	var game := make_game(); var link: Dictionary = Signs.Data.passages("village_market").filter(func(row): return row.port == "left")[0]
	game.current_location = "village_market"; game.player = link.position
	game.world_loot_nodes = [{"kind":"chest","location":"overworld","position":link.spawn}]
	expect(Regions.travel(game,"left") and game.player != link.spawn and game.player.distance_to(link.spawn) <= 204, "occupied default spawn uses bounded nearby free ground")
	expect(game.NavigationSystem.is_walkable(game,game.player), "fallback spawn respects actual container collision")
	game.world_loot_nodes.clear()
	for y in range(-192,193,24):
		for x in range(-192,193,24): game.world_loot_nodes.append({"kind":"chest","location":"overworld","position":link.spawn+Vector2(x,y)})
	game.current_location = "village_market"; game.player = link.position
	var counts: Dictionary = game.export_inventory_counts(); var coins: int = game.coins
	expect(not Regions.travel(game,"left") and game.current_location == "village_market" and game.player == link.position, "fully blocked arrival keeps the original location and position")
	expect(game.export_inventory_counts() == counts and game.coins == coins and not game.message.is_empty(), "rejected travel is explained and consumes no belongings")
	game.free()

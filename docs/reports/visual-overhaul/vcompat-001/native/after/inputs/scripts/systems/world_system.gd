extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const LOCATIONS := ["overworld","forest","rocky","ruins","cave","cursed","glassworks","pirate_ship"]
const NAMES := {"overworld":"Деревня и гильдия","forest":"Обычный лес","rocky":"Каменистая область","ruins":"Орочьи руины","cave":"Кристальные пещеры","cursed":"Проклятая земля","glassworks":"Мастерская стеклодува","pirate_ship":"Корабль «Чёрная сельдь»","moon_glade":"Лунная поляна","village_market":"Торговая слобода","village_garden":"Сад травницы","village_river":"Речная переправа","village_workyard":"Ремесленный двор","village_orchard":"Яблоневый сад"}

## Выполняет операцию «следующего локации» и возвращает результат согласно контракту метода.
static func next_location(current: String) -> String:
	if preload("res://scripts/systems/cave_room_data.gd").is_cave(current): return "cursed"
	return LOCATIONS[(LOCATIONS.find(current) + 1) % LOCATIONS.size()]

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func name(kind: String) -> String:
	return LocaleSystem.location(kind)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func travel(game: Node) -> void:
	if not preload("res://scripts/systems/cave_boss_arena_system.gd").can_exit(game): return
	var early_return: String = game.FirstChapterSystem.early_return_location(game)
	game.current_location = early_return if not early_return.is_empty() else next_location(game.current_location)
	game.player = Vector2(220, 430)
	if game.current_location == "cave": game.player = preload("res://scripts/systems/cave_map_data.gd").START
	game.sync_background_location(); game.update_camera()
	game.play_sfx("travel")
	game.message = name(game.current_location)
	game.notify_tutorial("locations")
	game.FirstChapterSystem.on_location_changed(game)
	if game.current_location == "pirate_ship": game.notify_tutorial("pirate_ship")
	game.DiscoverySystem.show_location(game, game.current_location)

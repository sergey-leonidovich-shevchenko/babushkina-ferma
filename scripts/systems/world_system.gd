extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const LOCATIONS := ["overworld","forest","rocky","ruins","cave","cursed","glassworks"]
const NAMES := {"overworld":"Деревня и гильдия","forest":"Обычный лес","rocky":"Каменистая область","ruins":"Орочьи руины","cave":"Кристальные пещеры","cursed":"Проклятая земля","glassworks":"Мастерская стеклодува"}

static func next_location(current: String) -> String:
	return LOCATIONS[(LOCATIONS.find(current) + 1) % LOCATIONS.size()]

static func name(kind: String) -> String:
	return LocaleSystem.location(kind)

static func travel(game: Node) -> void:
	game.current_location = next_location(game.current_location)
	game.player = Vector2(220, 430)
	game.sync_background_location(); game.update_camera()
	game.play_sfx("travel")
	game.message = name(game.current_location)
	game.notify_tutorial("locations")
	game.DiscoverySystem.show_location(game, game.current_location)

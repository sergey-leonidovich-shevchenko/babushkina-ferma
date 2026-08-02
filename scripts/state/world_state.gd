extends RefCounted

const TreeSystem := preload("res://scripts/systems/tree_system.gd")
const MoonGladeSystem := preload("res://scripts/systems/moon_glade_system.gd")

var location: String = "overworld"
var day: int = 1
var minutes: float = 6.0 * 60.0
var coins: int = 20
var weather_day: int = 0
var weather: String = ""
var plots: Dictionary = {}
var dropped_items: Array = []
var world_loot_seed: int = 0
var world_loot_nodes: Array = []
var tree_nodes: Array = TreeSystem.default_nodes()
var moon_glade: Dictionary = MoonGladeSystem.default_state()


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	day = maxi(day, 1)
	minutes = fposmod(minutes, 24.0 * 60.0)
	coins = maxi(coins, 0)
	weather_day = maxi(weather_day, 0)
	moon_glade = MoonGladeSystem.normalize_state(moon_glade)
	for index in tree_nodes.size():
		var tree: Dictionary = tree_nodes[index]
		tree.health = clampi(int(tree.get("health", TreeSystem.MAX_HEALTH)), 0, TreeSystem.MAX_HEALTH)
		tree.stage = clampi(int(tree.get("stage", 3)), 0, 3)
		tree.regrow_timer = clampf(float(tree.get("regrow_timer", TreeSystem.REGROW_DURATION)), 0.0, TreeSystem.REGROW_DURATION)
		tree.hit_flash = 0.0
		tree_nodes[index] = tree

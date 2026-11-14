extends RefCounted

const TreeSystem := preload("res://scripts/systems/tree_system.gd")
const MoonGladeSystem := preload("res://scripts/systems/moon_glade_system.gd")
const CastleCampaignSystem := preload("res://scripts/systems/castle_campaign_system.gd")
const EstateSystem := preload("res://scripts/systems/estate_system.gd")

var location: String = "overworld"
var day: int = 1
var minutes: float = 6.0 * 60.0
var coins: int = 20
var weather_day: int = 0
var weather: String = ""
var plots: Dictionary = {}
var world_plots: Dictionary = {}
var dropped_items: Array = []
var world_loot_seed: int = 0
var rng_state: Dictionary = {}
var world_loot_nodes: Array = []
var tree_nodes: Array = TreeSystem.default_nodes()
var moon_glade: Dictionary = MoonGladeSystem.default_state()
var castle_campaign: Dictionary = CastleCampaignSystem.default_state()
var estate: Dictionary = EstateSystem.default_state()
var cave_arena: Dictionary = {"relic_awarded": false}
var cave_boss: Dictionary = preload("res://scripts/systems/cave_boss_data.gd").default_state()


## Преобразует только настоящие числовые значения старого сохранения.
static func normalized_int(value: Variant, fallback: int) -> int:
	if value is bool:
		return 1 if value else 0
	if value is int or value is float:
		return str(value).to_int()
	return fallback


## Преобразует только настоящие числовые значения таймера старого сохранения.
static func normalized_float(value: Variant, fallback: float) -> float:
	if value is bool:
		return 1.0 if value else 0.0
	if value is int or value is float:
		return str(value).to_float()
	return fallback


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	day = maxi(day, 1)
	minutes = fposmod(minutes, 24.0 * 60.0)
	coins = maxi(coins, 0)
	weather_day = maxi(weather_day, 0)
	moon_glade = MoonGladeSystem.normalize_state(moon_glade)
	castle_campaign = CastleCampaignSystem.normalize_state(castle_campaign)
	estate = EstateSystem.normalize_state(estate)
	var expansion: Dictionary = estate.get("expansion", {})
	if not expansion.has("fences") or not expansion.get("fences") is Array:
		expansion["fences"] = []
	estate["expansion"] = expansion
	for index in tree_nodes.size():
		var tree: Dictionary = tree_nodes[index]
		tree.health = clampi(
			normalized_int(tree.get("health", TreeSystem.MAX_HEALTH), TreeSystem.MAX_HEALTH),
			0,
			TreeSystem.MAX_HEALTH,
		)
		tree.stage = clampi(normalized_int(tree.get("stage", 3), 3), 0, 3)
		tree.regrow_timer = clampf(
			normalized_float(
				tree.get("regrow_timer", TreeSystem.REGROW_DURATION), TreeSystem.REGROW_DURATION
			),
			0.0,
			TreeSystem.REGROW_DURATION,
		)
		tree.hit_flash = 0.0
		tree_nodes[index] = tree

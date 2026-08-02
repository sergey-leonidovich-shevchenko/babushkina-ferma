extends RefCounted

var location: String = "overworld"
var day: int = 1
var minutes: float = 6.0 * 60.0
var coins: int = 20
var plots: Dictionary = {}
var dropped_items: Array = []
var world_loot_seed: int = 0
var world_loot_nodes: Array = []


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	day = maxi(day, 1)
	minutes = fposmod(minutes, 24.0 * 60.0)
	coins = maxi(coins, 0)


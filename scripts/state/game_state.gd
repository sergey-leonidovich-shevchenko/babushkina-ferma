extends RefCounted

const PlayerState := preload("res://scripts/state/player_state.gd")
const InventoryState := preload("res://scripts/state/inventory_state.gd")
const WorldState := preload("res://scripts/state/world_state.gd")

var player := PlayerState.new()
var inventory := InventoryState.new()
var world := WorldState.new()


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	player.normalize()
	world.normalize()

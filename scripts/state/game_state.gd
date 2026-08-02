extends RefCounted

const PlayerState := preload("res://scripts/state/player_state.gd")
const InventoryState := preload("res://scripts/state/inventory_state.gd")
const WorldState := preload("res://scripts/state/world_state.gd")
const StorageState := preload("res://scripts/state/storage_state.gd")
const ForgeState := preload("res://scripts/state/forge_state.gd")
const ContractState := preload("res://scripts/state/contract_state.gd")

var player := PlayerState.new()
var inventory := InventoryState.new()
var world := WorldState.new()
var storage := StorageState.new()
var forge := ForgeState.new()
var contracts := ContractState.new()


## Приводит загруженное состояние к безопасным допустимым значениям.
func normalize() -> void:
	player.normalize()
	world.normalize()
	storage.normalize()
	forge.normalize()
	contracts.normalize()

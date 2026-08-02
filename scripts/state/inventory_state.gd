extends RefCounted

const DEFAULT_SLOTS := ["seeds", "carrot", "pickaxe", "fishing_rod", "slime", "wood", "stone", "crystal", "fish", "sword", "bow", "crystal_sword", "apple", "berries", "nut", "mushroom", "iron_helmet", "guardian_armor", "travel_boots", "crystal_ring", "orange", "orc_blade", "red_crystal", "green_crystal", "raw_meat", "hide", "fur", "tusk", "bat_wing", "watermelon", "healing_potion", "oak_shield", "lizard_scale", ""]
const DEFAULT_HOTBAR := ["hoe", "seeds", "water", "hand", "pickaxe", "fishing_rod", "carrot", "apple", "berries", "mushroom"]
const DEFAULT_EQUIPMENT := {"head": "", "body": "", "legs": "", "hands": "", "offhand": "", "ring": ""}
const INITIAL_COUNTS := {
	"seeds": 8, "carrot": 0, "slime": 0, "wood": 2, "stone": 0,
	"crystal": 0, "fish": 0, "apple": 0, "berries": 0, "nut": 0,
	"mushroom": 0, "orange": 0, "iron_helmet": 0, "guardian_armor": 0,
	"travel_boots": 0, "crystal_ring": 0, "fiber": 0, "rare_seeds": 0,
	"metal": 0, "bones": 0, "ancient_key": 0, "blue_gem": 0,
	"red_crystal": 0, "green_crystal": 0, "orc_blade": 0, "moon_relic": 0,
	"raw_meat": 0, "hide": 0, "fur": 0, "tusk": 0, "bat_wing": 0,
	"lizard_scale": 0, "watermelon": 0, "healing_potion": 0, "oak_shield": 0,
}

var counts: Dictionary = INITIAL_COUNTS.duplicate(true)
var slots: Array = DEFAULT_SLOTS.duplicate()
var hotbar: Array = DEFAULT_HOTBAR.duplicate()
var equipment: Dictionary = DEFAULT_EQUIPMENT.duplicate(true)
var selected_slot: int = 0
var selected_hotbar: int = 0
var scroll_row: int = 0


func count(kind: String) -> int:
	return int(counts.get(kind, 0))


func has(kind: String, amount: int = 1) -> bool:
	return amount >= 0 and count(kind) >= amount


func set_count(kind: String, amount: int) -> bool:
	if kind.is_empty() or not counts.has(kind) or amount < 0:
		return false
	counts[kind] = amount
	return true


func change(kind: String, amount: int) -> bool:
	if not counts.has(kind):
		return false
	var updated := count(kind) + amount
	if updated < 0:
		return false
	counts[kind] = updated
	return true


func import_counts(saved_counts: Dictionary) -> void:
	for kind in counts:
		counts[kind] = maxi(int(saved_counts.get(kind, 0)), 0)


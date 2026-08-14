extends RefCounted

const DEFAULT_SLOTS := ["seeds", "carrot", "pickaxe", "fishing_rod", "slime", "wood", "stone", "crystal", "fish", "sword", "bow", "crystal_sword", "apple", "berries", "nut", "mushroom", "iron_helmet", "guardian_armor", "travel_boots", "crystal_ring", "orange", "orc_blade", "red_crystal", "green_crystal", "raw_meat", "hide", "fur", "tusk", "bat_wing", "watermelon", "healing_potion", "mana_potion", "energy_potion", "invisibility_potion", "strength_potion", "regeneration_potion", "speed_potion", "defense_potion", "oak_shield", "lizard_scale", "arrows", "home_chest", "guild_badge", "axe", "pirate_doubloon", "ectoplasm", "cursed_compass", "pirate_cutlass", "eclipse_core", "tomato", "cabbage", "egg", "milk", "wheat", "corn", "potato", "onion", "cheese", "rope", "cotton", "flower", "honey", "bread", "pie", "pumpkin", "flour", "butter", "jam", "soup", "omelet", "cornbread", "wool", "bouquet", "rustic_table", "wooden_chair", "woven_rug", "potted_fern", "wooden_wardrobe", "museum_token", "pear", "cherry", "plum", "tomato_seeds", "cabbage_seeds", "wheat_seeds", "corn_seeds", "potato_seeds", "onion_seeds", "pumpkin_seeds", "strawberry_seeds", "beet_seeds", "pepper_seeds", "cucumber_seeds", "sunflower_seeds", "cotton_seeds", "melon_seeds", "herb_seeds", "strawberry", "beet", "pepper", "cucumber", "sunflower", "melon", "herbs"]
const DEFAULT_HOTBAR := ["hoe", "seeds", "water", "hand", "pickaxe", "fishing_rod", "axe", "apple", "berries", "mushroom"]
const DEFAULT_EQUIPMENT := {"head": "", "body": "", "legs": "", "hands": "", "offhand": "", "ring": ""}
const INITIAL_COUNTS := {
	"seeds": 8, "carrot": 0, "slime": 0, "wood": 2, "stone": 0,
	"crystal": 0, "fish": 0, "apple": 0, "pear": 0, "cherry": 0, "plum": 0, "berries": 0, "nut": 0,
	"mushroom": 0, "orange": 0, "iron_helmet": 0, "guardian_armor": 0,
	"travel_boots": 0, "crystal_ring": 0, "fiber": 0, "rare_seeds": 0,
	"metal": 0, "bones": 0, "ancient_key": 0, "blue_gem": 0,
	"red_crystal": 0, "green_crystal": 0, "orc_blade": 0, "moon_relic": 0,
	"raw_meat": 0, "hide": 0, "fur": 0, "tusk": 0, "bat_wing": 0,
	"lizard_scale": 0, "watermelon": 0, "healing_potion": 0, "oak_shield": 0,
	"mana_potion":0, "energy_potion":0, "invisibility_potion":0, "strength_potion":0,
	"regeneration_potion":0, "speed_potion":0, "defense_potion":0,
	"arrows": 0, "home_chest": 0, "guild_badge": 0, "axe": 1,
	"pirate_doubloon": 0, "ectoplasm": 0, "cursed_compass": 0, "pirate_cutlass": 0,
	"eclipse_core": 0,
	"tomato":0, "cabbage":0, "egg":0, "milk":0, "wheat":0, "corn":0,
	"potato":0, "onion":0, "cheese":0, "rope":0, "cotton":0, "flower":0,
	"honey":0, "bread":0, "pie":0, "pumpkin":0, "flour":0, "butter":0,
	"jam":0, "soup":0, "omelet":0, "cornbread":0, "wool":0, "bouquet":0,
	"rustic_table":0,"wooden_chair":0,"woven_rug":0,"potted_fern":0,"wooden_wardrobe":0,"museum_token":0,
	"tomato_seeds":0,"cabbage_seeds":0,"wheat_seeds":0,"corn_seeds":0,"potato_seeds":0,
	"onion_seeds":0,"pumpkin_seeds":0,"strawberry_seeds":0,"beet_seeds":0,"pepper_seeds":0,
	"cucumber_seeds":0,"sunflower_seeds":0,"cotton_seeds":0,"melon_seeds":0,"herb_seeds":0,
	"strawberry":0,"beet":0,"pepper":0,"cucumber":0,"sunflower":0,"melon":0,"herbs":0,
}

var counts: Dictionary = INITIAL_COUNTS.duplicate(true)
var slots: Array = DEFAULT_SLOTS.duplicate()
var hotbar: Array = DEFAULT_HOTBAR.duplicate()
var equipment: Dictionary = DEFAULT_EQUIPMENT.duplicate(true)
var selected_slot: int = 0
var selected_hotbar: int = 0
var scroll_row: int = 0
var backpack_level: int = 0
var durability: Dictionary = {"hoe":100,"water":100,"pickaxe":100,"fishing_rod":100,"axe":100,"sword":100,"bow":100,"crystal_sword":100,"orc_blade":100}


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func count(kind: String) -> int:
	return int(counts.get(kind, 0))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func has(kind: String, amount: int = 1) -> bool:
	return amount >= 0 and count(kind) >= amount


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func set_count(kind: String, amount: int) -> bool:
	if kind.is_empty() or not counts.has(kind) or amount < 0:
		return false
	counts[kind] = amount
	return true


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
func change(kind: String, amount: int) -> bool:
	if not counts.has(kind):
		return false
	var updated := count(kind) + amount
	if updated < 0:
		return false
	counts[kind] = updated
	return true


## Устанавливает относящееся к методу значение и синхронизирует зависимое состояние.
func import_counts(saved_counts: Dictionary) -> void:
	for kind in counts:
		var legacy_fallback: int = INITIAL_COUNTS[kind] if kind == "axe" else 0
		counts[kind] = maxi(int(saved_counts.get(kind, legacy_fallback)), 0)


## Возвращает вместимость рюкзака с учётом купленных улучшений.
func capacity() -> int:
	return 60 + clampi(backpack_level, 0, 4) * 12


## Нормализует износ снаряжения и уровень расширения после загрузки.
func normalize_meta() -> void:
	backpack_level = clampi(backpack_level, 0, 4)
	for kind in durability: durability[kind] = clampi(int(durability[kind]), 0, 100)

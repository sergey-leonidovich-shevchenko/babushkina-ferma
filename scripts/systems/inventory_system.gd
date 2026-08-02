extends RefCounted

const ITEM_DATA := {
	"hoe": {"name": "Мотыга", "short": "Мотыга", "color": Color("a87542"), "tool": 0},
	"seeds": {"name": "Семена моркови", "short": "Семена", "color": Color("d8b86b"), "tool": 1},
	"water": {"name": "Лейка", "short": "Лейка", "color": Color("5aa4d6"), "tool": 2},
	"hand": {"name": "Руки", "short": "Руки", "color": Color("e4b486"), "tool": 3},
	"pickaxe": {"name": "Кирка", "short": "Кирка", "color": Color("87989c"), "tool": 4},
	"fishing_rod": {"name": "Удочка", "short": "Удочка", "color": Color("b77a45"), "tool": 5},
	"carrot": {"name": "Морковь", "short": "Морковь", "color": Color("ee7a32"), "edible": true},
	"apple": {"name": "Лесное яблоко", "short": "Яблоко", "color": Color("df4b45"), "edible": true},
	"berries": {"name": "Лесные ягоды", "short": "Ягоды", "color": Color("7656c7"), "edible": true},
	"nut": {"name": "Крепкий орех", "short": "Орех", "color": Color("a8733e"), "edible": true},
	"mushroom": {"name": "Красный гриб", "short": "Гриб", "color": Color("d95c50"), "edible": true},
	"orange": {"name": "Сочный апельсин", "short": "Апельсин", "color": Color("ff9217"), "edible": true},
	"iron_helmet": {"name": "Железный шлем", "short": "Шлем", "color": Color("b8c3ca"), "equip": "head"},
	"guardian_armor": {"name": "Доспех хранителя", "short": "Доспех", "color": Color("d79b42"), "equip": "body"},
	"travel_boots": {"name": "Походные сапоги", "short": "Сапоги", "color": Color("8c6745"), "equip": "legs"},
	"crystal_ring": {"name": "Алмазный талисман", "short": "Алмаз", "color": Color("62dce5"), "equip": "ring"}
}

static func data(kind: String) -> Dictionary:
	return ITEM_DATA.get(kind, {"name": kind, "short": kind, "color": Color.WHITE})

static func assign_hotbar(game: Node, inventory_index: int, hotbar_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= game.inventory_slots.size() or hotbar_index < 0 or hotbar_index >= 10:
		return false
	var kind: String = game.inventory_slots[inventory_index]
	if kind.is_empty(): return false
	game.hotbar_slots[hotbar_index] = kind
	game.selected_hotbar = hotbar_index
	select_hotbar(game, hotbar_index)
	game.message = "%s назначен в быстрый слот %d" % [data(kind).name, hotbar_index + 1]
	game.notify_tutorial("hotbar")
	return true

static func select_hotbar(game: Node, index: int) -> bool:
	if index < 0 or index >= game.hotbar_slots.size(): return false
	game.selected_hotbar = index
	var kind: String = game.hotbar_slots[index]
	var item := data(kind)
	if item.has("tool"): game.selected_tool = item.tool
	game.message = "В руках: %s" % item.name
	return not kind.is_empty()

static func equip(game: Node, kind: String) -> bool:
	var item := data(kind)
	if not item.has("equip") or game.inventory_item_count(kind) <= 0: return false
	var slot: String = item.equip
	game.equipment[slot] = "" if game.equipment.get(slot, "") == kind else kind
	recalculate_stats(game)
	game.message = "%s: %s" % [slot, item.name]
	game.notify_tutorial("equipment")
	return true

static func recalculate_stats(game: Node) -> void:
	var bonus_hp := 0
	if game.equipment.head == "iron_helmet": bonus_hp += 10
	if game.equipment.body == "guardian_armor": bonus_hp += 20
	game.player_max_hp = game.MAX_BASE_HP + (game.player_level - 1) * 10 + bonus_hp
	game.player_hp = mini(game.player_hp, game.player_max_hp)

static func damage_bonus(game: Node) -> int:
	return 1 if game.equipment.ring == "crystal_ring" else 0

static func speed_multiplier(game: Node) -> float:
	return 1.1 if game.equipment.legs == "travel_boots" else 1.0

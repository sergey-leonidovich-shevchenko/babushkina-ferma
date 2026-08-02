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
	"slime": {"name": "Слизь", "short": "Слизь", "color": Color("72d4a2")},
	"wood": {"name": "Древесина", "short": "Дерево", "color": Color("a46c42")},
	"stone": {"name": "Камень", "short": "Камень", "color": Color("8f8a7c")},
	"crystal": {"name": "Синий кристалл", "short": "Кристалл", "color": Color("54d7e8")},
	"red_crystal": {"name": "Красный кристалл", "short": "Красный", "color": Color("ef5d67")},
	"green_crystal": {"name": "Зелёный кристалл", "short": "Зелёный", "color": Color("69d17d")},
	"fish": {"name": "Речная рыба", "short": "Рыба", "color": Color("5aa4d6")},
	"sword": {"name": "Лесной меч", "short": "Меч", "color": Color("d9e4e6")},
	"bow": {"name": "Охотничий лук", "short": "Лук", "color": Color("c58a4d")},
	"crystal_sword": {"name": "Кристальный меч", "short": "Кр. меч", "color": Color("6ce8ef")},
	"fiber": {"name": "Лесное волокно", "short": "Волокно", "color": Color("85a85a")},
	"rare_seeds": {"name": "Редкие семена", "short": "Ред. сем.", "color": Color("d4b765")},
	"metal": {"name": "Металл", "short": "Металл", "color": Color("9ca7ae")},
	"bones": {"name": "Кости", "short": "Кости", "color": Color("ded8be")},
	"ancient_key": {"name": "Древний ключ", "short": "Ключ", "color": Color("c29b50")},
	"blue_gem": {"name": "Синий алмаз", "short": "Алмаз", "color": Color("5cbce8")},
	"moon_relic": {"name": "Лунная реликвия", "short": "Реликвия", "color": Color("d4ecff")},
	"iron_helmet": {"name": "Железный шлем", "short": "Шлем", "color": Color("b8c3ca"), "equip": "head"},
	"guardian_armor": {"name": "Доспех хранителя", "short": "Доспех", "color": Color("d79b42"), "equip": "body"},
	"travel_boots": {"name": "Походные сапоги", "short": "Сапоги", "color": Color("8c6745"), "equip": "legs"},
	"crystal_ring": {"name": "Алмазный талисман", "short": "Алмаз", "color": Color("62dce5"), "equip": "ring"},
	"orc_blade": {"name": "Клинок орка", "short": "Клинок", "color": Color("8aa05c"), "equip": "hands"}
}

static func data(kind: String) -> Dictionary:
	return ITEM_DATA.get(kind, {"name": "Неизвестный предмет", "short": "?", "color": Color.WHITE})

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
	var bonus := 1 if game.equipment.ring == "crystal_ring" else 0
	if game.equipment.hands == "orc_blade":
		bonus += 2
	return bonus

static func speed_multiplier(game: Node) -> float:
	return 1.1 if game.equipment.legs == "travel_boots" else 1.0

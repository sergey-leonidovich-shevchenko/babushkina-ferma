extends RefCounted

const LocaleSystem := preload("res://scripts/systems/locale_system.gd")

const COLUMNS := 6
const VISIBLE_ROWS := 5
const VISIBLE_SLOTS := COLUMNS * VISIBLE_ROWS

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
	"watermelon": {"name": "Сочный арбуз", "short": "Арбуз", "color": Color("ef4962"), "edible": true},
	"healing_potion": {"name": "Лечебное зелье", "short": "Зелье", "color": Color("df3c4d"), "edible": true},
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
	"raw_meat": {"name": "Сырое мясо", "short": "Мясо", "color": Color("c96767")},
	"hide": {"name": "Оленья шкура", "short": "Шкура", "color": Color("a77a55")},
	"fur": {"name": "Лисий мех", "short": "Мех", "color": Color("dc8a47")},
	"tusk": {"name": "Кабаний клык", "short": "Клык", "color": Color("e4d9b9")},
	"bat_wing": {"name": "Крыло летучей мыши", "short": "Крыло", "color": Color("76658c")},
	"lizard_scale": {"name": "Чешуя лугового ящера", "short": "Чешуя", "color": Color("8fcf62")},
	"iron_helmet": {"name": "Железный шлем", "short": "Шлем", "color": Color("b8c3ca"), "equip": "head"},
	"guardian_armor": {"name": "Доспех хранителя", "short": "Доспех", "color": Color("d79b42"), "equip": "body"},
	"travel_boots": {"name": "Походные сапоги", "short": "Сапоги", "color": Color("8c6745"), "equip": "legs"},
	"crystal_ring": {"name": "Алмазный талисман", "short": "Алмаз", "color": Color("62dce5"), "equip": "ring"},
	"orc_blade": {"name": "Клинок орка", "short": "Клинок", "color": Color("8aa05c"), "equip": "hands"},
	"oak_shield": {"name": "Дубовый щит", "short": "Щит", "color": Color("7d5b47"), "equip": "offhand"}
}

## Возвращает локализованные метаданные предмета по его идентификатору.
static func data(kind: String) -> Dictionary:
	var result: Dictionary = ITEM_DATA.get(kind, {"name": kind, "short": "?", "color": Color.WHITE}).duplicate()
	if LocaleSystem.ITEMS.has(kind):
		result.name = LocaleSystem.item(kind)
		result.short = LocaleSystem.item(kind, true)
	return result

## Определяет категорию предмета для отображения и сортировки.
static func category(kind: String) -> String:
	var item := data(kind)
	if item.has("tool"): return "tool"
	if item.has("edible"): return "food"
	if item.has("equip"): return "equipment"
	if kind in ["ancient_key", "moon_relic"]: return "quest"
	return "resource"

## Возвращает ключ локализованного описания выбранной категории предмета.
static func detail_key(kind: String) -> String:
	match category(kind):
		"tool": return "detail_tool"
		"food": return "detail_food"
		"equipment": return "detail_equipment"
		"quest": return "detail_quest"
		_: return "detail_resource"

## Проверяет заявленное методом условие без изменения игрового состояния.
static func can_use(kind: String) -> bool:
	return not kind.is_empty() and data(kind).has("edible")

## Проверяет условие «возможности экипировки» без изменения состояния.
static func can_equip(kind: String) -> bool:
	return not kind.is_empty() and data(kind).has("equip")

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func swap_slots(game: Node, from_index: int, to_index: int) -> bool:
	if from_index < 0 or to_index < 0 or from_index >= game.inventory_slots.size() or to_index >= game.inventory_slots.size() or from_index == to_index:
		return false
	var previous: String = game.inventory_slots[to_index]
	game.inventory_slots[to_index] = game.inventory_slots[from_index]
	game.inventory_slots[from_index] = previous
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func sort_slots(game: Node) -> void:
	var selected_kind: String = game.inventory_slots[game.inventory_selected] if game.inventory_selected >= 0 and game.inventory_selected < game.inventory_slots.size() else ""
	var items: Array[String] = []
	for value in game.inventory_slots:
		var kind := String(value)
		if not kind.is_empty() and game.inventory_item_count(kind) > 0: items.append(kind)
	var order := {"tool":0, "food":1, "equipment":2, "quest":3, "resource":4}
	items.sort_custom(func(left: String, right: String) -> bool:
		var left_rank: int = order.get(category(left), 5)
		var right_rank: int = order.get(category(right), 5)
		return left < right if left_rank == right_rank else left_rank < right_rank
	)
	for index in game.inventory_slots.size(): game.inventory_slots[index] = items[index] if index < items.size() else ""
	ensure_capacity(game)
	game.inventory_selected = maxi(items.find(selected_kind), 0)
	game.inventory_scroll_row = 0
	game.inventory_move_from = -1
	game.message = game.LocaleSystem.text("inventory_sorted")

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ensure_item_slot(game: Node, kind: String) -> int:
	if kind.is_empty():
		return -1
	var existing: int = game.inventory_slots.find(kind)
	if existing >= 0:
		ensure_capacity(game)
		return existing
	var empty: int = game.inventory_slots.find("")
	if empty < 0:
		empty = game.inventory_slots.size()
		game.inventory_slots.append(kind)
	else:
		game.inventory_slots[empty] = kind
	ensure_capacity(game)
	return empty

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func ensure_capacity(game: Node) -> void:
	var last_used := -1
	for index in game.inventory_slots.size():
		if not String(game.inventory_slots[index]).is_empty():
			last_used = index
	var required_rows := maxi(VISIBLE_ROWS, ceili(float(last_used + 1) / COLUMNS) + 1)
	var required_slots := required_rows * COLUMNS
	while game.inventory_slots.size() < required_slots:
		game.inventory_slots.append("")

## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func max_scroll_row(game: Node) -> int:
	return maxi(0, ceili(float(game.inventory_slots.size()) / COLUMNS) - VISIBLE_ROWS)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func scroll(game: Node, rows: int) -> void:
	game.inventory_scroll_row = clampi(game.inventory_scroll_row + rows, 0, max_scroll_row(game))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func keep_selection_visible(game: Node) -> void:
	var selected_row: int = game.inventory_selected / COLUMNS
	if selected_row < game.inventory_scroll_row:
		game.inventory_scroll_row = selected_row
	elif selected_row >= game.inventory_scroll_row + VISIBLE_ROWS:
		game.inventory_scroll_row = selected_row - VISIBLE_ROWS + 1
	game.inventory_scroll_row = clampi(game.inventory_scroll_row, 0, max_scroll_row(game))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func assign_hotbar(game: Node, inventory_index: int, hotbar_index: int) -> bool:
	if inventory_index < 0 or inventory_index >= game.inventory_slots.size() or hotbar_index < 0 or hotbar_index >= 10:
		return false
	var kind: String = game.inventory_slots[inventory_index]
	if kind.is_empty(): return false
	game.hotbar_slots[hotbar_index] = kind
	game.selected_hotbar = hotbar_index
	select_hotbar(game, hotbar_index)
	game.message = game.LocaleSystem.text("assigned", [data(kind).name, hotbar_index + 1])
	game.notify_tutorial("hotbar")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func select_hotbar(game: Node, index: int) -> bool:
	if index < 0 or index >= game.hotbar_slots.size(): return false
	game.selected_hotbar = index
	var kind: String = game.hotbar_slots[index]
	var item := data(kind)
	if item.has("tool"): game.selected_tool = item.tool
	game.message = game.LocaleSystem.text("in_hand", [item.name])
	return not kind.is_empty()

## Выполняет операцию «экипировки» и возвращает результат согласно контракту метода.
static func equip(game: Node, kind: String) -> bool:
	var item := data(kind)
	if not item.has("equip") or game.inventory_item_count(kind) <= 0: return false
	var slot: String = item.equip
	game.equipment[slot] = "" if game.equipment.get(slot, "") == kind else kind
	recalculate_stats(game)
	game.message = "%s: %s" % [slot, item.name]
	game.notify_tutorial("equipment")
	if kind == "oak_shield":
		game.notify_tutorial("shield")
	return true

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func recalculate_stats(game: Node) -> void:
	game.SkillSystem.recalculate_resources(game)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func damage_bonus(game: Node) -> int:
	var bonus := 1 if game.equipment.ring == "crystal_ring" else 0
	if game.equipment.hands == "orc_blade":
		bonus += 2
	return bonus + game.SkillSystem.combat_bonus(game)

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func speed_multiplier(game: Node) -> float:
	return 1.1 if game.equipment.legs == "travel_boots" else 1.0

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func incoming_damage(game: Node, amount: int) -> int:
	return maxi(1, amount - (5 if game.equipment.get("offhand", "") == "oak_shield" else 0))

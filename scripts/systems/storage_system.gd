extends RefCounted

const CHEST_POSITION := Vector2(790, 260)
const MAX_VISIBLE_ROWS := 8


## Устанавливает купленный или созданный сундук дома и расходует набор мебели.
static func install(game: Node) -> bool:
	if game.home_chest_owned or game.inventory_item_count("home_chest") <= 0:
		return false
	game.change_inventory_count("home_chest", -1)
	game.home_chest_owned = true
	game.message = game.LocaleSystem.text("chest_installed")
	game.notify_tutorial("chest_install")
	return true


## Возвращает предметы рюкзака с положительным количеством в порядке его слотов.
static func inventory_items(game: Node) -> Array[String]:
	var result: Array[String] = []
	for value in game.inventory_slots:
		var kind := String(value)
		if not kind.is_empty() and game.inventory_item_count(kind) > 0 and kind not in result:
			result.append(kind)
	return result


## Возвращает отсортированный список предметов, находящихся в домашнем сундуке.
static func stored_items(game: Node) -> Array[String]:
	var result: Array[String] = []
	for kind in game.home_chest_counts:
		if int(game.home_chest_counts[kind]) > 0:
			result.append(String(kind))
	result.sort_custom(func(left: String, right: String): return game.inventory_item_name(left) < game.inventory_item_name(right))
	return result


## Возвращает список активной колонки интерфейса сундука.
static func selected_items(game: Node) -> Array[String]:
	return inventory_items(game) if game.storage_side == 0 else stored_items(game)


## Ограничивает выбранную строку после переноса или смены колонки.
static func clamp_selection(game: Node) -> void:
	var items := selected_items(game)
	game.storage_selected = clampi(game.storage_selected, 0, maxi(items.size() - 1, 0))


## Открывает установленный сундук только внутри дома бабушки.
static func open(game: Node) -> bool:
	if not game.home_chest_owned or game.current_location != "cottage_interior":
		game.message = game.LocaleSystem.text("chest_missing")
		return false
	game.storage_open = true
	game.storage_side = 0
	game.storage_selected = 0
	game.clear_movement_keys()
	game.message = game.LocaleSystem.text("chest_opened")
	game.notify_tutorial("chest_open")
	return true


## Кладёт указанное количество предмета из рюкзака в домашний сундук.
static func deposit(game: Node, kind: String, amount: int = 1) -> bool:
	amount = mini(maxi(amount, 0), game.inventory_item_count(kind))
	if not game.home_chest_owned or kind.is_empty() or kind == "home_chest" or amount <= 0:
		return false
	if not game.change_inventory_count(kind, -amount):
		return false
	game.state.storage.change(kind, amount)
	for slot in game.equipment:
		if game.equipment[slot] == kind and game.inventory_item_count(kind) == 0:
			game.equipment[slot] = ""
	if game.inventory_item_count(kind) == 0 and game.WeaponSystem.item_kind(game.equipped_weapon) == kind:
		game.equipped_weapon = "none"; game.equipment.hands = ""; game.sword_equipped = false
	game.InventorySystem.recalculate_stats(game)
	game.message = game.LocaleSystem.text("chest_deposited", [game.inventory_item_name(kind), amount])
	game.notify_tutorial("chest_deposit")
	return true


## Забирает указанное количество предмета из сундука обратно в рюкзак.
static func withdraw(game: Node, kind: String, amount: int = 1) -> bool:
	amount = mini(maxi(amount, 0), game.state.storage.count(kind))
	if kind.is_empty() or amount <= 0 or not game.state.storage.change(kind, -amount):
		return false
	game.change_inventory_count(kind, amount)
	game.message = game.LocaleSystem.text("chest_withdrawn", [game.inventory_item_name(kind), amount])
	game.notify_tutorial("chest_withdraw")
	return true


## Переносит один предмет или весь выбранный стек в противоположную колонку.
static func transfer_selected(game: Node, whole_stack: bool = false) -> bool:
	var items := selected_items(game)
	if items.is_empty():
		return false
	var kind: String = items[clampi(game.storage_selected, 0, items.size() - 1)]
	var amount: int = (game.inventory_item_count(kind) if game.storage_side == 0 else game.state.storage.count(kind)) if whole_stack else 1
	var transferred := deposit(game, kind, amount) if game.storage_side == 0 else withdraw(game, kind, amount)
	clamp_selection(game)
	return transferred


## Возвращает начало видимой области так, чтобы выбранная строка оставалась на экране.
static func visible_start(selected: int, item_count: int) -> int:
	return clampi(selected - MAX_VISIBLE_ROWS + 1, 0, maxi(item_count - MAX_VISIBLE_ROWS, 0))

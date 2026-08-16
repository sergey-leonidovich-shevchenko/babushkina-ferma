extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")

const VIEWPORT := Rect2(0, 0, 1152, 648)
const SHELL := Rect2(54, 46, 1044, 556)
const CLOSE_BUTTON := Rect2(1018, 65, 50, 50)
const CRAFT_SECTION := Rect2(194, 146, 764, 414)
const SHOP_STOCK_SECTION := Rect2(112, 150, 266, 390)
const SHOP_TABLE_SECTION := Rect2(390, 150, 608, 390)
const STORAGE_LEFT_SECTION := Rect2(82, 146, 458, 406)
const STORAGE_RIGHT_SECTION := Rect2(612, 146, 458, 406)
const FORGE_SECTION := Rect2(142, 146, 868, 414)


## Проверяет, относится ли текущее модальное состояние к общему семейству предметных окон.
static func is_open(game: Node) -> bool:
	return game.inventory_open or game.shop_open or game.crafting_open or game.storage_open or game.forge_open


## Закрывает активное предметное окно общей нарисованной кнопкой, очищая состояние перетаскивания.
static func close_active(game: Node) -> bool:
	if not is_open(game): return false
	game.inventory_open = false; game.shop_open = false; game.crafting_open = false; game.storage_open = false; game.forge_open = false
	game.inventory_move_from = -1
	game.UiFeedbackSystem.back(game)
	game.queue_redraw()
	return true


## Рисует общий затемнённый каркас предметного окна с резным заголовком и кнопкой закрытия.
static func draw_shell(game: Node, title: String, subtitle: String = "") -> void:
	game.draw_rect(VIEWPORT, Color(0.012, 0.020, 0.016, 0.78))
	UiKitSystem.draw_modal_panel(game, SHELL, true)
	game.draw_ui_string(game.MENU_FONT, Vector2(250, 103), title, HORIZONTAL_ALIGNMENT_CENTER, 652, 28, Color("fff0bd"))
	if not subtitle.is_empty():
		game.draw_ui_string(game.UI_FONT, Vector2(306, 128), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 540, 10, Color("efd59b"))
	game.draw_texture_rect(UiKitSystem.texture("close_button"), CLOSE_BUTTON, false)
	game.draw_ui_string(game.MENU_FONT, CLOSE_BUTTON.position + Vector2(4, 37), "×", HORIZONTAL_ALIGNMENT_CENTER, CLOSE_BUTTON.size.x - 8, 24, Color("fff0bd"))


## Рисует пергаментную секцию внутри общего предметного окна, сохраняя латунные углы.
static func draw_section(game: Node, rect: Rect2) -> void:
	UiKitSystem.draw_panel(game, rect, false)


## Рисует строку списка как полноценную художественную кнопку с внутренним фокусом.
static func draw_row(game: Node, rect: Rect2, selected: bool, enabled: bool = true) -> Rect2:
	UiKitSystem.draw_button(game, rect, selected, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	if not enabled: game.draw_rect(rect.grow(-9), Color(0.66, 0.18, 0.12, 0.08))
	return rect.grow(-8)


## Рисует подсказку управления в спокойной нижней области общего каркаса.
static func draw_help(game: Node, text: String) -> void:
	game.draw_ui_string(game.UI_FONT, Vector2(166, 582), text, HORIZONTAL_ALIGNMENT_CENTER, 820, 11, Color("efd59b"))


## Рисует верстак или котелок в едином предметном каркасе с иконками результатов и доступностью рецептов.
static func draw_crafting(game: Node) -> void:
	var title: String = "КОТЕЛОК • ДОМАШНЯЯ КУХНЯ" if game.crafting_station == "cauldron" else game.LocaleSystem.ui("workbench")
	draw_shell(game, title)
	draw_section(game, CRAFT_SECTION)
	var visible: Array[int] = game.CraftingSystem.visible_indices(game)
	var selected_position: int = maxi(visible.find(game.crafting_selected), 0)
	var first_position: int = clampi(selected_position - 4, 0, maxi(0, visible.size() - 9))
	for position in range(first_position, mini(first_position + 9, visible.size())):
		var index: int = visible[position]
		var recipe: Dictionary = game.CraftingSystem.RECIPES[index]
		var row := Rect2(220, 164 + (position - first_position) * 43, 712, 38)
		var available: bool = game.CraftingSystem.can_craft(game, recipe)
		draw_row(game, row, index == game.crafting_selected, available)
		game.draw_item_icon(String(recipe.output), Rect2(row.position + Vector2(14, 5), Vector2(28, 28)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(52, 25), game.inventory_item_name(recipe.output), HORIZONTAL_ALIGNMENT_LEFT, 210, 13, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(270, 24), game.CraftingSystem.ingredients_text(game, recipe), HORIZONTAL_ALIGNMENT_LEFT, 420, 10, UiKitSystem.COLORS.success if available else UiKitSystem.COLORS.danger)
	draw_help(game, game.LocaleSystem.ui("craft_help"))


## Рисует деревенскую лавку как две связанные секции: атмосферный прилавок и таблицу товаров.
static func draw_shop(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("shop"), "●  %d" % game.coins)
	draw_section(game, SHOP_STOCK_SECTION)
	draw_section(game, SHOP_TABLE_SECTION)
	game.draw_texture_rect_region(game.SUPPLY_SHEET, Rect2(145, 184, 200, 154), Rect2(0, 0, 176, 136))
	game.draw_ui_string(game.MENU_FONT, Vector2(130, 382), game.LocaleSystem.ui("grandma_stock"), HORIZONTAL_ALIGNMENT_CENTER, 230, 18, Color("fff0bd"))
	game.draw_multiline_string(game.UI_FONT, Vector2(136, 418), game.LocaleSystem.ui("shop_help"), HORIZONTAL_ALIGNMENT_CENTER, 218, 11, 3, Color("efd59b"))
	var table := Rect2(405, 174, 570, 340)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", Rect2(table.position, Vector2(table.size.x, 42)))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(52, 28), game.LocaleSystem.ui("product"), HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color("fff0cf"))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(360, 28), game.LocaleSystem.ui("buy"), HORIZONTAL_ALIGNMENT_CENTER, 78, 13, Color("fff0cf"))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(460, 28), game.LocaleSystem.ui("sell"), HORIZONTAL_ALIGNMENT_CENTER, 78, 13, Color("fff0cf"))
	var first_product: int = clampi(game.shop_selected - 4, 0, maxi(0, game.shop_products.size() - 9))
	for index in range(first_product, mini(first_product + 9, game.shop_products.size())):
		var product: Dictionary = game.shop_products[index]
		var row := Rect2(table.position + Vector2(0, 42 + (index - first_product) * 32), Vector2(table.size.x, 32))
		draw_row(game, row, index == game.shop_selected)
		if product.has("icon"):
			game.draw_texture_rect_region(game.SUPPLY_SHEET, Rect2(row.position + Vector2(13, 3), Vector2(26, 26)), product.icon)
		else:
			game.draw_item_icon(String(product.kind), Rect2(row.position + Vector2(13, 3), Vector2(26, 26)))
		var product_label: String = game.inventory_item_name(product.kind)
		if bool(product.get("seed", false)):
			var crop_kind: String = game.CropCatalogSystem.crop_for_seed(String(product.kind))
			if not crop_kind.is_empty():
				product_label += "  •  " + game.LocaleSystem.ui("growth_seconds_short", [roundi(game.CropCatalogSystem.growth_duration(crop_kind))])
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(48, 22), product_label, HORIZONTAL_ALIGNMENT_LEFT, 290, 11, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(360, 22), ("%d ●" % product.buy) if product.buy > 0 else "—", HORIZONTAL_ALIGNMENT_CENTER, 78, 11, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(460, 22), ("%d ●" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_CENTER, 78, 11, UiKitSystem.COLORS.ink)
	draw_help(game, game.LocaleSystem.ui("shop_help"))


## Рисует домашний сундук двумя симметричными колонками общего предметного семейства.
static func draw_storage(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("home_storage"))
	draw_section(game, STORAGE_LEFT_SECTION)
	draw_section(game, STORAGE_RIGHT_SECTION)
	game.draw_ui_string(game.MENU_FONT, Vector2(96, 176), game.LocaleSystem.ui("backpack_column"), HORIZONTAL_ALIGNMENT_CENTER, 430, 16, Color("fff0bd"))
	game.draw_ui_string(game.MENU_FONT, Vector2(626, 176), game.LocaleSystem.ui("chest_column"), HORIZONTAL_ALIGNMENT_CENTER, 430, 16, Color("fff0bd"))
	draw_storage_column(game, game.StorageSystem.inventory_items(game), 0, game.InterfaceRenderer.STORAGE_LEFT_ROWS)
	draw_storage_column(game, game.StorageSystem.stored_items(game), 1, game.InterfaceRenderer.STORAGE_RIGHT_ROWS)
	UiKitSystem.draw_button(game, game.InterfaceRenderer.STORAGE_TRANSFER_ONE, false, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	UiKitSystem.draw_button(game, game.InterfaceRenderer.STORAGE_TRANSFER_ALL, false, true, game.settings_state.reduced_motion, Time.get_ticks_msec())
	game.draw_ui_string(game.UI_FONT, game.InterfaceRenderer.STORAGE_TRANSFER_ONE.position + Vector2(4, 24), game.LocaleSystem.ui("transfer_one"), HORIZONTAL_ALIGNMENT_CENTER, 108, 10, UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.UI_FONT, game.InterfaceRenderer.STORAGE_TRANSFER_ALL.position + Vector2(4, 24), game.LocaleSystem.ui("transfer_all"), HORIZONTAL_ALIGNMENT_CENTER, 108, 10, UiKitSystem.COLORS.ink)
	draw_help(game, game.LocaleSystem.ui("storage_help"))


## Рисует одну прокручиваемую колонку сундука с одинаковыми слотами, количеством и внутренним фокусом.
static func draw_storage_column(game: Node, items: Array[String], side: int, rect: Rect2) -> void:
	var selected: int = game.storage_selected if game.storage_side == side else 0
	var start: int = game.StorageSystem.visible_start(selected, items.size())
	for visible_index in game.StorageSystem.MAX_VISIBLE_ROWS:
		var index: int = start + visible_index
		var row := Rect2(rect.position + Vector2(0, visible_index * 40), Vector2(rect.size.x, 38))
		draw_row(game, row, game.storage_side == side and index == game.storage_selected)
		if index >= items.size(): continue
		var kind: String = items[index]
		game.draw_item_icon(kind, Rect2(row.position + Vector2(10, 5), Vector2(28, 28)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(48, 25), game.inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 290, 11, UiKitSystem.COLORS.ink)
		var amount: int = game.inventory_item_count(kind) if side == 0 else game.state.storage.count(kind)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(350, 25), "×%d" % amount, HORIZONTAL_ALIGNMENT_RIGHT, 60, 11, UiKitSystem.COLORS.ink)


## Рисует кузницу как список постоянных улучшений с иконкой, рангом, стоимостью и прочностью.
static func draw_forge(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("forge_title"))
	draw_section(game, FORGE_SECTION)
	for index in game.ForgeSystem.UPGRADES.size():
		var upgrade: Dictionary = game.ForgeSystem.UPGRADES[index]
		var row := Rect2(164, 154 + index * 44, 824, 40)
		var current_level: int = game.ForgeSystem.level(game, upgrade.kind)
		var available: bool = game.ForgeSystem.can_upgrade(game, index)
		draw_row(game, row, index == game.forge_selected, available or current_level >= game.ForgeSystem.MAX_UPGRADE_LEVEL)
		game.draw_item_icon(String(upgrade.kind), Rect2(row.position + Vector2(10, 5), Vector2(30, 30)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(50, 26), game.inventory_item_name(upgrade.kind), HORIZONTAL_ALIGNMENT_LEFT, 220, 12, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(278, 26), game.LocaleSystem.ui("upgrade_level", [current_level, game.ForgeSystem.MAX_UPGRADE_LEVEL]), HORIZONTAL_ALIGNMENT_LEFT, 130, 10, Color("6b5136"))
		var cost: String = game.LocaleSystem.ui("upgrade_max") if current_level >= game.ForgeSystem.MAX_UPGRADE_LEVEL else game.ForgeSystem.cost_text(game, upgrade)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(410, 25), cost, HORIZONTAL_ALIGNMENT_LEFT, 278, 9, UiKitSystem.COLORS.success if available else UiKitSystem.COLORS.danger)
		var durability: int = int(game.state.inventory.durability.get(upgrade.kind, game.state.inventory.durability.get("sword", 100) if upgrade.kind == "sword" else -1))
		if durability >= 0:
			game.draw_ui_string(game.UI_FONT, row.position + Vector2(690, 25), "◆ %d%%" % durability, HORIZONTAL_ALIGNMENT_RIGHT, 110, 9, UiKitSystem.COLORS.success if durability > 20 else UiKitSystem.COLORS.danger)
	draw_help(game, "%s • R / X — ремонт" % game.LocaleSystem.ui("forge_help"))

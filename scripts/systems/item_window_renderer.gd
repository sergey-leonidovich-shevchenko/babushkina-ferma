extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const ItemTooltipRenderer := preload("res://scripts/presentation/item_tooltip_renderer.gd")
const ItemPresentationSystem := preload("res://scripts/systems/item_presentation_system.gd")
const ROW_PARCHMENT_SOURCE := Rect2(42, 36, 150, 82)

const VIEWPORT := Rect2(0, 0, 1152, 648)
const SHELL := Rect2(54, 46, 1044, 556)
const CLOSE_BUTTON := Rect2(1018, 65, 50, 50)
const CRAFT_SECTION := Rect2(194, 146, 764, 414)
const CRAFT_LIST := Rect2(210, 164, 470, 382)
const CRAFT_DETAIL := Rect2(696, 164, 246, 382)
const CRAFT_ACTION := Rect2(714, 498, 210, 40)
const ALCHEMY_FILTER := Rect2(210, 120, 470, 28)
const SHOP_STOCK_SECTION := Rect2(112, 150, 266, 390)
const SHOP_TOOLTIP := Rect2(120, 188, 250, 292)
const SHOP_TABLE_SECTION := Rect2(390, 150, 608, 390)
const SHOP_TABLE := Rect2(405, 174, 570, 340)
const SHOP_BUY_ACTION := Rect2(122, 490, 118, 38)
const SHOP_SELL_ACTION := Rect2(250, 490, 118, 38)
const STORAGE_LEFT_SECTION := Rect2(82, 146, 458, 374)
const STORAGE_RIGHT_SECTION := Rect2(612, 146, 458, 374)
const FORGE_SECTION := Rect2(142, 146, 868, 414)
const FORGE_UPGRADE_ACTION := Rect2(556, 508, 206, 42)
const FORGE_REPAIR_ACTION := Rect2(778, 508, 206, 42)


## Проверяет, относится ли текущее модальное состояние к общему семейству предметных окон.
static func is_open(game: Node) -> bool:
	return game.inventory_open or game.shop_open or game.crafting_open or game.storage_open or game.forge_open


## Возвращает hit-зону крестика активного окна, учитывая отдельную геометрию нарисованного скина рюкзака.
static func close_button_rect(game:Node)->Rect2:
	return game.InterfaceRenderer.INVENTORY_CLOSE_BUTTON if game.inventory_open else CLOSE_BUTTON


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


## Рисует светлый пергамент внутри общей деревянной рамы, чтобы тёмный текст не попадал на древесину.
static func draw_section(game: Node, rect: Rect2) -> void:
	UiKitSystem.draw_nine_patch(game, "tooltip", rect)


## Рисует спокойную строку на фактурном пергаменте без сжатия массивной рамы в высоту текста.
static func draw_row(game: Node, rect: Rect2, selected: bool, enabled: bool = true) -> Rect2:
	var surface := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 3))
	game.draw_texture_rect_region(UiKitSystem.texture("tooltip"), surface, ROW_PARCHMENT_SOURCE)
	game.draw_rect(surface, Color(0.32, 0.46, 0.23, 0.22) if selected else Color(0.48, 0.32, 0.16, 0.05))
	game.draw_line(surface.position + Vector2(0, surface.size.y), surface.end, Color("bd9b63"), 1)
	if selected:
		game.draw_rect(surface, Color("7b8645"), false, 1)
	if not enabled:
		game.draw_rect(Rect2(surface.end - Vector2(7, surface.size.y - 7), Vector2(3, surface.size.y - 14)), Color("b78967"))
	return surface.grow(-6)


## Добавляет к общей строке тонкую метку редкости предмета без уменьшения области текста или hit-зоны.
static func draw_item_row(game:Node,rect:Rect2,kind:String,selected:bool,enabled:bool=true)->Rect2:
	var inner:=draw_row(game,rect,selected,enabled)
	game.draw_rect(Rect2(inner.position+Vector2(1,3),Vector2(3,inner.size.y-6)),ItemPresentationSystem.rarity_color(kind))
	return inner


## Рисует подсказку управления в спокойной нижней области общего каркаса.
static func draw_help(game: Node, text: String) -> void:
	game.draw_ui_string(game.UI_FONT, Vector2(166, 582), text, HORIZONTAL_ALIGNMENT_CENTER, 820, 12, Color("efd59b"))


## Рисует верстак или котелок в едином предметном каркасе с иконками результатов и доступностью рецептов.
static func draw_crafting(game: Node) -> void:
	if game.ResearchSystem.handles(game.crafting_station): preload("res://scripts/presentation/research_renderer.gd").draw(game); return
	var title: String = game.LocaleSystem.ui("cauldron_title") if game.crafting_station == "cauldron" else game.LocaleSystem.ui("workbench")
	if game.crafting_station=="alchemy": title=game.LocaleSystem.ui("alchemy_title",[game.CraftingSystem.Alchemy.rank(game)])
	if game.crafting_station=="furnace": title=game.LocaleSystem.ui("furnace_title",[game.FurnaceSystem.state(game).level])
	if game.WorkshopSystem.handles(game.crafting_station): title=game.LocaleSystem.ui(game.crafting_station+"_title",[game.WorkshopSystem.state(game,game.crafting_station).level])
	var local:Dictionary=preload("res://scripts/systems/basement_station_system.gd").active(game,game.crafting_station)
	if not local.is_empty(): title=game.LocaleSystem.ui("basement_level",[preload("res://scripts/systems/basement_locale.gd").name_for(game,local.kind,int(local.level)),local.level])
	draw_shell(game, title)
	if game.crafting_station=="alchemy":
		draw_table_header(game,ALCHEMY_FILTER)
		game.draw_ui_string(game.UI_FONT,ALCHEMY_FILTER.position+Vector2(8,20),"‹  "+game.LocaleSystem.ui("alchemy_"+String(game.get_meta("alchemy_filter","all")))+"  ›",HORIZONTAL_ALIGNMENT_CENTER,ALCHEMY_FILTER.size.x-16,12,Color("fff0cf"))
		game.draw_ui_string(game.UI_FONT,Vector2(700,140),game.LocaleSystem.ui("alchemy_progress",[game.CraftingSystem.Alchemy.state(game).discovered.size(),game.CraftingSystem.Alchemy.state(game).xp]),HORIZONTAL_ALIGNMENT_CENTER,240,10,Color("efd59b"))
	draw_section(game, CRAFT_SECTION)
	var visible: Array[int] = game.CraftingSystem.visible_indices(game)
	var first_position: int = game.CraftingSystem.list_start(game,visible)
	for position in range(first_position, mini(first_position + game.CraftingSystem.visible_rows(game), visible.size())):
		var index: int = visible[position]
		var recipe: Dictionary = game.CraftingSystem.RECIPES[index]
		var row := craft_row_rect(position - first_position)
		var available: bool = game.CraftingSystem.can_craft(game, recipe)
		draw_item_row(game, row, String(recipe.output), index == game.crafting_selected, available)
		game.draw_item_icon(String(recipe.output), Rect2(row.position + Vector2(14, 5), Vector2(28, 28)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(52, 25), game.inventory_item_name(recipe.output), HORIZONTAL_ALIGNMENT_LEFT, 178, 12, UiKitSystem.COLORS.ink)
		var ingredients:String=game.CraftingSystem.row_ingredients_text(game,recipe)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(238, 24), ingredients, HORIZONTAL_ALIGNMENT_LEFT, 222, 10, Color("456537") if available else UiKitSystem.COLORS.danger)
	if not visible.is_empty():
		var selected: Dictionary = game.CraftingSystem.RECIPES[game.crafting_selected]
		var detail := CRAFT_DETAIL
		game.draw_line(detail.position - Vector2(9, -10), detail.position + Vector2(-9, detail.size.y - 10), Color("bc9a64"), 1)
		draw_table_header(game, Rect2(detail.position, Vector2(detail.size.x, 42)))
		game.draw_ui_string(game.UI_FONT, detail.position + Vector2(10, 27), game.CraftingSystem.category_name(game, selected), HORIZONTAL_ALIGNMENT_CENTER, detail.size.x - 20, 12, Color("fff0cf"))
		game.draw_item_icon(String(selected.output), Rect2(detail.position + Vector2(83, 58), Vector2(80, 80)))
		game.draw_ui_multiline_string(game.UI_FONT, detail.position + Vector2(10, 159), game.inventory_item_name(selected.output), HORIZONTAL_ALIGNMENT_CENTER, detail.size.x - 20, 40, 17, 2, UiKitSystem.COLORS.ink)
		var status:String=game.WorkshopSystem.status(game) if game.WorkshopSystem.handles(game.crafting_station) else (game.FurnaceSystem.status(game) if game.crafting_station=="furnace" else ItemPresentationSystem.effect_text(game,selected.output))
		game.draw_ui_multiline_string(game.UI_FONT, detail.position + Vector2(18, 202), status, HORIZONTAL_ALIGNMENT_CENTER, detail.size.x - 36, 34, 11, 2, Color("456537"))
		game.draw_ui_multiline_string(game.UI_FONT, detail.position + Vector2(18, 242), game.CraftingSystem.ingredients_text(game, selected), HORIZONTAL_ALIGNMENT_CENTER, detail.size.x - 36, 42, 12, 3, UiKitSystem.COLORS.ink)
		game.draw_ui_multiline_string(game.UI_FONT, detail.position + Vector2(18, 295), game.CraftingSystem.production_summary(game, selected), HORIZONTAL_ALIGNMENT_CENTER, detail.size.x - 36, 32, 11, 2, Color("456537") if game.CraftingSystem.can_craft(game, selected) else UiKitSystem.COLORS.danger)
		var can_create: bool = game.CraftingSystem.can_craft(game, selected)
		UiKitSystem.draw_nine_patch(game, "editor_button_selected" if can_create else "editor_button_normal", CRAFT_ACTION)
		game.draw_ui_string(game.UI_FONT, CRAFT_ACTION.position + Vector2(14, 26), game.LocaleSystem.ui("furnace_action" if game.crafting_station=="furnace" or game.WorkshopSystem.handles(game.crafting_station) or game.CraftingSystem.Kitchen.active(game) else "craft_action"), HORIZONTAL_ALIGNMENT_CENTER, CRAFT_ACTION.size.x - 28, 14, UiKitSystem.COLORS.ink if can_create else Color("846d50"))
	if game.crafting_station=="furnace": preload("res://scripts/presentation/furnace_renderer.gd").draw_toolbar(game)
	if game.WorkshopSystem.handles(game.crafting_station): preload("res://scripts/presentation/workshop_renderer.gd").draw_toolbar(game)
	if game.CraftingSystem.Kitchen.active(game): preload("res://scripts/presentation/kitchen_renderer.gd").draw_toolbar(game)
	draw_help(game, game.LocaleSystem.ui("kitchen_help" if game.CraftingSystem.Kitchen.active(game) else ("furnace_help" if game.crafting_station in ["furnace","glassblowing"] else ("workshop_help" if game.WorkshopSystem.handles(game.crafting_station) else ("alchemy_help" if game.crafting_station=="alchemy" else "craft_help")))))


## Рисует деревенскую лавку как две связанные секции: атмосферный прилавок и таблицу товаров.
static func draw_shop(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("shop"), "●  %d" % game.coins)
	draw_section(game, SHOP_STOCK_SECTION)
	draw_section(game, SHOP_TABLE_SECTION)
	game.draw_ui_string(game.UI_FONT, Vector2(130, 179), game.LocaleSystem.ui("grandma_stock"), HORIZONTAL_ALIGNMENT_CENTER, 230, 15, UiKitSystem.COLORS.ink)
	if not game.shop_products.is_empty():
		var selected_product:Dictionary=game.shop_products[clampi(game.shop_selected,0,game.shop_products.size()-1)]
		ItemTooltipRenderer.draw(game,String(selected_product.kind),SHOP_TOOLTIP,game.inventory_item_count(String(selected_product.kind)),true)
	draw_action(game, SHOP_BUY_ACTION, game.LocaleSystem.ui("buy"), game.ShopSystem.can_buy(game, game.shop_selected))
	draw_action(game, SHOP_SELL_ACTION, game.LocaleSystem.ui("sell"), game.ShopSystem.can_sell(game, game.shop_selected))
	var table := SHOP_TABLE
	draw_table_header(game, Rect2(table.position, Vector2(table.size.x, 42)))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(52, 28), game.LocaleSystem.ui("product"), HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color("fff0cf"))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(360, 28), game.LocaleSystem.ui("buy"), HORIZONTAL_ALIGNMENT_CENTER, 78, 13, Color("fff0cf"))
	game.draw_ui_string(game.UI_FONT, table.position + Vector2(460, 28), game.LocaleSystem.ui("sell"), HORIZONTAL_ALIGNMENT_CENTER, 78, 13, Color("fff0cf"))
	var first_product: int = clampi(game.shop_selected - 4, 0, maxi(0, game.shop_products.size() - 9))
	for index in range(first_product, mini(first_product + 9, game.shop_products.size())):
		var product: Dictionary = game.shop_products[index]
		var row := shop_row_rect(index - first_product)
		draw_item_row(game, row, String(product.kind), index == game.shop_selected)
		game.draw_item_icon(String(product.kind), Rect2(row.position + Vector2(13, 3), Vector2(26, 26)))
		var product_label: String = game.inventory_item_name(product.kind)
		if bool(product.get("seed", false)):
			var crop_kind: String = game.CropCatalogSystem.crop_for_seed(String(product.kind))
			if not crop_kind.is_empty():
				product_label += "  •  " + game.LocaleSystem.ui("growth_seconds_short", [roundi(game.CropCatalogSystem.growth_duration(crop_kind))])
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(48, 22), product_label, HORIZONTAL_ALIGNMENT_LEFT, 290, 11, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(360, 22), ("%d ●" % game.ShopSystem.purchase_price(game, product)) if product.buy > 0 else "—", HORIZONTAL_ALIGNMENT_CENTER, 78, 11, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(460, 22), ("%d ●" % product.sell) if product.sell > 0 else "—", HORIZONTAL_ALIGNMENT_CENTER, 78, 11, UiKitSystem.COLORS.ink)
	draw_help(game, game.LocaleSystem.ui("shop_help"))


## Рисует домашний сундук двумя симметричными колонками общего предметного семейства.
static func draw_storage(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("home_storage"))
	draw_section(game, STORAGE_LEFT_SECTION)
	draw_section(game, STORAGE_RIGHT_SECTION)
	game.draw_ui_string(game.UI_FONT, Vector2(96, 176), game.LocaleSystem.ui("backpack_column"), HORIZONTAL_ALIGNMENT_CENTER, 430, 16, UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.UI_FONT, Vector2(626, 176), game.LocaleSystem.ui("chest_column"), HORIZONTAL_ALIGNMENT_CENTER, 430, 16, UiKitSystem.COLORS.ink)
	draw_storage_column(game, game.StorageSystem.inventory_items(game), 0, game.InterfaceRenderer.STORAGE_LEFT_ROWS)
	draw_storage_column(game, game.StorageSystem.stored_items(game), 1, game.InterfaceRenderer.STORAGE_RIGHT_ROWS)
	var can_transfer: bool = not game.StorageSystem.selected_items(game).is_empty()
	draw_action(game, game.InterfaceRenderer.STORAGE_TRANSFER_ONE, game.LocaleSystem.ui("transfer_one"), can_transfer)
	draw_action(game, game.InterfaceRenderer.STORAGE_TRANSFER_ALL, game.LocaleSystem.ui("transfer_all"), can_transfer)
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
		game.draw_rect(Rect2(row.position+Vector2(9,8),Vector2(3,row.size.y-16)),ItemPresentationSystem.rarity_color(kind))
		game.draw_item_icon(kind, Rect2(row.position + Vector2(10, 5), Vector2(28, 28)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(48, 25), game.inventory_item_name(kind), HORIZONTAL_ALIGNMENT_LEFT, 290, 11, UiKitSystem.COLORS.ink)
		var amount: int = game.inventory_item_count(kind) if side == 0 else game.state.storage.count(kind)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(350, 25), "×%d" % amount, HORIZONTAL_ALIGNMENT_RIGHT, 60, 11, UiKitSystem.COLORS.ink)


## Рисует кузницу как список постоянных улучшений с иконкой, рангом, стоимостью и прочностью.
static func draw_forge(game: Node) -> void:
	draw_shell(game, game.LocaleSystem.ui("forge_title"))
	draw_section(game, FORGE_SECTION)
	var first_index: int = game.ForgeSystem.visible_start(game.forge_selected)
	for index in range(first_index, mini(first_index + game.ForgeSystem.VISIBLE_ROWS, game.ForgeSystem.UPGRADES.size())):
		var upgrade: Dictionary = game.ForgeSystem.UPGRADES[index]
		var row := forge_row_rect(index - first_index)
		var current_level: int = game.ForgeSystem.level(game, upgrade.kind)
		var available: bool = game.ForgeSystem.can_upgrade(game, index)
		draw_item_row(game, row, String(upgrade.kind), index == game.forge_selected, available or current_level >= game.ForgeSystem.MAX_UPGRADE_LEVEL)
		game.draw_item_icon(String(upgrade.kind), Rect2(row.position + Vector2(10, 3), Vector2(28, 28)))
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(50, 23), game.inventory_item_name(upgrade.kind), HORIZONTAL_ALIGNMENT_LEFT, 220, 12, UiKitSystem.COLORS.ink)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(278, 23), game.LocaleSystem.ui("upgrade_level", [current_level, game.ForgeSystem.MAX_UPGRADE_LEVEL]), HORIZONTAL_ALIGNMENT_LEFT, 130, 10, Color("6b5136"))
		var cost: String = game.LocaleSystem.ui("upgrade_max") if current_level >= game.ForgeSystem.MAX_UPGRADE_LEVEL else game.ForgeSystem.cost_text(game, upgrade, true)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(410, 23), cost, HORIZONTAL_ALIGNMENT_LEFT, 278, 9, UiKitSystem.COLORS.success if available else UiKitSystem.COLORS.danger)
		var durability: int = int(game.state.inventory.durability.get(upgrade.kind, game.state.inventory.durability.get("sword", 100) if upgrade.kind == "sword" else -1))
		if durability >= 0:
			game.draw_ui_string(game.UI_FONT, row.position + Vector2(690, 23), "◆ %d%%" % durability, HORIZONTAL_ALIGNMENT_RIGHT, 110, 9, UiKitSystem.COLORS.success if durability > 20 else UiKitSystem.COLORS.danger)
	draw_action(game, FORGE_UPGRADE_ACTION, game.LocaleSystem.ui("forge_upgrade_action"), game.ForgeSystem.can_upgrade(game, game.forge_selected))
	var repair_cost := forge_repair_price(game)
	draw_action(game, FORGE_REPAIR_ACTION, "%s  ·  %d ●" % [game.LocaleSystem.ui("forge_repair_action"), repair_cost], repair_cost > 0 and game.coins >= repair_cost)
	draw_help(game, "%s • %d–%d/%d" % [game.LocaleSystem.ui("forge_help_with_repair"), first_index + 1, mini(first_index + game.ForgeSystem.VISIBLE_ROWS, game.ForgeSystem.UPGRADES.size()), game.ForgeSystem.UPGRADES.size()])


## Возвращает строку рецепта в общей области списка без расхождения между рендером и аудитом.
static func craft_row_rect(visible_index:int)->Rect2:
	return Rect2(CRAFT_LIST.position+Vector2(0,visible_index*43),Vector2(CRAFT_LIST.size.x,38))


## Возвращает строку товара под заголовком таблицы с единым шагом в 32 пикселя.
static func shop_row_rect(visible_index:int)->Rect2:
	return Rect2(SHOP_TABLE.position+Vector2(0,42+visible_index*32),Vector2(SHOP_TABLE.size.x,32))


## Возвращает строку улучшения кузницы с общей геометрией для рендера, ввода и аудита.
static func forge_row_rect(visible_index:int)->Rect2:
	return Rect2(164,154+visible_index*38,824,34)


## Рисует явное подтверждение действия с достаточной светлой областью и спокойным недоступным состоянием.
static func draw_action(game: Node, rect: Rect2, label: String, enabled: bool) -> void:
	draw_row(game, rect, enabled, enabled)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10, rect.size.y * 0.5 + 5), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 12, UiKitSystem.COLORS.ink if enabled else Color("947f61"))


## Выбирает товар отдельным нажатием и проводит сделку только явной кнопкой покупки или продажи.
static func handle_shop_pointer(game: Node, position: Vector2) -> bool:
	if SHOP_BUY_ACTION.has_point(position):
		if game.ShopSystem.can_buy(game, game.shop_selected): game.buy_selected_product()
	elif SHOP_SELL_ACTION.has_point(position):
		if game.ShopSystem.can_sell(game, game.shop_selected): game.sell_selected_product()
	else:
		var first := clampi(game.shop_selected - 4, 0, maxi(0, game.shop_products.size() - 9))
		for index in 9:
			if shop_row_rect(index).has_point(position) and first + index < game.shop_products.size():
				game.shop_selected = first + index
				game.UiFeedbackSystem.focus(game, "shop_product:%d" % game.shop_selected)
				break
	game.queue_redraw()
	return true


## Даёт лавке стандартные кнопки геймпада: навигацию, покупку, продажу и отмену.
static func handle_shop_gamepad(game: Node, event: InputEventJoypadButton) -> bool:
	if not event.pressed: return true
	match event.button_index:
		JOY_BUTTON_B: close_active(game)
		JOY_BUTTON_DPAD_UP: game.shop_selected = posmod(game.shop_selected - 1, maxi(1, game.shop_products.size()))
		JOY_BUTTON_DPAD_DOWN: game.shop_selected = posmod(game.shop_selected + 1, maxi(1, game.shop_products.size()))
		JOY_BUTTON_A:
			if game.ShopSystem.can_buy(game, game.shop_selected): game.buy_selected_product()
		JOY_BUTTON_X:
			if game.ShopSystem.can_sell(game, game.shop_selected): game.sell_selected_product()
	game.queue_redraw()
	return true


## Прокручивает длинные предметные списки колесом, сохраняя выбранный элемент внутри видимой страницы.
static func handle_list_scroll(game: Node, direction: int) -> bool:
	if game.shop_open:
		game.shop_selected = clampi(game.shop_selected + direction, 0, maxi(0, game.shop_products.size() - 1))
	elif game.forge_open:
		game.forge_selected = clampi(game.forge_selected + direction, 0, game.ForgeSystem.UPGRADES.size() - 1)
	elif game.crafting_open:
		var visible: Array[int] = game.CraftingSystem.visible_indices(game)
		if not visible.is_empty(): game.crafting_selected = visible[clampi(visible.find(game.crafting_selected) + direction, 0, visible.size() - 1)]
	elif game.storage_open:
		game.storage_selected += direction
		game.StorageSystem.clamp_selection(game)
	else: return false
	game.queue_redraw()
	return true


## Возвращает стоимость восстановления выбранного предмета либо ноль, если ремонт ему не требуется.
static func forge_repair_price(game: Node) -> int:
	if game.forge_selected < 0 or game.forge_selected >= game.ForgeSystem.UPGRADES.size(): return 0
	var kind: String = game.ForgeSystem.UPGRADES[game.forge_selected].kind
	var durability := ItemPresentationSystem.durability(game, kind)
	return ceili((100 - durability) / 10.0) if durability >= 0 else 0


## Сначала выбирает улучшение для осмотра; улучшение и ремонт выполняются отдельными кнопками без случайного расхода ресурсов.
static func handle_forge_pointer(game: Node, position: Vector2) -> bool:
	if FORGE_UPGRADE_ACTION.has_point(position):
		if game.ForgeSystem.can_upgrade(game, game.forge_selected): game.ForgeSystem.upgrade(game, game.forge_selected)
	elif FORGE_REPAIR_ACTION.has_point(position):
		var price := forge_repair_price(game)
		if price > 0 and game.coins >= price:
			game.AdventurePolishSystem.repair(game, String(game.ForgeSystem.UPGRADES[game.forge_selected].kind))
	else:
		var first: int = game.ForgeSystem.visible_start(game.forge_selected)
		for index in game.ForgeSystem.VISIBLE_ROWS:
			if forge_row_rect(index).has_point(position) and first + index < game.ForgeSystem.UPGRADES.size():
				game.forge_selected = first + index
				game.UiFeedbackSystem.focus(game, "forge_item:%d" % game.forge_selected)
				break
	game.queue_redraw()
	return true


## Сначала выбирает рецепт для чтения, а материалы расходует только после явного нажатия кнопки создания.
static func handle_crafting_pointer(game: Node, position: Vector2) -> bool:
	if game.ResearchSystem.handles(game.crafting_station): return preload("res://scripts/presentation/research_renderer.gd").handle_pointer(game,position)
	if game.CraftingSystem.Kitchen.active(game) and preload("res://scripts/presentation/kitchen_renderer.gd").handle_pointer(game,position): return true
	if game.WorkshopSystem.handles(game.crafting_station) and preload("res://scripts/presentation/workshop_renderer.gd").handle_pointer(game,position): return true
	if game.crafting_station=="furnace" and preload("res://scripts/presentation/furnace_renderer.gd").handle_pointer(game,position): return true
	if game.crafting_station=="alchemy" and ALCHEMY_FILTER.has_point(position):
		game.CraftingSystem.Alchemy.cycle_filter(game,-1 if position.x<ALCHEMY_FILTER.get_center().x else 1); return true
	if CRAFT_ACTION.has_point(position):
		if game.crafting_selected >= 0 and game.crafting_selected < game.CraftingSystem.RECIPES.size():
			var recipe: Dictionary = game.CraftingSystem.RECIPES[game.crafting_selected]
			if game.CraftingSystem.can_craft(game, recipe):
				game.UiFeedbackSystem.press(game, CRAFT_ACTION)
				game.CraftingSystem.craft(game, game.crafting_selected)
	else:
		var recipe_index: int = game.crafting_recipe_at(position)
		if recipe_index >= 0:
			game.crafting_selected = recipe_index
			game.UiFeedbackSystem.focus(game, "craft_recipe:%d" % recipe_index)
	game.queue_redraw()
	return true


## Выделяет заголовок таблицы тёмной полосой с тонким золотым кантом и достаточным внутренним полем.
static func draw_table_header(game: Node, rect: Rect2) -> void:
	game.draw_rect(rect.grow(-1), Color("694627"))
	game.draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2), Color("ba965a"), 1)
	game.draw_line(Vector2(rect.position.x + 2, rect.end.y - 2), rect.end - Vector2(2, 2), Color("49301f"), 1)

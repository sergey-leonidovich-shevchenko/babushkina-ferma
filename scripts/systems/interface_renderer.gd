extends RefCounted

const VIEWPORT := Rect2(0, 0, 1152, 648)
const INVENTORY_FILTERS := ["all", "tool", "food", "equipment", "resource", "quest"]
const HUD_RECT := Rect2(0, 0, 1152, 74)
const PLAYER_BARS_RECT := Rect2(212, 9, 364, 51)
const LOCATION_BADGE := Rect2(588, 9, 390, 51)
const INVENTORY_WINDOW := Rect2(18, 18, 1116, 616)
const INVENTORY_GRID_ORIGIN := Vector2(56, 166)
const INVENTORY_SLOT_SIZE := Vector2(80, 54)
const INVENTORY_SLOT_PITCH := Vector2(88, 59)
const INVENTORY_HOTBAR_ORIGIN := Vector2(226, 548)
const INVENTORY_HOTBAR_SIZE := Vector2(66, 56)
const INVENTORY_HOTBAR_PITCH := 70.0
const USE_BUTTON := Rect2(622, 406, 88, 36)
const EQUIP_BUTTON := Rect2(716, 406, 88, 36)
const DROP_BUTTON := Rect2(622, 448, 182, 32)
const SORT_BUTTON := Rect2(914, 111, 166, 38)
const SKILL_BUTTON := Rect2(986, 10, 72, 50)
const QUEST_BUTTON := Rect2(1066, 10, 72, 50)
const PAUSE_BUTTON := Rect2(18, 584, 54, 54)
const DODGE_BUTTON := Rect2(1004, 520, 60, 48)
const BLOCK_BUTTON := Rect2(1072, 520, 60, 48)
const HOTBAR_ORIGIN := Vector2(279, 584)
const HOTBAR_SLOT_SIZE := Vector2(54, 54)
const HOTBAR_PITCH := 60.0
const STORAGE_LEFT_ROWS := Rect2(96, 168, 430, 320)
const STORAGE_RIGHT_ROWS := Rect2(626, 168, 430, 320)
const STORAGE_TRANSFER_ONE := Rect2(454, 494, 116, 36)
const STORAGE_TRANSFER_ALL := Rect2(582, 494, 116, 36)
const FORGE_ROWS := Rect2(164, 154, 824, 396)
const CONTRACT_ROWS := Rect2(154, 190, 844, 300)
const QUEST_PREV := Rect2(170, 526, 54, 34)
const QUEST_NEXT := Rect2(622, 526, 54, 34)

const INK := Color("f8f1dc")
const MUTED := Color("b9c8b8")
const PANEL := Color(0.055, 0.09, 0.08, 0.96)
const PANEL_INNER := Color("203b35")
const WOOD := Color("78563b")
const PARCHMENT := Color("e8d7aa")
const GOLD := Color("efc766")


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_slot_rect(visible_index: int) -> Rect2:
	var column := visible_index % 6
	var row := visible_index / 6
	return Rect2(INVENTORY_GRID_ORIGIN + Vector2(column * INVENTORY_SLOT_PITCH.x, row * INVENTORY_SLOT_PITCH.y), INVENTORY_SLOT_SIZE)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_slot_at(point: Vector2, scroll_row: int, slot_count: int) -> int:
	for visible_index in 30:
		if inventory_slot_rect(visible_index).has_point(point):
			return mini(scroll_row * 6 + visible_index, slot_count - 1)
	return -1


## Возвращает реальный индекс предмета с учётом активной вкладки и прокрутки.
static func inventory_slot_at_game(game: Node, point: Vector2) -> int:
	var indices: Array[int] = game.InventorySystem.filtered_indices(game)
	for visible_index in game.InventorySystem.VISIBLE_SLOTS:
		if inventory_slot_rect(visible_index).has_point(point):
			var position: int = game.inventory_scroll_row * game.InventorySystem.COLUMNS + visible_index
			return indices[position] if position < indices.size() else -1
	return -1


## Возвращает прямоугольник одной вкладки категорий деревянного рюкзака.
static func inventory_category_rect(index: int) -> Rect2:
	return Rect2(54 + index * 91, 111, 86, 38)


## Определяет выбранную указателем категорию или возвращает пустую строку.
static func inventory_category_at(point: Vector2) -> String:
	for index in INVENTORY_FILTERS.size():
		if inventory_category_rect(index).has_point(point): return INVENTORY_FILTERS[index]
	return ""


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_hotbar_rect(index: int) -> Rect2:
	return Rect2(INVENTORY_HOTBAR_ORIGIN + Vector2(index * INVENTORY_HOTBAR_PITCH, 0), INVENTORY_HOTBAR_SIZE)


## Выполняет операцию «инвентаря быстрой панели at» и возвращает результат согласно контракту метода.
static func inventory_hotbar_at(point: Vector2) -> int:
	for index in 10:
		if inventory_hotbar_rect(index).has_point(point): return index
	return -1


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func hotbar_rect(index: int) -> Rect2:
	return Rect2(HOTBAR_ORIGIN + Vector2(index * HOTBAR_PITCH, 0), HOTBAR_SLOT_SIZE)


## Выполняет операцию «быстрой панели at» и возвращает результат согласно контракту метода.
static func hotbar_at(point: Vector2) -> int:
	for index in 10:
		if hotbar_rect(index).has_point(point): return index
	return -1


## Координирует отрисовку текущего состояния без изменения игровой логики.
static func draw(game: Node) -> void:
	draw_hud(game)
	game.draw_mission_tracker()
	if game.tutorial_visible and game.tutorial_step < game.tutorial_steps.size():
		panel(game, Rect2(18, 88, 405, 64), PANEL)
		game.draw_string(game.UI_FONT, Vector2(32, 110), game.LocaleSystem.ui("tutorial", [game.tutorial_step + 1, game.tutorial_steps.size()]), HORIZONTAL_ALIGNMENT_LEFT, 375, 12, Color("9ed6b3"))
		game.draw_string(game.UI_FONT, Vector2(32, 137), game.LocaleSystem.tutorial(game.tutorial_steps[game.tutorial_step].event), HORIZONTAL_ALIGNMENT_LEFT, 375, 15, INK)
	game.draw_discovery_card()
	if game.shop_open: game.draw_shop()
	if game.inventory_open: draw_inventory(game)
	if game.crafting_open: game.draw_crafting_window()
	if game.storage_open: game.draw_storage_window()
	if game.forge_open: game.draw_forge_window()
	if game.contract_open: game.ContractRenderer.draw(game)
	if game.quest_log_open: game.draw_quest_log()
	if game.skill_menu_open: game.draw_skill_menu()


## Отрисовывает HUD по текущему состоянию игры.
static func draw_hud(game: Node) -> void:
	game.draw_rect(HUD_RECT, Color(0.035, 0.065, 0.06, 0.94))
	game.draw_line(Vector2(0, 73), Vector2(1152, 73), Color("456456"), 2)
	var hours := floori(game.game_minutes / 60.0)
	var minutes := int(game.game_minutes) % 60
	panel(game, Rect2(14, 9, 182, 51), Color("29463d"))
	game.draw_string(game.UI_FONT, Vector2(26, 31), game.LocaleSystem.ui("day", [game.day, hours, minutes]), HORIZONTAL_ALIGNMENT_LEFT, 158, 16, Color("ffe39d"))
	game.draw_string(game.UI_FONT, Vector2(26, 50), "🪙 %d" % game.coins, HORIZONTAL_ALIGNMENT_LEFT, 158, 12, INK)
	game.draw_string(game.UI_FONT, Vector2(26, 62), game.WorldEventSystem.hud_text(game), HORIZONTAL_ALIGNMENT_LEFT, 170, 9, Color("bfe1c4"))
	draw_bar(game, Rect2(212, 12, 176, 18), float(game.player_hp) / game.player_max_hp, "HP %d/%d" % [game.player_hp, game.player_max_hp], Color("d75b59"))
	var xp_needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	draw_bar(game, Rect2(400, 12, 176, 18), float(game.player_xp) / xp_needed, "LV %d  XP %d/%d" % [game.player_level, game.player_xp, xp_needed], Color("5796d6"))
	draw_bar(game, Rect2(212, 39, 176, 18), float(game.player_mana) / game.player_max_mana, game.LocaleSystem.ui("mana_label", [game.player_mana, game.player_max_mana]), Color("666fda"))
	var stamina_max: int = game.SkillSystem.max_stamina(game)
	draw_bar(game, Rect2(400, 39, 176, 18), float(game.energy) / stamina_max, game.LocaleSystem.ui("stamina_label", [game.energy, stamina_max]), Color("dfa943"))
	var effects: Array[String] = []
	if game.regeneration_timer > 0.0: effects.append("❤ %.0fs" % game.regeneration_timer)
	if game.strength_timer > 0.0: effects.append("⚔ %.0fs" % game.strength_timer)
	if game.speed_timer > 0.0: effects.append("➜ %.0fs" % game.speed_timer)
	if game.invisibility_timer > 0.0: effects.append("◉ %.0fs" % game.invisibility_timer)
	if game.defense_timer > 0.0: effects.append("◆ %.0fs" % game.defense_timer)
	if not game.active_companions.is_empty(): effects.append(game.LocaleSystem.ui("companion_command", [game.LocaleSystem.ui("companion_command_%s" % game.state.player.companion_command)]))
	panel(game, LOCATION_BADGE, Color("203b35"))
	game.draw_string(game.UI_FONT, LOCATION_BADGE.position + Vector2(12, 23), location_icon(game.current_location), HORIZONTAL_ALIGNMENT_CENTER, 28, 19, Color("efc766"))
	game.draw_string(game.UI_FONT, LOCATION_BADGE.position + Vector2(43, 22), game.LocaleSystem.ui("location_label", [game.WorldSystem.name(game.current_location)]), HORIZONTAL_ALIGNMENT_CENTER, 334, 15, INK)
	game.draw_string(game.UI_FONT, LOCATION_BADGE.position + Vector2(12, 43), "  ".join(effects), HORIZONTAL_ALIGNMENT_CENTER, 366, 12, Color("a9dfb8"))
	draw_header_button(game, SKILL_BUTTON, "K", game.skill_points)
	draw_header_button(game, QUEST_BUTTON, "J", 0)
	if game.state.fishing.phase == game.FishingSystem.PHASE_WAITING: game.draw_string(game.UI_FONT, Vector2(446, 115), "%.1f" % maxf(game.state.fishing.timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif game.state.fishing.phase == game.FishingSystem.PHASE_BITE:
		game.draw_circle(Vector2(576, 105), 20 + sin(Time.get_ticks_msec() / 100.0) * 3, GOLD)
		game.draw_string(game.UI_FONT, Vector2(566, 112), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, Color("47351f"))
	if not game.message.is_empty():
		panel(game, Rect2(286, 544, 580, 30), Color(0.04, 0.08, 0.07, 0.9))
		game.draw_string(game.UI_FONT, Vector2(300, 565), game.message, HORIZONTAL_ALIGNMENT_CENTER, 552, 14, INK)
	panel(game, PAUSE_BUTTON, Color("29463d"))
	game.draw_string(game.UI_FONT, PAUSE_BUTTON.position + Vector2(4, 35), "Ⅱ", HORIZONTAL_ALIGNMENT_CENTER, PAUSE_BUTTON.size.x - 8, 22, Color("ffe39d"))
	draw_action_button(game, DODGE_BUTTON, game.LocaleSystem.ui("dodge_short"), game.state.player.dodge_cooldown <= 0.0 and game.energy >= 2)
	draw_action_button(game, BLOCK_BUTTON, game.LocaleSystem.ui("block_short"), game.energy > 0)
	draw_hotbar(game)


## Возвращает компактный символ типа активной внешней зоны или интерьера.
static func location_icon(location: String) -> String:
	return {
		"overworld":"⌂", "forest":"♣", "rocky":"▲", "ruins":"⚔", "cave":"◆", "cursed":"☠", "glassworks":"✦",
		"cottage_interior":"⌂", "shop_interior":"$", "guild_interior":"⚜", "forge_interior":"◆", "chapel_interior":"✦",
		"prison_interior":"▦", "tower_interior":"✧", "castle_hall":"♜", "castle_upper":"♜", "castle_dungeon":"▦",
	}.get(location, "●")


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_bar(game: Node, rect: Rect2, ratio: float, label: String, color: Color) -> void:
	game.draw_rect(rect, Color("17231f"))
	game.draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2((rect.size.x - 4) * clampf(ratio, 0.0, 1.0), rect.size.y - 4)), color)
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, 14), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 11, Color.WHITE)


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_header_button(game: Node, rect: Rect2, key: String, badge: int) -> void:
	panel(game, rect, Color("29463d"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, 32), key, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 18, Color("ffe39d"))
	if badge > 0:
		game.draw_circle(rect.position + Vector2(rect.size.x - 8, 8), 9, Color("db6a52"))
		game.draw_string(game.UI_FONT, rect.position + Vector2(rect.size.x - 14, 13), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 12, 10, Color.WHITE)


## Отрисовывает быстрой панели по текущему состоянию игры.
static func draw_hotbar(game: Node) -> void:
	for index in 10:
		var rect: Rect2 = hotbar_rect(index)
		var selected: bool = index == game.selected_hotbar
		panel(game, rect, GOLD if selected else Color("314e44"))
		game.draw_rect(rect.grow(-4), Color("f4dfaa") if selected else Color("1e332d"))
		var kind: String = game.hotbar_slots[index]
		game.draw_item_icon(kind, Rect2(rect.position + Vector2(12, 8), Vector2(32, 32)))
		game.draw_string(game.UI_FONT, rect.position + Vector2(4, 14), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, 12, 10, Color("493726") if selected else MUTED)
		if not kind.is_empty() and game.inventory_item_count(kind) > 1:
			game.draw_string(game.UI_FONT, rect.position + Vector2(28, 48), str(game.inventory_item_count(kind)), HORIZONTAL_ALIGNMENT_RIGHT, 20, 10, Color("493726") if selected else INK)


## Отрисовывает инвентаря по текущему состоянию игры.
static func draw_inventory(game: Node) -> void:
	game.draw_rect(VIEWPORT, Color(0.015, 0.025, 0.02, 0.72))
	draw_wood_frame(game, INVENTORY_WINDOW)
	game.draw_rect(Rect2(34, 32, 1084, 66), Color("684026")); game.draw_rect(Rect2(40, 38, 1072, 54), WOOD)
	game.draw_string(game.UI_FONT, Vector2(62, 76), game.LocaleSystem.ui("inventory"), HORIZONTAL_ALIGNMENT_LEFT, 500, 27, Color("fff0bd"))
	var occupied: int = game.inventory_slots.filter(func(kind): return not String(kind).is_empty() and game.inventory_item_count(kind) > 0).size()
	game.draw_string(game.UI_FONT, Vector2(548, 74), game.LocaleSystem.ui("inventory_capacity", [occupied, game.inventory_slots.size()]), HORIZONTAL_ALIGNMENT_CENTER, 230, 13, Color("f7d989"))
	draw_action_button(game, SORT_BUTTON, game.LocaleSystem.ui("sort_inventory"), true)
	game.draw_string(game.UI_FONT, Vector2(876, 75), game.LocaleSystem.ui("close_inventory"), HORIZONTAL_ALIGNMENT_RIGHT, 212, 12, Color("ead5aa"))
	draw_category_tabs(game)
	panel(game, Rect2(44, 156, 548, 326), PARCHMENT)
	var filtered: Array[int] = game.InventorySystem.filtered_indices(game)
	var first_visible: int = game.inventory_scroll_row * game.InventorySystem.COLUMNS
	for visible_index in game.InventorySystem.VISIBLE_SLOTS:
		var position: int = first_visible + visible_index
		if position >= filtered.size(): break
		draw_inventory_slot(game, filtered[position], visible_index)
	draw_scrollbar(game)
	draw_item_detail(game)
	draw_equipment(game)
	game.draw_string(game.UI_FONT, Vector2(226, 536), game.LocaleSystem.ui("quick_access"), HORIZONTAL_ALIGNMENT_CENTER, 696, 12, Color("f6d58b"))
	for index in 10: draw_inventory_hotbar_slot(game, index)
	draw_action_button(game, USE_BUTTON, game.LocaleSystem.ui("eat"), game.InventorySystem.can_use(selected_kind(game)))
	draw_action_button(game, EQUIP_BUTTON, game.LocaleSystem.ui("equip"), game.InventorySystem.can_equip(selected_kind(game)))
	draw_action_button(game, DROP_BUTTON, "X • %s" % game.LocaleSystem.ui("drop_item"), not selected_kind(game).is_empty())
	game.draw_string(game.UI_FONT, Vector2(72, 624), game.LocaleSystem.ui("inventory_help"), HORIZONTAL_ALIGNMENT_CENTER, 1008, 10, Color("e4c993"))


## Рисует шесть интерактивных вкладок категорий с крупным состоянием фокуса.
static func draw_category_tabs(game: Node) -> void:
	var symbols := ["▦", "⚒", "●", "♜", "◆", "!"]
	for index in game.InventorySystem.FILTERS.size():
		var filter_id: String = game.InventorySystem.FILTERS[index]; var active: bool = game.inventory_filter == filter_id; var rect: Rect2 = inventory_category_rect(index)
		game.draw_rect(rect, GOLD if active else Color("6a452a")); game.draw_rect(rect.grow(-3), Color("5f7545") if active else Color("b9864d"))
		game.draw_string(game.UI_FONT, rect.position + Vector2(5, 16), symbols[index], HORIZONTAL_ALIGNMENT_CENTER, 18, 14, Color("fff3c4"))
		var label: String = game.LocaleSystem.ui("inventory_all") if filter_id == "all" else game.LocaleSystem.ui("category_" + filter_id)
		game.draw_string(game.UI_FONT, rect.position + Vector2(22, 24), label, HORIZONTAL_ALIGNMENT_CENTER, 59, 8, Color("fff3c4"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_inventory_slot(game: Node, index: int, visible_index: int) -> void:
	var rect: Rect2 = inventory_slot_rect(visible_index)
	var selected: bool = index == game.inventory_selected
	var moving: bool = index == game.inventory_move_from
	game.draw_rect(rect, GOLD if selected else Color("567064"))
	game.draw_rect(rect.grow(-3), Color("cce6bd") if moving else (Color("ffe8a4") if selected else Color("ead6a4")))
	var kind: String = game.inventory_slots[index]
	if kind.is_empty() or game.inventory_item_count(kind) <= 0: return
	game.draw_item_icon(kind, Rect2(rect.position + Vector2(17, 8), Vector2(44, 40)))
	game.draw_string(game.UI_FONT, rect.position + Vector2(48, 49), "×%d" % game.inventory_item_count(kind), HORIZONTAL_ALIGNMENT_RIGHT, 26, 10, Color("473726"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_scrollbar(game: Node) -> void:
	var total_rows := ceili(float(game.InventorySystem.filtered_indices(game).size()) / game.InventorySystem.COLUMNS)
	var track := Rect2(580, 166, 6, 294)
	game.draw_rect(track, Color("385047"))
	var thumb_height := maxf(30.0, track.size.y * game.InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, game.InventorySystem.VISIBLE_ROWS)))
	var ratio := float(game.inventory_scroll_row) / float(maxi(game.InventorySystem.max_scroll_row(game), 1))
	game.draw_rect(Rect2(track.position + Vector2(0, (track.size.y - thumb_height) * ratio), Vector2(6, thumb_height)), GOLD)
	game.draw_string(game.UI_FONT, Vector2(488, 476), game.LocaleSystem.ui("row", [game.inventory_scroll_row + 1, maxi(total_rows - game.InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 98, 9, Color("70492d"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func selected_kind(game: Node) -> String:
	if game.inventory_selected < 0 or game.inventory_selected >= game.inventory_slots.size(): return ""
	return game.inventory_slots[game.inventory_selected]


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_item_detail(game: Node) -> void:
	var rect := Rect2(610, 156, 202, 326)
	panel(game, rect, PARCHMENT)
	var kind := selected_kind(game)
	if kind.is_empty():
		game.draw_string(game.UI_FONT, Vector2(630, 300), game.LocaleSystem.ui("empty_slot"), HORIZONTAL_ALIGNMENT_CENTER, 166, 14, MUTED)
		return
	var item: Dictionary = game.InventorySystem.data(kind)
	game.draw_item_icon(kind, Rect2(674, 168, 76, 76))
	game.draw_string(game.UI_FONT, Vector2(624, 265), item.name, HORIZONTAL_ALIGNMENT_CENTER, 174, 16, Color("4b3425"))
	var category: String = game.LocaleSystem.ui("category_" + game.InventorySystem.category(kind))
	game.draw_string(game.UI_FONT, Vector2(626, 287), category, HORIZONTAL_ALIGNMENT_CENTER, 174, 10, Color("688052"))
	game.draw_line(Vector2(630, 298), Vector2(792, 298), Color("a98755"), 1)
	game.draw_string(game.UI_FONT, Vector2(630, 320), game.LocaleSystem.ui("quantity", [game.inventory_item_count(kind)]), HORIZONTAL_ALIGNMENT_LEFT, 166, 12, Color("4b3425"))
	game.draw_multiline_string(game.UI_FONT, Vector2(630, 344), game.LocaleSystem.ui(game.InventorySystem.detail_key(kind)), HORIZONTAL_ALIGNMENT_LEFT, 166, 11, 2, Color("765a3c"))
	game.draw_string(game.UI_FONT, Vector2(630, 394), game.LocaleSystem.ui("sell_value", [game.ShopSystem.sell_price(kind)]), HORIZONTAL_ALIGNMENT_LEFT, 166, 11, Color("775226"))


## Отрисовывает экипировки по текущему состоянию игры.
static func draw_equipment(game: Node) -> void:
	panel(game, Rect2(830, 156, 278, 326), PARCHMENT)
	game.draw_string(game.UI_FONT, Vector2(846, 184), game.LocaleSystem.ui("equipment"), HORIZONTAL_ALIGNMENT_CENTER, 246, 17, Color("4b3425"))
	game.draw_texture_rect_region(game.FARMER_SHEET, Rect2(920, 210, 98, 154), Rect2(20, 8, 24, 46))
	var slots := ["head", "body", "legs", "hands", "offhand", "ring"]
	for index in slots.size():
		var left := index % 2 == 0
		var rect := Rect2(846 if left else 1034, 198 + (index / 2) * 88, 58, 64)
		var slot_name: String = slots[index]
		game.draw_rect(rect, Color("9b7749"))
		game.draw_rect(rect.grow(-3), Color("e3d3a7"))
		game.draw_string(game.UI_FONT, rect.position + Vector2(3, 15), game.LocaleSystem.ui(slot_name), HORIZONTAL_ALIGNMENT_CENTER, 58, 9, Color("59452f"))
		var kind: String = game.equipment[slot_name]
		if not kind.is_empty(): game.draw_item_icon(kind, Rect2(rect.position + Vector2(14, 22), Vector2(38, 38)))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_inventory_hotbar_slot(game: Node, index: int) -> void:
	var rect: Rect2 = inventory_hotbar_rect(index)
	var selected: bool = index == game.selected_hotbar
	game.draw_rect(rect, GOLD if selected else Color("567064"))
	game.draw_rect(rect.grow(-3), Color("ffe5a0") if selected else Color("c59051"))
	game.draw_item_icon(game.hotbar_slots[index], Rect2(rect.position + Vector2(14, 8), Vector2(40, 40)))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, 13), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, 10, 9, Color("493726") if selected else MUTED)


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_action_button(game: Node, rect: Rect2, label: String, enabled: bool) -> void:
	game.draw_rect(rect, Color("668d68") if enabled else Color("3f5049"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(5, 30), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10, 11, Color.WHITE if enabled else Color("87958c"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func panel(game: Node, rect: Rect2, color: Color) -> void:
	game.draw_rect(rect, Color(0.02, 0.035, 0.03, 0.95))
	game.draw_rect(rect.grow(-3), color)


## Рисует многослойную деревянную раму с латунными уголками и прожилками.
static func draw_wood_frame(game: Node, rect: Rect2) -> void:
	game.draw_rect(rect, Color("3b2419")); game.draw_rect(rect.grow(-5), Color("9b663b")); game.draw_rect(rect.grow(-13), Color("53331f"))
	for y in range(int(rect.position.y + 18), int(rect.end.y - 12), 22): game.draw_line(Vector2(rect.position.x + 14, y), Vector2(rect.end.x - 14, y), Color(0.25, 0.12, 0.06, 0.28), 1)
	for corner in [rect.position + Vector2(9,9), Vector2(rect.end.x - 9, rect.position.y + 9), Vector2(rect.position.x + 9, rect.end.y - 9), rect.end - Vector2(9,9)]:
		game.draw_circle(corner, 8, Color("d7aa45")); game.draw_circle(corner, 3, Color("76502a"))

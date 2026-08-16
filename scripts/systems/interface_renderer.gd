extends RefCounted

const VIEWPORT := Rect2(0, 0, 1152, 648)
const INVENTORY_SKIN := preload("res://assets/game/ui/inventory_grandmother_skin.png")
const HUD_PORTRAIT_FRAME := preload("res://assets/game/ui/hud/grandmother_hud_portrait_v2.tres")
const HUD_STATUS_FRAME := preload("res://assets/game/ui/hud/grandmother_hud_status_v2.tres")
const HUD_CLOCK_FRAME := preload("res://assets/game/ui/hud/grandmother_hud_clock_v2.tres")
const HUD_LOCATION_FRAME := preload("res://assets/game/ui/hud/grandmother_hud_location_v2.tres")
const HUD_SKILL_BUTTON := preload("res://assets/game/ui/hud/grandmother_hud_skill_v2.tres")
const HUD_QUEST_BUTTON := preload("res://assets/game/ui/hud/grandmother_hud_quest_v2.tres")
const HUD_SKILL_ICON := preload("res://assets/game/ui/hud/grandmother_hud_skill_icon_v2.png")
const HUD_QUEST_ICON := preload("res://assets/game/ui/hud/grandmother_hud_quest_icon_v2.png")
const CONTROL_ATLAS := preload("res://assets/game/ui/controls/control_atlas.png")
const CARD_ATLAS := preload("res://assets/game/ui/cards/card_atlas.png")
const HudRenderer := preload("res://scripts/systems/hud_renderer.gd")
const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const StoryUiRenderer := preload("res://scripts/systems/story_ui_renderer.gd")
const WEATHER_ICONS := {
	"clear":preload("res://assets/game/ui/hud/weather_clear.tres"),
	"rain":preload("res://assets/game/ui/hud/weather_rain.tres"),
	"wind":preload("res://assets/game/ui/hud/weather_wind.tres"),
	"snow":preload("res://assets/game/ui/hud/weather_snow.tres"),
	"storm":preload("res://assets/game/ui/hud/weather_storm.tres"),
}
const INVENTORY_FILTERS := ["all", "tool", "food", "equipment", "resource", "quest"]
const HUD_RECT := Rect2(0, 0, 1152, 96)
const PLAYER_PORTRAIT_RECT := Rect2(0, 0, 165, 96)
const PLAYER_BARS_RECT := Rect2(165, 0, 321, 96)
const CLOCK_BADGE := Rect2(486, 0, 184, 96)
const CLOCK_WEATHER_RECT := Rect2(510, 26, 28, 28)
const CLOCK_TIME_RECT := Rect2(538, 25, 105, 34)
const CLOCK_CALENDAR_RECT := Rect2(505, 63, 145, 16)
const LOCATION_BADGE := Rect2(670, 0, 267, 96)
const INVENTORY_WINDOW := Rect2(88, 7, 976, 634)
const INVENTORY_GRID_ORIGIN := Vector2(149, 164)
const INVENTORY_SLOT_SIZE := Vector2(57, 50)
const INVENTORY_SLOT_PITCH := Vector2(65.5, 58.0)
const INVENTORY_HOTBAR_ORIGIN := Vector2(207, 543)
const INVENTORY_HOTBAR_SIZE := Vector2(66, 65)
const INVENTORY_HOTBAR_PITCH := 73.4
const INVENTORY_HOTBAR_SKIN_RECT := Rect2(190, 532, 762, 84)
const WORLD_HOTBAR_PANEL := Rect2(190, 558, 762, 84)
const USE_BUTTON := Rect2(580, 430, 195, 31)
const EQUIP_BUTTON := Rect2(580, 469, 94, 29)
const DROP_BUTTON := Rect2(680, 469, 95, 29)
const SORT_BUTTON := Rect2(649, 90, 175, 42)
const SKILL_BUTTON := Rect2(937, 0, 102, 96)
const QUEST_BUTTON := Rect2(1039, 0, 113, 96)
const PAUSE_BUTTON := Rect2(18, 584, 54, 54)
const DODGE_BUTTON := Rect2(1004, 520, 60, 48)
const BLOCK_BUTTON := Rect2(1072, 520, 60, 48)
const MESSAGE_CARD := Rect2(286, 490, 580, 66)
const TUTORIAL_CARD := Rect2(18, 106, 405, 102)
const INTERACTION_PROMPT := Rect2(840, 438, 294, 58)
const HOTBAR_ORIGIN := Vector2(207, 568)
const HOTBAR_SLOT_SIZE := INVENTORY_HOTBAR_SIZE
const HOTBAR_PITCH := INVENTORY_HOTBAR_PITCH
const STORAGE_LEFT_ROWS := Rect2(96, 190, 430, 320)
const STORAGE_RIGHT_ROWS := Rect2(626, 190, 430, 320)
const STORAGE_TRANSFER_ONE := Rect2(454, 520, 116, 36)
const STORAGE_TRANSFER_ALL := Rect2(582, 520, 116, 36)
const FORGE_ROWS := Rect2(164, 154, 824, 396)
const CONTRACT_ROWS := Rect2(154, 190, 844, 300)
const QUEST_PREV := StoryUiRenderer.QUEST_PREV
const QUEST_NEXT := StoryUiRenderer.QUEST_NEXT

const INK := Color("f8f1dc")
const MUTED := Color("b9c8b8")
const PANEL := Color(0.055, 0.09, 0.08, 0.96)
const PANEL_INNER := Color("203b35")
const WOOD := Color("78563b")
const GOLD := Color("efc766")

# Области исходных атласов хранятся рядом с геометрией HUD: так рисунок действительно
# режется на независимые спрайты, а не показывается одной готовой картинкой.
const CONTROL_PAUSE_SOURCE := Rect2(25, 45, 280, 250)
const CONTROL_DODGE_SOURCES := [Rect2(18, 382, 288, 278), Rect2(329, 382, 288, 278), Rect2(642, 382, 288, 278)]
const CONTROL_BLOCK_SOURCES := [Rect2(18, 690, 288, 286), Rect2(329, 690, 288, 286), Rect2(642, 690, 288, 286)]
const CARD_MESSAGE_SOURCE := Rect2(36, 206, 650, 260)
const CARD_TUTORIAL_SOURCE := Rect2(714, 122, 492, 398)
const CARD_DISCOVERY_SOURCE := Rect2(86, 646, 470, 456)
const CARD_QUEST_SOURCE := Rect2(710, 646, 476, 470)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_slot_rect(visible_index: int) -> Rect2:
	var column := visible_index % 6
	var row := visible_index / 6
	return Rect2(INVENTORY_GRID_ORIGIN + Vector2(column * INVENTORY_SLOT_PITCH.x, row * INVENTORY_SLOT_PITCH.y), INVENTORY_SLOT_SIZE)


## Центрирует содержимое внутри контейнера как CSS flex с выравниванием по обеим осям.
static func centered_rect(container: Rect2, size: Vector2) -> Rect2:
	return Rect2(container.get_center() - size * 0.5, size)


## Возвращает одинаково центрированную область иконки для любой из тридцати шести ячеек рюкзака.
static func inventory_icon_rect(visible_index: int) -> Rect2:
	return centered_rect(inventory_slot_rect(visible_index), Vector2(40, 40))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_slot_at(point: Vector2, scroll_row: int, slot_count: int) -> int:
	for visible_index in 36:
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
	return Rect2(146 + index * 79, 90, 75, 44)


## Определяет выбранную указателем категорию или возвращает пустую строку.
static func inventory_category_at(point: Vector2) -> String:
	for index in INVENTORY_FILTERS.size():
		if inventory_category_rect(index).has_point(point): return INVENTORY_FILTERS[index]
	return ""


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_hotbar_rect(index: int) -> Rect2:
	return Rect2(INVENTORY_HOTBAR_ORIGIN + Vector2(index * INVENTORY_HOTBAR_PITCH, 0), INVENTORY_HOTBAR_SIZE)


## Центрирует иконку быстрого доступа в рамке тем же flex-правилом, что и основную сетку.
static func hotbar_icon_rect(rect: Rect2) -> Rect2:
	return centered_rect(rect, Vector2(43, 43))


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
	var clean_hud_preview := game.has_meta("capture_hud_clean")
	if not clean_hud_preview and not game.AdventurePolishSystem.has_modal(game): game.draw_mission_tracker()
	if not clean_hud_preview and game.tutorial_visible and game.tutorial_step < game.tutorial_steps.size():
		game.StoryUiRenderer.draw_tutorial(game)
	if not clean_hud_preview and not game.AdventurePolishSystem.has_modal(game): game.draw_discovery_card()
	HudRenderer.draw_interaction_prompt(game, game.InterfaceRenderer)
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
	HudRenderer.draw(game, game.InterfaceRenderer)


## Рисует единый верхний фон из того же деревянного скина, что и инвентарь.
static func draw_hud_background(game: Node) -> void:
	var modules := [
		[HUD_PORTRAIT_FRAME, PLAYER_PORTRAIT_RECT], [HUD_STATUS_FRAME, PLAYER_BARS_RECT],
		[HUD_CLOCK_FRAME, CLOCK_BADGE], [HUD_LOCATION_FRAME, LOCATION_BADGE],
		[HUD_SKILL_BUTTON, SKILL_BUTTON], [HUD_QUEST_BUTTON, QUEST_BUTTON],
	]
	for module in modules:
		game.draw_texture_rect(module[0], module[1], false)


## Возвращает компактный символ типа активной внешней зоны или интерьера.
static func location_icon(location: String) -> String:
	return {
		"overworld":"⌂", "forest":"♣", "rocky":"▲", "ruins":"⚔", "cave":"◆", "cursed":"☠", "glassworks":"✦",
		"cottage_interior":"⌂", "shop_interior":"$", "guild_interior":"⚜", "forge_interior":"◆", "chapel_interior":"✦",
		"prison_interior":"▦", "tower_interior":"✧", "castle_hall":"♜", "castle_upper":"♜", "castle_dungeon":"▦",
	}.get(location, "●")


## Возвращает вырезанную из погодного атласа иконку либо безопасный солнечный вариант.
static func weather_icon(weather: String) -> Texture2D:
	return WEATHER_ICONS.get(weather, WEATHER_ICONS.clear)


## Подсчитывает активные сюжетные и побочные задания для бейджа нарисованного свитка.
static func active_quest_count(game: Node) -> int:
	var count := 1 if game.quest_active and not game.quest_complete else 0
	for state in game.mission_states.values():
		if state == "active": count += 1
	return count


## Рисует игровую панель из того же участка деревянного скина и тех же слотов, что используются в рюкзаке.
static func draw_hotbar(game: Node) -> void:
	var skin_size: Vector2 = INVENTORY_SKIN.get_size()
	var source_scale := Vector2(skin_size.x / VIEWPORT.size.x, skin_size.y / VIEWPORT.size.y)
	var source_rect := Rect2(INVENTORY_HOTBAR_SKIN_RECT.position * source_scale, INVENTORY_HOTBAR_SKIN_RECT.size * source_scale)
	game.draw_texture_rect_region(INVENTORY_SKIN, WORLD_HOTBAR_PANEL, source_rect)
	for index in 10:
		draw_hotbar_slot(game, hotbar_rect(index), index)
	var kind: String = game.hotbar_slots[game.selected_hotbar]
	if not kind.is_empty():
		game.draw_rect(Rect2(430, 550, 292, 24), Color(0.16, 0.08, 0.035, 0.92))
		game.draw_string(game.UI_FONT, Vector2(440, 567), game.InventorySystem.data(kind).name, HORIZONTAL_ALIGNMENT_CENTER, 272, 11, Color("ffe4a2"))


## Отрисовывает инвентаря по текущему состоянию игры.
static func draw_inventory(game: Node) -> void:
	game.draw_rect(VIEWPORT, Color(0.015, 0.025, 0.02, 0.72))
	game.draw_texture_rect(INVENTORY_SKIN, VIEWPORT, false)
	draw_inventory_title(game, game.LocaleSystem.ui("backpack_column"), Rect2(456, 19, 240, 43), 27)
	var occupied: int = game.inventory_slots.filter(func(kind): return not String(kind).is_empty() and game.inventory_item_count(kind) > 0).size()
	game.draw_string(game.UI_FONT, Vector2(496, 77), "%d / ∞" % occupied, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color("f9df91"))
	draw_inventory_button_label(game, SORT_BUTTON, game.LocaleSystem.ui("sort_inventory"), true, Color("ffe8a8"))
	game.draw_string(game.UI_FONT, Vector2(992, 86), "×", HORIZONTAL_ALIGNMENT_CENTER, 34, 29, Color("ffe9a4"))
	draw_category_tabs(game)
	var filtered: Array[int] = game.InventorySystem.filtered_indices(game)
	var first_visible: int = game.inventory_scroll_row * game.InventorySystem.COLUMNS
	for visible_index in game.InventorySystem.VISIBLE_SLOTS:
		var position: int = first_visible + visible_index
		if position >= filtered.size(): break
		draw_inventory_slot(game, filtered[position], visible_index)
	draw_scrollbar(game)
	draw_item_detail(game)
	draw_equipment(game)
	draw_inventory_title(game, game.LocaleSystem.ui("quick_access").get_slice(" • ", 0), Rect2(437, 507, 278, 32), 13)
	for index in 10: draw_inventory_hotbar_slot(game, index)
	draw_inventory_button_label(game, USE_BUTTON, game.LocaleSystem.ui("eat"), game.InventorySystem.can_use(selected_kind(game)), Color("fff5c8"))
	draw_inventory_button_label(game, EQUIP_BUTTON, game.LocaleSystem.ui("equip"), game.InventorySystem.can_equip(selected_kind(game)), Color("fff5c8"))
	draw_inventory_button_label(game, DROP_BUTTON, game.LocaleSystem.ui("drop_item"), not selected_kind(game).is_empty(), Color("fff5c8"))


## Рисует надпись с пиксельной тенью поверх резной таблички инвентаря.
static func draw_inventory_title(game: Node, label: String, rect: Rect2, font_size: int) -> void:
	game.draw_string(game.UI_FONT, rect.position + Vector2(2, rect.size.y - 5 + 2), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("3a1c0f"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(0, rect.size.y - 5), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("fff0b3"))


## Накладывает только динамическую подпись и состояние доступности, сохраняя нарисованную кнопку скина.
static func draw_inventory_button_label(game: Node, rect: Rect2, label: String, enabled: bool, color: Color) -> void:
	if not enabled: game.draw_rect(rect.grow(-3), Color(0.12, 0.12, 0.1, 0.48))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, rect.size.y * 0.68), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 10, color if enabled else Color("a89f82"))


## Рисует шесть интерактивных вкладок категорий с крупным состоянием фокуса.
static func draw_category_tabs(game: Node) -> void:
	var symbols := ["▦", "⚒", "●", "♜", "◆", "!"]
	for index in game.InventorySystem.FILTERS.size():
		var filter_id: String = game.InventorySystem.FILTERS[index]; var active: bool = game.inventory_filter == filter_id; var rect: Rect2 = inventory_category_rect(index)
		UiKitSystem.draw_nine_patch(game, "tab_selected" if active else "tab_normal", rect)
		game.draw_string(game.UI_FONT, rect.position + Vector2(4, 17), symbols[index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 15, Color("ffe8a8"))
		var label: String = game.LocaleSystem.ui("inventory_all") if filter_id == "all" else game.LocaleSystem.ui("category_" + filter_id)
		game.draw_string(game.UI_FONT, rect.position + Vector2(4, 37), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 7, Color("fff1bd"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_inventory_slot(game: Node, index: int, visible_index: int) -> void:
	var rect: Rect2 = inventory_slot_rect(visible_index)
	var selected: bool = index == game.inventory_selected
	var moving: bool = index == game.inventory_move_from
	UiKitSystem.draw_slot(game, rect, selected)
	if moving: game.draw_rect(rect.grow(-8), Color(0.55, 0.76, 0.46, 0.30))
	var kind: String = game.inventory_slots[index]
	if kind.is_empty() or game.inventory_item_count(kind) <= 0: return
	game.draw_item_icon(kind, inventory_icon_rect(visible_index))
	game.draw_string(game.UI_FONT, rect.position + Vector2(31, 47), str(game.inventory_item_count(kind)), HORIZONTAL_ALIGNMENT_RIGHT, 22, 10, Color("3d281c"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_scrollbar(game: Node) -> void:
	var total_rows := ceili(float(game.InventorySystem.filtered_indices(game).size()) / game.InventorySystem.COLUMNS)
	var track := Rect2(542, 174, 7, 292)
	game.draw_texture_rect(UiKitSystem.texture("scrollbar"), Rect2(530, 164, 31, 312), false)
	var thumb_height := maxf(30.0, track.size.y * game.InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, game.InventorySystem.VISIBLE_ROWS)))
	var ratio := float(game.inventory_scroll_row) / float(maxi(game.InventorySystem.max_scroll_row(game), 1))
	game.draw_rect(Rect2(track.position + Vector2(0, (track.size.y - thumb_height) * ratio), Vector2(7, thumb_height)), Color("f2c55d"))
	game.draw_string(game.UI_FONT, Vector2(443, 496), game.LocaleSystem.ui("row", [game.inventory_scroll_row + 1, maxi(total_rows - game.InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 91, 8, Color("70492d"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func selected_kind(game: Node) -> String:
	if game.inventory_selected < 0 or game.inventory_selected >= game.inventory_slots.size(): return ""
	var kind: String = game.inventory_slots[game.inventory_selected]
	return kind if not kind.is_empty() and game.inventory_item_count(kind) > 0 else ""


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_item_detail(game: Node) -> void:
	var kind := selected_kind(game)
	if kind.is_empty():
		game.draw_string(game.UI_FONT, Vector2(580, 319), game.LocaleSystem.ui("empty_slot"), HORIZONTAL_ALIGNMENT_CENTER, 195, 14, Color("80684a"))
		return
	var item: Dictionary = game.InventorySystem.data(kind)
	game.draw_item_icon(kind, Rect2(641, 165, 74, 74))
	game.draw_string(game.UI_FONT, Vector2(579, 280), item.name, HORIZONTAL_ALIGNMENT_CENTER, 197, 16, Color("4b3425"))
	var category: String = game.LocaleSystem.ui("category_" + game.InventorySystem.category(kind))
	game.draw_string(game.UI_FONT, Vector2(580, 300), category, HORIZONTAL_ALIGNMENT_CENTER, 195, 9, Color("66804c"))
	game.draw_line(Vector2(583, 309), Vector2(772, 309), Color("a98755"), 1)
	game.draw_string(game.UI_FONT, Vector2(585, 329), game.LocaleSystem.ui("quantity", [game.inventory_item_count(kind)]), HORIZONTAL_ALIGNMENT_LEFT, 185, 11, Color("4b3425"))
	game.draw_multiline_string(game.UI_FONT, Vector2(585, 351), game.LocaleSystem.ui(game.InventorySystem.detail_key(kind)), HORIZONTAL_ALIGNMENT_LEFT, 185, 10, 2, Color("765a3c"))
	game.draw_string(game.UI_FONT, Vector2(585, 415), game.LocaleSystem.ui("sell_value", [game.ShopSystem.sell_price(kind)]), HORIZONTAL_ALIGNMENT_LEFT, 185, 10, Color("775226"))


## Отрисовывает экипировки по текущему состоянию игры.
static func draw_equipment(game: Node) -> void:
	game.draw_string(game.UI_FONT, Vector2(812, 181), game.LocaleSystem.ui("equipment"), HORIZONTAL_ALIGNMENT_CENTER, 194, 16, Color("4b3425"))
	var slots := ["head", "body", "legs", "hands", "offhand", "ring"]
	for index in slots.size():
		var left := index % 2 == 0
		var rect := Rect2(812 if left else 944, 190 + (index / 2) * 89, 59, 68)
		var slot_name: String = slots[index]
		game.draw_string(game.UI_FONT, rect.position + Vector2(3, 14), game.LocaleSystem.ui(slot_name), HORIZONTAL_ALIGNMENT_CENTER, 53, 8, Color("59452f"))
		var kind: String = game.equipment[slot_name]
		if not kind.is_empty(): game.draw_item_icon(kind, Rect2(rect.position + Vector2(11, 21), Vector2(38, 39)))


## Накладывает содержимое слота рюкзака через общий отрисовщик обеих быстрых панелей.
static func draw_inventory_hotbar_slot(game: Node, index: int) -> void:
	draw_hotbar_slot(game, inventory_hotbar_rect(index), index)


## Рисует единое динамическое содержимое быстрого слота поверх подготовленной деревянной рамки.
static func draw_hotbar_slot(game: Node, rect: Rect2, index: int) -> void:
	var selected: bool = index == game.selected_hotbar
	var kind: String = game.hotbar_slots[index]
	var count: int = game.inventory_item_count(kind) if not kind.is_empty() else 0
	UiKitSystem.draw_slot(game, rect, selected)
	if not kind.is_empty(): game.draw_item_icon(kind, hotbar_icon_rect(rect))
	if kind.is_empty() or count <= 0:
		game.draw_rect(rect.grow(-4), Color(0.10, 0.07, 0.05, 0.50))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, 14), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, 11, 9, Color("ffe7a0"))
	if not kind.is_empty() and count > 1:
		game.draw_string(game.UI_FONT, rect.position + Vector2(37, 59), str(count), HORIZONTAL_ALIGNMENT_RIGHT, 23, 9, Color("ffe7a0"))
	var readiness: float = hotbar_readiness(game, kind)
	if not kind.is_empty() and readiness < 1.0:
		game.draw_rect(Rect2(rect.position + Vector2(7, 58), Vector2(52, 4)), Color("3d2921"))
		game.draw_rect(Rect2(rect.position + Vector2(7, 58), Vector2(52 * readiness, 4)), Color("77ba62").lerp(Color("d75c47"), 1.0 - readiness))


## Возвращает готовность активного инструмента: энергия выступает его видимой шкалой состояния, оружие учитывает задержку удара.
static func hotbar_readiness(game: Node, kind: String) -> float:
	if kind.is_empty(): return 1.0
	var data: Dictionary = game.InventorySystem.data(kind)
	if data.get("weapon", false) or kind in ["sword", "bow", "iron_sword"]:
		return 1.0 - clampf(game.player_attack_timer / game.ATTACK_REPEAT_INTERVAL, 0.0, 1.0)
	if data.has("tool"):
		return clampf(float(game.energy) / game.SkillSystem.max_stamina(game), 0.0, 1.0)
	return 1.0


## Вырезает один независимый элемент общего атласа и масштабирует его в нужную область интерфейса.
static func draw_atlas_piece(game: Node, atlas: Texture2D, destination: Rect2, source: Rect2) -> void:
	game.draw_texture_rect_region(atlas, destination, source)


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func panel(game: Node, rect: Rect2, color: Color) -> void:
	game.draw_rect(rect, Color(0.02, 0.035, 0.03, 0.95))
	game.draw_rect(rect.grow(-3), color)

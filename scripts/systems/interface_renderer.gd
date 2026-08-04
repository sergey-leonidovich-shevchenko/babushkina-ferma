extends RefCounted

const VIEWPORT := Rect2(0, 0, 1152, 648)
const INVENTORY_SKIN := preload("res://assets/game/ui/inventory_grandmother_skin.png")
const HUD_PORTRAIT_FRAME := preload("res://assets/game/ui/hud/hud_portrait_frame.tres")
const HUD_STATUS_FRAME := preload("res://assets/game/ui/hud/hud_status_frame.tres")
const HUD_CLOCK_FRAME := preload("res://assets/game/ui/hud/hud_clock_frame.tres")
const HUD_LOCATION_FRAME := preload("res://assets/game/ui/hud/hud_location_frame.tres")
const HUD_SKILL_BUTTON := preload("res://assets/game/ui/hud/hud_skill_button.tres")
const HUD_QUEST_BUTTON := preload("res://assets/game/ui/hud/hud_quest_button.tres")
const WEATHER_ICONS := {
	"clear":preload("res://assets/game/ui/hud/weather_clear.tres"),
	"rain":preload("res://assets/game/ui/hud/weather_rain.tres"),
	"wind":preload("res://assets/game/ui/hud/weather_wind.tres"),
	"snow":preload("res://assets/game/ui/hud/weather_snow.tres"),
	"storm":preload("res://assets/game/ui/hud/weather_storm.tres"),
}
const INVENTORY_FILTERS := ["all", "tool", "food", "equipment", "resource", "quest"]
const HUD_RECT := Rect2(0, 0, 1152, 96)
const PLAYER_PORTRAIT_RECT := Rect2(0, 0, 100, 96)
const PLAYER_BARS_RECT := Rect2(100, 0, 330, 96)
const CLOCK_BADGE := Rect2(430, 0, 290, 96)
const LOCATION_BADGE := Rect2(720, 0, 250, 96)
const INVENTORY_WINDOW := Rect2(88, 7, 976, 634)
const INVENTORY_GRID_ORIGIN := Vector2(149, 164)
const INVENTORY_SLOT_SIZE := Vector2(57, 50)
const INVENTORY_SLOT_PITCH := Vector2(65.5, 58.0)
const INVENTORY_HOTBAR_ORIGIN := Vector2(207, 544)
const INVENTORY_HOTBAR_SIZE := Vector2(66, 65)
const INVENTORY_HOTBAR_PITCH := 73.4
const INVENTORY_HOTBAR_SKIN_RECT := Rect2(190, 532, 762, 84)
const WORLD_HOTBAR_PANEL := Rect2(190, 564, 762, 84)
const USE_BUTTON := Rect2(580, 430, 195, 31)
const EQUIP_BUTTON := Rect2(580, 469, 94, 29)
const DROP_BUTTON := Rect2(680, 469, 95, 29)
const SORT_BUTTON := Rect2(649, 90, 175, 42)
const SKILL_BUTTON := Rect2(970, 0, 91, 96)
const QUEST_BUTTON := Rect2(1061, 0, 91, 96)
const PAUSE_BUTTON := Rect2(18, 584, 54, 54)
const DODGE_BUTTON := Rect2(1004, 520, 60, 48)
const BLOCK_BUTTON := Rect2(1072, 520, 60, 48)
const HOTBAR_ORIGIN := Vector2(207, 576)
const HOTBAR_SLOT_SIZE := INVENTORY_HOTBAR_SIZE
const HOTBAR_PITCH := INVENTORY_HOTBAR_PITCH
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
const GOLD := Color("efc766")


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func inventory_slot_rect(visible_index: int) -> Rect2:
	var column := visible_index % 6
	var row := visible_index / 6
	return Rect2(INVENTORY_GRID_ORIGIN + Vector2(column * INVENTORY_SLOT_PITCH.x, row * INVENTORY_SLOT_PITCH.y), INVENTORY_SLOT_SIZE)


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
		panel(game, Rect2(18, 110, 405, 64), PANEL)
		game.draw_string(game.UI_FONT, Vector2(32, 132), game.LocaleSystem.ui("tutorial", [game.tutorial_step + 1, game.tutorial_steps.size()]), HORIZONTAL_ALIGNMENT_LEFT, 375, 12, Color("9ed6b3"))
		game.draw_string(game.UI_FONT, Vector2(32, 159), game.LocaleSystem.tutorial(game.tutorial_steps[game.tutorial_step].event), HORIZONTAL_ALIGNMENT_LEFT, 375, 15, INK)
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
	game.draw_texture_rect(HUD_PORTRAIT_FRAME, PLAYER_PORTRAIT_RECT, false)
	game.draw_texture_rect(HUD_STATUS_FRAME, PLAYER_BARS_RECT, false)
	game.draw_texture_rect(HUD_CLOCK_FRAME, CLOCK_BADGE, false)
	game.draw_texture_rect(HUD_LOCATION_FRAME, LOCATION_BADGE, false)
	game.draw_texture_rect(HUD_SKILL_BUTTON, SKILL_BUTTON, false)
	game.draw_texture_rect(HUD_QUEST_BUTTON, QUEST_BUTTON, false)
	var hours := floori(game.game_minutes / 60.0)
	var minutes := int(game.game_minutes) % 60
	draw_player_portrait(game)
	draw_hud_bar(game, Rect2(120, 10, 292, 20), float(game.player_hp) / game.player_max_hp, "♥ HP", "%d/%d" % [game.player_hp, game.player_max_hp], Color("c94d47"))
	draw_hud_bar(game, Rect2(120, 38, 292, 20), float(game.player_mana) / game.player_max_mana, "◆ MP", "%d/%d" % [game.player_mana, game.player_max_mana], Color("5368c9"))
	var stamina_max: int = game.SkillSystem.max_stamina(game)
	draw_hud_bar(game, Rect2(120, 66, 292, 20), float(game.energy) / stamina_max, "✦ EN", "%d/%d" % [game.energy, stamina_max], Color("d49a32"))
	draw_clock_badge(game, hours, minutes)
	var effects: Array[String] = []
	if game.regeneration_timer > 0.0: effects.append("❤ %.0fs" % game.regeneration_timer)
	if game.strength_timer > 0.0: effects.append("⚔ %.0fs" % game.strength_timer)
	if game.speed_timer > 0.0: effects.append("➜ %.0fs" % game.speed_timer)
	if game.invisibility_timer > 0.0: effects.append("◉ %.0fs" % game.invisibility_timer)
	if game.defense_timer > 0.0: effects.append("◆ %.0fs" % game.defense_timer)
	if not game.active_companions.is_empty(): effects.append(game.LocaleSystem.ui("companion_command", [game.LocaleSystem.ui("companion_command_%s" % game.state.player.companion_command)]))
	game.draw_string(game.UI_FONT, Vector2(742, 33), location_icon(game.current_location), HORIZONTAL_ALIGNMENT_CENTER, 22, 16, GOLD)
	game.draw_string(game.UI_FONT, Vector2(764, 31), game.WorldSystem.name(game.current_location).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 178, 11, Color("ffe8a8"))
	game.draw_string(game.UI_FONT, Vector2(746, 76), "●  %d" % game.coins, HORIZONTAL_ALIGNMENT_LEFT, 54, 12, GOLD)
	game.draw_string(game.UI_FONT, Vector2(801, 76), "  ".join(effects), HORIZONTAL_ALIGNMENT_CENTER, 141, 8, Color("f3dab0"))
	draw_hud_icon_badge(game, SKILL_BUTTON, game.skill_points)
	draw_hud_icon_badge(game, QUEST_BUTTON, active_quest_count(game))
	if game.state.fishing.phase == game.FishingSystem.PHASE_WAITING: game.draw_string(game.UI_FONT, Vector2(446, 115), "%.1f" % maxf(game.state.fishing.timer, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 260, 20, Color("d7f6ff"))
	elif game.state.fishing.phase == game.FishingSystem.PHASE_BITE:
		game.draw_circle(Vector2(576, 105), 20 + sin(Time.get_ticks_msec() / 100.0) * 3, GOLD)
		game.draw_string(game.UI_FONT, Vector2(566, 112), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 22, Color("47351f"))
	if not game.message.is_empty():
		panel(game, Rect2(286, 528, 580, 30), Color(0.04, 0.08, 0.07, 0.9))
		game.draw_string(game.UI_FONT, Vector2(300, 549), game.message, HORIZONTAL_ALIGNMENT_CENTER, 552, 14, INK)
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


## Рисует портрет текущего облика героя, уровень и тонкую шкалу опыта в левой медальонной секции.
static func draw_player_portrait(game: Node) -> void:
	var stage: int = game.SkillSystem.hero_skin_stage(game.player_level)
	var texture: Texture2D = game.DirectionalCharacterSystem.HERO_TEXTURES[stage]
	var source: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.DOWN, 0.0, false)
	source.position += Vector2(source.size.x * 0.22, 0.0)
	source.size = Vector2(source.size.x * 0.56, source.size.y * 0.62)
	game.draw_texture_rect_region(texture, Rect2(27, 7, 58, 61), source)
	game.draw_string(game.UI_FONT, Vector2(28, 86), game.LocaleSystem.ui("level_short", [game.player_level]), HORIZONTAL_ALIGNMENT_CENTER, 57, 8, Color("ffe5a0"))
	var xp_needed: int = game.SkillSystem.xp_to_next_character_level(game.player_level)
	game.draw_rect(Rect2(30, 90, 53 * clampf(float(game.player_xp) / xp_needed, 0.0, 1.0), 2), GOLD)


## Рисует статусную шкалу с отдельной иконкой, подписью и числовым значением в стиле выбранного макета.
static func draw_hud_bar(game: Node, rect: Rect2, ratio: float, label: String, value: String, color: Color) -> void:
	game.draw_rect(Rect2(rect.position + Vector2(61, 6), Vector2((rect.size.x - 70) * clampf(ratio, 0.0, 1.0), rect.size.y - 12)), Color(color, 0.92))
	game.draw_string(game.UI_FONT, rect.position + Vector2(8, 15), label, HORIZONTAL_ALIGNMENT_LEFT, 50, 9, Color("ffe4a2"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(64, 15), value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 75, 9, Color.WHITE)


## Рисует центральную пергаментную карточку времени, дня, сезона и текущей погоды.
static func draw_clock_badge(game: Node, hours: int, minutes: int) -> void:
	var weather: String = game.WorldEventSystem.weather(game)
	var season: String = game.WorldEventSystem.season(game.day)
	game.draw_texture_rect(weather_icon(weather), Rect2(499, 22, 36, 36), false)
	game.draw_string(game.UI_FONT, Vector2(520, 54), "%02d:%02d" % [hours, minutes], HORIZONTAL_ALIGNMENT_CENTER, 174, 28, Color("4a2c1b"))
	var calendar := "%s  •  %s  •  %s" % [game.LocaleSystem.ui("day_short", [game.day]), game.LocaleSystem.ui("season_" + season), game.LocaleSystem.ui("weather_" + weather)]
	game.draw_string(game.UI_FONT, Vector2(462, 82), calendar.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 230, 9, Color("6b4326"))


## Возвращает вырезанную из погодного атласа иконку либо безопасный солнечный вариант.
static func weather_icon(weather: String) -> Texture2D:
	return WEATHER_ICONS.get(weather, WEATHER_ICONS.clear)


## Накладывает числовой бейдж на нарисованную иконку навыков или журнала, не подменяя её буквой.
static func draw_hud_icon_badge(game: Node, rect: Rect2, badge: int) -> void:
	if badge > 0:
		game.draw_circle(rect.position + Vector2(rect.size.x - 15, 15), 10, Color("c64d35"))
		game.draw_circle(rect.position + Vector2(rect.size.x - 15, 15), 10, GOLD, false, 2.0)
		game.draw_string(game.UI_FONT, rect.position + Vector2(rect.size.x - 22, 20), str(badge), HORIZONTAL_ALIGNMENT_CENTER, 14, 9, Color.WHITE)


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
	if not enabled:
		game.draw_rect(rect.grow(-3), Color(0.12, 0.12, 0.1, 0.48))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, rect.size.y * 0.68), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 10, color if enabled else Color("a89f82"))


## Рисует шесть интерактивных вкладок категорий с крупным состоянием фокуса.
static func draw_category_tabs(game: Node) -> void:
	var symbols := ["▦", "⚒", "●", "♜", "◆", "!"]
	for index in game.InventorySystem.FILTERS.size():
		var filter_id: String = game.InventorySystem.FILTERS[index]; var active: bool = game.inventory_filter == filter_id; var rect: Rect2 = inventory_category_rect(index)
		if active:
			game.draw_rect(rect.grow(-3), Color(0.31, 0.43, 0.22, 0.88))
			game.draw_rect(rect, GOLD, false, 2.0)
		game.draw_string(game.UI_FONT, rect.position + Vector2(4, 17), symbols[index], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 15, Color("ffe8a8"))
		var label: String = game.LocaleSystem.ui("inventory_all") if filter_id == "all" else game.LocaleSystem.ui("category_" + filter_id)
		game.draw_string(game.UI_FONT, rect.position + Vector2(4, 37), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 7, Color("fff1bd"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_inventory_slot(game: Node, index: int, visible_index: int) -> void:
	var rect: Rect2 = inventory_slot_rect(visible_index)
	var selected: bool = index == game.inventory_selected
	var moving: bool = index == game.inventory_move_from
	if moving: game.draw_rect(rect.grow(-4), Color(0.55, 0.76, 0.46, 0.38))
	if selected:
		var pulse := 0.72 + sin(Time.get_ticks_msec() / 145.0) * 0.18
		game.draw_rect(rect.grow(2), Color(1.0, 0.72, 0.17, pulse), false, 3.0)
	var kind: String = game.inventory_slots[index]
	if kind.is_empty() or game.inventory_item_count(kind) <= 0: return
	game.draw_item_icon(kind, Rect2(rect.position + Vector2(8, 3), Vector2(41, 40)))
	game.draw_string(game.UI_FONT, rect.position + Vector2(31, 47), str(game.inventory_item_count(kind)), HORIZONTAL_ALIGNMENT_RIGHT, 22, 10, Color("3d281c"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_scrollbar(game: Node) -> void:
	var total_rows := ceili(float(game.InventorySystem.filtered_indices(game).size()) / game.InventorySystem.COLUMNS)
	var track := Rect2(542, 174, 7, 292)
	var thumb_height := maxf(30.0, track.size.y * game.InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, game.InventorySystem.VISIBLE_ROWS)))
	var ratio := float(game.inventory_scroll_row) / float(maxi(game.InventorySystem.max_scroll_row(game), 1))
	game.draw_rect(Rect2(track.position + Vector2(0, (track.size.y - thumb_height) * ratio), Vector2(7, thumb_height)), Color("f2c55d"))
	game.draw_string(game.UI_FONT, Vector2(443, 496), game.LocaleSystem.ui("row", [game.inventory_scroll_row + 1, maxi(total_rows - game.InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 91, 8, Color("70492d"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func selected_kind(game: Node) -> String:
	if game.inventory_selected < 0 or game.inventory_selected >= game.inventory_slots.size(): return ""
	return game.inventory_slots[game.inventory_selected]


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
	if selected:
		game.draw_rect(rect.grow(1), Color("ffd35d"), false, 3.0)
	game.draw_item_icon(game.hotbar_slots[index], Rect2(rect.position + Vector2(12, 8), Vector2(43, 43)))
	game.draw_string(game.UI_FONT, rect.position + Vector2(4, 14), str(index + 1 if index < 9 else 0), HORIZONTAL_ALIGNMENT_LEFT, 11, 9, Color("ffe7a0"))
	var kind: String = game.hotbar_slots[index]
	if not kind.is_empty() and game.inventory_item_count(kind) > 1:
		game.draw_string(game.UI_FONT, rect.position + Vector2(37, 59), str(game.inventory_item_count(kind)), HORIZONTAL_ALIGNMENT_RIGHT, 23, 9, Color("ffe7a0"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_action_button(game: Node, rect: Rect2, label: String, enabled: bool) -> void:
	game.draw_rect(rect, Color("668d68") if enabled else Color("3f5049"))
	game.draw_string(game.UI_FONT, rect.position + Vector2(5, 30), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10, 11, Color.WHITE if enabled else Color("87958c"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func panel(game: Node, rect: Rect2, color: Color) -> void:
	game.draw_rect(rect, Color(0.02, 0.035, 0.03, 0.95))
	game.draw_rect(rect.grow(-3), color)

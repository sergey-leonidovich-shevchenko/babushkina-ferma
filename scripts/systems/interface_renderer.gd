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
const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")
const HudChrome := preload("res://scripts/presentation/hud_chrome_system.gd")
const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const StoryUiRenderer := preload("res://scripts/systems/story_ui_renderer.gd")
const ItemTooltipRenderer := preload("res://scripts/presentation/item_tooltip_renderer.gd")
const QuickAccessRenderer := preload("res://scripts/presentation/quick_access_renderer.gd")
const WEATHER_ICONS := {
	"clear":preload("res://assets/game/ui/hud/weather_clear.tres"),
	"rain":preload("res://assets/game/ui/hud/weather_rain.tres"),
	"wind":preload("res://assets/game/ui/hud/weather_wind.tres"),
	"snow":preload("res://assets/game/ui/hud/weather_snow.tres"),
	"storm":preload("res://assets/game/ui/hud/weather_storm.tres"),
}
const INVENTORY_FILTERS := ["all", "tool", "food", "equipment", "resource", "quest"]
const HUD_RECT := HudChrome.HUD_RECT
const PLAYER_PORTRAIT_RECT := HudChrome.PORTRAIT
const PLAYER_BARS_RECT := HudChrome.BARS
const CLOCK_BADGE := HudChrome.CLOCK
const CLOCK_WEATHER_RECT := HudChrome.WEATHER
const CLOCK_TIME_RECT := HudChrome.TIME
const CLOCK_CALENDAR_RECT := HudChrome.CALENDAR
const LOCATION_BADGE := HudChrome.LOCATION
const INVENTORY_WINDOW := Rect2(0, 0, 1152, 648)
const INVENTORY_GRID_ORIGIN := Vector2(40, 148)
const INVENTORY_SLOT_SIZE := Vector2(80, 62)
const INVENTORY_SLOT_PITCH := Vector2(88, 68)
const INVENTORY_HOTBAR_ORIGIN := Vector2(296, 579)
const INVENTORY_HOTBAR_SIZE := Vector2(60, 58)
const INVENTORY_HOTBAR_PITCH := 66.0
const INVENTORY_HOTBAR_SKIN_RECT := Rect2(286, 571, 674, 72)
const INVENTORY_TITLE_RECT := Rect2(26, 20, 210, 36)
const INVENTORY_CLOSE_BUTTON := Rect2(1094, 18, 38, 38)
const INVENTORY_DETAIL_RECT := Rect2(600, 134, 270, 423)
const INVENTORY_TOOLTIP_RECT := Rect2(600, 134, 270, 320)
const INVENTORY_GRID_PANEL := Rect2(24, 134, 552, 423)
const INVENTORY_EQUIPMENT_RECT := Rect2(898, 134, 230, 423)
const WORLD_HOTBAR_PANEL := QuickAccessRenderer.WORLD_PANEL
const USE_BUTTON := Rect2(616, 468, 238, 31)
const EQUIP_BUTTON := Rect2(616, 512, 113, 31)
const DROP_BUTTON := Rect2(741, 512, 113, 31)
const SORT_BUTTON := Rect2(920, 89, 208, 34)
const SKILL_BUTTON := HudChrome.SKILLS
const QUEST_BUTTON := HudChrome.QUESTS
const PAUSE_BUTTON := Rect2(18, 590, 38, 38)
const DODGE_BUTTON := Rect2(1004, 520, 60, 48)
const BLOCK_BUTTON := Rect2(1072, 520, 60, 48)
const MESSAGE_CARD := HudLayoutSystem.NOTIFICATION_RECT
const TUTORIAL_CARD := HudLayoutSystem.TUTORIAL_RECT
const OBJECTIVE_CARD := HudLayoutSystem.OBJECTIVE_RECT
const INTERACTION_PROMPT := HudLayoutSystem.INTERACTION_RECT
const HOTBAR_ORIGIN := QuickAccessRenderer.WORLD_ORIGIN
const HOTBAR_SLOT_SIZE := QuickAccessRenderer.WORLD_SLOT_SIZE
const HOTBAR_PITCH := QuickAccessRenderer.WORLD_PITCH
const STORAGE_LEFT_ROWS := Rect2(44,224,300,320)
const STORAGE_RIGHT_ROWS := Rect2(662,224,434,320)
const STORAGE_TRANSFER_ONE := Rect2(390,486,116,32)
const STORAGE_TRANSFER_ALL := Rect2(514,526,116,32)
const FORGE_ROWS := Rect2(164, 154, 824, 338)
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


## Возвращает адаптивную hit-зону кнопки паузы для текущего размера сенсорного управления.
static func pause_button_rect(game: Node) -> Rect2:
	return game.UiScaleSystem.touch_rect(game, PAUSE_BUTTON)


## Возвращает адаптивную hit-зону рывка с сохранением безопасного отступа от края.
static func dodge_button_rect(game: Node) -> Rect2:
	var block := block_button_rect(game)
	var size: Vector2 = game.UiScaleSystem.touch_rect(game, DODGE_BUTTON).size
	return Rect2(Vector2(block.position.x - 8.0 - size.x, DODGE_BUTTON.get_center().y - size.y * 0.5), size)


## Возвращает адаптивную hit-зону блока с сохранением безопасного отступа от края.
static func block_button_rect(game: Node) -> Rect2:
	var size: Vector2 = game.UiScaleSystem.touch_rect(game, BLOCK_BUTTON).size
	return Rect2(Vector2(VIEWPORT.end.x - 20.0 - size.x, BLOCK_BUTTON.get_center().y - size.y * 0.5), size)


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
	return centered_rect(inventory_slot_rect(visible_index), Vector2(48, 48))


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
	return Rect2(24+index*106,89,100,34)


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
	var side:=minf(43.0,minf(rect.size.x,rect.size.y)-16.0)
	return centered_rect(rect, Vector2(side,side))


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
	if preload("res://scripts/systems/dev_cabinet_system.gd").active(game):
		preload("res://scripts/presentation/dev_cabinet_renderer.gd").draw(game); return
	if game.storage_open:
		game.draw_storage_window(); return
	if not preload("res://scripts/systems/menu_hub_system.gd").active(game): draw_hud(game)
	var clean_hud_preview := game.has_meta("capture_hud_clean")
	var fishing_focus:bool=game.state.fishing.phase in [game.FishingSystem.PHASE_CHARGING,game.FishingSystem.PHASE_MINIGAME,game.FishingSystem.PHASE_RESULT]
	var farm_life:Dictionary=game.FarmLifeSystem.state(game); var farm_modal:bool=bool(farm_life.compendium) or not String(farm_life.cutscene).is_empty()
	farm_modal = farm_modal or preload("res://scripts/systems/dev_cabinet_system.gd").active(game) or game.inventory_open or game.shop_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.AdventurePolishSystem.has_modal(game)
	if not clean_hud_preview and not fishing_focus and not farm_modal and game.tutorial_visible and game.tutorial_step < game.tutorial_steps.size():
		game.StoryUiRenderer.draw_tutorial(game)
	if not clean_hud_preview and not fishing_focus and not farm_modal and not game.AdventurePolishSystem.has_modal(game): game.draw_discovery_card()
	HudRenderer.draw_interaction_prompt(game, game.InterfaceRenderer)
	if game.shop_open: game.draw_shop()
	if game.inventory_open: draw_inventory(game)
	if game.crafting_open: game.draw_crafting_window()
	if game.storage_open: game.draw_storage_window()
	if game.forge_open: game.draw_forge_window()
	if game.contract_open: game.ContractRenderer.draw(game)
	if game.quest_log_open: game.draw_quest_log()
	if game.skill_menu_open: game.draw_skill_menu()
	preload("res://scripts/presentation/dev_cabinet_renderer.gd").draw(game)


## Отрисовывает HUD по текущему состоянию игры.
static func draw_hud(game: Node) -> void:
	HudRenderer.draw(game, game.InterfaceRenderer)


## Собирает компактные независимые карточки с общим древесным стилем и неизменным размером резных углов.
static func draw_hud_background(game: Node) -> void:
	for rect in [HudChrome.STATUS, CLOCK_BADGE, LOCATION_BADGE]: HudChrome.draw_panel(game, rect)
	game.draw_line(Vector2(76, 22), Vector2(76, 62), Color(0.80, 0.64, 0.34, 0.32), 1)


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


## Делегирует компактную игровую панель общему компоненту без запечённых дублирующих рамок.
static func draw_hotbar(game: Node) -> void:
	QuickAccessRenderer.draw_world(game)


## Отрисовывает инвентаря по текущему состоянию игры.
static func draw_inventory(game: Node) -> void:
	preload("res://scripts/presentation/moon_inventory_renderer.gd").draw(game)


## Рисует надпись с пиксельной тенью поверх резной таблички инвентаря.
static func draw_inventory_title(game: Node, label: String, rect: Rect2, font_size: int) -> void:
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(2, rect.size.y - 5 + 2), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("3a1c0f"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(0, rect.size.y - 5), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color("fff0b3"))


## Накладывает только динамическую подпись и состояние доступности, сохраняя нарисованную кнопку скина.
static func draw_inventory_button_label(game: Node, rect: Rect2, label: String, enabled: bool, color: Color) -> void:
	if not enabled: game.draw_rect(rect.grow(-3), Color(0.12, 0.12, 0.1, 0.48))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(4, rect.size.y * 0.68), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 10, color if enabled else Color("a89f82"))


## Рисует шесть интерактивных вкладок категорий с крупным состоянием фокуса.
static func draw_category_tabs(game: Node) -> void:
	for index in game.InventorySystem.FILTERS.size():
		var filter_id: String = game.InventorySystem.FILTERS[index]; var active: bool = game.inventory_filter == filter_id; var rect: Rect2 = inventory_category_rect(index)
		game.ItemWindowRenderer.draw_row(game, rect, active)
		var label: String = game.LocaleSystem.ui("inventory_all") if filter_id == "all" else game.LocaleSystem.ui("category_short_" + filter_id)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(7, 27), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 14, 10, Color("3d281c"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_inventory_slot(game: Node, index: int, visible_index: int) -> void:
	var rect: Rect2 = inventory_slot_rect(visible_index)
	var selected: bool = index >= 0 and index == game.inventory_selected
	var moving: bool = index >= 0 and index == game.inventory_move_from
	UiKitSystem.draw_slot(game, rect, selected)
	if moving: game.draw_rect(rect.grow(-8), Color(0.55, 0.76, 0.46, 0.30))
	if index < 0: return
	var kind: String = game.inventory_slots[index]
	if kind.is_empty() or game.inventory_item_count(kind) <= 0: return
	game.draw_item_icon(kind, inventory_icon_rect(visible_index))
	var amount: int = game.inventory_item_count(kind)
	if amount > 1:
		var count_rect := Rect2(rect.end - Vector2(27, 15), Vector2(22, 12))
		game.draw_rect(count_rect, Color(0.93, 0.83, 0.59, 0.92))
		game.draw_ui_string(game.UI_FONT, count_rect.position + Vector2(1, 10), str(amount), HORIZONTAL_ALIGNMENT_RIGHT, count_rect.size.x - 2, 9, Color("3d281c"))


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_scrollbar(game: Node) -> void:
	var total_rows := ceili(float(game.InventorySystem.filtered_indices(game).size()) / game.InventorySystem.COLUMNS)
	var track := Rect2(542, 174, 7, 292)
	game.draw_style_box(UiKitSystem.style("scrollbar"),track)
	var thumb_height := maxf(30.0, track.size.y * game.InventorySystem.VISIBLE_ROWS / float(maxi(total_rows, game.InventorySystem.VISIBLE_ROWS)))
	var ratio := float(game.inventory_scroll_row) / float(maxi(game.InventorySystem.max_scroll_row(game), 1))
	game.draw_rect(Rect2(track.position + Vector2(0, (track.size.y - thumb_height) * ratio), Vector2(7, thumb_height)), UiKitSystem.Paper.ACCENT_TEXT)
	game.draw_ui_string(game.UI_FONT, Vector2(443, 496), game.LocaleSystem.ui("row", [game.inventory_scroll_row + 1, maxi(total_rows - game.InventorySystem.VISIBLE_ROWS + 1, 1)]), HORIZONTAL_ALIGNMENT_RIGHT, 91, 8, Color("70492d"))


## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func selected_kind(game: Node) -> String:
	if game.inventory_selected < 0 or game.inventory_selected >= game.inventory_slots.size(): return ""
	var kind: String = game.inventory_slots[game.inventory_selected]
	return kind if not kind.is_empty() and game.inventory_item_count(kind) > 0 else ""


## Отрисовывает соответствующий элемент по текущим данным активной сцены.
static func draw_item_detail(game: Node) -> void:
	var kind := selected_kind(game)
	if kind.is_empty():
		game.draw_ui_string(game.UI_FONT, Vector2(580, 319), game.LocaleSystem.ui("empty_slot"), HORIZONTAL_ALIGNMENT_CENTER, 195, 14, Color("80684a"))
		return
	ItemTooltipRenderer.draw(game,kind,INVENTORY_TOOLTIP_RECT,game.inventory_item_count(kind))


## Отрисовывает экипировки по текущему состоянию игры.
static func draw_equipment(game: Node) -> void:
	game.draw_ui_string(game.UI_FONT, Vector2(812, 181), game.LocaleSystem.ui("equipment"), HORIZONTAL_ALIGNMENT_CENTER, 194, 16, Color("4b3425"))
	var slots := ["head", "body", "legs", "hands", "offhand", "ring"]
	for index in slots.size():
		var left := index % 2 == 0
		var rect := Rect2(812 if left else 944, 190 + (index / 2) * 89, 59, 68)
		var slot_name: String = slots[index]
		var slot_label:String=game.LocaleSystem.ui("offhand_short" if slot_name=="offhand" else slot_name)
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(3, 14), slot_label, HORIZONTAL_ALIGNMENT_CENTER, 53, 8, Color("59452f"))
		var kind: String = game.equipment[slot_name]
		if not kind.is_empty(): game.draw_item_icon(kind, Rect2(rect.position + Vector2(11, 21), Vector2(38, 39)))


## Накладывает содержимое слота рюкзака через общий отрисовщик обеих быстрых панелей.
static func draw_inventory_hotbar_slot(game: Node, index: int) -> void:
	draw_hotbar_slot(game, inventory_hotbar_rect(index), index)


## Делегирует содержимое слота, сохраняя большую геометрию инвентаря и компактную геометрию мира.
static func draw_hotbar_slot(game: Node, rect: Rect2, index: int) -> void:
	QuickAccessRenderer.draw_slot(game, rect, index)


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

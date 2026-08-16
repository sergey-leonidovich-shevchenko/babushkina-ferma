extends "res://tests/suites/suite_base.gd"


## Запускает все сценарии текущего набора тестов в фиксированном порядке.
func run() -> void:
	test_inventory_uses_grandmother_skin_and_six_rows()
	test_item_windows_share_storybook_shell_and_close_control()
	test_story_windows_share_visual_language_and_input_geometry()
	test_inventory_layout_and_touch_mapping()
	test_item_context_and_actions()
	test_hud_layout_is_compact_and_safe()
	test_inventory_touch_actions()
	test_mouse_drag_context_and_hotbar()
	test_inventory_sorting()
	test_every_owned_item_has_a_visible_slot_and_icon_fallback()
	test_inventory_category_filters_support_pointer_and_gamepad()
	test_sprite_cards_and_action_controls_use_sliced_atlases()
	test_touch_controls_follow_last_input_device()
	test_hotbar_readiness_and_hud_feedback_animations()


## Сценарий: журнал, диалог, обучение, уведомление и награда главы используют единый сказочный UI-набор.
## Исходное состояние: общий сюжетный renderer загружен, геометрия интерактивных зон доступна, эталонные снимки созданы.
## Ожидаемый результат: панели не выходят за viewport, варианты ответа не пересекаются, а прежняя плоская отрисовка удалена.
func test_story_windows_share_visual_language_and_input_geometry() -> void:
	var game := make_game()
	var renderer = game.StoryUiRenderer
	expect(Rect2(0, 0, 1152, 648).encloses(renderer.QUEST_WINDOW) and renderer.QUEST_WINDOW.encloses(renderer.QUEST_HEADER), "quest journal and carved title stay in the native viewport")
	for rect in renderer.QUEST_CARD_RECTS:
		expect(renderer.QUEST_WINDOW.encloses(rect), "every mission card stays inside the storybook shell")
	expect(game.InterfaceRenderer.QUEST_PREV == renderer.QUEST_PREV and game.InterfaceRenderer.QUEST_NEXT == renderer.QUEST_NEXT, "quest drawing and pointer navigation share one geometry source")
	for count in [1, 2, 3]:
		for index in count:
			var rect: Rect2 = renderer.dialogue_choice_rect(index, count)
			expect(renderer.DIALOGUE_WINDOW.encloses(rect) and renderer.dialogue_choice_at(rect.get_center(), count) == index, "dialogue choice %d of %d is centered and touchable" % [index + 1, count])
			if index > 0: expect(not rect.intersects(renderer.dialogue_choice_rect(index - 1, count)), "dialogue choices never overlap")
	var dialogue_source := FileAccess.get_file_as_string("res://scripts/systems/adventure_polish_renderer.gd")
	var quest_source := FileAccess.get_file_as_string("res://scripts/game_renderer.gd")
	expect(dialogue_source.contains("StoryUiRenderer.draw_dialogue") and quest_source.contains("StoryUiRenderer.draw_quest_log"), "legacy dialogue and quest entry points delegate to the shared story renderer")
	game.AdventurePolishSystem.open_quest_dialogue(game, "miron")
	var choices: Array = game.state.player.adventure_ui.dialogue.choices
	var decline := InputEventMouseButton.new(); decline.button_index = MOUSE_BUTTON_LEFT; decline.pressed = true; decline.position = renderer.dialogue_choice_rect(1, choices.size()).get_center()
	expect(game.AdventurePolishSystem.handle_input(game, decline) and not game.state.player.adventure_ui.dialogue_open, "mouse and touch geometry activates the chosen dialogue reply")
	for name in ["quest_log", "dialogue", "tutorial", "notification", "chapter_reward"]:
		var path := "res://assets/generated/ui/%s_ingame_preview.png" % name
		var preview := Image.load_from_file(ProjectSettings.globalize_path(path))
		expect(preview != null and preview.get_width() >= 1152 and absf(float(preview.get_width()) / preview.get_height() - 16.0 / 9.0) < 0.01, "%s story window keeps a native-or-larger 16:9 reference" % name)
	game.free()


## Сценарий: рюкзак, лавка, верстак, сундук и кузница образуют одно художественное семейство.
## Исходное состояние: общий renderer и пять эталонных снимков доступны, а рюкзак открыт для проверки кнопки закрытия.
## Ожидаемый результат: секции входят в общий каркас, снимки сохраняют 16:9, фокус не использует внешнюю рамку и крестик закрывает окно.
func test_item_windows_share_storybook_shell_and_close_control() -> void:
	var game := make_game()
	var renderer = game.ItemWindowRenderer
	for section in [renderer.CRAFT_SECTION, renderer.SHOP_STOCK_SECTION, renderer.SHOP_TABLE_SECTION, renderer.STORAGE_LEFT_SECTION, renderer.STORAGE_RIGHT_SECTION, renderer.FORGE_SECTION]:
		expect(renderer.SHELL.encloses(section), "shared storybook shell encloses every item-window section")
	expect(not game.InterfaceRenderer.STORAGE_LEFT_ROWS.intersects(game.InterfaceRenderer.STORAGE_TRANSFER_ONE) and not game.InterfaceRenderer.STORAGE_RIGHT_ROWS.intersects(game.InterfaceRenderer.STORAGE_TRANSFER_ALL), "storage rows stay clear of transfer controls after grid alignment")
	var interface_source := FileAccess.get_file_as_string("res://scripts/systems/interface_renderer.gd")
	expect(not interface_source.contains("draw_rect(rect.grow(2)") and not interface_source.contains("draw_rect(rect.grow(1)"), "inventory and hotbar focus use selected sprite art instead of an external yellow rectangle")
	for name in ["inventory", "shop", "crafting", "storage", "forge"]:
		var path := "res://assets/generated/ui/%s_ingame_preview.png" % name
		var preview := Image.load_from_file(ProjectSettings.globalize_path(path))
		expect(preview != null and preview.get_width() >= 1152 and absf(float(preview.get_width()) / preview.get_height() - 16.0 / 9.0) < 0.01, "%s item window keeps a native-or-larger 16:9 reference" % name)
	game.open_inventory()
	var close := InputEventMouseButton.new(); close.button_index = MOUSE_BUTTON_LEFT; close.pressed = true; close.position = renderer.CLOSE_BUTTON.get_center()
	expect(game.handle_gamepad_and_touch(close) and not renderer.is_open(game), "painted close button dismisses the active item window through the shared hit zone")
	game.free()


## Сценарий: рюкзак использует утверждённый резной скин и сетку эталона 6×6.
## Исходное состояние: графический ресурс загружен, а константы интерфейса доступны без запуска окна.
## Ожидаемый результат: скин имеет исходное соотношение 16:9, показаны 36 ячеек, а рабочие панели не выходят за деревянную раму.
func test_inventory_uses_grandmother_skin_and_six_rows() -> void:
	var game := make_game()
	expect(game.InterfaceRenderer.INVENTORY_SKIN.get_size() == Vector2(1672, 941), "inventory uses the approved full-resolution grandmother skin")
	expect(game.InventorySystem.VISIBLE_ROWS == 6 and game.InventorySystem.VISIBLE_SLOTS == 36, "reference 6 by 6 item grid is preserved")
	expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(game.InterfaceRenderer.inventory_slot_rect(35)), "last cell of the reference grid stays inside the carved frame")
	expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(game.InterfaceRenderer.inventory_hotbar_rect(9)), "tenth quick slot stays inside the carved frame")
	game.free()


## Сценарий: все ячейки рюкзака и быстрых слотов находятся внутри окна и точно распознают касания.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_inventory_layout_and_touch_mapping() -> void:
	var game := make_game()
	for visible_index in game.InventorySystem.VISIBLE_SLOTS:
		var rect: Rect2 = game.InterfaceRenderer.inventory_slot_rect(visible_index)
		var icon_rect: Rect2 = game.InterfaceRenderer.inventory_icon_rect(visible_index)
		expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(rect), "inventory grid slot %d stays inside its window" % visible_index)
		expect(game.InterfaceRenderer.inventory_slot_at(rect.get_center(), 0, game.inventory_slots.size()) == visible_index, "inventory touch maps exactly to slot %d" % visible_index)
		expect(rect.encloses(icon_rect) and icon_rect.get_center().is_equal_approx(rect.get_center()), "inventory icon uses flex-style centering in slot %d" % visible_index)
		if visible_index >= game.InventorySystem.COLUMNS:
			var previous_icon: Rect2 = game.InterfaceRenderer.inventory_icon_rect(visible_index - game.InventorySystem.COLUMNS)
			expect(is_equal_approx(icon_rect.get_center().x, previous_icon.get_center().x) and is_equal_approx(icon_rect.get_center().y - previous_icon.get_center().y, game.InterfaceRenderer.INVENTORY_SLOT_PITCH.y), "inventory row %d cannot accumulate icon offset" % (visible_index / game.InventorySystem.COLUMNS))
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.inventory_hotbar_rect(index)
		var icon_rect: Rect2 = game.InterfaceRenderer.hotbar_icon_rect(rect)
		expect(game.InterfaceRenderer.inventory_hotbar_at(rect.get_center()) == index, "inventory quick slot touch maps to %d" % index)
		expect(rect.encloses(icon_rect) and icon_rect.get_center().is_equal_approx(rect.get_center()), "quick slot icon uses the same flex-style centering: %d" % index)
		expect(not rect.intersects(game.InterfaceRenderer.USE_BUTTON) and not rect.intersects(game.InterfaceRenderer.EQUIP_BUTTON), "quick slot %d does not overlap contextual actions" % index)
		expect(game.InterfaceRenderer.INVENTORY_HOTBAR_SKIN_RECT.encloses(rect), "inventory quick slot %d is centered inside the carved skin strip" % index)
	for index in game.InventorySystem.FILTERS.size():
		var tab: Rect2 = game.InterfaceRenderer.inventory_category_rect(index)
		expect(game.InterfaceRenderer.INVENTORY_WINDOW.encloses(tab) and game.InterfaceRenderer.inventory_category_at(tab.get_center()) == game.InventorySystem.FILTERS[index], "wooden inventory category maps exactly: %s" % game.InventorySystem.FILTERS[index])
	game.free()


## Сценарий: категории скрывают неподходящие предметы и переключаются указателем и плечевыми кнопками.
## Исходное состояние: в рюкзаке есть еда, ресурс и экипировка, активна общая вкладка.
## Ожидаемый результат: каждая вкладка возвращает только свой тип, выбор остаётся видимым, цикл не выходит за каталог.
func test_inventory_category_filters_support_pointer_and_gamepad() -> void:
	var game := make_game(); game.change_inventory_count("carrot", 1); game.change_inventory_count("stone", 1); game.change_inventory_count("iron_helmet", 1); game.open_inventory()
	expect(game.InventorySystem.set_filter(game, "food") and game.InventorySystem.filtered_indices(game).all(func(index): return game.InventorySystem.category(game.inventory_slots[index]) == "food"), "food tab contains only owned edible items")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = game.InterfaceRenderer.inventory_category_rect(4).get_center()
	game.InventoryInputSystem.handle_mouse(game, click)
	expect(game.inventory_filter == "resource" and game.InventorySystem.category(game.inventory_slots[game.inventory_selected]) == "resource", "mouse selects resource tab and its first owned item")
	game.InventorySystem.cycle_filter(game, 1)
	expect(game.inventory_filter == "quest", "gamepad-style category cycling advances in fixed order")
	game.free()


## Сценарий: категория предмета определяет описание и доступность употребления или экипировки.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_item_context_and_actions() -> void:
	var game := make_game()
	expect(game.InventorySystem.category("hoe") == "tool", "inventory identifies tools")
	expect(game.InventorySystem.category("carrot") == "food" and game.InventorySystem.can_use("carrot"), "inventory identifies usable food")
	expect(game.InventorySystem.category("iron_helmet") == "equipment" and game.InventorySystem.can_equip("iron_helmet"), "inventory identifies wearable equipment")
	expect(game.InventorySystem.category("moon_relic") == "quest", "inventory protects quest items with a distinct category")
	expect(game.InventorySystem.category("stone") == "resource", "inventory identifies crafting resources")
	expect(not game.InventorySystem.can_use("stone") and not game.InventorySystem.can_equip("stone"), "context buttons stay disabled for incompatible items")
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		expect(not game.LocaleSystem.ui("detail_" + game.InventorySystem.category("carrot")).is_empty(), "food detail is localized for %s" % locale)
	game.LocaleSystem.set_locale("ru")
	game.free()


## Сценарий: частичное старое сохранение содержит предмет, но потеряло его позицию в сетке.
## Исходное состояние: у героя есть металл и редкие семена, их идентификаторы вручную удалены из слотов.
## Ожидаемый результат: открытие рюкзака возвращает оба слота, а каждый предмет каталога имеет видимый знак fallback.
func test_every_owned_item_has_a_visible_slot_and_icon_fallback() -> void:
	var game := make_game(); game.state.inventory.counts.metal = 3; game.state.inventory.counts.rare_seeds = 2
	game.inventory_slots.erase("metal"); game.inventory_slots.erase("rare_seeds"); game.open_inventory()
	expect(game.inventory_slots.has("metal") and game.inventory_slots.has("rare_seeds"), "inventory repairs missing slots for every owned legacy item")
	for kind in game.InventorySystem.ITEM_DATA:
		expect(not game.fallback_item_glyph(kind).is_empty(), "registered item always has visible icon fallback: %s" % kind)
	game.free()


## Сценарий: общая вкладка рюкзака не выдаёт будущие предметы с нулевым количеством за занятые слоты.
## Исходное состояние: стандартный список хранит идентификаторы открываемых позднее предметов, но герой ими ещё не владеет.
## Ожидаемый результат: сначала отображаются только полученные предметы, затем настоящие пустые слоты, а карточка не показывает скрытый предмет.
func test_inventory_all_filter_hides_zero_count_placeholders() -> void:
	var game := make_game()
	game.inventory_selected = game.inventory_slots.find("carrot")
	game.open_inventory()
	var indices: Array[int] = game.InventorySystem.filtered_indices(game)
	var first_empty_position := indices.find_custom(func(index: int) -> bool: return String(game.inventory_slots[index]).is_empty())
	expect(indices.all(func(index: int) -> bool: return String(game.inventory_slots[index]).is_empty() or game.inventory_item_count(game.inventory_slots[index]) > 0), "all tab excludes catalog placeholders that the player does not own")
	expect(first_empty_position < 0 or indices.slice(0, first_empty_position).all(func(index: int) -> bool: return game.inventory_item_count(game.inventory_slots[index]) > 0), "owned item icons are compacted before genuine empty slots")
	expect(game.inventory_selected == indices[0] and not game.InterfaceRenderer.selected_kind(game).is_empty(), "opening inventory repairs selection from a hidden zero-count item")
	game.inventory_selected = game.inventory_slots.find("carrot")
	expect(game.InterfaceRenderer.selected_kind(game).is_empty(), "right detail panel rejects an unowned placeholder even when its legacy slot is selected")
	game.free()


## Сценарий: игровой интерфейс занимает ограниченную высоту, а его кнопки и быстрые слоты не перекрываются.
## Исходное состояние: новый изолированный экземпляр игры; необходимые ресурсы, позиции и таймеры задаются в начале сценария.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_hud_layout_is_compact_and_safe() -> void:
	var game := make_game()
	expect(game.InterfaceRenderer.HUD_RECT.size.y <= 96.0, "sliced adventurer HUD keeps its height below one sixth of the screen")
	expect(not game.InterfaceRenderer.SKILL_BUTTON.intersects(game.InterfaceRenderer.QUEST_BUTTON), "HUD menu buttons do not overlap")
	expect(game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.PLAYER_PORTRAIT_RECT) and game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.CLOCK_BADGE), "portrait and calendar stay inside the carved top frame")
	expect(game.InterfaceRenderer.CLOCK_BADGE.encloses(game.InterfaceRenderer.CLOCK_WEATHER_RECT) and game.InterfaceRenderer.CLOCK_BADGE.encloses(game.InterfaceRenderer.CLOCK_TIME_RECT) and game.InterfaceRenderer.CLOCK_BADGE.encloses(game.InterfaceRenderer.CLOCK_CALENDAR_RECT), "clock icon time and calendar own separate centered safe areas")
	expect(game.InterfaceRenderer.HUD_RECT.encloses(game.InterfaceRenderer.LOCATION_BADGE), "persistent location badge stays inside compact HUD")
	expect(not game.InterfaceRenderer.LOCATION_BADGE.intersects(game.InterfaceRenderer.PLAYER_BARS_RECT) and not game.InterfaceRenderer.LOCATION_BADGE.intersects(game.InterfaceRenderer.SKILL_BUTTON), "location badge does not overlap player bars or menu buttons")
	expect(not game.InterfaceRenderer.PLAYER_BARS_RECT.intersects(game.InterfaceRenderer.CLOCK_BADGE) and not game.InterfaceRenderer.CLOCK_BADGE.intersects(game.InterfaceRenderer.LOCATION_BADGE), "second concept keeps portrait bars clock and location in separate modules")
	for weather in game.WorldEventSystem.WEATHER_NAMES:
		expect(game.InterfaceRenderer.weather_icon(weather) is AtlasTexture, "every weather state uses a sliced pixel-art icon: %s" % weather)
	var hud_sprites := [game.InterfaceRenderer.HUD_PORTRAIT_FRAME, game.InterfaceRenderer.HUD_STATUS_FRAME, game.InterfaceRenderer.HUD_CLOCK_FRAME, game.InterfaceRenderer.HUD_LOCATION_FRAME, game.InterfaceRenderer.HUD_SKILL_BUTTON, game.InterfaceRenderer.HUD_QUEST_BUTTON]
	for sprite in hud_sprites:
		expect(sprite is AtlasTexture and sprite.region.size.y == 96.0, "every top HUD module is a real slice of the native grandmother-style production atlas")
	expect(game.InterfaceRenderer.HUD_PORTRAIT_FRAME.atlas.resource_path.ends_with("grandmother_hud_atlas_v2.png"), "top HUD uses its own authored wood parchment and brass art instead of stretching inventory pixels")
	expect(game.InterfaceRenderer.HUD_SKILL_ICON.get_size() == Vector2(72, 72) and game.InterfaceRenderer.HUD_QUEST_ICON.get_size() == Vector2(72, 72), "new HUD keeps readable pixel-art book and scroll icons inside its authored button frames")
	expect(game.InterfaceRenderer.HUD_PORTRAIT_FRAME.region.end.x == game.InterfaceRenderer.HUD_STATUS_FRAME.region.position.x, "portrait and status atlas slices meet at the authored divider")
	expect(game.InterfaceRenderer.HUD_STATUS_FRAME.region.end.x == game.InterfaceRenderer.HUD_CLOCK_FRAME.region.position.x, "status and clock atlas slices meet at the authored divider")
	expect(game.InterfaceRenderer.HUD_CLOCK_FRAME.region.end.x == game.InterfaceRenderer.HUD_LOCATION_FRAME.region.position.x, "clock and location atlas slices meet at the authored divider")
	expect(game.InterfaceRenderer.HUD_LOCATION_FRAME.region.end.x == game.InterfaceRenderer.HUD_SKILL_BUTTON.region.position.x, "location and skill atlas slices meet at the authored divider")
	expect(game.InterfaceRenderer.HUD_SKILL_BUTTON.region.end.x == game.InterfaceRenderer.HUD_QUEST_BUTTON.region.position.x, "skill book and quest scroll use adjacent authored sprites")
	game.FarmLifeSystem.state(game).reputation = 17
	expect(game.InterfaceRenderer.HudRenderer.secondary_summary(game).contains("20") and game.InterfaceRenderer.HudRenderer.secondary_summary(game).contains("17"), "location module combines coins and reputation without a duplicate bottom calendar")
	var farm_life_source := FileAccess.get_file_as_string("res://scripts/systems/farm_life_renderer.gd")
	expect(not farm_life_source.contains("Rect2(14,610,330,26)"), "legacy bottom calendar strip no longer competes with the clock and hotbar")
	var hud_preview: Texture2D = load("res://assets/generated/ui/hud_ingame_preview.png")
	var preview_size := hud_preview.get_size() if hud_preview != null else Vector2.ZERO
	expect(hud_preview != null and preview_size.x >= 1152.0 and is_equal_approx(preview_size.x / preview_size.y, 16.0 / 9.0), "clean HUD reference preserves the native sixteen-by-nine visual-test canvas at fullscreen resolution")
	game.quest_active = true
	game.mission_states["hud_test"] = "active"
	expect(game.InterfaceRenderer.active_quest_count(game) == 2, "quest scroll badge counts active story and side missions without keyboard letters")
	for location in game.WorldSystem.LOCATIONS:
		expect(not game.InterfaceRenderer.location_icon(location).is_empty(), "location badge has an icon for %s" % location)
	for location in game.BuildingSystem.INTERIORS:
		expect(not game.InterfaceRenderer.location_icon(location).is_empty(), "interior location badge has an icon for %s" % location)
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale)
		expect(not game.LocaleSystem.ui("location_label", [game.WorldSystem.name("cave")]).is_empty(), "persistent location name is localized for %s" % locale)
	game.LocaleSystem.set_locale("ru")
	expect(game.InterfaceRenderer.HOTBAR_SLOT_SIZE == game.InterfaceRenderer.INVENTORY_HOTBAR_SIZE, "world and inventory quick slots use the same approved dimensions")
	expect(is_equal_approx(game.InterfaceRenderer.HOTBAR_PITCH, game.InterfaceRenderer.INVENTORY_HOTBAR_PITCH), "world and inventory quick slots use the same spacing")
	for index in 10:
		var rect: Rect2 = game.InterfaceRenderer.hotbar_rect(index)
		expect(game.InterfaceRenderer.VIEWPORT.encloses(rect), "world quick slot %d stays inside the viewport" % index)
		expect(game.InterfaceRenderer.WORLD_HOTBAR_PANEL.encloses(rect), "world quick slot %d stays inside the inventory-style wooden panel" % index)
		expect(game.InterfaceRenderer.hotbar_at(rect.get_center()) == index, "world quick slot touch maps to %d" % index)
	game.free()


## Сценарий: касание выбирает предмет, назначает его в панель быстрого доступа и употребляет через контекстную кнопку.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_inventory_touch_actions() -> void:
	var game := make_game()
	game.carrots = 1
	game.open_inventory()
	var select_touch := InputEventScreenTouch.new()
	select_touch.position = game.InterfaceRenderer.inventory_slot_rect(1).get_center()
	select_touch.pressed = true
	expect(game.handle_gamepad_and_touch(select_touch) and game.inventory_selected == 1, "touch selects the redesigned inventory slot")
	var assign_touch := InputEventScreenTouch.new()
	assign_touch.position = game.InterfaceRenderer.inventory_hotbar_rect(7).get_center()
	assign_touch.pressed = true
	expect(game.handle_gamepad_and_touch(assign_touch) and game.hotbar_slots[7] == "carrot", "touch assigns selected item in redesigned quick access")
	game.player_hp = 40
	var use_touch := InputEventScreenTouch.new()
	use_touch.position = game.InterfaceRenderer.USE_BUTTON.get_center()
	use_touch.pressed = true
	expect(game.handle_gamepad_and_touch(use_touch) and game.player_hp == 55, "touch context button consumes selected food")
	game.free()


## Сценарий: мышь перетаскивает предметы, выполняет действие правой кнопкой и выбирает панель быстрого доступа.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_mouse_drag_context_and_hotbar() -> void:
	var game := make_game()
	game.open_inventory()
	var visible_indices: Array[int] = game.InventorySystem.filtered_indices(game)
	var first_index := visible_indices[0]
	var target_index := visible_indices[5]
	var first_kind: String = game.inventory_slots[first_index]
	var target_kind: String = game.inventory_slots[target_index]
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = game.InterfaceRenderer.inventory_slot_rect(0).get_center()
	press.pressed = true
	expect(game.handle_gamepad_and_touch(press) and game.inventory_move_from == first_index, "left mouse press starts inventory drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = game.InterfaceRenderer.inventory_slot_rect(5).get_center()
	release.pressed = false
	expect(game.handle_gamepad_and_touch(release) and game.inventory_slots[target_index] == first_kind and game.inventory_slots[first_index] == target_kind, "mouse drag swaps two inventory slots")
	game.carrots = 1
	game.inventory_selected = game.inventory_slots.find("carrot")
	var carrot_position: int = game.InventorySystem.filtered_indices(game).find(game.inventory_selected)
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = game.InterfaceRenderer.inventory_slot_rect(carrot_position).get_center()
	right_click.pressed = true
	game.player_hp = 40
	game.handle_inventory_input(right_click)
	expect(game.player_hp == 55 and game.carrots == 0, "right click uses edible inventory item contextually")
	game.inventory_open = false
	var hotbar_click := InputEventMouseButton.new()
	hotbar_click.button_index = MOUSE_BUTTON_LEFT
	hotbar_click.position = game.InterfaceRenderer.hotbar_rect(4).get_center()
	hotbar_click.pressed = true
	expect(game.handle_gamepad_and_touch(hotbar_click) and game.selected_hotbar == 4, "mouse selects a world quick slot")
	game.free()


## Сценарий: сортировка группирует предметы по назначению и сохраняет текущий выбор.
## Исходное состояние: новая игра со стандартным рюкзаком; нужные количества предметов и открытые окна задаются сценарием.
## Ожидаемый результат: все перечисленные переходы и итоговые значения совпадают с контрактом сценария.
func test_inventory_sorting() -> void:
	var game := make_game()
	for kind in game.state.inventory.counts: game.state.inventory.counts[kind] = 0
	game.has_pickaxe = true
	game.change_inventory_count("carrot", 1)
	game.change_inventory_count("iron_helmet", 1)
	game.change_inventory_count("moon_relic", 1)
	game.change_inventory_count("stone", 1)
	for index in game.inventory_slots.size(): game.inventory_slots[index] = ""
	game.inventory_slots[0] = "stone"
	game.inventory_slots[1] = "iron_helmet"
	game.inventory_slots[2] = "carrot"
	game.inventory_slots[3] = "pickaxe"
	game.inventory_slots[4] = "moon_relic"
	game.inventory_selected = 2
	game.InventorySystem.sort_slots(game)
	expect(game.inventory_slots.slice(0, 5) == ["pickaxe", "carrot", "iron_helmet", "moon_relic", "stone"], "sorting groups tools food equipment quests and resources")
	expect(game.inventory_slots[game.inventory_selected] == "carrot" and game.inventory_scroll_row == 0, "sorting preserves selected item and returns to the first row")
	expect(game.message == game.LocaleSystem.text("inventory_sorted"), "sorting provides localized feedback")
	game.free()


## Сценарий: сообщения, обучение и боевые кнопки используют независимые области двух новых пиксельных атласов.
## Исходное состояние: оба PNG импортированы Godot, а их области и экранные прямоугольники объявлены рендерером.
## Ожидаемый результат: каждый вырез находится внутри своего атласа, карточки не перекрывают хотбар, а кнопки сохраняют прежние зоны касания.
func test_sprite_cards_and_action_controls_use_sliced_atlases() -> void:
	var game := make_game()
	var renderer = game.InterfaceRenderer
	expect(renderer.CONTROL_ATLAS != null and renderer.CARD_ATLAS != null, "control and parchment atlases are imported as real textures")
	var control_bounds := Rect2(Vector2.ZERO, renderer.CONTROL_ATLAS.get_size())
	for source in renderer.CONTROL_DODGE_SOURCES + renderer.CONTROL_BLOCK_SOURCES + [renderer.CONTROL_PAUSE_SOURCE]:
		expect(control_bounds.encloses(source), "every action-state sprite is sliced inside the control atlas")
	var card_bounds := Rect2(Vector2.ZERO, renderer.CARD_ATLAS.get_size())
	for source in [renderer.CARD_MESSAGE_SOURCE, renderer.CARD_TUTORIAL_SOURCE, renderer.CARD_DISCOVERY_SOURCE, renderer.CARD_QUEST_SOURCE]:
		expect(card_bounds.encloses(source), "every parchment component is sliced inside the card atlas")
	expect(not renderer.MESSAGE_CARD.intersects(renderer.WORLD_HOTBAR_PANEL) and not renderer.TUTORIAL_CARD.intersects(renderer.HUD_RECT), "parchment notifications preserve the playable viewport and quick bar")
	expect(renderer.DODGE_BUTTON.size == Vector2(60, 48) and renderer.BLOCK_BUTTON.size == Vector2(60, 48), "sprite buttons preserve stable touch hit targets")
	game.free()


## Сценарий: мобильные кнопки появляются после касания и автоматически скрываются после клавиатуры или мыши.
## Исходное состояние: игра запущена на обычной desktop-среде без активного сенсорного режима.
## Ожидаемый результат: последнее реальное устройство ввода однозначно переключает только видимость мобильного слоя.
func test_touch_controls_follow_last_input_device() -> void:
	var game := make_game(); game.touch_controls_visible = false
	var touch := InputEventScreenTouch.new(); touch.position = game.InterfaceRenderer.DODGE_BUTTON.get_center(); touch.pressed = true
	game.update_input_device(touch)
	expect(game.touch_controls_visible, "screen touch reveals sprite combat controls")
	var keyboard := key_event(KEY_D, KEY_D, true)
	game.update_input_device(keyboard)
	expect(not game.touch_controls_visible, "keyboard input hides mobile controls immediately")
	game.touch_controls_visible = true
	var mouse := InputEventMouseButton.new(); mouse.button_index = MOUSE_BUTTON_LEFT; mouse.position = Vector2(500, 300); mouse.pressed = false
	game.update_input_device(mouse)
	expect(not game.touch_controls_visible, "mouse input also restores the clean desktop HUD")
	game.free()


## Сценарий: хотбар показывает готовность инструмента, а HUD запускает короткие реакции на урон, монеты, время и погоду.
## Исходное состояние: эталонные значения HUD сначала синхронизированы, затем энергия, здоровье, монеты и игровая минута изменены.
## Ожидаемый результат: готовность пропорциональна энергии, а все соответствующие таймеры анимации становятся положительными.
func test_hotbar_readiness_and_hud_feedback_animations() -> void:
	var game := make_game(); game.hotbar_slots[0] = "hoe"; game.energy = game.SkillSystem.max_stamina(game)
	expect(is_equal_approx(game.InterfaceRenderer.hotbar_readiness(game, "hoe"), 1.0), "full stamina renders a ready tool condition bar")
	game.energy = game.SkillSystem.max_stamina(game) / 2
	expect(game.InterfaceRenderer.hotbar_readiness(game, "hoe") < 0.6, "spent stamina visibly lowers tool readiness")
	game.update_hud_feedback(0.0)
	game.player_hp -= 3; game.coins += 2; game.game_minutes += 1.0
	game.update_hud_feedback(0.01)
	expect(game.hud_hp_flash > 0.0 and game.hud_coin_pop > 0.0 and game.hud_clock_tick > 0.0, "damage coin and clock changes each start their HUD feedback")
	game.hud_last_weather = "impossible_weather"
	game.update_hud_feedback(0.01)
	expect(game.hud_weather_transition > 0.0, "weather change starts a soft icon transition")
	game.free()

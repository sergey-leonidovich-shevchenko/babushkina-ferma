extends "res://tests/suites/suite_base.gd"

const QuickAccess := preload("res://scripts/presentation/quick_access_renderer.gd")


## Проверяет геометрию компактной панели, читаемость количества и реальный ввод в её ячейки.
func run() -> void:
	test_world_grid_and_inventory_size()
	test_quantity_bounds_and_abbreviations()
	test_labels_fit_all_locales_at_larger_scale()
	test_mouse_and_touch_match_new_slot_art()


## Сценарий: все десять мировых слотов сравниваются с геометрией рисунка, хитбоксами и большим рюкзаком.
## Исходное состояние: новая игра, компактная панель по центру нижнего края; инвентарная панель остаётся прежней.
## Ожидаемый результат: одинаковые квадраты без пересечений, иконки центрированы, отступы панели не меньше четырёх пикселей.
func test_world_grid_and_inventory_size() -> void:
	var game := make_game()
	for index in QuickAccess.SLOT_COUNT:
		var rect: Rect2 = game.InterfaceRenderer.hotbar_rect(index)
		var icon: Rect2 = game.InterfaceRenderer.hotbar_icon_rect(rect)
		expect(rect == QuickAccess.world_slot_rect(index), "world render and input share quick slot %d" % index)
		expect(rect.size == Vector2(48,48) and rect.position == rect.position.round(), "world slot has stable integer square geometry")
		expect(QuickAccess.WORLD_PANEL.grow(-4).encloses(rect), "world slot stays inside the compact backing")
		expect(rect.grow(-8).encloses(icon) and icon.get_center().is_equal_approx(rect.get_center()), "quick item keeps centered eight-pixel padding")
		expect(game.InterfaceRenderer.inventory_hotbar_rect(index).size.x > game.InterfaceRenderer.hotbar_rect(index).size.x and game.InterfaceRenderer.inventory_hotbar_rect(index).size.y > game.InterfaceRenderer.hotbar_rect(index).size.y, "inventory quick slot remains larger than world quick access")
		if index < QuickAccess.SLOT_COUNT-1:
			var next := QuickAccess.world_slot_rect(index+1)
			expect(is_equal_approx(next.position.x-rect.end.x,4.0) and not rect.intersects(next), "adjacent quick slots keep exactly four pixels of separation")
	expect(is_equal_approx(QuickAccess.WORLD_PANEL.get_center().x,576.0), "compact quick panel stays horizontally centered")
	game.free()


## Сценарий: пустые, обычные и очень большие стопки получают подписи количества.
## Исходное состояние: набор включает граничные значения тысяч, миллионов и максимальный безопасный счётчик.
## Ожидаемый результат: единица скрыта, сокращения не завышают количество, подпись отделена от шкалы готовности.
func test_quantity_bounds_and_abbreviations() -> void:
	for pair in [[-1,""],[0,""],[1,""],[2,"2"],[999,"999"],[1000,"1k"],[1099,"1k"],[1100,"1.1k"],[9999,"9.9k"],[10000,"10k"],[999999,"999k"],[1000000,"1M"],[1234567,"1.2M"],[999999999,"999M"],[1000000000,"1B+"],[9223372036854775807,"1B+"]]:
		expect(QuickAccess.quantity_text(pair[0]) == pair[1], "compact stack count: %d" % pair[0])
	for size in [Vector2(48,48),Vector2(66,65)]:
		var slot := Rect2(Vector2(207,543),size)
		var count := QuickAccess.quantity_rect(slot)
		var readiness := QuickAccess.readiness_rect(slot)
		var key := QuickAccess.hotkey_rect(slot)
		expect(slot.grow(-2).encloses(count) and slot.grow(-2).encloses(key) and slot.grow(-2).encloses(readiness), "all quick labels remain inside their frame")
		expect(not count.intersects(readiness) and count.end.y <= readiness.position.y-2, "quantity cannot collide with tool readiness")
		expect(not key.intersects(count), "hotkey and quantity have separate corners")


## Сценарий: подписи количества рисуются на каждой локали при масштабе текста 120%.
## Исходное состояние: используются настоящий игровой шрифт и те же области, что у production-отрисовщика.
## Ожидаемый результат: цифры целиком помещаются по обеим осям; рюкзак и компактный HUD не нуждаются в обрезке.
func test_labels_fit_all_locales_at_larger_scale() -> void:
	var game := make_game()
	var old_locale: String = game.LocaleSystem.current
	game.settings_state.text_scale = 1.2
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.current = locale
		for rect in [game.InterfaceRenderer.hotbar_rect(0),game.InterfaceRenderer.inventory_hotbar_rect(0)]:
			for count in [2,99,999,9900,999999,999999999,1000000000]:
				var label := QuickAccess.quantity_text(count)
				var area := QuickAccess.quantity_rect(rect)
				var size := QuickAccess.label_font_size(game,area,label,9)
				var font: Font = game.UI_FONT
				expect(font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x <= area.size.x+0.1 and font.get_height(size) <= area.size.y+0.1, "quick quantity fits at 120 percent in %s: %s" % [locale,label])
	game.LocaleSystem.current = old_locale
	game.free()


## Сценарий: мышь и палец выбирают каждый компактный слот после его переноса ближе к нижнему краю.
## Исходное состояние: игровые окна закрыты, на панели назначены предметы, инструмент ещё не применялся.
## Ожидаемый результат: центры настоящих рисунков выбирают соответствующие индексы, промежутки не принадлежат слотам.
func test_mouse_and_touch_match_new_slot_art() -> void:
	var game := make_game()
	var energy: int = game.energy
	for index in QuickAccess.SLOT_COUNT:
		var rect := QuickAccess.world_slot_rect(index)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = true; mouse.position = rect.get_center()
		expect(game.handle_gamepad_and_touch(mouse) and game.selected_hotbar == index, "mouse selects compact quick slot %d" % index)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true; touch.position = rect.get_center()
		expect(game.handle_gamepad_and_touch(touch) and game.selected_hotbar == index, "touch selects compact quick slot %d" % index)
		if index < QuickAccess.SLOT_COUNT-1:
			expect(game.InterfaceRenderer.hotbar_at(Vector2(rect.end.x+2,rect.get_center().y)) == -1, "quick slot gap remains non-interactive")
	expect(game.energy == energy, "quick selection does not apply the tool behind the HUD")
	game.free()

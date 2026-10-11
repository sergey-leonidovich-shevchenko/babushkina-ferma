extends "res://tests/suites/suite_base.gd"

const Chrome := preload("res://scripts/presentation/hud_chrome_system.gd")


## Проверяет размеры компактного HUD, непересекающиеся элементы и реальные метрики шести локалей при 120%.
func run() -> void:
	test_compact_geometry_and_free_playfield()
	test_status_tracks_and_extreme_values()
	test_localized_labels_at_large_text_scale()


## Сценарий: новая раскладка заменяет старые блоки 318×80, 216×80 и нижнюю панель с названием предмета.
## Исходное состояние: доступны единые прямоугольники рендера, ввода и камеры.
## Ожидаемый результат: статус и часы заметно меньше, кнопки не мельче сенсорного минимума, камера получает освободившееся место.
func test_compact_geometry_and_free_playfield() -> void:
	var game := make_game()
	expect(Chrome.STATUS.get_area() < 318.0 * 80.0 * 0.7, "status panel occupies at least thirty percent less area")
	expect(Chrome.CLOCK.get_area() < 216.0 * 80.0 * 0.65, "clock removes the oversized decorative frame")
	var modules: Array[Rect2] = [Chrome.STATUS, Chrome.CLOCK, Chrome.LOCATION, Chrome.SUMMARY, Chrome.SKILLS, Chrome.QUESTS]
	for index in modules.size():
		expect(Chrome.HUD_RECT.encloses(modules[index]), "compact module stays inside the eighty-pixel top reserve")
		for other in range(index + 1, modules.size()):
			expect(not modules[index].intersects(modules[other]), "compact header modules never overlap")
	for rect in [Chrome.PORTRAIT_IMAGE, Chrome.LEVEL, Chrome.EXPERIENCE]:
		expect(Chrome.PORTRAIT.encloses(rect), "portrait image level and experience remain within their own column")
	for rect in [Chrome.WEATHER, Chrome.TIME, Chrome.CALENDAR]:
		expect(Chrome.CLOCK.encloses(rect), "clock weather time and date have separate padded content areas")
	expect(not Chrome.TIME.intersects(Chrome.WEATHER) and not Chrome.CALENDAR.intersects(Chrome.TIME), "clock labels never cover the weather sprite")
	expect(Chrome.SKILLS.size.x >= 48 and Chrome.QUESTS.size.y >= 48, "compact menu buttons retain the touch target minimum")
	var field: Rect2 = game.CameraSystem.playfield_rect(game)
	expect(field.position.y == Chrome.HUD_RECT.end.y and field.end.y == game.InterfaceRenderer.WORLD_HOTBAR_PANEL.position.y, "camera uses the actual compact HUD reserves")
	expect(field.size.y >= 500, "compact HUD restores at least five hundred design pixels of vertical playfield")
	game.free()


## Сценарий: здоровье, мана и энергия пусты, заполнены либо временно вышли за пределы максимума.
## Исходное состояние: все три строки используют один профиль толщины и полей.
## Ожидаемый результат: шкалы и цифры разделены, заполнение ограничено дорожкой, переполнение значения не меняет геометрию.
func test_status_tracks_and_extreme_values() -> void:
	for index in 3:
		var row := Chrome.stat_row(index)
		var parts := Chrome.stat_parts(row)
		expect(Chrome.BARS.encloses(row), "stat row remains inside the shared status panel")
		for rect in parts.values(): expect(row.encloses(rect), "stat label track and number each have padded bounds")
		expect(not Rect2(parts.label).intersects(parts.track) and not Rect2(parts.track).intersects(parts.value), "stat numbers never cover the fill")
		for ratio in [-1.0, 0.0, 0.01, 0.5, 1.0, 2.0]:
			var fill := Chrome.fill_rect(parts.track, ratio)
			expect(Rect2(parts.track).encloses(fill) and fill.size.x >= 0, "stat fill clamps negative and overflowing ratios")


## Сценарий: на всех шести языках включены 120%, поздний день, длинная локация и большие числовые значения.
## Исходное состояние: используются настоящий UI-шрифт и тот же расчёт базовой линии, что при рисовании HUD.
## Ожидаемый результат: ширина и высота текста укладываются в прямоугольник, кегль остаётся читаемым без выхода за рамки.
func test_localized_labels_at_large_text_scale() -> void:
	var game := make_game()
	game.settings_state.text_scale = 1.2
	for locale in game.LocaleSystem.LOCALES:
		game.LocaleSystem.set_locale(locale, false)
		var samples := [[Chrome.TIME, "23:59", 20], [Chrome.LEVEL, game.LocaleSystem.ui("level_short", [20]), 8], [Chrome.LOCATION_TITLE, game.WorldSystem.name("cottage_interior"), 11], [Chrome.SUMMARY, "● 999999   ★ 9999", 9]]
		for season in ["spring", "summer", "autumn", "winter"]:
			samples.append([Chrome.CALENDAR, "%s  •  %s" % [game.LocaleSystem.ui("day_short", [9999]), game.LocaleSystem.ui("season_" + season)], 9])
		for value in ["0/100", "100/100", "9999/9999"]:
			samples.append([Chrome.stat_parts(Chrome.stat_row(0)).value, value, 9])
		for sample in samples:
			var rect: Rect2 = sample[0]
			var text := String(sample[1])
			var layout := Chrome.text_layout(game, rect, text, sample[2])
			var size := int(layout.size)
			var top: float = layout.baseline.y - game.UI_FONT.get_ascent(size)
			var bottom: float = layout.baseline.y + game.UI_FONT.get_descent(size)
			expect(game.UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= rect.size.x + 0.01, "compact text fits horizontally at 120 percent in %s: %s" % [locale, text])
			expect(top >= rect.position.y - 0.5 and bottom <= rect.end.y + 0.5 and size >= 7, "compact text preserves vertical padding and legibility in %s" % locale)
	game.free()

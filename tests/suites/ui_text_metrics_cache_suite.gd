extends "res://tests/suites/suite_base.gd"

const Cache := preload("res://scripts/systems/ui_text_metrics_cache_system.gd")
const Scale := preload("res://scripts/systems/ui_scale_system.gd")
const DebugKit := preload("res://scripts/systems/debug_ui_kit_system.gd")


## Запускает независимые проверки эквивалентности, ключа и ограниченной памяти кеша текстовых метрик.
func run() -> void:
	test_results_match_original_algorithms()
	test_bounded_lines_account_for_tall_fallback()
	test_cache_key_and_changed_font()
	test_memory_is_bounded_and_labels_are_copies()
	Cache.clear()


## Сценарий: подписи шести языков встречаются в узких и широких контейнерах при нескольких масштабах текста.
## Исходное состояние: исходный шрифт UI, пустые и длинные строки, отрицательная ширина и слишком большой запрос кегля.
## Ожидаемый результат: кешированный путь дословно совпадает с прежними циклами shrink и ellipsis, включая минимум6 и неограниченную ширину.
func test_results_match_original_algorithms() -> void:
	Cache.clear(); var game := make_game()
	var labels := ["Рюкзак и инструменты", "Crafting equipment", "Inventario y herramientas", "Ausrüstungsgegenstände", "Équipement et fabrication", "背包与制造工具", ""]
	for label in labels:
		for factor in [0.9, 1.0, 1.2]:
			game.settings_state.text_scale = factor
			for width in [-1.0, 1.0, 76.5, 260.0]:
				expect(Scale.fitted_font_size(game, game.UI_FONT, label, width, 24) == _original_size(game.UI_FONT, label, width, 0, 24, factor), "Однострочный кегль совпадает с исходным: %s/%s/%s" % [label, factor, width])
			for area in [Vector2(1, 1), Vector2(76.5, 24), Vector2(260, 80), Vector2(76, 0)]:
				expect(Scale.fitted_multiline_font_size(game, game.UI_FONT, label, area.x, area.y, 24) == _original_size(game.UI_FONT, label, area.x, area.y, 24, factor, true), "Многострочный кегль совпадает с исходным: %s/%s/%s" % [label, factor, area])
		for width in [0.0, 12.0, 80.0, 300.0]:
			expect(DebugKit.fit_label(game.UI_FONT, label, width, 18, 7) == _original_label(game.UI_FONT, label, width, 18, 7), "Подпись и многоточие остались дословно прежними: %s/%s" % [label, width])
	game.settings_state.text_scale = 1.2
	for requested in [-3, 0, 3, 6, 72]:
		expect(Scale.fitted_font_size(game, game.UI_FONT, "Очень длинная подпись", 12, requested) == _original_size(game.UI_FONT, "Очень длинная подпись", 12, 0, requested, 1.2), "Крайний запрошенный кегль сохраняет исходную семантику: %d" % requested)
	game.free()


## Сценарий: цифры используют обычную гарнитуру, а запасной шрифт увеличивает общую высоту строки.
## Исходное состояние: независимая копия UI-шрифта с высоким fallback, текст 120% и узкая подпись ресурса.
## Ожидаемый результат: целая строка помещается по обеим осям, остаётся читаемой и повторно берётся из кеша.
func test_bounded_lines_account_for_tall_fallback() -> void:
	Cache.clear(); var game := make_game()
	var font: Font = game.UI_FONT.duplicate()
	var fallback := FontFile.new(); fallback.data = FileAccess.get_file_as_bytes("res://assets/game/fonts/Alice-Regular.ttf")
	for point_size in range(6,17):
		fallback.get_height(point_size)
		fallback.set_cache_ascent(0,point_size,point_size*1.3)
		fallback.set_cache_descent(0,point_size,point_size*0.2)
	font.fallbacks = [fallback]
	game.settings_state.text_scale = 1.2
	var label := "999M"; var area := Vector2(60,18)
	expect(font.get_height(16) > font.get_multiline_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,100,16).y, "Fallback height exceeds the numeric glyph line")
	var glyph_size := Scale.fitted_multiline_font_size(game,font,label,area.x,area.y,13)
	expect(font.get_height(glyph_size) > area.y, "Numeric glyph metrics alone leave the full line outside its rectangle")
	var size := Scale.fitted_singleline_font_size(game,font,label,area.x,area.y,13)
	expect(size >= 6 and size < 16 and font.get_height(size) <= area.y and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x <= area.x, "Tall fallback fits without clipping or shrinking below the readable minimum")
	var misses: int = Cache.statistics().misses
	expect(Scale.fitted_singleline_font_size(game,font,label,area.x,area.y,13) == size and Cache.statistics().misses == misses and Cache.statistics().hits == 1, "Bounded labels reuse measured fallback metrics")
	var tighter := Scale.fitted_singleline_font_size(game,font,label,area.x,area.y-2,13)
	expect(tighter <= size and font.get_height(tighter) <= area.y-2 and Cache.statistics().misses == misses+1, "A shorter line has its own cached fit")
	game.free()


## Сценарий: одна подпись повторяется, затем меняются ширина, высота, масштаб и ресурс шрифта.
## Исходное состояние: пустой кеш и два отдельных FontVariation с одинаковой начальной базой; второй затем меняет межбуквенный интервал.
## Ожидаемый результат: повторы не вызывают подбор, разные ключи не смешиваются, сигнал changed удаляет устаревшие результаты только своей гарнитуры.
func test_cache_key_and_changed_font() -> void:
	Cache.clear(); var game := make_game()
	var first := FontVariation.new(); first.base_font = game.UI_FONT
	var second := FontVariation.new(); second.base_font = game.UI_FONT
	var text := "Длинная подпись"
	var initial := Cache.fitted_size(first, text, 150, 20, 18, 1.0)
	var misses: int = Cache.statistics().misses
	for repeat in 4: expect(Cache.fitted_size(first, text, 150, 20, 18, 1.0) == initial, "Повторный результат сохраняет тот же кегль")
	expect(Cache.statistics().misses == misses and Cache.statistics().hits == 4, "Повторные кадры обходятся без измерения текста")
	for values in [[150.0001,20.0,18,1.0,false],[150.0,21.0,18,1.0,false],[150.0,20.0,19,1.0,false],[150.0,20.0,18,1.2,false],[150.0,20.0,18,1.0,true]]:
		Cache.fitted_size(first, text, values[0], values[1], values[2], values[3], values[4])
	expect(Cache.statistics().misses == misses + 5, "Точные width/height/requested/scale и режим имеют отдельные записи")
	Cache.fitted_size(second, text, 150, 20, 18, 1.0)
	expect(Cache.statistics().fonts == 2 and Cache.statistics().misses == misses + 6, "Разные ресурсы и Font RID не смешивают метрики")
	var before_change: int = Cache.statistics().misses
	second.spacing_glyph = 18; second.emit_changed()
	var changed := Cache.fitted_size(second, text, 150, 20, 18, 1.0)
	expect(changed == _original_size(second, text, 150, 20, 18, 1.0) and changed < initial, "Изменённый spacing пересчитан по новым метрикам шрифта")
	expect(Cache.statistics().misses == before_change + 1, "Font.changed инвалидирует старое попадание")
	var before_hit: int = Cache.statistics().hits
	Cache.fitted_size(first, text, 150, 20, 18, 1.0)
	expect(Cache.statistics().hits == before_hit + 1, "Изменение второго шрифта не уничтожает кеш первого")
	game.free()


## Сценарий: часы/F10 выдают больше уникальных строк, чем может хранить кеш, а вызывающий код изменяет результат сокращённой подписи.
## Исходное состояние: пустой кеш; затем создаются512+37 строк, слишком длинная строка и больше32 временных гарнитур.
## Ожидаемый результат: FIFO и реестр шрифтов имеют жёсткие пределы, длинные строки не сохраняются, изменение возвращённого Dictionary не портит будущий кадр.
func test_memory_is_bounded_and_labels_are_copies() -> void:
	Cache.clear(); var game := make_game()
	for index in Cache.MAX_ENTRIES + 37: Cache.fitted_size(game.UI_FONT, "F10:%d" % index, 1000, 0, 10, 1.0)
	expect(Cache.statistics().entries == Cache.MAX_ENTRIES and Cache.statistics().slots == Cache.MAX_ENTRIES, "Таблица и FIFO не растут сверх512 записей")
	var misses: int = Cache.statistics().misses
	Cache.fitted_size(game.UI_FONT, "F10:0", 1000, 0, 10, 1.0)
	expect(Cache.statistics().misses == misses + 1 and Cache.statistics().entries == Cache.MAX_ENTRIES, "Старейшая строка вытеснена, новый расчёт сохраняет ограничение памяти")
	var entries: int = Cache.statistics().entries
	Cache.fitted_size(game.UI_FONT, "X".repeat(Cache.MAX_TEXT_LENGTH + 1), -1, 0, 10, 1.0)
	expect(Cache.statistics().entries == entries, "Очень длинный диагностический текст не удерживается в кеше")
	var label := DebugKit.fit_label(game.UI_FONT, "Уменьшенная подпись кнопки", 62, 15, 7)
	var expected := label.duplicate(); label.text = "испорчено"; label.size = 99
	expect(DebugKit.fit_label(game.UI_FONT, "Уменьшенная подпись кнопки", 62, 15, 7) == expected, "Подпись возвращается копией, а не изменяемой записью кеша")
	for index in Cache.MAX_FONTS + 3:
		var font := FontVariation.new(); font.base_font = game.UI_FONT
		Cache.fitted_size(font, "font", -1, 0, 10, 1.0)
	expect(Cache.statistics().fonts <= Cache.MAX_FONTS and Cache.statistics().entries <= Cache.MAX_ENTRIES, "Реестр временных шрифтов также ограничен и не хранит сильные ссылки")
	Cache.clear()
	expect(Cache.statistics().entries == 0 and Cache.statistics().slots == 0 and Cache.statistics().fonts == 0, "Явная очистка освобождает записи, кольцо и подписки")
	game.free()


## Сохраняет исходный цикл подбора как независимый эталон теста, не вызывая новый кеш.
func _original_size(font: Font, text: String, width: float, height: float, requested: int, scale: float, multiline: bool = false) -> int:
	var size := maxi(1, roundi(requested * scale))
	if width <= 0.0 or (multiline and height <= 0.0): return size
	if multiline:
		while size > 6 and font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y > height: size -= 1
	else:
		while size > 6 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: size -= 1
	return size


## Сохраняет исходный алгоритм debug-подписи с теми же порогами и порядком добавления многоточия.
func _original_label(font: Font, label: String, width: float, preferred: int, minimum: int) -> Dictionary:
	var size := preferred; var text := label
	while size > minimum and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: size -= 1
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width: return {"text":text, "size":size}
	while text.length() > 1 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: text = text.left(text.length() - 1)
	return {"text":text + "…", "size":size}

extends RefCounted

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")

## Рисует установленные в текущей локации крабовые ловушки как постоянные мировые объекты.
static func draw_traps(game: Node2D) -> void:
	for trap in game.state.fishing.traps:
		if String(trap.location) != game.current_location: continue
		var position := Vector2(trap.position)
		game.draw_item_icon("crab_trap", Rect2(position - Vector2(28, 28), Vector2(56, 56)))
		if game.day >= int(trap.ready_day):
			game.draw_circle(position + Vector2(20, -24), 8, Color("f3c75d"))
			game.draw_ui_string(game.UI_FONT, position + Vector2(14, -19), "!", HORIZONTAL_ALIGNMENT_CENTER, 12, 12, Color("47301d"))

const PANEL := Rect2(686, 96, 410, 438)
const WATER_TRACK := Rect2(718, 166, 126, 310)
const PROGRESS_TRACK := Rect2(864, 166, 26, 310)
const TENSION_TRACK := Rect2(906, 166, 18, 310)
const CAST_TRACK := Rect2(752, 205, 302, 30)


## Отрисовывает соответствующий текущей стадии самостоятельный интерфейс рыбалки.
static func draw(game: Node2D) -> void:
	var state = game.state.fishing
	if state.phase == game.FishingSystem.PHASE_IDLE: return
	if state.phase == game.FishingSystem.PHASE_CHARGING: _draw_cast_meter(game, state); return
	if state.phase == game.FishingSystem.PHASE_MINIGAME: _draw_minigame(game, state); return
	if state.phase == game.FishingSystem.PHASE_RESULT: _draw_result(game, state)


## Рисует качающуюся шкалу силы заброса с отдельной отметкой максимума.
static func _draw_cast_meter(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, Rect2(716, 136, 380, 168))
	game.draw_ui_string(game.UI_FONT, Vector2(738, 177), game.LocaleSystem.text("fish_cast_title"), HORIZONTAL_ALIGNMENT_CENTER, 336, 20, Color("fff0bd"))
	game.draw_rect(CAST_TRACK, Color("172a35"), true)
	for boundary in [0.36, 0.72]:
		var x: float = CAST_TRACK.position.x + CAST_TRACK.size.x * boundary
		game.draw_line(Vector2(x, CAST_TRACK.position.y), Vector2(x, CAST_TRACK.end.y), Color("d9c38b"), 1)
	var fill := Rect2(CAST_TRACK.position + Vector2(3, 3), Vector2((CAST_TRACK.size.x - 6) * state.cast_power, CAST_TRACK.size.y - 6))
	game.draw_rect(fill, Color("62c979").lerp(Color("f2c55c"), state.cast_power), true)
	var sweet_start := CAST_TRACK.position.x + CAST_TRACK.size.x * 0.82; var sweet_end := CAST_TRACK.position.x + CAST_TRACK.size.x * 0.98
	game.draw_rect(Rect2(sweet_start, CAST_TRACK.position.y, sweet_end - sweet_start, CAST_TRACK.size.y), Color("fff4a0"), false, 2)
	for index in 3:
		var key: String = ["shallow", "middle", "deep"][index]
		game.draw_ui_string(game.UI_FONT, Vector2(CAST_TRACK.position.x + index * CAST_TRACK.size.x / 3.0, 253), game.LocaleSystem.text("fish_depth_" + key), HORIZONTAL_ALIGNMENT_CENTER, CAST_TRACK.size.x / 3.0, 9, Color("b8d5dc"))
	game.draw_ui_string(game.UI_FONT, Vector2(738, 287), game.LocaleSystem.text("fish_release"), HORIZONTAL_ALIGNMENT_CENTER, 336, 12, Color("cbe9df"))


## Рисует вертикальный водяной трек, управляемую зону, рыбу, сундук и шкалу улова.
static func _draw_minigame(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, PANEL)
	game.draw_ui_string(game.UI_FONT, Vector2(706, 137), game.LocaleSystem.text("fish_minigame_title"), HORIZONTAL_ALIGNMENT_CENTER, 370, 20, Color("fff0bd"))
	game.draw_rect(WATER_TRACK, Color("183c56"), true)
	for stripe in 6:
		game.draw_rect(Rect2(WATER_TRACK.position + Vector2(0, stripe * 50), Vector2(WATER_TRACK.size.x, 25)), Color(0.16, 0.42, 0.58, 0.24), true)
	var bar_height: float = WATER_TRACK.size.y * state.bar_size
	var bar_center: float = WATER_TRACK.position.y + WATER_TRACK.size.y * state.bar_y
	var bar_rect := Rect2(WATER_TRACK.position.x + 5, bar_center - bar_height * 0.5, WATER_TRACK.size.x - 10, bar_height)
	game.draw_rect(bar_rect, Color(0.25, 0.78, 0.35, 0.78), true)
	game.draw_rect(bar_rect, Color("bdf58e"), false, 3)
	var fish_position := Vector2(WATER_TRACK.position.x + 59, WATER_TRACK.position.y + WATER_TRACK.size.y * state.fish_y)
	_draw_fish_icon(game, fish_position)
	if state.treasure_visible and not state.treasure_caught and state.elapsed >= state.treasure_appears_at:
		_draw_treasure(game, Vector2(WATER_TRACK.end.x - 23, WATER_TRACK.position.y + WATER_TRACK.size.y * state.treasure_y), state.treasure_progress)
	game.draw_rect(PROGRESS_TRACK, Color("172a35"), true)
	var progress_height: float = (PROGRESS_TRACK.size.y - 6) * state.catch_progress
	var progress_rect := Rect2(PROGRESS_TRACK.position + Vector2(3, PROGRESS_TRACK.size.y - 3 - progress_height), Vector2(PROGRESS_TRACK.size.x - 6, progress_height))
	game.draw_rect(progress_rect, Color("e9bd4f").lerp(Color("6fd978"), state.catch_progress), true)
	game.draw_rect(PROGRESS_TRACK, Color("d6eadb"), false, 2)
	game.draw_rect(TENSION_TRACK, Color("172a35"), true)
	var tension_height: float = (TENSION_TRACK.size.y - 6) * state.line_tension
	var tension_rect := Rect2(TENSION_TRACK.position + Vector2(3, TENSION_TRACK.size.y - 3 - tension_height), Vector2(TENSION_TRACK.size.x - 6, tension_height))
	game.draw_rect(tension_rect, Color("e3b24e").lerp(Color("d84d45"), state.line_tension), true); game.draw_rect(TENSION_TRACK, Color("d6eadb"), false, 2)
	var info_x := 940.0
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 188), state.fish_name, HORIZONTAL_ALIGNMENT_LEFT, 132, 12, Color("fff0bd"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 211), game.LocaleSystem.text("fish_rarity_" + state.fish_rarity), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, _rarity_color(state.fish_rarity))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 235), game.LocaleSystem.text("fish_behavior_" + state.fish_behavior), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("cbe9df"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 259), game.LocaleSystem.text("fish_depth_" + state.depth_kind) + " • " + game.LocaleSystem.text("fish_water_" + state.water_kind), HORIZONTAL_ALIGNMENT_LEFT, 132, 8, Color("a9c9d8"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 291), game.LocaleSystem.text("fish_hook_" + state.hook_grade), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("e7c66e"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 326), game.LocaleSystem.text("fish_catch_progress", [roundi(state.catch_progress * 100.0)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 10, Color("fff0bd"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 352), game.LocaleSystem.text("fish_tension", [roundi(state.line_tension * 100.0)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("f2a063") if state.line_tension >= 0.65 else Color("cbe9df"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 378), game.LocaleSystem.text("fish_streak", [FishingBalanceText.seconds(state.control_streak), FishingBalanceText.multiplier(state.control_streak)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("91df89"))
	var control_lines: PackedStringArray = game.LocaleSystem.text("fish_hold_hint").split("\n")
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 420), control_lines[0] + " / " + control_lines[1], HORIZONTAL_ALIGNMENT_CENTER, 132, 9, Color("d6eadb"))
	if state.perfect: game.draw_ui_string(game.UI_FONT, Vector2(info_x, 461), "★ PERFECT", HORIZONTAL_ALIGNMENT_CENTER, 132, 14, Color("f6d85d"))


## Рисует краткую карточку результата, чтобы качество и рекорд не терялись в общем HUD.
static func _draw_result(game: Node2D, state: RefCounted) -> void:
	var rect := Rect2(650, 172, 446, 220); _draw_panel(game, rect)
	game.draw_ui_string(game.UI_FONT, Vector2(672, 211), game.LocaleSystem.text("fish_catch_title") if state.catch_progress >= 1.0 else game.LocaleSystem.text("fish_escaped"), HORIZONTAL_ALIGNMENT_CENTER, 402, 20, Color("fff0bd"))
	if state.catch_progress < 1.0:
		game.draw_ui_string(game.UI_FONT, Vector2(672, 258), game.LocaleSystem.text("fish_escape_" + state.escape_reason), HORIZONTAL_ALIGNMENT_CENTER, 402, 13, Color("f0b092"))
		game.draw_ui_string(game.UI_FONT, Vector2(672, 322), game.LocaleSystem.text("fish_result_close"), HORIZONTAL_ALIGNMENT_CENTER, 402, 10, Color("b9cfcb")); return
	game.draw_item_icon("fish", Rect2(684, 232, 88, 88))
	game.draw_ui_string(game.UI_FONT, Vector2(792, 247), state.fish_name, HORIZONTAL_ALIGNMENT_LEFT, 270, 15, Color("fff0bd"))
	game.draw_ui_string(game.UI_FONT, Vector2(792, 274), "%d %s • %s" % [state.fish_size, game.LocaleSystem.text("fish_cm"), game.LocaleSystem.text("quality_" + state.quality)], HORIZONTAL_ALIGNMENT_LEFT, 270, 11, Color("d6eadb"))
	game.draw_ui_string(game.UI_FONT, Vector2(792, 299), game.LocaleSystem.text("fish_result_xp", [state.experience_awarded]), HORIZONTAL_ALIGNMENT_LEFT, 270, 10, Color("91df89"))
	if state.new_record: game.draw_ui_string(game.UI_FONT, Vector2(792, 325), game.LocaleSystem.text("fish_new_record"), HORIZONTAL_ALIGNMENT_LEFT, 270, 11, Color("f6d85d"))
	game.draw_ui_string(game.UI_FONT, Vector2(672, 370), game.LocaleSystem.text("fish_result_close"), HORIZONTAL_ALIGNMENT_CENTER, 402, 10, Color("b9cfcb"))


## Рисует оригинальную процедурную пиктограмму рыбы без копирования чужих игровых материалов.
static func _draw_fish_icon(game: Node2D, position: Vector2) -> void:
	game.draw_item_icon("fish",Rect2(position-Vector2(18,18),Vector2(36,36)))


## Рисует сундук и компактный круговой индикатор его отдельного заполнения.
static func _draw_treasure(game: Node2D, position: Vector2, progress: float) -> void:
	game.draw_item_icon("home_chest",Rect2(position-Vector2(15,15),Vector2(30,30)))
	game.draw_arc(position, 15, -PI * 0.5, -PI * 0.5 + TAU * progress, 20, Color("8df08c"), 3)


## Рисует рыбацкую карточку общей резной панелью вместо отдельной процедурной рамки.
static func _draw_panel(game: Node2D, rect: Rect2) -> void:
	UiKitSystem.draw_modal_panel(game,rect,false)


## Возвращает устойчивый цвет редкости для быстрой оценки рыбы без чтения длинного текста.
static func _rarity_color(rarity: String) -> Color:
	return {"common":Color("c8d4c3"), "uncommon":Color("8fd89a"), "rare":Color("73b8ef"), "legendary":Color("dba5f2")}.get(rarity, Color.WHITE)


## Внутренний форматтер сохраняет renderer компактным и не смешивает числа с правилами баланса.
class FishingBalanceText:
	## Форматирует длительность серии управления с одной цифрой после запятой.
	static func seconds(value: float) -> String: return "%.1fs" % value
	## Форматирует ограниченный множитель серии тем же правилом, что применяет механика.
	static func multiplier(value: float) -> String: return "x%.1f" % (1.0 + minf(maxf(value, 0.0) / 5.0, 0.6))

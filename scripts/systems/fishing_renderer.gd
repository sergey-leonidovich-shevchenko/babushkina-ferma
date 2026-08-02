extends RefCounted

const PANEL := Rect2(770, 104, 326, 414)
const WATER_TRACK := Rect2(816, 158, 118, 300)
const PROGRESS_TRACK := Rect2(956, 158, 28, 300)
const CAST_TRACK := Rect2(816, 205, 234, 28)


## Отрисовывает соответствующий текущей стадии самостоятельный интерфейс рыбалки.
static func draw(game: Node2D) -> void:
	var state = game.state.fishing
	if state.phase == game.FishingSystem.PHASE_IDLE: return
	if state.phase == game.FishingSystem.PHASE_CHARGING: _draw_cast_meter(game, state); return
	if state.phase == game.FishingSystem.PHASE_MINIGAME: _draw_minigame(game, state); return
	if state.phase == game.FishingSystem.PHASE_RESULT: _draw_result(game, state)


## Рисует качающуюся шкалу силы заброса с отдельной отметкой максимума.
static func _draw_cast_meter(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, Rect2(770, 142, 326, 132))
	game.draw_string(game.UI_FONT, Vector2(792, 183), game.LocaleSystem.text("fish_cast_title"), HORIZONTAL_ALIGNMENT_CENTER, 282, 20, Color("fff0bd"))
	game.draw_rect(CAST_TRACK, Color("172a35"), true)
	var fill := Rect2(CAST_TRACK.position + Vector2(3, 3), Vector2((CAST_TRACK.size.x - 6) * state.cast_power, CAST_TRACK.size.y - 6))
	game.draw_rect(fill, Color("62c979").lerp(Color("f2c55c"), state.cast_power), true)
	game.draw_line(Vector2(CAST_TRACK.end.x - 5, CAST_TRACK.position.y), Vector2(CAST_TRACK.end.x - 5, CAST_TRACK.end.y), Color("fff5b5"), 3)
	game.draw_string(game.UI_FONT, Vector2(794, 258), game.LocaleSystem.text("fish_release"), HORIZONTAL_ALIGNMENT_CENTER, 278, 14, Color("cbe9df"))


## Рисует вертикальный водяной трек, управляемую зону, рыбу, сундук и шкалу улова.
static func _draw_minigame(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, PANEL)
	game.draw_string(game.UI_FONT, Vector2(792, 139), game.LocaleSystem.text("fish_minigame_title"), HORIZONTAL_ALIGNMENT_CENTER, 282, 20, Color("fff0bd"))
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
	var control_lines: PackedStringArray = game.LocaleSystem.text("fish_hold_hint").split("\n")
	game.draw_string(game.UI_FONT, Vector2(995, 238), control_lines[0], HORIZONTAL_ALIGNMENT_CENTER, 79, 13, Color("d6eadb"))
	game.draw_string(game.UI_FONT, Vector2(995, 258), control_lines[1], HORIZONTAL_ALIGNMENT_CENTER, 79, 13, Color("d6eadb"))
	game.draw_string(game.UI_FONT, Vector2(995, 292), "%d%%" % roundi(state.catch_progress * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 79, 18, Color("fff0bd"))
	if state.perfect: game.draw_string(game.UI_FONT, Vector2(995, 337), "★", HORIZONTAL_ALIGNMENT_CENTER, 79, 28, Color("f6d85d"))


## Рисует краткую карточку результата, чтобы качество и рекорд не терялись в общем HUD.
static func _draw_result(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, Rect2(716, 194, 380, 118))
	game.draw_string(game.UI_FONT, Vector2(738, 232), game.LocaleSystem.text("fish_catch_title") if state.catch_progress >= 1.0 else game.LocaleSystem.text("fish_escaped"), HORIZONTAL_ALIGNMENT_CENTER, 336, 20, Color("fff0bd"))
	game.draw_string(game.UI_FONT, Vector2(738, 270), state.result_text, HORIZONTAL_ALIGNMENT_CENTER, 336, 15, Color("d6eadb"))


## Рисует оригинальную процедурную пиктограмму рыбы без копирования чужих игровых материалов.
static func _draw_fish_icon(game: Node2D, position: Vector2) -> void:
	game.draw_circle(position, 12, Color("f2c55c"))
	var tail := PackedVector2Array([position + Vector2(-10, 0), position + Vector2(-22, -10), position + Vector2(-22, 10)])
	game.draw_colored_polygon(tail, Color("df8e48"))
	game.draw_circle(position + Vector2(5, -3), 2, Color("23363a"))


## Рисует сундук и компактный круговой индикатор его отдельного заполнения.
static func _draw_treasure(game: Node2D, position: Vector2, progress: float) -> void:
	game.draw_rect(Rect2(position - Vector2(10, 8), Vector2(20, 16)), Color("b76f3d"), true)
	game.draw_rect(Rect2(position - Vector2(10, 8), Vector2(20, 16)), Color("f2c55c"), false, 2)
	game.draw_arc(position, 15, -PI * 0.5, -PI * 0.5 + TAU * progress, 20, Color("8df08c"), 3)


## Рисует единый затемнённый фон рыбацких карточек с мягкой рамкой.
static func _draw_panel(game: Node2D, rect: Rect2) -> void:
	game.draw_rect(rect, Color(0.035, 0.075, 0.08, 0.96), true)
	game.draw_rect(rect, Color("5e8e82"), false, 3)

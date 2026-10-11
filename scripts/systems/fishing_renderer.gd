extends RefCounted

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")
const TREASURE_TEXTURE := preload("res://assets/game/world_loot/containers/chest.png")
const WATER_SURFACE := preload("res://assets/game/tiles/editor/water/water_ripples.png")
const HOLD_CARD := Rect2(718, 466, 166, 44)
const RELEASE_CARD := Rect2(896, 466, 166, 44)
static var _catch_zone_style: StyleBoxFlat

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
const WATER_TRACK := Rect2(718, 166, 126, 278)
const PROGRESS_TRACK := Rect2(864, 166, 26, 278)
const TENSION_TRACK := Rect2(906, 166, 18, 278)
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
	game.draw_ui_string(game.UI_FONT, Vector2(738, 280), game.LocaleSystem.text("fish_release"), HORIZONTAL_ALIGNMENT_CENTER, 336, 12, Color("cbe9df"))


## Рисует вертикальный водяной трек, управляемую зону, рыбу, сундук и шкалу улова.
static func _draw_minigame(game: Node2D, state: RefCounted) -> void:
	_draw_panel(game, PANEL)
	game.draw_ui_string(game.UI_FONT, Vector2(706, 137), game.LocaleSystem.text("fish_minigame_title"), HORIZONTAL_ALIGNMENT_CENTER, 370, 20, Color("fff0bd"))
	_draw_water_track(game)
	var bar_rect := catch_zone_rect(state.bar_y, state.bar_size)
	var fish_in_zone: bool = absf(state.fish_y - state.bar_y) <= state.bar_size * 0.5
	_draw_catch_zone(game, bar_rect, fish_in_zone)
	var fish_position := Vector2(WATER_TRACK.position.x + 59, WATER_TRACK.position.y + WATER_TRACK.size.y * state.fish_y)
	_draw_fish_icon(game, fish_position)
	if state.treasure_visible and not state.treasure_caught and state.elapsed >= state.treasure_appears_at:
		_draw_treasure(game, Vector2(WATER_TRACK.end.x - 23, WATER_TRACK.position.y + WATER_TRACK.size.y * state.treasure_y), state.treasure_progress)
	_draw_vertical_gauge(game, PROGRESS_TRACK, state.catch_progress, Color("dfbb63").lerp(Color("75bd8b"), state.catch_progress))
	_draw_vertical_gauge(game, TENSION_TRACK, state.line_tension, Color("d6b267").lerp(Color("cf6655"), state.line_tension))
	var info_x := 940.0
	game.draw_ui_multiline_string(game.UI_FONT, Vector2(info_x, 186), state.fish_name, HORIZONTAL_ALIGNMENT_LEFT, 132, 36, 13, 2, Color("fff0bd"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 222), game.LocaleSystem.text("fish_rarity_" + state.fish_rarity), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, _rarity_color(state.fish_rarity))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 246), game.LocaleSystem.text("fish_behavior_" + state.fish_behavior), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("cbe9df"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 270), game.LocaleSystem.text("fish_depth_" + state.depth_kind) + " • " + game.LocaleSystem.text("fish_water_" + state.water_kind), HORIZONTAL_ALIGNMENT_LEFT, 132, 8, Color("a9c9d8"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 296), game.LocaleSystem.text("fish_hook_" + state.hook_grade), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("e7c66e"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 326), game.LocaleSystem.text("fish_catch_progress", [roundi(state.catch_progress * 100.0)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 10, Color("fff0bd"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 352), game.LocaleSystem.text("fish_tension", [roundi(state.line_tension * 100.0)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("f2a063") if state.line_tension >= 0.65 else Color("cbe9df"))
	game.draw_ui_string(game.UI_FONT, Vector2(info_x, 378), game.LocaleSystem.text("fish_streak", [FishingBalanceText.seconds(state.control_streak), FishingBalanceText.multiplier(state.control_streak)]), HORIZONTAL_ALIGNMENT_LEFT, 132, 9, Color("91df89"))
	if state.perfect: game.draw_ui_string(game.UI_FONT, Vector2(info_x, 420), game.LocaleSystem.text("fish_perfect"), HORIZONTAL_ALIGNMENT_CENTER, 132, 12, Color("f6d85d"))
	_draw_control_cards(game)


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
	game.draw_item_icon("fish",Rect2(position-Vector2(22,22),Vector2(44,44)))


## Рисует сундук и компактный круговой индикатор его отдельного заполнения.
static func _draw_treasure(game: Node2D, position: Vector2, progress: float) -> void:
	game.draw_circle(position, 20, Color(0.04,0.10,0.12,0.70))
	game.draw_texture_rect(TREASURE_TEXTURE, treasure_icon_rect(position), false)
	game.draw_arc(position, 20, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress,0.0,1.0), 24, Color("dcc178"), 2)


## Рисует рыбацкую карточку общей резной панелью вместо отдельной процедурной рамки.
static func _draw_panel(game: Node2D, rect: Rect2) -> void:
	UiKitSystem.draw_modal_panel(game,rect,false)
	var content := Rect2(rect.position + Vector2(20,54), rect.size - Vector2(40,72))
	game.draw_rect(content, Color("1c302d"))
	game.draw_rect(content, Color("826741"), false, 1.0)


## Строит управляемую область внутри водного трека даже на крайних положениях поплавка.
static func catch_zone_rect(center: float, size: float) -> Rect2:
	var height := WATER_TRACK.size.y * clampf(size,0.04,1.0)
	var top := WATER_TRACK.position.y + WATER_TRACK.size.y * center - height * 0.5
	return Rect2(WATER_TRACK.position.x + 5, clampf(top,WATER_TRACK.position.y,WATER_TRACK.end.y-height), WATER_TRACK.size.x - 10, height)


## Вписывает настоящий сундук в рыбацкий трек с исходными пропорциями четыре к трём.
static func treasure_icon_rect(position: Vector2) -> Rect2:
	var size := TREASURE_TEXTURE.get_size() * (36.0 / TREASURE_TEXTURE.get_width())
	return Rect2(position - size * 0.5, size)


## Добавляет мелкую водную фактуру и плавное затемнение глубины вместо крупных полос-заглушек.
static func _draw_water_track(game: Node2D) -> void:
	game.draw_texture_rect(WATER_SURFACE, WATER_TRACK, true, Color("74aaa8"))
	for band in 28:
		var ratio := float(band) / 27.0
		game.draw_rect(Rect2(WATER_TRACK.position + Vector2(0,band * WATER_TRACK.size.y/28.0), Vector2(WATER_TRACK.size.x,WATER_TRACK.size.y/28.0+0.5)), Color(0.025,0.09,0.14,0.30+ratio*0.44))
	game.draw_rect(WATER_TRACK.grow(1), Color("7d7854"), false, 2.0)
	for marker in range(1,10):
		var y := WATER_TRACK.position.y + WATER_TRACK.size.y * marker / 10.0
		game.draw_line(Vector2(WATER_TRACK.position.x,y),Vector2(WATER_TRACK.position.x+5,y),Color(0.66,0.83,0.76,0.5),1.0)


## Подсвечивает контакт с рыбой мягкой округлой зоной, не закрывая саму рыбу непрозрачной плашкой.
static func _draw_catch_zone(game: Node2D, rect: Rect2, fish_in_zone: bool) -> void:
	if _catch_zone_style == null:
		_catch_zone_style = StyleBoxFlat.new()
		_catch_zone_style.set_corner_radius_all(5)
		_catch_zone_style.set_border_width_all(2)
	_catch_zone_style.bg_color = Color(0.22,0.65,0.43,0.68) if fish_in_zone else Color(0.26,0.49,0.39,0.55)
	_catch_zone_style.border_color = Color("a0d99b") if fish_in_zone else Color("86b793")
	game.draw_style_box(_catch_zone_style,rect)


## Рисует тонкую оправленную шкалу улова или лески без ярких белых технических рамок.
static func _draw_vertical_gauge(game: Node2D, rect: Rect2, progress: float, color: Color) -> void:
	game.draw_rect(rect,Color("13201f"))
	game.draw_rect(rect,Color("8e784c"),false,1.0)
	var inner := rect.grow(-3)
	var height := inner.size.y * clampf(progress,0.0,1.0)
	if height > 0.0:
		var filled := Rect2(Vector2(inner.position.x,inner.end.y-height),Vector2(inner.size.x,height))
		game.draw_rect(filled,color)
		game.draw_line(filled.position,Vector2(filled.position.x,filled.end.y),color.lightened(0.18),1.0)


## Возвращает фактические назначенные клавиши, чтобы рыбалка не учила ошибочному управлению после переназначения.
static func action_key_label() -> String:
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events("use_item"):
		if event is InputEventKey:
			var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			labels.append(OS.get_keycode_string(key))
	return " / ".join(labels)


## Показывает удержание и отпускание в двух просторных карточках с понятным направлением зоны.
static func _draw_control_cards(game: Node2D) -> void:
	var lines: PackedStringArray = game.LocaleSystem.text("fish_hold_hint").split("\n")
	UiKitSystem.draw_inset_card(game,HOLD_CARD,game.action_held,true,true)
	UiKitSystem.draw_inset_card(game,RELEASE_CARD,not game.action_held)
	game.draw_ui_string(game.UI_FONT,HOLD_CARD.position+Vector2(10,20),"↑  " + lines[0],HORIZONTAL_ALIGNMENT_CENTER,HOLD_CARD.size.x-20,11,UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.UI_FONT,HOLD_CARD.position+Vector2(10,35),action_key_label(),HORIZONTAL_ALIGNMENT_CENTER,HOLD_CARD.size.x-20,8,Color("655036"))
	game.draw_ui_string(game.UI_FONT,RELEASE_CARD.position+Vector2(10,28),"↓  " + lines[1],HORIZONTAL_ALIGNMENT_CENTER,RELEASE_CARD.size.x-20,11,UiKitSystem.COLORS.ink)


## Возвращает устойчивый цвет редкости для быстрой оценки рыбы без чтения длинного текста.
static func _rarity_color(rarity: String) -> Color:
	return {"common":Color("c8d4c3"), "uncommon":Color("8fd89a"), "rare":Color("73b8ef"), "legendary":Color("dba5f2")}.get(rarity, Color.WHITE)


## Внутренний форматтер сохраняет renderer компактным и не смешивает числа с правилами баланса.
class FishingBalanceText:
	## Форматирует длительность серии управления с одной цифрой после запятой.
	static func seconds(value: float) -> String: return "%.1fs" % value
	## Форматирует ограниченный множитель серии тем же правилом, что применяет механика.
	static func multiplier(value: float) -> String: return "x%.1f" % (1.0 + minf(maxf(value, 0.0) / 5.0, 0.6))

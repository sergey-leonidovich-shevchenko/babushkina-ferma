extends RefCounted

const PANEL_FILL := Color(0.025, 0.045, 0.05, 0.97)
const PANEL_BORDER := Color("78e2b1")
const ROW_FILL := Color("142d29")
const TEXT := Color("e9fff3")
const MUTED := Color("91b3a4")


## Рисует сворачиваемую очередь миссий, страницы и активное модальное окно поверх уровня.
static func draw(game: Node2D) -> void:
	if not game.DebugOverlaySystem.active(game): return
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	draw_header(game, state)
	if bool(state.get("missions_expanded", false)): draw_list(game, state)
	if not String(state.get("mission_details", "")).is_empty(): draw_details(game, String(state.mission_details))
	elif bool(state.get("mission_completion", {}).get("open", false)): draw_completion(game, state.mission_completion)


## Рисует постоянный заголовок, по которому очередь открывается и сворачивается.
static func draw_header(game: Node2D, state: Dictionary) -> void:
	var rect: Rect2 = game.DebugMissionSystem.HEADER
	game.DebugUiKitSystem.draw_readout(game,rect)
	var marker := "▼" if bool(state.get("missions_expanded", false)) else "▶"
	var complete := 1 if game.quest_complete else 0
	for mission_id in game.QuestSystem.MISSIONS:
		if game.QuestSystem.mission_state(game, mission_id) == game.QuestSystem.COMPLETED: complete += 1
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(10,23), "%s МИССИИ · %d/%d" % [marker, complete, game.DebugMissionSystem.ordered_ids(game).size()], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 13, TEXT)


## Рисует восемь миссий страницы со статусом, прогрессом и кнопками подробностей и завершения.
static func draw_list(game: Node2D, state: Dictionary) -> void:
	var panel: Rect2 = game.DebugMissionSystem.PANEL
	game.DebugUiKitSystem.draw_panel(game,panel)
	draw_header(game, state)
	for row in game.DebugMissionSystem.visible_rows(game): draw_row(game, row)
	var page := int(state.get("mission_page", 0)) + 1; var pages: int = game.DebugMissionSystem.page_count(game)
	draw_small_button(game, game.DebugMissionSystem.PREVIOUS, "‹", page > 1)
	draw_small_button(game, game.DebugMissionSystem.NEXT, "›", page < pages)
	game.draw_ui_string(game.UI_FONT, Vector2(408,574), "СТРАНИЦА %d/%d · i подробности · ✓ пройти" % [page, pages], HORIZONTAL_ALIGNMENT_CENTER, 288, 11, MUTED)


## Рисует одну миссию с компактным типом, названием, состоянием и текущей целью.
static func draw_row(game: Node2D, row: Dictionary) -> void:
	var mission_id := String(row.id); var view: Dictionary = game.DebugMissionSystem.mission_view(game, mission_id)
	var status: String = game.DebugMissionSystem.mission_state(game, mission_id)
	var colors := {game.QuestSystem.AVAILABLE:Color("dfbd62"), game.QuestSystem.ACTIVE:Color("65d7ff"), game.QuestSystem.LOCKED:Color("808b87"), game.QuestSystem.COMPLETED:Color("6ce49c")}
	game.draw_rect(row.rect, ROW_FILL); game.draw_rect(row.rect, Color("34554a"), false, 1.0)
	game.draw_ui_string(game.UI_FONT, row.rect.position + Vector2(8,15), "%s · %s" % [view.type, view.title], HORIZONTAL_ALIGNMENT_LEFT, 286, 11, colors.get(status, TEXT))
	game.draw_ui_string(game.UI_FONT, row.rect.position + Vector2(8,32), String(view.objective), HORIZONTAL_ALIGNMENT_LEFT, 286, 10, MUTED)
	draw_small_button(game, row.info, "i", true)
	draw_small_button(game, row.complete, "✓", status != game.QuestSystem.COMPLETED)


## Рисует компактную квадратную кнопку с явным disabled-состоянием.
static func draw_small_button(game: Node2D, rect: Rect2, label: String, enabled: bool) -> void:
	game.DebugUiKitSystem.draw_button(game,rect,label,false,enabled)


## Рисует подробности задания и полный состав его награды в центральной модальной карточке.
static func draw_details(game: Node2D, mission_id: String) -> void:
	var view: Dictionary = game.DebugMissionSystem.mission_view(game, mission_id)
	var rect := Rect2(332, 148, 488, 360)
	draw_modal_frame(game, rect, "%s · %s" % [view.type, view.title])
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(24,70), "Выдаёт: %s" % view.giver, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 13, Color("dfbd62"))
	draw_wrapped(game, String(view.description), rect.position + Vector2(24,98), rect.size.x - 48, 14, TEXT)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(24,230), "ЦЕЛЬ: %s" % view.objective, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48, 13, Color("65d7ff"))
	draw_wrapped(game, "НАГРАДА: %s" % view.reward, rect.position + Vector2(24,260), rect.size.x - 48, 13, Color("6ce49c"))
	draw_small_button(game, Rect2(510,468,132,34), "ЗАКРЫТЬ", true)


## Рисует подтверждение штатно выданной награды после debug-завершения миссии.
static func draw_completion(game: Node2D, completion: Dictionary) -> void:
	var rect := Rect2(374, 188, 404, 282); var view: Dictionary = game.DebugMissionSystem.mission_view(game, String(completion.id))
	draw_modal_frame(game, rect, "МИССИЯ ЗАВЕРШЕНА")
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(24,82), String(view.title), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 48, 21, Color("6ce49c"))
	draw_wrapped(game, String(completion.get("message", "")), rect.position + Vector2(28,120), rect.size.x - 56, 13, TEXT)
	draw_small_button(game, Rect2(510,430,132,34), "ПРИНЯТЬ", true)


## Рисует общий затемнённый фон и рамку модального окна поверх обеих debug-панелей.
static func draw_modal_frame(game: Node2D, rect: Rect2, title: String) -> void:
	game.draw_rect(Rect2(0,0,1152,648), Color(0.0,0.0,0.0,0.58)); game.DebugUiKitSystem.draw_panel(game,rect)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(18,38), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 36, 18, Color("caffdf"))


## Переносит русский текст по словам без зависимости от отдельного Control-узла.
static func draw_wrapped(game: Node2D, value: String, origin: Vector2, width: float, font_size: int, color: Color) -> void:
	var line := ""; var y := origin.y
	for word in value.split(" "):
		var candidate := String(word) if line.is_empty() else "%s %s" % [line, word]
		if game.UI_FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not line.is_empty():
			game.draw_ui_string(game.UI_FONT, Vector2(origin.x,y), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color); y += font_size + 6; line = String(word)
		else: line = candidate
	if not line.is_empty(): game.draw_ui_string(game.UI_FONT, Vector2(origin.x,y), line, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

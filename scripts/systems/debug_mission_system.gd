extends RefCounted

const PAGE_SIZE := 8
const PANEL := Rect2(344, 26, 416, 596)
const HEADER := Rect2(356, 38, 392, 34)
const PREVIOUS := Rect2(356, 554, 42, 28)
const NEXT := Rect2(706, 554, 42, 28)
const GRANDMOTHER_ID := "tutorial_grandmother"
const ROW_HEIGHT := 45.0
const ROW_START_Y := 94.0
const INFO_WIDTH := 30.0
const COMPLETE_WIDTH := 34.0
const SIDE_ORDER := ["side_seed", "side_fisher", "side_smith", "side_feast", "side_hunter", "side_miner", "side_bones", "side_wings", "side_glass", "side_pirate_compass"]


## Создаёт независимое от сохранения состояние списка и модального окна миссий.
static func default_state() -> Dictionary:
	return {"expanded":false, "page":0, "details":"", "completion":{}}


## Возвращает хронологию: обучение бабушки, сюжетная цепочка, затем побочные задания.
static func ordered_ids(game: Node) -> Array[String]:
	var result: Array[String] = [GRANDMOTHER_ID]
	var story := "story_relic"
	while not story.is_empty():
		result.append(story)
		var next := ""
		for mission_id in game.QuestSystem.MISSIONS:
			if String(game.QuestSystem.MISSIONS[mission_id].get("requires", "")) == story: next = mission_id; break
		story = next
	for mission_id in SIDE_ORDER:
		if game.QuestSystem.MISSIONS.has(mission_id): result.append(mission_id)
	for mission_id in game.QuestSystem.MISSIONS:
		if not game.QuestSystem.is_story_mission(mission_id) and mission_id not in result: result.append(mission_id)
	return result


## Возвращает геометрию видимых строк текущей страницы для renderer-а и мышиного ввода.
static func visible_rows(game: Node) -> Array[Dictionary]:
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY, {})
	var ids := ordered_ids(game); var page := clampi(int(state.get("mission_page", 0)), 0, page_count(game) - 1)
	var result: Array[Dictionary] = []
	for local_index in PAGE_SIZE:
		var absolute_index := page * PAGE_SIZE + local_index
		if absolute_index >= ids.size(): break
		var rect := Rect2(PANEL.position.x + 12, ROW_START_Y + local_index * ROW_HEIGHT, PANEL.size.x - 24, ROW_HEIGHT - 4)
		result.append({"id":ids[absolute_index], "rect":rect, "info":Rect2(rect.end.x - INFO_WIDTH - COMPLETE_WIDTH - 8, rect.position.y + 6, INFO_WIDTH, 29), "complete":Rect2(rect.end.x - COMPLETE_WIDTH - 4, rect.position.y + 6, COMPLETE_WIDTH, 29)})
	return result


## Возвращает количество страниц, не допуская нулевого делителя и пустой навигации.
static func page_count(game: Node) -> int:
	return maxi(1, ceili(float(ordered_ids(game).size()) / PAGE_SIZE))


## Возвращает состояние специального задания бабушки или обычной миссии каталога.
static func mission_state(game: Node, mission_id: String) -> String:
	if mission_id == GRANDMOTHER_ID:
		return game.QuestSystem.COMPLETED if game.quest_complete else (game.QuestSystem.ACTIVE if game.quest_active else game.QuestSystem.AVAILABLE)
	return game.QuestSystem.mission_state(game, mission_id)


## Возвращает компактные данные строки и полное описание для модального окна.
static func mission_view(game: Node, mission_id: String) -> Dictionary:
	if mission_id == GRANDMOTHER_ID:
		return {"type":"ОБУЧЕНИЕ", "title":"Десять морковок", "giver":"Бабушка", "description":"Вырасти или купи десять морковок и принеси их бабушке.", "objective":"Морковь: %d/10" % mini(game.carrots, 10), "reward":"50 монет · 25 XP · Охотничий лук"}
	var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
	return {"type":mission.type, "title":mission.title, "giver":mission.giver, "description":mission.description, "objective":game.QuestSystem.objective_text(game, mission_id), "reward":"%d монет · %d XP · %s ×%d" % [mission.coins, mission.xp, game.inventory_item_name(mission.reward_item), mission.reward_count]}


## Обрабатывает сворачивание, страницы, подробности и принудительное завершение выбранной строки.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	if bool(state.get("mission_completion", {}).get("open", false)):
		if Rect2(510, 430, 132, 34).has_point(point): state.mission_completion = {}; game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw()
		return true
	if not String(state.get("mission_details", "")).is_empty():
		if Rect2(510, 468, 132, 34).has_point(point): state.mission_details = ""; game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw()
		return true
	if HEADER.has_point(point):
		state.missions_expanded = not bool(state.get("missions_expanded", false)); game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw(); return true
	if not bool(state.get("missions_expanded", false)) or not PANEL.has_point(point): return false
	if PREVIOUS.has_point(point): state.mission_page = posmod(int(state.get("mission_page", 0)) - 1, page_count(game)); game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw(); return true
	if NEXT.has_point(point): state.mission_page = posmod(int(state.get("mission_page", 0)) + 1, page_count(game)); game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw(); return true
	for row in visible_rows(game):
		if row.info.has_point(point): state.mission_details = row.id; game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw(); return true
		if row.complete.has_point(point): return debug_complete(game, row.id)
	return true


## Завершает зависимости и выбранное задание через штатную выдачу наград, затем открывает карточку результата.
static func debug_complete(game: Node, mission_id: String) -> bool:
	if mission_state(game, mission_id) == game.QuestSystem.COMPLETED: return true
	if mission_id == GRANDMOTHER_ID:
		game.quest_active = true; game.change_inventory_count("carrot", maxi(0, 10 - game.carrots)); game.QuestSystem.talk_to_grandmother(game)
	else:
		debug_complete_without_popup(game, mission_id)
	var state: Dictionary = game.get_meta(game.DebugOverlaySystem.META_KEY)
	state.mission_details = ""; state.mission_completion = {"open":true, "id":mission_id, "message":game.message}
	game.set_meta(game.DebugOverlaySystem.META_KEY, state); game.queue_redraw(); return true


## Подготавливает цель, очищает её мировые источники и вызывает обычную сдачу миссии без отдельной формулы награды.
static func debug_complete_without_popup(game: Node, mission_id: String) -> bool:
	if mission_state(game, mission_id) == game.QuestSystem.COMPLETED: return true
	var mission: Dictionary = game.QuestSystem.MISSIONS[mission_id]
	var requirement := String(mission.get("requires", ""))
	if not requirement.is_empty() and mission_state(game, requirement) != game.QuestSystem.COMPLETED:
		debug_complete_without_popup(game, requirement)
	if String(mission.get("condition", "")) == "moon_glade_clear": complete_moon_expedition(game)
	game.mission_states[mission_id] = game.QuestSystem.ACTIVE
	var missing := maxi(0, int(mission.count) - game.inventory_item_count(mission.item))
	if missing > 0: game.change_inventory_count(mission.item, missing)
	consume_world_source(game, String(mission.item))
	return game.QuestSystem.talk(game, mission_id)


## Переводит связанный сундук, выпавшую вещь, врага или жилу в уже использованное состояние.
static func consume_world_source(game: Node, item_kind: String) -> void:
	for index in range(game.dropped_items.size() - 1, -1, -1):
		if String(game.dropped_items[index].kind) == item_kind: game.dropped_items.remove_at(index)
	for index in game.world_loot_nodes.size():
		var container: Dictionary = game.world_loot_nodes[index]
		if int(container.get("contents", {}).get(item_kind, 0)) > 0: container.opened = true; container.contents = {}; game.world_loot_nodes[index] = container
	for index in game.enemy_nodes.size():
		var enemy: Dictionary = game.enemy_nodes[index]
		if game.CombatSystem.TYPES.get(enemy.kind, {}).get("loot", {}).has(item_kind): enemy.alive = false; enemy.hp = 0; game.enemy_nodes[index] = enemy
	for index in game.resource_nodes.size():
		if String(game.resource_nodes[index].kind) == item_kind: game.resource_nodes[index].hits = 0


## Завершает уникальную Лунную экспедицию и открывает её сундук до сдачи Сердца затмения.
static func complete_moon_expedition(game: Node) -> void:
	var state: Dictionary = game.state.world.moon_glade
	if int(state.completed_runs) > 0 and state.chest_opened: return
	state.flower_collected = true; state.crystal_charged = true; state.echoes = [true, true, true]; state.altar_activated = true
	state.guardian_alive = false; state.guardian_defeated = true; state.guardian_hp = 0
	game.MoonGladeSystem.open_chest(game)

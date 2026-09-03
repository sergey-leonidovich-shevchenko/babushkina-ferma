extends RefCounted

const UiScaleSystem := preload("res://scripts/systems/ui_scale_system.gd")

const TUTORIAL_RECT := Rect2(18, 106, 414, 112)
const OBJECTIVE_RECT := Rect2(446, 106, 510, 82)
const MINIMAP_RECT := Rect2(972, 104, 164, 136)
const DISCOVERY_RECT := Rect2(18, 424, 310, 108)
const NOTIFICATION_RECT := Rect2(340, 462, 472, 76)
const INTERACTION_RECT := Rect2(840, 438, 294, 58)
const EFFECTS_RECT := Rect2(446, 194, 510, 48)
const HUD_RESERVED_RECT := Rect2(0, 0, 1152, 96)
const HOTBAR_RESERVED_RECT := Rect2(190, 548, 762, 100)
const TOUCH_ACTION_RESERVED_RECT := Rect2(996, 512, 156, 76)
const DISPLAY_PROFILES := [
	{"id":"16x9","label":"16:9","size":Vector2i(1152,648)},
	{"id":"16x10","label":"16:10","size":Vector2i(1280,800)},
	{"id":"ultrawide","label":"21:9","size":Vector2i(1680,720)},
]


## Возвращает все принадлежащие координатору карточки для отрисовки, ввода и физического аудита.
static func context_rects() -> Dictionary:
	return {"tutorial":TUTORIAL_RECT,"objective":OBJECTIVE_RECT,"minimap":MINIMAP_RECT,"discovery":DISCOVERY_RECT,"notification":NOTIFICATION_RECT,"interaction":INTERACTION_RECT,"effects":EFFECTS_RECT}


## Преобразует контекстные карточки в физические координаты выбранного экрана без растяжения пиксель-арта.
static func physical_layout(viewport_size: Vector2, physical_safe_area: Rect2 = Rect2()) -> Dictionary:
	var safe_area := physical_safe_area if physical_safe_area.size.x > 0.0 and physical_safe_area.size.y > 0.0 else Rect2(Vector2.ZERO,viewport_size)
	var viewport_layout := UiScaleSystem.viewport_layout_in_area(viewport_size,safe_area)
	var cards: Dictionary = {}
	for key in context_rects(): cards[key]=UiScaleSystem.design_rect_to_screen(context_rects()[key],viewport_size,safe_area)
	return {"scale":viewport_layout.scale,"offset":viewport_layout.offset,"content":Rect2(viewport_layout.offset,viewport_layout.content_size),"safe_area":viewport_layout.safe_area,"cards":cards}


## Возвращает одну приоритетную цель вместо нескольких конкурирующих трекеров на одном экране.
static func primary_objective(game: Node) -> Dictionary:
	if game.current_location == "moon_glade":
		return _objective(game.LocaleSystem.location("moon_glade"), game.MoonGladeSystem.objective(game), "moon")
	var campaign_text: String = game.CastleCampaignSystem.objective(game)
	if not campaign_text.is_empty() and not game.state.world.castle_campaign.completed:
		return _objective(game.LocaleSystem.ui("hud_story_objective"), campaign_text, "story")
	var chapter: Dictionary = game.FirstChapterSystem.state(game)
	if not bool(chapter.completed) and not bool(chapter.reward_pending):
		var objective:=_objective(game.FirstChapterSystem.word(game, "title"), game.FirstChapterSystem.objective(game), "chapter"); objective.ratio=game.FirstChapterSystem.progress(game); return objective
	if game.quest_active and not game.quest_complete:
		return {"title":game.LocaleSystem.ui("hud_grandmother_quest"), "text":game.LocaleSystem.ui("hud_carrot_progress", [mini(game.carrots, 10), 10]), "kind":"quest", "source":"mission", "ratio":float(mini(game.carrots, 10)) / 10.0}
	var active: Array[String] = game.QuestSystem.active_mission_ids(game)
	if not active.is_empty():
		var mission_id: String = active[0]
		var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
		var needed := maxi(1, int(mission.get("count", 1)))
		var owned := mini(needed, game.inventory_item_count(String(mission.get("item", ""))))
		return {"title":String(mission.title), "text":game.QuestSystem.objective_text(game, mission_id), "kind":"story" if game.QuestSystem.is_story_mission(mission_id) else "side", "source":"mission", "ratio":float(owned) / needed}
	return {}


## Создаёт стандартные данные текстовой цели без искусственного прогресса для сюжетного этапа.
static func _objective(title: String, text: String, kind: String) -> Dictionary:
	return {"title":title, "text":text, "kind":kind, "source":"system", "ratio":-1.0}


## Возвращает количество дополнительных активных поручений, скрытых за одной главной целью.
static func hidden_objective_count(game: Node) -> int:
	var count: int = game.QuestSystem.active_mission_ids(game).size()
	if game.quest_active and not game.quest_complete: count += 1
	var primary: Dictionary = primary_objective(game)
	return maxi(0, count - (1 if String(primary.get("source", "")) == "mission" else 0))


## Формирует локализованное действие для конкретного объекта вместо общей надписи «действие».
static func interaction_label(game: Node, interaction: String) -> String:
	var key := "context_interact"
	if interaction in ["npc"] or interaction.begins_with("quest_npc:") or interaction.begins_with("prisoner:"): key = "context_talk"
	elif interaction in ["shop"] or interaction=="interior_service:shop" or interaction.begins_with("village_event:"): key = "context_shop"
	elif interaction=="interior_service:bed": key="context_sleep"
	elif interaction in ["interior_service:craft","interior_service:cauldron"]: key="context_craft"
	elif interaction == "crate": key = "context_sell"
	elif interaction == "workbench": key = "context_craft"
	elif interaction in ["home_chest", "loot"] or interaction.begins_with("container:"): key = "context_open"
	elif interaction.begins_with("drop:"): key = "context_pickup"
	elif interaction.begins_with("resource:"): key = "context_mine"
	elif interaction.begins_with("food:") or interaction.begins_with("life:animal:"): key = "context_collect"
	elif interaction == "life:trough": key = "context_feed"
	elif interaction == "chapter_bridge": key = "context_repair"
	elif interaction == "estate_board": key = "context_upgrade"
	elif interaction.begins_with("fence_gate:"): key = "context_gate"
	elif interaction == "interior_exit" or interaction == "cave_exit": key = "context_exit"
	elif interaction.begins_with("building:") or interaction.begins_with("interior_link:") or interaction in ["cave_entrance", "world_gate", "moon_portal"]: key = "context_enter"
	return game.LocaleSystem.ui("context_action", [game.LocaleSystem.ui(key)])


## Рассчитывает спокойное время чтения сообщения по длине, не оставляя старую плашку навсегда.
static func notification_duration(message: String) -> float:
	return clampf(3.2 + message.length() / 32.0, 3.8, 7.0)


## Проверяет принадлежность карточек холсту и отсутствие пересечений с постоянным HUD и панелью быстрого доступа.
static func layout_is_safe() -> bool:
	var viewport := Rect2(Vector2.ZERO,UiScaleSystem.DESIGN_SIZE)
	var rects: Array[Rect2] = []
	for rect in context_rects().values():
		if not viewport.encloses(rect): return false
		rects.append(rect)
	for first in rects.size():
		for second in range(first + 1, rects.size()):
			if rects[first].intersects(rects[second]): return false
	for rect in rects:
		if rect.intersects(HUD_RESERVED_RECT) or rect.intersects(HOTBAR_RESERVED_RECT) or rect.intersects(TOUCH_ACTION_RESERVED_RECT): return false
	return true

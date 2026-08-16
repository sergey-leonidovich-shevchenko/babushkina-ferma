extends RefCounted

const TUTORIAL_RECT := Rect2(18, 106, 414, 112)
const OBJECTIVE_RECT := Rect2(446, 106, 510, 82)
const MINIMAP_RECT := Rect2(972, 104, 164, 136)
const DISCOVERY_RECT := Rect2(18, 424, 310, 108)
const NOTIFICATION_RECT := Rect2(340, 474, 472, 64)
const INTERACTION_RECT := Rect2(840, 438, 294, 58)


## Возвращает одну приоритетную цель вместо нескольких конкурирующих трекеров на одном экране.
static func primary_objective(game: Node) -> Dictionary:
	if game.current_location == "moon_glade":
		return _objective(game.LocaleSystem.location("moon_glade"), game.MoonGladeSystem.objective(game), "moon")
	var campaign_text: String = game.CastleCampaignSystem.objective(game)
	if not campaign_text.is_empty() and not game.state.world.castle_campaign.completed:
		return _objective(game.LocaleSystem.ui("hud_story_objective"), campaign_text, "story")
	var chapter: Dictionary = game.FirstChapterSystem.state(game)
	if not bool(chapter.completed) and not bool(chapter.reward_pending):
		return _objective(game.FirstChapterSystem.word(game, "title"), game.FirstChapterSystem.objective(game), "chapter")
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
	elif interaction in ["shop"] or interaction.begins_with("interior_service:") or interaction.begins_with("village_event:"): key = "context_shop"
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


## Проверяет отсутствие пересечений у четырёх постоянных информативных зон HUD.
static func layout_is_safe() -> bool:
	var rects := [TUTORIAL_RECT, OBJECTIVE_RECT, MINIMAP_RECT, DISCOVERY_RECT, NOTIFICATION_RECT, INTERACTION_RECT]
	for first in rects.size():
		for second in range(first + 1, rects.size()):
			if rects[first].intersects(rects[second]): return false
	return true

class_name StoryUiRenderer
extends RefCounted

const UiKitSystem := preload("res://scripts/systems/ui_kit_system.gd")
const HudLayoutSystem := preload("res://scripts/systems/hud_layout_system.gd")

const QUEST_WINDOW := Rect2(86, 42, 980, 552)
const QUEST_HEADER := Rect2(326, 54, 500, 66)
const QUEST_CARD_RECTS := [Rect2(132, 132, 888, 124), Rect2(132, 266, 888, 124), Rect2(132, 400, 888, 124)]
const QUEST_PREV := Rect2(94, 500, 42, 42)
const QUEST_NEXT := Rect2(1016, 500, 42, 42)
const DIALOGUE_WINDOW := Rect2(68, 344, 1016, 286)
const DIALOGUE_PORTRAIT := Rect2(96, 374, 176, 178)
const TUTORIAL_CARD := HudLayoutSystem.TUTORIAL_RECT
const NOTIFICATION_CARD := HudLayoutSystem.NOTIFICATION_RECT
const REWARD_WINDOW := Rect2(122, 144, 908, 386)
const REWARD_ICONS := ["fruit_sapling", "healing_potion", "travel_boots"]


## Рисует журнал как резную книгу с тремя отдельными карточками, статусами, наградами и прогрессом.
static func draw_quest_log(game: Node2D) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.015, 0.02, 0.015, 0.72))
	UiKitSystem.draw_modal_panel(game, QUEST_WINDOW)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", QUEST_HEADER)
	game.draw_ui_string(game.UI_FONT, QUEST_HEADER.position + Vector2(28, 42), game.LocaleSystem.ui("quest_log").to_upper(), HORIZONTAL_ALIGNMENT_CENTER, QUEST_HEADER.size.x - 56, 24, UiKitSystem.COLORS.text_light)
	var mission_ids: Array[String] = game.QuestSystem.ordered_mission_ids(game)
	var page_count := maxi(1, ceili(float(mission_ids.size()) / 3.0))
	game.quest_log_page = clampi(game.quest_log_page, 0, page_count - 1)
	for visible_index in QUEST_CARD_RECTS.size():
		var mission_index: int = game.quest_log_page * 3 + visible_index
		if mission_index < mission_ids.size(): draw_mission_card(game, QUEST_CARD_RECTS[visible_index], mission_ids[mission_index])
	UiKitSystem.draw_button(game, QUEST_PREV, false, game.quest_log_page > 0, true)
	UiKitSystem.draw_button(game, QUEST_NEXT, false, game.quest_log_page + 1 < page_count, true)
	game.draw_ui_string(game.UI_FONT, QUEST_PREV.position + Vector2(1, 29), "←", HORIZONTAL_ALIGNMENT_CENTER, 40, 19, UiKitSystem.COLORS.text_light)
	game.draw_ui_string(game.UI_FONT, QUEST_NEXT.position + Vector2(1, 29), "→", HORIZONTAL_ALIGNMENT_CENTER, 40, 19, UiKitSystem.COLORS.text_light)
	game.draw_ui_string(game.UI_FONT, Vector2(430, 542), game.LocaleSystem.ui("quest_page", [game.quest_log_page + 1, page_count]), HORIZONTAL_ALIGNMENT_CENTER, 292, 11, UiKitSystem.COLORS.ink)
	game.draw_ui_string(game.UI_FONT, Vector2(756, 542), game.LocaleSystem.ui("quest_close"), HORIZONTAL_ALIGNMENT_RIGHT, 190, 9, Color("77583a"))


## Рисует одну миссию с цветовым кодом типа, предметной наградой и фактическим прогрессом героя.
static func draw_mission_card(game: Node2D, rect: Rect2, mission_id: String) -> void:
	var mission: Dictionary = game.QuestSystem.mission_data(mission_id)
	var state: String = game.QuestSystem.mission_state(game, mission_id)
	var state_names := {
		game.QuestSystem.LOCKED:game.LocaleSystem.ui("locked"), game.QuestSystem.AVAILABLE:game.LocaleSystem.ui("available"),
		game.QuestSystem.ACTIVE:game.LocaleSystem.ui("active"), game.QuestSystem.COMPLETED:game.LocaleSystem.ui("completed"),
	}
	UiKitSystem.draw_panel(game, rect, false)
	if state == game.QuestSystem.LOCKED: game.draw_rect(rect.grow(-8), Color(0.13, 0.11, 0.09, 0.48))
	var story: bool = game.QuestSystem.is_story_mission(mission_id)
	var type_color := Color("80543a") if story else Color("47714f")
	game.draw_rect(Rect2(rect.position + Vector2(16, 16), Vector2(86, 25)), type_color)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(22, 34), String(mission.type), HORIZONTAL_ALIGNMENT_CENTER, 74, 10, Color("fff0cf"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(116, 36), String(mission.title), HORIZONTAL_ALIGNMENT_LEFT, 510, 18, Color("fff0cf"))
	var state_color := Color("a9d17e") if state == game.QuestSystem.COMPLETED else (UiKitSystem.COLORS.text_disabled if state == game.QuestSystem.LOCKED else Color("f2bd63"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(650, 34), String(state_names.get(state, state)).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, 180, 11, state_color)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(20, 62), String(mission.description), HORIZONTAL_ALIGNMENT_LEFT, 676, 11, Color("ead7ae"))
	var needed := maxi(1, int(mission.get("count", 1)))
	var owned := mini(needed, game.inventory_item_count(String(mission.get("item", ""))))
	var ratio := 1.0 if state == game.QuestSystem.COMPLETED else float(owned) / needed
	UiKitSystem.draw_progress(game, Rect2(rect.position + Vector2(20, 82), Vector2(492, 28)), ratio, Color("6f914f"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(34, 102), game.QuestSystem.objective_text(game, mission_id), HORIZONTAL_ALIGNMENT_LEFT, 462, 10, Color("fff0cf"))
	var reward_icon_rect := UiKitSystem.draw_slot(game, Rect2(rect.position + Vector2(738, 50), Vector2(58, 58)), false)
	game.draw_item_icon(String(mission.reward_item), reward_icon_rect)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(570, 100), "%d XP  •  %d ●  •  ×%d" % [mission.xp, mission.coins, mission.reward_count], HORIZONTAL_ALIGNMENT_RIGHT, 158, 10, Color("f0c87c"))


## Рисует портретный диалог с настоящим спрайтом собеседника и кнопками без внешних рамок.
static func draw_dialogue(game: Node2D) -> void:
	var ui: Dictionary = game.state.player.adventure_ui
	var dialogue: Dictionary = ui.get("dialogue", {})
	game.draw_rect(Rect2(0,0,1152,648),Color(0.012,0.018,0.014,0.34))
	UiKitSystem.draw_modal_panel(game, DIALOGUE_WINDOW)
	game.draw_texture_rect(UiKitSystem.texture("portrait_frame"), DIALOGUE_PORTRAIT, false)
	draw_npc_portrait(game, DIALOGUE_PORTRAIT.grow(-23), String(dialogue.get("npc_id", "")))
	var npc_id := String(dialogue.get("npc_id", ""))
	game.draw_ui_string(game.UI_FONT, Vector2(DIALOGUE_PORTRAIT.position.x + 10, 574), game.QuestSystem.npc_name(npc_id), HORIZONTAL_ALIGNMENT_CENTER, DIALOGUE_PORTRAIT.size.x - 20, 12, UiKitSystem.COLORS.text_light)
	var friendship := int(game.state.player.relationships.get(npc_id, 0))
	game.draw_ui_string(game.UI_FONT, Vector2(294, 430), "%s" % dialogue.get("title", game.AdventurePolishSystem.word(game, "continue")), HORIZONTAL_ALIGNMENT_LEFT, 540, 18, UiKitSystem.COLORS.ink)
	UiKitSystem.draw_nine_patch(game, "badge", Rect2(850, 365, 180, 54))
	game.draw_ui_string(game.UI_FONT, Vector2(870, 399), "♥ %d / 100" % friendship, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color("934840"))
	var full_text := String(dialogue.get("text", ""))
	var visible_text := full_text.left(floori(float(dialogue.get("revealed", full_text.length()))))
	game.draw_multiline_string(game.UI_FONT, Vector2(294, 458), visible_text, HORIZONTAL_ALIGNMENT_LEFT, 720, 13, 3, Color("4c3828"))
	var choices: Array = dialogue.get("choices", ["leave"])
	for index in choices.size():
		var choice_rect := dialogue_choice_rect(index, choices.size())
		UiKitSystem.draw_button(game, choice_rect, index == int(ui.choice), true, game.settings_state.reduced_motion, Time.get_ticks_msec())
		game.draw_ui_string(game.UI_FONT, choice_rect.position + Vector2(14, 31), game.AdventurePolishSystem.word(game, String(choices[index])), HORIZONTAL_ALIGNMENT_CENTER, choice_rect.size.x - 28, 14, UiKitSystem.COLORS.text_light)
	game.draw_ui_string(game.UI_FONT, Vector2(734, 610), game.AdventurePolishSystem.word(game, "gift_hint"), HORIZONTAL_ALIGNMENT_RIGHT, 286, 10, Color("765738"))


## Возвращает равномерно распределённую область варианта ответа для мыши, тача и отрисовки.
static func dialogue_choice_rect(index: int, count: int) -> Rect2:
	var safe_count := maxi(1, count)
	var available_width := 726.0
	var gap := 14.0
	var width := (available_width - gap * (safe_count - 1)) / safe_count
	return Rect2(294 + index * (width + gap), 520, width, 54)


## Находит вариант ответа под указателем либо сообщает об отсутствии попадания.
static func dialogue_choice_at(point: Vector2, count: int) -> int:
	for index in count:
		if dialogue_choice_rect(index, count).has_point(point): return index
	return -1


## Вырезает спокойный фронтальный кадр нужного архетипа NPC и центрирует его внутри портретной рамки.
static func draw_npc_portrait(game: Node2D, rect: Rect2, npc_id: String) -> void:
	var data: Dictionary = game.QuestSystem.NPCS.get(npc_id, {})
	var sprite_index := clampi(int(data.get("sprite", 0)), 0, game.DirectionalCharacterSystem.NPC_TEXTURES.size() - 1)
	var texture: Texture2D = game.DirectionalCharacterSystem.NPC_TEXTURES[sprite_index]
	var source: Rect2 = game.DirectionalCharacterSystem.source_rect(texture, Vector2.DOWN, 0.0, false)
	var destination := UiKitSystem.centered_content_rect(rect, Vector2(112, 132), 0)
	game.draw_texture_rect_region(texture, destination, source, data.get("tint", Color.WHITE))


## Рисует компактный шаг обучения в безопасном углу, показывая номер и общий прогресс курса.
static func draw_tutorial(game: Node2D) -> void:
	UiKitSystem.draw_nine_patch(game, "tooltip", TUTORIAL_CARD)
	var total: int = game.tutorial_steps.size()
	var step: int = game.tutorial_step + 1
	game.draw_ui_string(game.UI_FONT, Vector2(42, 132), game.LocaleSystem.ui("tutorial", [step, total]), HORIZONTAL_ALIGNMENT_LEFT, 258, 11, Color("70452b"))
	UiKitSystem.draw_progress(game, Rect2(300, 116, 104, 28), float(step) / maxi(1, total), Color("76934f"))
	game.draw_multiline_string(game.UI_FONT, Vector2(42, 160), game.LocaleSystem.tutorial(game.tutorial_steps[game.tutorial_step].event), HORIZONTAL_ALIGNMENT_LEFT, 356, 12, 3, UiKitSystem.COLORS.ink)


## Рисует системное сообщение как спокойную пергаментную плашку с типовой иконкой награды или события.
static func draw_notification(game: Node2D) -> void:
	if game.message.is_empty() or game.hud_message_timer <= 0.0 or game.inventory_open or game.shop_open or game.quest_log_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open: return
	if game.AdventurePolishSystem.has_modal(game) or game.FirstChapterSystem.modal_active(game) or game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open: return
	var bob := 0.0 if game.settings_state.reduced_motion else sin(Time.get_ticks_msec() / 260.0) * 1.5
	var rect := Rect2(NOTIFICATION_CARD.position + Vector2(0, bob), NOTIFICATION_CARD.size)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", rect)
	var reward: bool = "+" in game.message or "награ" in game.message.to_lower() or "получ" in game.message.to_lower()
	UiKitSystem.draw_nine_patch(game, "badge", Rect2(rect.position + Vector2(18, 12), Vector2(46, 46)))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(28, 45), "★" if reward else "!", HORIZONTAL_ALIGNMENT_CENTER, 26, 17, Color("8c542e"))
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(70, 42), game.message, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 90, 11, UiKitSystem.COLORS.ink)


## Рисует итог главы как три крупные коллекционные карты, сохраняя исходные зоны выбора наград.
static func draw_chapter_reward(game: Node2D) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.015, 0.01, 0.76))
	UiKitSystem.draw_modal_panel(game, REWARD_WINDOW)
	UiKitSystem.draw_nine_patch(game, "quest_ribbon", Rect2(322, 158, 508, 66))
	game.draw_ui_string(game.UI_FONT, Vector2(350, 201), game.FirstChapterSystem.word(game, "reward_title"), HORIZONTAL_ALIGNMENT_CENTER, 452, 23, UiKitSystem.COLORS.text_light)
	for index in game.FirstChapterSystem.REWARD_RECTS.size():
		var rect: Rect2 = game.FirstChapterSystem.REWARD_RECTS[index]
		UiKitSystem.draw_panel(game, rect, false)
		var icon_rect := UiKitSystem.draw_slot(game, Rect2(rect.position + Vector2(78, 10), Vector2(80, 80)), false)
		game.draw_item_icon(REWARD_ICONS[index], icon_rect)
		var key := "reward_%s" % game.FirstChapterSystem.REWARDS[index]
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(14, 112), game.FirstChapterSystem.word(game, key), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 28, 15, Color("fff0cf"))
		game.draw_ui_string(game.UI_FONT, rect.position + Vector2(16, 138), game.FirstChapterSystem.word(game, key + "_desc"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32, 9, Color("e1c894"))
	game.draw_ui_string(game.UI_FONT, Vector2(250, 494), game.FirstChapterSystem.word(game, "reward_hint"), HORIZONTAL_ALIGNMENT_CENTER, 652, 12, Color("6a482e"))

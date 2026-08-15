class_name FirstChapterRenderer
extends RefCounted

## Отрисовывает строительный узел восточной переправы и его читаемый сюжетный маркер.
static func draw_world(game: Node) -> void:
	if game.current_location != "overworld": return
	var value: Dictionary = game.FirstChapterSystem.state(game); var position: Vector2 = game.FirstChapterSystem.REPAIR_POSITION
	game.WorldPolishRenderer.draw_effect(game,"wood",position,0.55 if value.bridge_repaired else 1.0)
	if not value.bridge_repaired:
		game.draw_circle(position+Vector2(0,-46),17.0,Color("e4b757")); game.draw_string(game.UI_FONT,position+Vector2(-10,-40),"!",HORIZONTAL_ALIGNMENT_CENTER,20,20,Color("392315"))

## Отрисовывает постоянную компактную цель главы и модальный выбор итогового пути.
static func draw_ui(game: Node) -> void:
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open: return
	var value: Dictionary = game.FirstChapterSystem.state(game)
	if not value.completed:
		var card := Rect2(724,103,404,58); game.draw_rect(card,Color(0.07,0.10,0.08,0.91)); game.draw_rect(card,Color("b88b42"),false,2.0)
		game.draw_string(game.UI_FONT,card.position+Vector2(14,21),game.FirstChapterSystem.word(game,"title"),HORIZONTAL_ALIGNMENT_LEFT,374,13,Color("e8bd62"))
		game.draw_string(game.UI_FONT,card.position+Vector2(14,46),game.FirstChapterSystem.objective(game),HORIZONTAL_ALIGNMENT_LEFT,374,12,Color("fff4cf"))
	if value.reward_pending: draw_reward(game)

## Отрисовывает три визуально различимых карточки награды с иконками физических предметов.
static func draw_reward(game: Node) -> void:
	game.draw_rect(Rect2(0,0,1152,648),Color(0,0,0,0.67)); game.draw_rect(Rect2(146,164,860,342),Color("3b2417")); game.draw_rect(Rect2(156,174,840,322),Color("ead7a3"))
	game.draw_string(game.UI_FONT,Vector2(196,224),game.FirstChapterSystem.word(game,"reward_title"),HORIZONTAL_ALIGNMENT_CENTER,760,27,Color("4a2e1c"))
	var icons := ["fruit_sapling","healing_potion","travel_boots"]
	for index in game.FirstChapterSystem.REWARD_RECTS.size():
		var rect: Rect2 = game.FirstChapterSystem.REWARD_RECTS[index]; game.draw_rect(rect,Color("c9aa70")); game.draw_rect(rect,Color("8a5c2b"),false,3.0); game.draw_item_icon(icons[index],Rect2(rect.position+Vector2(82,12),Vector2(72,72)))
		var key := "reward_%s" % game.FirstChapterSystem.REWARDS[index]; game.draw_string(game.UI_FONT,rect.position+Vector2(10,104),game.FirstChapterSystem.word(game,key),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-20,17,Color("4c3020")); game.draw_string(game.UI_FONT,rect.position+Vector2(12,132),game.FirstChapterSystem.word(game,key+"_desc"),HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-24,11,Color("65462f"))
	game.draw_string(game.UI_FONT,Vector2(196,478),game.FirstChapterSystem.word(game,"reward_hint"),HORIZONTAL_ALIGNMENT_CENTER,760,14,Color("6a482e"))

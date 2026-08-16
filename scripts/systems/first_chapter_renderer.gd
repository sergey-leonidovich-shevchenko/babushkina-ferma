class_name FirstChapterRenderer
extends RefCounted

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")

## Отрисовывает строительный узел восточной переправы и его читаемый сюжетный маркер.
static func draw_world(game: Node) -> void:
	if game.current_location != "overworld": return
	var value: Dictionary = game.FirstChapterSystem.state(game); var position: Vector2 = game.FirstChapterSystem.REPAIR_POSITION
	game.WorldPolishRenderer.draw_effect(game,"wood",position,0.55 if value.bridge_repaired else 1.0)
	if not value.bridge_repaired:
		game.draw_circle(position+Vector2(0,-46),17.0,Color("e4b757")); game.draw_ui_string(game.UI_FONT,position+Vector2(-10,-40),"!",HORIZONTAL_ALIGNMENT_CENTER,20,20,Color("392315"))

## Отрисовывает постоянную компактную цель главы и модальный выбор итогового пути.
static func draw_ui(game: Node) -> void:
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open: return
	var farm_life:Dictionary=game.FarmLifeSystem.state(game)
	if bool(farm_life.compendium) or not String(farm_life.cutscene).is_empty(): return
	var value: Dictionary = game.FirstChapterSystem.state(game)
	if not value.completed and not value.reward_pending and not game.AdventurePolishSystem.has_modal(game):
		var card := Rect2(724,103,404,68); UiKitSystem.draw_nine_patch(game,"tooltip",card)
		game.draw_ui_string(game.UI_FONT,card.position+Vector2(18,24),game.FirstChapterSystem.word(game,"title"),HORIZONTAL_ALIGNMENT_LEFT,366,12,Color("7b4f2d"))
		game.draw_ui_string(game.UI_FONT,card.position+Vector2(18,49),game.FirstChapterSystem.objective(game),HORIZONTAL_ALIGNMENT_LEFT,366,11,UiKitSystem.COLORS.ink)
	if value.reward_pending: draw_reward(game)

## Отрисовывает три визуально различимых карточки награды с иконками физических предметов.
static func draw_reward(game: Node) -> void:
	game.StoryUiRenderer.draw_chapter_reward(game)

class_name FirstChapterRenderer
extends RefCounted

## Отрисовывает строительный узел восточной переправы и его читаемый сюжетный маркер.
static func draw_world(game: Node) -> void:
	if game.current_location != "overworld": return
	var value: Dictionary = game.FirstChapterSystem.state(game); var position: Vector2 = game.FirstChapterSystem.REPAIR_POSITION
	game.WorldPolishRenderer.draw_effect(game,"wood",position,0.55 if value.bridge_repaired else 1.0)
	if not value.bridge_repaired:
		preload("res://scripts/presentation/world_marker_renderer.gd").draw(game,position+Vector2(0,-46),"!",19)

## Делегирует постоянную цель общему HUD и рисует только модальный выбор итогового пути.
static func draw_ui(game: Node) -> void:
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open: return
	var farm_life:Dictionary=game.FarmLifeSystem.state(game)
	if bool(farm_life.compendium) or not String(farm_life.cutscene).is_empty(): return
	var value: Dictionary = game.FirstChapterSystem.state(game)
	if value.reward_pending: draw_reward(game)

## Отрисовывает три визуально различимых карточки награды с иконками физических предметов.
static func draw_reward(game: Node) -> void:
	game.StoryUiRenderer.draw_chapter_reward(game)

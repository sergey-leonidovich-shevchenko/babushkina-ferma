extends RefCounted

const UiKitSystem:=preload("res://scripts/systems/ui_kit_system.gd")
const GOLD := Color("efc45f")


## Рисует следы, кадр действия, боевую фиксацию и предупреждение атаки в мировых координатах.
static func draw_world(game: Node2D) -> void:
	var feedback: Dictionary = game.state.player.feedback
	for footprint in feedback.get("footprints", []):
		game.draw_circle(footprint.position + Vector2(-4, 0), 2.5, Color(0.20, 0.16, 0.10, float(footprint.time) * 0.16))
		game.draw_circle(footprint.position + Vector2(4, 4), 2.5, Color(0.20, 0.16, 0.10, float(footprint.time) * 0.16))
	if float(feedback.get("timer", 0.0)) > 0.0:
		var action := String(feedback.get("action", ""))
		if game.AdventurePolishSystem.ACTIONS.has(action): draw_effect(game,int(game.AdventurePolishSystem.ACTIONS[action]),feedback.position,game.facing.x<-0.1); game.WorldPolishRenderer.draw_effect(game,{"mine":"stone","chop":"wood","fish_cast":"splash","harvest":"leaves"}.get(action,"dust"),feedback.position+Vector2(0,18),clampf(float(feedback.timer)*2.0,0.0,1.0))
	for number in feedback.get("damage_numbers", []):
		game.draw_ui_string(game.UI_FONT, number.position, number.text, HORIZONTAL_ALIGNMENT_CENTER, 70, 21, number.color)
	draw_target(game); draw_enemy_telegraphs(game)


## Рисует независимый модульный эффект действия через единый визуальный каталог.
static func draw_effect(game:Node2D,index:int,position:Vector2,flip_x:bool=false)->void:
	game.ActionEffectVisualSystem.draw(game,index,position,flip_x)


## Рисует кольцо, направление и имя зафиксированной цели.
static func draw_target(game: Node2D) -> void:
	var index := int(game.state.player.adventure_ui.get("target_enemy", -1))
	if index < 0 or index >= game.enemy_nodes.size(): return
	var enemy: Dictionary = game.enemy_nodes[index]
	game.draw_arc(enemy.position + Vector2(0, 18), 29, 0, TAU, 24, GOLD, 3)
	game.draw_line(game.player + game.facing * 22.0, enemy.position, Color(1.0, 0.78, 0.28, 0.32), 2)


## Показывает красный сектор незадолго до удара каждого врага.
static func draw_enemy_telegraphs(game: Node2D) -> void:
	for enemy in game.enemy_nodes:
		if not enemy.alive or enemy.location != game.current_location: continue
		var timer := float(enemy.get("attack_timer", 0.0))
		var distance: float = enemy.position.distance_to(game.player)
		var reach: float = float(game.CombatSystem.TYPES[enemy.kind].range)
		if distance <= reach + 12.0 and timer > 0.0 and timer < 0.38:
			game.draw_arc(enemy.position, reach, -0.65 + enemy.position.angle_to_point(game.player), 0.65 + enemy.position.angle_to_point(game.player), 16, Color(1.0, 0.20, 0.12, 0.72), 4)


## Рисует постоянную мини-карту активной локации в свободном правом углу HUD.
static func draw_minimap(game: Node2D) -> void:
	var farm_life:Dictionary=game.FarmLifeSystem.state(game)
	if game.inventory_open or game.shop_open or game.quest_log_open or game.world_map_open or game.skill_menu_open or game.crafting_open or game.storage_open or game.forge_open or game.contract_open or game.AdventurePolishSystem.has_modal(game) or bool(farm_life.compendium) or not String(farm_life.cutscene).is_empty() or game.state.fishing.phase in [game.FishingSystem.PHASE_CHARGING,game.FishingSystem.PHASE_MINIGAME,game.FishingSystem.PHASE_RESULT]: return
	var rect := Rect2(972, 104, 164, 136)
	UiKitSystem.draw_panel(game,rect,false)
	game.draw_ui_string(game.UI_FONT, rect.position + Vector2(9, 30), game.LocaleSystem.location(game.current_location), HORIZONTAL_ALIGNMENT_LEFT, 144, 10, UiKitSystem.COLORS.ink)
	var world_size: Vector2 = game.WORLD_SIZE
	var map_rect := Rect2(rect.position + Vector2(8, 38), Vector2(148, 86))
	game.draw_rect(map_rect, Color("6f9b5a"))
	if game.current_location == "overworld":
		game.draw_rect(Rect2(map_rect.position + Vector2(0, 54), Vector2(148, 18)), Color("4d91a3"))
		game.draw_line(map_rect.position + Vector2(18, 42), map_rect.position + Vector2(98, 42), Color("d6b67b"), 5)
	var dot := map_rect.position + Vector2(clampf(game.player.x / world_size.x, 0.0, 1.0) * map_rect.size.x, clampf(game.player.y / world_size.y, 0.0, 1.0) * map_rect.size.y)
	game.draw_circle(dot, 4, Color("ffe168")); game.draw_circle(dot, 2, Color("542f25"))


## Рисует поверх HUD активное создание персонажа или портретный диалог.
static func draw_ui(game: Node2D) -> void:
	draw_minimap(game)
	if bool(game.state.player.adventure_ui.get("creation_open", false)): draw_creation(game)
	elif bool(game.state.player.adventure_ui.get("dialogue_open", false)): draw_dialogue(game)


## Рисует деревянно-пергаментное окно выбора имени, фермы, внешности и специализации.
static func draw_creation(game: Node2D) -> void:
	game.draw_rect(Rect2(0, 0, 1152, 648), Color(0.02, 0.035, 0.03, 0.82))
	var outer := Rect2(215, 62, 722, 530); UiKitSystem.draw_modal_panel(game,outer)
	var title:=Rect2(326,74,500,58); UiKitSystem.draw_nine_patch(game,"quest_ribbon",title); game.draw_ui_string(game.UI_FONT,title.position+Vector2(28,39),game.AdventurePolishSystem.word(game,"new_story"),HORIZONTAL_ALIGNMENT_CENTER,title.size.x-56,22,UiKitSystem.COLORS.text_light)
	var profile: Dictionary = game.state.player.profile
	var fields := [[game.AdventurePolishSystem.word(game,"name"),profile.name],[game.AdventurePolishSystem.word(game,"farm"),profile.farm_name],[game.AdventurePolishSystem.word(game,"appearance"),game.AdventurePolishSystem.word(game,"variant",[int(profile.appearance)+1])],[game.AdventurePolishSystem.word(game,"clothes"),game.AdventurePolishSystem.word(game,"set",[int(profile.clothes)+1])],[game.AdventurePolishSystem.word(game,"calling"),specialization_name(game, String(profile.specialization))]]
	var selected := int(game.state.player.adventure_ui.get("creation_field", 0))
	for index in fields.size():
		var row := Rect2(288, 150 + index * 67, 576, 52)
		UiKitSystem.draw_button(game,row,index==selected,true,game.settings_state.reduced_motion,Time.get_ticks_msec())
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(15, 32), fields[index][0], HORIZONTAL_ALIGNMENT_LEFT, 160, 15, UiKitSystem.COLORS.text_light)
		game.draw_ui_string(game.UI_FONT, row.position + Vector2(180, 33), "‹  %s  ›" % fields[index][1], HORIZONTAL_ALIGNMENT_CENTER, 370, 16, UiKitSystem.COLORS.text_light)
	game.draw_ui_string(game.UI_FONT, Vector2(315, 536), game.AdventurePolishSystem.word(game, "creation_help"), HORIZONTAL_ALIGNMENT_CENTER, 522, 17, Color("573c27"))


## Возвращает читаемое название стартовой специализации.
static func specialization_name(game: Node, kind: String) -> String:
	return game.AdventurePolishSystem.word(game, kind)


## Рисует портретную сцену разговора, отношения, описание задания и варианты ответа.
static func draw_dialogue(game: Node2D) -> void:
	game.StoryUiRenderer.draw_dialogue(game)

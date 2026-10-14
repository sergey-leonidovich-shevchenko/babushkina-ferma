extends RefCounted

## Выполняет один физический кадр и задаёт единственный порядок обновления игровых подсистем.
static func physics_process(game: Node, delta: float) -> void:
	preload("res://scripts/systems/basement_input_system.gd").update(game,delta)
	game.AudioSystem.update(game, delta)
	game.update_hud_feedback(delta)
	game.UiFeedbackSystem.update(game, delta)
	if gameplay_window_open(game) or game.menu_state.pause_open or game.menu_state.settings_open or game.menu_state.defeat_open or not game.menu_state.confirmation.is_empty():
		game.queue_redraw()
		return
	if game.LevelEditorSystem.active(game):
		game.queue_redraw()
		return
	game.PublishedLevelSystem.update(game)
	if game.LevelEditorSystem.active(game):
		game.queue_redraw()
		return
	game.FenceSystem.update(game, delta)
	game.DebugOverlaySystem.update(game, delta)
	delta = game.DebugOverlaySystem.simulation_delta(game, delta)
	if delta <= 0.0:
		game.queue_redraw()
		return
	game.AdventurePolishSystem.update(game, delta)
	delta = game.FarmLifeSystem.simulation_delta(game, delta)
	if delta <= 0.0:
		game.queue_redraw()
		return
	if game.DebugPlaygroundSystem.active(game):
		game.DebugPlaygroundSystem.update(game, delta)
		delta = game.DebugPlaygroundSystem.simulation_delta(game, delta)
		if delta <= 0.0:
			game.queue_redraw()
			return
	game.FirstChapterSystem.update(game)
	if modal_active(game):
		game.queue_redraw()
		return
	update_world(game, delta)
	if gameplay_window_open(game):
		game.queue_redraw()
		return
	update_player(game, delta)
	preload("res://scripts/systems/dropped_loot_system.gd").update(game,delta)
	game.queue_redraw()

## Проверяет, блокирует ли текущее модальное состояние симуляцию мира.
static func modal_active(game: Node) -> bool:
	return game.title_screen \
		or game.menu_state.pause_open \
		or game.menu_state.settings_open \
		or game.menu_state.defeat_open \
		or game.AdventurePolishSystem.has_modal(game) \
		or game.FarmLifeSystem.modal_active(game) \
		or game.FirstChapterSystem.modal_active(game)

## Проверяет полноэкранные игровые окна, при которых мир и боевые события поставлены на паузу.
static func gameplay_window_open(game: Node) -> bool:
	return preload("res://scripts/systems/dev_cabinet_system.gd").active(game) or preload("res://scripts/systems/apiary_input_system.gd").active(game) or game.BasementSystem.modal(game) or game.shop_open \
		or game.inventory_open \
		or game.crafting_open \
		or game.storage_open \
		or game.forge_open \
		or game.contract_open \
		or game.quest_log_open \
		or game.skill_menu_open \
		or game.world_map_open

## Обновляет мир, существ и прогресс в детерминированном порядке одного кадра.
static func update_world(game: Node, delta: float) -> void:
	game.update_game_clock(delta)
	game.WorldEventSystem.update(game)
	game.sync_background_environment()
	game.EstateSystem.update_daily_event(game)
	game.VillageEventSystem.update(game)
	game.FarmLifeSystem.update(game, delta)
	game.update_crops(delta)
	game.TreeSystem.update(game, delta)
	game.MoonGladeSystem.update(game, delta)
	game.CastleCampaignSystem.update(game, delta)
	game.update_combat(delta)
	game.update_fishing(delta)
	game.update_status_effects(delta)
	game.FurnaceSystem.update(game,delta)
	game.WorkshopSystem.update(game,delta)
	preload("res://scripts/systems/basement_production_system.gd").update(game,delta)
	game.SpellSystem.update(game, delta)
	game.CompanionSystem.update(game, delta)
	game.NpcMovementSystem.update(game, delta)
	game.PlayerSystem.update_animation(game, delta)
	game.AnimationSystem.update(game, delta)
	game.SkillSystem.update_resources(game, delta)
	game.ForageSystem.update(game)
	if not game.DebugPlaygroundSystem.active(game):
		game.DiscoverySystem.update(game, delta)
		game.WildlifeSystem.update(game, delta)
	if game.benchmark_autoplay:
		game.update_benchmark_route(delta)

## Обновляет перемещение и удерживаемые действия героя после симуляции мира.
static func update_player(game: Node, delta: float) -> void:
	if preload("res://scripts/systems/basement_construction_system.gd").update_hold(game,delta): game.update_camera(); return
	game.update_player_movement(delta)
	game.LocationTransitionSystem.update(game, delta)
	game.update_held_action(delta)
	game.update_held_attack(delta)
	game.update_camera()

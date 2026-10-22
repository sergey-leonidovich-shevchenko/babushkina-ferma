extends RefCounted

const LOCATION_META := &"combat_location"

## Прекращает физическое удержание, не уничтожая честно начатый удар или уже оплаченный результат.
static func release_holds(game: Node) -> void:
	game.state.player.blocking=false
	if game.state.fishing.phase==game.FishingSystem.PHASE_CHARGING: game.FishingSystem.cancel(game)
	if game.has_meta("basement_ui"):
		var ui:Dictionary=game.get_meta("basement_ui"); ui.holding=0; ui.touch_id=-1
	var pose:Dictionary=game.get_meta(game.HeroActionSystem.META,{})
	if pose.get("action","")=="build": game.remove_meta(game.HeroActionSystem.META)

## Синхронизирует одну границу локации; повтор на прежней карте сохраняет бой и ожидание поклёвки.
static func location_changed(game: Node, force: bool=false) -> void:
	game.FishingSystem.on_location_changed(game)
	if force or String(game.get_meta(LOCATION_META,game.current_location))!=game.current_location: cancel_transients(game)
	game.set_meta(LOCATION_META,game.current_location)

## Убирает угрозы и жесты старого мира, сохраняя инвентарь, знания, оплаченные очереди и частичную стройку.
static func cancel_transients(game: Node) -> void:
	game.clear_movement_keys(); game.CombatSystem.reset_transients(game); game.CaveBossSystem.reset(game)
	game.FishingSystem.cancel(game); game.SpellSystem.state(game).effects.clear()
	game.state.player.dodge_timer=0.0
	game.inventory_move_from=-1; game.inventory_touch_drag_y=0.0
	for field in ["shop_open","inventory_open","crafting_open","storage_open","forge_open","contract_open","quest_log_open","skill_menu_open","world_map_open"]: game.set(field,false)
	if game.has_meta("basement_ui"):
		var ui:Dictionary=game.get_meta("basement_ui"); ui.open=false; ui.placing=false; ui.holding=0; ui.touch_id=-1; ui.pointer=Vector2.ZERO
	if game.has_meta("basement_active_station"): game.remove_meta("basement_active_station")

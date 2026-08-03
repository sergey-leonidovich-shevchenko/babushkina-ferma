extends RefCounted

const LOCATIONS := {
	"overworld":Vector2(205, 280), "forest":Vector2(340, 195), "rocky":Vector2(365, 405),
	"ruins":Vector2(560, 280), "cave":Vector2(585, 445), "cursed":Vector2(755, 315),
	"glassworks":Vector2(748, 185), "pirate_ship":Vector2(970, 255), "moon_glade":Vector2(820, 425),
}
const CONNECTIONS := [["overworld","forest"],["overworld","rocky"],["forest","ruins"],["rocky","cave"],["ruins","cursed"],["ruins","glassworks"],["cursed","pirate_ship"],["cave","moon_glade"]]


## Переключает карту мира и регистрирует знакомство с её обозначениями.
static func toggle(game: Node) -> bool:
	game.world_map_open = not game.world_map_open
	if game.world_map_open:
		game.clear_movement_keys(); game.notify_tutorial("world_map")
	game.queue_redraw()
	return game.world_map_open


## Возвращает внешнюю область для текущего интерьера или саму открытую локацию.
static func current_region(game: Node) -> String:
	if game.BuildingSystem.is_interior(game.current_location):
		var building_id: String = String(game.BuildingSystem.INTERIORS[game.current_location].building)
		return String(game.BuildingSystem.BUILDINGS[building_id].location)
	return game.current_location


## Определяет сюжетную область, которую следует выделить на карте как следующую цель.
static func objective_region(game: Node) -> String:
	var campaign: Dictionary = game.state.world.castle_campaign
	if int(campaign.stage) == 1: return "ruins"
	if int(campaign.stage) in [2, 3, 4]: return "ruins"
	for mission_id in game.QuestSystem.MISSIONS:
		if String(game.mission_states.get(mission_id, game.QuestSystem.AVAILABLE)) == game.QuestSystem.ACTIVE:
			for npc_id in game.QuestSystem.NPCS:
				if mission_id in game.QuestSystem.NPCS[npc_id].missions: return String(game.QuestSystem.NPCS[npc_id].location)
	return ""

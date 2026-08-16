extends RefCounted

const LOCATIONS := {
	"overworld":Vector2(205, 280), "forest":Vector2(340, 195), "rocky":Vector2(365, 405),
	"ruins":Vector2(560, 280), "cave":Vector2(585, 445), "cursed":Vector2(755, 315),
	"glassworks":Vector2(748, 185), "pirate_ship":Vector2(970, 255), "moon_glade":Vector2(820, 425),
}
const CONNECTIONS := [["overworld","forest"],["overworld","rocky"],["forest","ruins"],["rocky","cave"],["ruins","cursed"],["ruins","glassworks"],["cursed","pirate_ship"],["cave","moon_glade"]]
const PAGE_COUNT := 5


## Переключает карту мира и регистрирует знакомство с её обозначениями.
static func toggle(game: Node) -> bool:
	game.world_map_open = not game.world_map_open
	if game.world_map_open:
		game.clear_movement_keys(); game.notify_tutorial("world_map")
	game.queue_redraw()
	return game.world_map_open


## Выбирает вкладку энциклопедии по безопасно ограниченному индексу.
static func set_page(game: Node, page: int) -> int:
	game.world_guide_page = clampi(page, 0, PAGE_COUNT - 1)
	game.queue_redraw()
	return game.world_guide_page


## Переключает вкладку по кругу для клавиатуры и плечевых кнопок геймпада.
static func cycle_page(game: Node, offset: int) -> int:
	game.world_guide_page = posmod(game.world_guide_page + offset, PAGE_COUNT)
	game.queue_redraw()
	return game.world_guide_page


## Обрабатывает указатель на вкладках, рецептах и кнопке закрытия энциклопедии.
static func handle_pointer(game: Node, point: Vector2) -> bool:
	if game.WorldMapRenderer.CLOSE_BUTTON.has_point(point): return toggle(game)
	var page: int = game.WorldMapRenderer.page_at(point)
	if page >= 0: set_page(game, page); return true
	if game.world_guide_page == 4:
		var recipe: int = game.WorldMapRenderer.recipe_at(game, point)
		if recipe >= 0: game.world_guide_selected = recipe; game.queue_redraw(); return true
	return true


## Перемещает выбранную строку рецепта внутри полного справочника.
static func move_selection(game: Node, offset: int) -> int:
	if game.world_guide_page != 4: return game.world_guide_selected
	game.world_guide_selected = posmod(game.world_guide_selected + offset, game.CraftingSystem.RECIPES.size())
	game.queue_redraw()
	return game.world_guide_selected


## Проверяет знакомство с семейством врага по сохранённой подсказке или уже поверженному представителю.
static func bestiary_discovered(game: Node, kind: String) -> bool:
	for discovery_id in game.seen_discoveries:
		if String(discovery_id).begins_with("enemy:%s:" % kind): return true
	for enemy in game.enemy_nodes:
		if String(enemy.kind) == kind and not bool(enemy.alive): return true
	return false


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
	var quest_region: String = game.QuestSystem.objective_region(game)
	if not quest_region.is_empty():
		return quest_region
	return ""

extends RefCounted

const WorldVisualProfileSystem := preload("res://scripts/systems/world_visual_profile_system.gd")
const CaveAssets := preload("res://scripts/systems/cave_asset_system.gd")
const CaveMap := preload("res://scripts/systems/cave_map_data.gd")
const VISUAL_PROFILE := "resource_node"
const RESOURCE_NAMES := {
	"stone": "камень",
	"crystal": "синий кристалл",
	"red_crystal": "красный кристалл",
	"green_crystal": "зелёный кристалл",
	"metal": "металлическая руда",
}
const SPAWNS := [
	{"position": Vector2(1200, 300), "location": "overworld", "kind": "stone", "hits": 2},
	{"position": Vector2(1710, 190), "location": "overworld", "kind": "red_crystal", "hits": 3},
	{"position": Vector2(520, 300), "location": "cave", "kind": "crystal", "hits": 3},
	{"position": Vector2(980, 570), "location": "cave", "kind": "stone", "hits": 2},
	{"position": Vector2(1500, 330), "location": "cave", "kind": "green_crystal", "hits": 3},
]


## Возвращает рассчитанное методом значение в безопасном для вызывающего кода виде.
static func default_nodes() -> Array:
	var nodes:=SPAWNS.duplicate(true)
	var placements:Dictionary=preload("res://scripts/systems/village_map_data.gd").RESOURCES
	for index in placements: nodes[index].position=placements[index]
	for index in CaveMap.RESOURCES: nodes[index].position = CaveMap.RESOURCES[index]
	nodes.append_array(CaveMap.EXTRA_RESOURCES.duplicate(true))
	nodes.append_array(preload("res://scripts/systems/cave_dungeon_content.gd").RESOURCES.duplicate(true))
	return nodes


## Возвращает общую нижнюю опору жилы так, чтобы её основание оставалось на исходной позиции.
static func ground_anchor(position: Vector2) -> Vector2:
	return position+Vector2(0,24)


## Строит видимый прямоугольник камня или кристалла через общий модульный профиль.
static func destination_rect(node: Dictionary) -> Rect2:
	if preload("res://scripts/systems/cave_room_data.gd").is_cave(String(node.get("location", ""))):
		return CaveAssets.destination_rect(CaveAssets.resource_art(node.kind), ground_anchor(Vector2(node.position)))
	return WorldVisualProfileSystem.visual_rect(VISUAL_PROFILE,ground_anchor(Vector2(node.position)))


## Строит основание ресурса для навигации и F10 по профилю его локации.
static func collision_rect(node: Dictionary) -> Rect2:
	if preload("res://scripts/systems/cave_room_data.gd").is_cave(String(node.get("location", ""))):
		return CaveAssets.collision_rect(CaveAssets.resource_art(node.kind), ground_anchor(Vector2(node.position)))
	return WorldVisualProfileSystem.collision_rect(VISUAL_PROFILE,ground_anchor(Vector2(node.position)))

## Выполняет заявленное игровое действие после проверки условий, затрат и наград.
static func mine_nearby(game: Node) -> bool:
	var interaction: String = game.nearest_interaction()
	if not interaction.begins_with("resource:"):
		game.message = game.LocaleSystem.text("no_resource")
		return false
	return mine(game, int(interaction.get_slice(":", 1)))

## Выполняет изолированную операцию своей подсистемы и возвращает результат согласно контракту.
static func mine(game: Node, index: int) -> bool:
	if not game.has_pickaxe or game.selected_tool != game.Tool.PICKAXE:
		game.message = game.LocaleSystem.text("need_pickaxe")
		return false
	if not game.AdventurePolishSystem.can_use(game, "pickaxe"): return false
	if index < 0 or index >= game.resource_nodes.size():
		return false
	var resource: Dictionary = game.resource_nodes[index]
	if resource.hits <= 0 or resource.location != game.current_location or game.player.distance_to(resource.position) > 92.0:
		return false
	resource.hits -= 1
	var yield_count: int = game.SkillSystem.mined_count(game)
	if not game.change_inventory_count(resource.kind, yield_count):
		return false
	game.award_xp(1)
	game.SkillSystem.award_profession_xp(game, "mining", 3)
	game.message = game.LocaleSystem.text("mined", [game.inventory_item_name(resource.kind), yield_count])
	if resource.hits <= 0:
		game.message += ". " + game.LocaleSystem.text("depleted")
	game.resource_nodes[index] = resource
	game.play_sfx("mine")
	game.AdventurePolishSystem.consume_durability(game, "pickaxe")
	game.notify_tutorial("mine")
	if resource.kind in ["red_crystal", "green_crystal"]:
		game.notify_tutorial("colored_crystal")
	if resource.kind == "metal" and preload("res://scripts/systems/cave_room_data.gd").is_cave(resource.location): game.notify_tutorial("cave_veins")
	return true

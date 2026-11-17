extends RefCounted

const Layout := preload("res://scripts/systems/village_layout_system.gd")
# Сохраняем имя, которое используют соседние карты и исторические инструменты.
# gdlint: disable=constant-name
const Props := {
	"well": preload("res://assets/game/locations/overworld/modular/prop_well_v1.png"),
	"bench": preload("res://assets/game/locations/overworld/modular/prop_bench_v1.png"),
	"lamp": preload("res://assets/game/locations/overworld/modular/prop_lamp_v1.png"),
	"board": preload("res://assets/game/locations/overworld/modular/prop_board_v1.png"),
	"cart": preload("res://assets/game/locations/overworld/modular/prop_cart_v1.png"),
}
# gdlint: enable=constant-name
const TreeTexture := preload("res://assets/game/environment/forest_tree_growth_atlas_v1.png")
const TreeSystem := preload("res://scripts/systems/tree_system.gd")
const BuildingSystem := preload("res://scripts/systems/building_system.gd")
const BuildingVisualSystem := preload("res://scripts/systems/building_visual_system.gd")
const TreeOcclusion := preload("res://scripts/systems/tree_occlusion_system.gd")
const WorldVisibility := preload("res://scripts/systems/world_visibility_system.gd")
const Bench := preload("res://scripts/presentation/village_bench_visual.gd")
const Street := preload("res://scripts/presentation/village_street_visual.gd")
const Board := preload("res://scripts/presentation/village_board_visual.gd")
const PilotPass := preload("res://scripts/presentation/pilot_object_pass.gd")
const Lamp := preload("res://scripts/presentation/village_lamp_visual.gd")
const Pose := preload("res://scripts/systems/presentation_pose_system.gd")
const GROUND_OFFSET := Vector2(0, 24)


## Рисует деревенские объекты на заднем или переднем плане по их точкам опоры.
static func draw(game: Node2D, foreground: bool) -> void:
	if game.get("current_location") != "overworld":
		return
	preload("res://scripts/presentation/village_fence_visual.gd").draw_farm(game, foreground)
	Board.draw_signs(game, foreground)
	var visible := WorldVisibility.visible_rect(game)
	if not foreground:
		for prop: Dictionary in Layout.PROP_PLACEMENTS:
			var position: Vector2 = prop.position
			var ground := position + GROUND_OFFSET
			var kind: String = prop.kind
			if (
				kind == "board"
				and visible.intersects(Board.destination("board", ground).grow(12), true)
			):
				Board.draw_shadow(game, "board", ground)
			elif kind == "bench" and visible.intersects(Bench.destination(ground).grow(12), true):
				Bench.draw_shadow(game, ground)
			elif (
				kind in ["well", "cart"]
				and visible.intersects(Street.destination(kind, ground).grow(12), true)
			):
				Street.draw_shadow(game, kind, ground)
	var player_ground := Pose.ground(game)
	for prop: Dictionary in Layout.PROP_PLACEMENTS:
		var position: Vector2 = prop.position
		if _in_front(position, player_ground) != foreground:
			continue
		var ground := position + GROUND_OFFSET
		var kind: String = prop.kind
		if kind == "board":
			if visible.intersects(Board.destination("board", ground), true):
				PilotPass.draw(game, prop, foreground, Board.draw.bind(game, "board", ground))
			continue
		if kind == "lamp":
			if visible.intersects(Lamp.destination(ground), true):
				Lamp.draw(game, ground)
			continue
		if kind in ["well", "cart"]:
			if visible.intersects(Street.destination(kind, ground), true):
				Street.draw(game, kind, ground)
			continue
		if kind == "bench":
			if visible.intersects(Bench.destination(ground), true):
				Bench.draw(game, ground)
			continue
		var rect: Rect2 = Layout.prop_rect(prop)
		if visible.intersects(rect, true):
			var texture: Texture2D = Props[kind]
			game.draw_texture_rect(texture, rect, false)
	if not foreground:
		for position: Vector2 in Layout.BORDER_TREES:
			var tree := {"position": position, "stage": 3}
			var rect: Rect2 = TreeSystem.destination_rect(tree)
			if visible.intersects(rect, true):
				TreeOcclusion.submit(
					game,
					TreeOcclusion.key_for("border", position),
					TreeTexture,
					rect,
					TreeSystem.source_rect(3),
					TreeSystem.ground_anchor(position).y,
					Color("d9e6c5")
				)


## Сравнивает линию земли, чтобы высокий объект мог перекрыть героя.
static func _in_front(position: Vector2, player: Vector2) -> bool:
	return player.y < position.y + 16.0


## Дорисовывает поверх героя те же фасады, когда персонаж действительно проходит за зданием.
static func draw_building_foreground(game: Node2D) -> void:
	if game.get("current_location") != "overworld":
		return
	var player_ground := Pose.ground(game)
	for id: String in BuildingSystem.buildings_at("overworld"):
		var door: Vector2 = BuildingSystem.BUILDINGS[id].door
		if player_ground.y < door.y - 24:
			BuildingVisualSystem.draw_building(game, id, door)

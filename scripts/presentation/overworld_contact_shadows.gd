# Карта и состояние приходят из композиционного игрового фасада.
@warning_ignore_start("unsafe_property_access")
extends RefCounted

const Shapes := preload("res://scripts/presentation/contact_shadow_shapes.gd")
const Layout := preload("res://scripts/systems/village_layout_system.gd")
const Map := preload("res://scripts/systems/village_map_data.gd")
const TreeSystem := preload("res://scripts/systems/tree_system.gd")
const Visibility := preload("res://scripts/systems/world_visibility_system.gd")


## Ставит контакт на землю под игровыми телами и независимо от временных эффектов.
static func draw(game: Node2D) -> void:
	if not preload("res://scripts/presentation/visual_version.gd").enabled(game):
		return
	var ground_view := Visibility.visible_rect(game)
	var workbench_ground: Vector2 = game.workbench_position + Vector2(0, 24)
	_draw_inside(game, Shapes.Shape.TABLE, workbench_ground, ground_view.grow(24))
	for prop: Dictionary in Layout.PROP_PLACEMENTS:
		if prop.kind == "lamp":
			var position: Vector2 = prop.position
			_draw_inside(game, Shapes.Shape.POST, position + Vector2(0, 24), ground_view)
	var tree_view := ground_view.grow(12)
	_draw_inside(game, Shapes.Shape.ROOTS, Map.SEASONAL_TREE, tree_view)
	for position: Vector2 in Layout.BORDER_TREES:
		_draw_inside(game, Shapes.Shape.ROOTS, TreeSystem.ground_anchor(position), tree_view)
	for tree: Dictionary in game.state.world.tree_nodes:
		var stage: int = tree.stage
		if stage == 3:
			var position: Vector2 = tree.position
			var ground := TreeSystem.ground_anchor(position)
			_draw_inside(game, Shapes.Shape.ROOTS, ground, tree_view)


## Пропускает опоры за пределами видимой земли с запасом для мягкой кромки.
static func _draw_inside(
	game: Node2D, shape: Shapes.Shape, anchor: Vector2, ground_view: Rect2
) -> void:
	if ground_view.has_point(anchor):
		Shapes.draw(game, shape, anchor)

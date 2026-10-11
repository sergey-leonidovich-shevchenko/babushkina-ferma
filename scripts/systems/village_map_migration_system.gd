extends RefCounted

const MapData:=preload("res://scripts/systems/village_map_data.gd")

## Переносит только координаты старого прототипа; награды, инвентарь, урожай и открытость сундуков не сбрасываются.
static func apply(game:Node,old_revision:int)->void:
	if old_revision>=MapData.REVISION: return
	if old_revision<2:
		game.WildlifeSystem.migrate_village_habitats(game)
		var default_containers:Array=game.LootContainerSystem.generate(game.world_loot_seed)
		for container in game.world_loot_nodes:
			if container.location!="overworld": continue
			for replacement in default_containers:
				if replacement.id==container.id: container.position=replacement.position; break
		game.NpcMovementSystem.initialize(game)
	for tree in game.state.world.tree_nodes:
		if tree.id=="tree_0" and Vector2(tree.position).is_equal_approx(Vector2(2016,336)):
			tree.position=MapData.TREES[0]
	if game.current_location=="overworld" and game.NavigationSystem.walkability_reason(game,game.player,-1,false)!="walkable":
		game.player=MapData.START if old_revision<2 else nearest_free_position(game,game.player)
	game.state.world.estate.map_revision=MapData.REVISION

## Выводит героя из нового основания рядом с прежней позицией; старый прогресс и обычные свободные координаты сохраняются.
static func nearest_free_position(game: Node, origin: Vector2) -> Vector2:
	for radius in range(12,193,12):
		for index in 16:
			var candidate := origin+Vector2.from_angle(index*TAU/16.0)*radius
			if game.NavigationSystem.walkability_reason(game,candidate,-1,false)=="walkable": return candidate
	return MapData.START

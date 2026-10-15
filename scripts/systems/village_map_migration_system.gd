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
	if old_revision<4:
		preload("res://scripts/systems/livestock_map_migration.gd").apply(game)
		var old_positions := {2:Vector2(864,1080),3:Vector2(696,1032),10:Vector2(792,984),11:Vector2(936,984),12:Vector2(1008,1080)}
		for index in old_positions:
			if index<game.food_nodes.size() and not bool(game.food_nodes[index].get("planted_by_player",false)) and Vector2(game.food_nodes[index].position).is_equal_approx(old_positions[index]):
				game.food_nodes[index].position=MapData.FORAGE[index]
	if old_revision<2 and game.current_location=="overworld" and game.VillageLayoutSystem.is_water(game.player,game.PLAYER_RADIUS): game.player=MapData.START
	if old_revision<5: preload("res://scripts/systems/water_save_migration.gd").apply(game)
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

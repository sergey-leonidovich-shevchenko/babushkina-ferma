extends RefCounted

const MapData:=preload("res://scripts/systems/village_map_data.gd")

## Переносит только координаты старого прототипа; награды, инвентарь, урожай и открытость сундуков не сбрасываются.
static func apply(game:Node,old_revision:int)->void:
	if old_revision>=MapData.REVISION: return
	game.WildlifeSystem.migrate_village_habitats(game)
	var default_containers:Array=game.LootContainerSystem.generate(game.world_loot_seed)
	for container in game.world_loot_nodes:
		if container.location!="overworld": continue
		for replacement in default_containers:
			if replacement.id==container.id: container.position=replacement.position; break
	if game.current_location=="overworld" and not game.NavigationSystem.is_walkable(game,game.player):
		game.player=MapData.START
	game.state.world.estate.map_revision=MapData.REVISION
	game.NpcMovementSystem.initialize(game)

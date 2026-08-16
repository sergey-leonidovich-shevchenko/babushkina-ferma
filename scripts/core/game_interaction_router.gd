extends RefCounted

const DEFAULT_RADIUS := 92.0

## Находит ближайшее доступное взаимодействие среди мира, сюжетных систем и предметов.
static func nearest(game: Node) -> String:
	var interactions := _fixed_interactions(game)
	var nearest := ""
	var nearest_distance := DEFAULT_RADIUS
	for key in interactions:
		var distance: float = game.player.distance_to(interactions[key])
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = key
	var building_interaction: String = game.BuildingSystem.nearest_interaction(game, nearest_distance)
	if not building_interaction.is_empty():
		nearest = building_interaction
		nearest_distance = game.player.distance_to(game.BuildingSystem.interaction_position(game, building_interaction))
	var quest_npc: String = game.QuestSystem.nearest_npc(game, nearest_distance)
	if not quest_npc.is_empty():
		nearest = "quest_npc:%s" % quest_npc
		nearest_distance = game.player.distance_to(game.QuestSystem.npc_position(game, quest_npc))
	var feature_result := _nearest_feature_interaction(game, nearest, nearest_distance)
	nearest = feature_result.interaction
	nearest_distance = feature_result.distance
	if game.home_chest_owned and game.current_location == "cottage_interior":
		var chest_distance: float = game.player.distance_to(game.StorageSystem.CHEST_POSITION)
		if chest_distance < nearest_distance:
			nearest = "home_chest"
			nearest_distance = chest_distance
	var prisoner_interaction: String = game.CompanionSystem.nearest_prisoner(game, nearest_distance)
	if not prisoner_interaction.is_empty():
		nearest = prisoner_interaction
		nearest_distance = game.player.distance_to(game.CompanionSystem.interaction_position(prisoner_interaction))
	return _nearest_dynamic_object(game, nearest, nearest_distance)

## Собирает фиксированные точки взаимодействия текущей локации.
static func _fixed_interactions(game: Node) -> Dictionary:
	var interactions := {}
	if game.current_location == "overworld":
		interactions = {
			"npc": game.NpcMovementSystem.actor(game, "grandmother", game.npc_position).position,
			"shop": game.BuildingSystem.SHOP_STALL_POSITION,
			"crate": game.BuildingSystem.SELL_CRATE_POSITION,
			"workbench": game.workbench_position,
			"cave_entrance": game.cave_entrance_position,
		}
		if game.loot_available:
			interactions["loot"] = game.slime_position
	elif game.current_location == "cave":
		interactions = {"cave_exit": game.cave_exit_position}
	if not game.BuildingSystem.is_interior(game.current_location):
		interactions["world_gate"] = game.world_gate_position
	return interactions

## Запрашивает ближайшие точки у независимых feature-систем в их прежнем приоритетном порядке.
static func _nearest_feature_interaction(game: Node, current: String, distance: float) -> Dictionary:
	var result := current
	var active_distance := distance
	var candidate: String = game.WorldEventSystem.nearest_interaction(game, distance)
	if not candidate.is_empty(): result = candidate
	candidate = game.VillageEventSystem.nearest_interaction(game, distance)
	if not candidate.is_empty(): result = candidate
	candidate = game.FarmLifeSystem.nearest_interaction(game, distance)
	if not candidate.is_empty(): result = candidate
	candidate = game.FirstChapterSystem.nearest_interaction(game, distance)
	if not candidate.is_empty(): result = candidate
	candidate = game.CastleCampaignSystem.nearest_interaction(game, active_distance)
	if not candidate.is_empty():
		result = candidate
		active_distance = game.player.distance_to(game.CastleCampaignSystem.interaction_position(candidate))
	candidate = game.EstateSystem.nearest_interaction(game, active_distance)
	if not candidate.is_empty(): result = candidate
	candidate = game.FenceSystem.nearest_gate(game, active_distance)
	if not candidate.is_empty():
		result = candidate
		var index := int(candidate.get_slice(":", 1))
		active_distance = game.player.distance_to(game.FenceSystem.structure_center(game.FenceSystem.structures(game)[index]))
	return {"interaction": result, "distance": active_distance}

## Сравнивает выброшенные предметы, контейнеры, ресурсы и собирательство без смешения их правил.
static func _nearest_dynamic_object(game: Node, current: String, distance: float) -> String:
	var nearest := current
	var nearest_distance := distance
	for index in game.dropped_items.size():
		var candidate_distance: float = game.player.distance_to(game.dropped_items[index].position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest = "drop:%d" % index
	for index in game.world_loot_nodes.size():
		var container: Dictionary = game.world_loot_nodes[index]
		if container.opened or container.location != game.current_location: continue
		var candidate_distance: float = game.player.distance_to(container.position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest = "container:%d" % index
	for index in game.resource_nodes.size():
		var resource: Dictionary = game.resource_nodes[index]
		if resource.hits <= 0 or resource.location != game.current_location: continue
		var candidate_distance: float = game.player.distance_to(resource.position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest = "resource:%d" % index
	for index in game.food_nodes.size():
		var food: Dictionary = game.food_nodes[index]
		if not game.ForageSystem.is_collectable(game, food) or food.get("location", "overworld") != game.current_location: continue
		var candidate_distance: float = game.player.distance_to(food.position)
		if candidate_distance < nearest_distance:
			nearest_distance = candidate_distance
			nearest = "food:%d" % index
	return nearest

## Выполняет найденное контекстное действие через единственного владельца соответствующей механики.
static func perform(game: Node) -> bool:
	var interaction: String = nearest(game)
	if interaction.begins_with("building:"): return game.BuildingSystem.enter(game, interaction.get_slice(":", 1))
	if interaction == "interior_exit": return game.BuildingSystem.leave(game)
	if interaction.begins_with("interior_link:"): return game.BuildingSystem.travel_inside(game, interaction.get_slice(":", 1))
	if interaction.begins_with("interior_service:"): return game.BuildingSystem.use_service(game, interaction.get_slice(":", 1))
	if interaction.begins_with("prisoner:"): return game.CompanionSystem.interact(game, interaction.get_slice(":", 1))
	if interaction.begins_with("quest_npc:"): return game.AdventurePolishSystem.open_quest_dialogue(game, interaction.get_slice(":", 1))
	if interaction == "home_chest": return game.StorageSystem.open(game)
	if interaction == "moon_portal": return game.WorldEventSystem.use_portal(game)
	if interaction.begins_with("moon_"): return game.MoonGladeSystem.interact(game, interaction)
	if interaction.begins_with("village_event:"): return game.VillageEventSystem.interact(game, interaction.get_slice(":", 1))
	if interaction.begins_with("life:"): return game.FarmLifeSystem.interact(game, interaction)
	if interaction == "chapter_bridge": return game.FirstChapterSystem.repair_bridge(game)
	if interaction.begins_with("castle_"): return game.CastleCampaignSystem.interact(game, interaction)
	if interaction == "estate_board": return game.EstateSystem.purchase_next(game)
	if interaction.begins_with("fence_gate:"): return game.FenceSystem.toggle_gate(game, int(interaction.get_slice(":", 1)))
	if interaction.begins_with("drop:"): return game.collect_dropped_item(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("container:"): return game.LootContainerSystem.open(game, int(interaction.get_slice(":", 1)))
	if interaction.begins_with("resource:"): return game.mine_resource(int(interaction.get_slice(":", 1)))
	if interaction.begins_with("food:"): return game.collect_food(int(interaction.get_slice(":", 1)))
	return _perform_fixed(game, interaction)

## Выполняет одну из небольших фиксированных операций первой локации.
static func _perform_fixed(game: Node, interaction: String) -> bool:
	match interaction:
		"npc": game.talk_to_grandmother()
		"shop": game.open_shop()
		"crate": game.sell_carrots()
		"workbench": game.open_crafting()
		"loot": game.collect_loot()
		"cave_entrance": game.enter_cave()
		"cave_exit": game.exit_cave()
		"world_gate": game.WorldSystem.travel(game)
		_: return false
	return true

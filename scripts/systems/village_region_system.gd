extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const Props := preload("res://scripts/systems/village_layout_system.gd")
const Buildings := preload("res://scripts/systems/building_visual_system.gd")
const Trees := preload("res://scripts/systems/tree_system.gd")

## Находит ближайшую дорогу в соседний район в той же системе радиусов, что автоматические переходы.
static func nearest(game: Node, radius: float) -> String:
	var result:=""
	for link in Data.passages(game.current_location):
		var distance:float=game.player.distance_to(link.position)
		if distance<radius: radius=distance; result="village_passage:"+String(link.port)
	return result

## Переводит героя по существующей обратимой связи, сохраняя весь мировой прогресс и размещая спутников рядом.
static func travel(game: Node, port: String) -> bool:
	for link in Data.passages(game.current_location):
		if link.port!=port or game.player.distance_to(link.position)>92: continue
		game.current_location=link.target; game.player=link.spawn
		game.location_transition_armed=false; game.location_transition_cooldown=game.LocationTransitionSystem.REENTRY_DELAY
		if Data.INWARD[port]==Data.INWARD[link.arrival]: game.clear_movement_keys()
		game.facing=Data.INWARD[link.arrival]
		game.action_held=false; game.attack_held=false; game.state.player.adventure_ui.target_enemy=-1
		game.companion_positions.clear()
		for companion in game.active_companions: game.companion_positions[companion]=game.player+Vector2(-48,24)
		game.NpcMovementSystem.update(game,0)
		game.sync_background_location(); game.update_camera(); game.play_sfx("travel")
		game.message=game.LocaleSystem.location(game.current_location); game.DiscoverySystem.show_location(game,game.current_location); game.notify_tutorial("village_regions")
		game.FirstChapterSystem.on_location_changed(game); return true
	return false

## Сверяет воду, фасады, декоративные основания и деревья с теми же профилями, которые рисует сцена.
static func blocks(game: Node, point: Vector2, radius: float) -> bool:
	var location:String=game.current_location
	if not Data.added(location): return false
	if Data.water_blocks(location,point,radius): return true
	if location=="village_river":
		for rail in Data.RAILS:
			if game.NavigationSystem.circle_intersects_rect(point,radius,rail): return true
	for house in Data.HOUSES.get(location,[]):
		if game.NavigationSystem.circle_intersects_rect(point,radius,Buildings.collision_bounds(house.kind,house.position)): return true
	for prop in Data.PROPS.get(location,[]):
		var rect:Rect2=game.FarmLifeVisualSystem.collision_rect("rustic_table",prop.position) if prop.kind=="table" else Props.prop_collision_rect(prop.merged({"solid":true}))
		if game.NavigationSystem.circle_intersects_rect(point,radius,rect): return true
	for tree in Data.trees(location):
		if game.NavigationSystem.circle_intersects_rect(point,radius,Trees.collision_rect(tree)): return true
	return false

## Проверяет, что указанная местная услуга существует и герой находится у её рабочей стороны.
static func use_service(game: Node, service: String) -> bool:
	var point:Vector2=Data.SERVICES.get(game.current_location,{}).get(service,Vector2.INF)
	if game.player.distance_to(point)>92: return false
	match service:
		"shop": game.open_shop()
		"workbench": game.open_crafting()
		"alchemy": game.open_crafting("alchemy")
		_: return false
	game.notify_tutorial("village_regions"); return true

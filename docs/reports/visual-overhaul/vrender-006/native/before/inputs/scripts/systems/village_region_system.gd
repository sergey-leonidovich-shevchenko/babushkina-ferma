extends RefCounted

const Data := preload("res://scripts/systems/village_region_data.gd")
const Props := preload("res://scripts/systems/village_layout_system.gd")
const Buildings := preload("res://scripts/systems/building_visual_system.gd")
const Trees := preload("res://scripts/systems/tree_system.gd")
const Workbench := preload("res://scripts/presentation/world_workbench_visual_system.gd")

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
		var source: String = game.current_location; var previous: Vector2 = game.player
		game.current_location=link.target
		var arrival := arrival_position(game,link)
		if not arrival.is_finite():
			game.current_location=source; game.player=previous
			game.message=preload("res://scripts/systems/village_wayfinding_system.gd").word(game,"blocked"); return false
		game.player=arrival
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

## Ищет свободное появление около того же входа, ограничивая обход шестью кольцами по восемь точек.
static func arrival_position(game: Node, link: Dictionary) -> Vector2:
	var origin: Vector2 = link.spawn
	if game.NavigationSystem.is_walkable(game,origin): return origin
	var inward: Vector2 = Data.INWARD[link.arrival]; var side := Vector2(-inward.y,inward.x)
	for distance in range(24,145,24):
		for offset in [inward,side,-side,-inward,inward+side,inward-side,-inward+side,-inward-side]:
			var candidate: Vector2 = origin+Vector2(offset)*distance
			if game.NavigationSystem.is_walkable(game,candidate): return candidate
	return Vector2.INF

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
		var rect:Rect2
		if prop.kind=="workbench": rect=Workbench.collision_rect(prop.position)
		elif prop.kind=="table": rect=game.FarmLifeVisualSystem.collision_rect("rustic_table",prop.position)
		else: rect=Props.prop_collision_rect(prop.merged({"solid":true}))
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

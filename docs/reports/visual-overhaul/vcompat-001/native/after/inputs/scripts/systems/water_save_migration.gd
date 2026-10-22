extends RefCounted

const Water := preload("res://scripts/systems/water_map_registry.gd")
static var _offsets: Array[Vector2i]=[]

## Выносит из нового русла только координаты, сохраняя содержимое, здоровье, количество и идентичность объектов.
static func apply(game: Node) -> void:
	var location: String=game.current_location
	var moved: Array=[]
	for entries in [game.dropped_items,game.world_loot_nodes,game.enemy_nodes,game.wildlife_nodes,game.food_nodes]:
		for entry in entries:
			var area: String=String(entry.get("location","overworld"))
			if area not in ["overworld","village_river","cave_lake"]: continue
			var point: Vector2=entry.position
			if not Water.blocks(area,point,27): continue
			game.current_location=area
			entry.position=nearest_land(game,point)
			moved.append({"location":area,"id":str(entry.get("id",entry.get("kind","object"))),"from":point,"to":entry.position})
			if entry.has("home") and Water.blocks(area,entry.home,27): entry.home=entry.position
	game.current_location=location
	if location in ["overworld","village_river","cave_lake"] and Water.blocks(location,game.player,game.PLAYER_RADIUS):
		game.player=nearest_land(game,game.player)
	game.set_meta("water_migration",moved)

## Проверяет сетку по расстоянию и использует проверенную точку входа только при отсутствии места рядом.
static func nearest_land(game: Node, origin: Vector2) -> Vector2:
	var center:=Vector2i((origin/24.0).round())
	if _offsets.is_empty():
		for y in range(-24,25):
			for x in range(-24,25): _offsets.append(Vector2i(x,y))
		_offsets.sort_custom(func(a: Vector2i,b: Vector2i): return a.length_squared()<b.length_squared() if a.length_squared()!=b.length_squared() else (a.y<b.y if a.y!=b.y else a.x<b.x))
	for offset in _offsets:
		var point:=Vector2(center+offset)*24
		if Water.blocks(game.current_location,point,27): continue
		if game.NavigationSystem.walkability_reason(game,point,-1,false,false)=="walkable": return point
	return preload("res://scripts/systems/recovery_system.gd").safe_spawn(game)

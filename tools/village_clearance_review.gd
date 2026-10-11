extends SceneTree

const Map := preload("res://scripts/systems/village_map_data.gd")
const Game := preload("res://scripts/game.gd")

## Измеряет поперечный запас всех размеченных дорожек реальным кругом героя, исключая только подвижных врагов.
func _initialize() -> void:
	var game := Game.new(); game._ready(); game.current_location="overworld"
	var results: Array = []
	var path_index := 0
	for path in Map.routes():
		var minimum := 1000.0; var worst := Vector2.ZERO; var blocked: Array = []
		for segment in range(path.size()-1):
			var start: Vector2 = path[segment]; var finish: Vector2 = path[segment+1]
			var normal := start.direction_to(finish).orthogonal()
			var count := maxi(1,ceili(start.distance_to(finish)/12))
			for sample in range(count+1):
				var point := start.lerp(finish,float(sample)/count)
				var reason: String = game.NavigationSystem.walkability_reason(game,point,-1,false)
				if reason!="walkable":
					if blocked.size()<10: blocked.append({"point":[point.x,point.y],"reason":reason})
					continue
				var width := clearance(game,point,normal)+clearance(game,point,-normal)+game.PLAYER_RADIUS*2
				if width<minimum: minimum=width; worst=point
		results.append({"path":path_index,"minimum_width":minimum,"worst":[worst.x,worst.y],"blocked":blocked})
		path_index+=1
	var guild: Array = game.BuildingSystem.collision_rects("guild_hall")
	var right := 0.0
	for rect in guild: right=maxf(right,rect.end.x)
	var tree: Rect2 = game.TreeSystem.collision_rect(game.state.world.tree_nodes[0])
	var report := {"revision":Map.REVISION,"player_radius":game.PLAYER_RADIUS,"resolution":2,"note":"Width equals admissible center band plus 36px body; moving enemies excluded, live persistent objects retained. Endpoints near interaction targets are included.","guild_tree_gap":tree.position.x-right,"paths":results}
	var path := "res://docs/reports/five-priorities-2026-10-11/village/clearance-before.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path=argument.trim_prefix("--output=")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("VILLAGE CLEARANCE ",JSON.stringify(report))
	var good: bool = report.guild_tree_gap>=60 and results.all(func(result):return result.blocked.is_empty() and result.minimum_width>=60)
	game.free(); quit(0 if good else 1)

## Ищет первый физический край с точностью два пикселя, не подменяя его нарисованной шириной дороги.
func clearance(game: Node, point: Vector2, direction: Vector2) -> float:
	for distance in range(2,122,2):
		if game.NavigationSystem.walkability_reason(game,point+direction*distance,-1,false)!="walkable": return float(distance-2)
	return 120.0

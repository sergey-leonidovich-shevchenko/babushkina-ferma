extends SceneTree

const Game := preload("res://scripts/game.gd")
const Art := preload("res://scripts/systems/cave_boss_art_system.gd")

## Сравнивает одинаковые горячие запросы отдельно от vsync; никаких пользовательских сохранений не читает.
func _initialize() -> void:
	var game := Game.new(); game._ready()
	game.current_location = "cave_sanctum"
	var frames: Array = []
	for kind in Art.catalog():
		for value in Art.catalog()[kind].frames: frames.append([kind,int(value.row),int(value.column)])
	var points: Array[Vector2] = []
	for y in range(360,1000,80):
		for x in range(1080,2040,80): points.append(Vector2(x,y))
	for point in points: game.NavigationSystem.walkability_reason(game,point,-1,false)
	var results := {"frame_lookup_us":[],"navigation_us":[],"frames_per_pass":frames.size()*500,"queries_per_pass":points.size()*30}
	for _pass in 5:
		var start := Time.get_ticks_usec()
		for _repeat in 500:
			for value in frames: Art.frame(value[0],value[1],value[2])
		results.frame_lookup_us.append(Time.get_ticks_usec()-start)
		start = Time.get_ticks_usec()
		for _repeat in 30:
			for point in points: game.NavigationSystem.walkability_reason(game,point,-1,false)
		results.navigation_us.append(Time.get_ticks_usec()-start)
	var path := "res://docs/reports/five-priorities-2026-10-11/performance/cpu-before.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): path = argument.trim_prefix("--output=")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(results,"  ")+"\n")
	print("BOSS CPU REVIEW: ",JSON.stringify(results))
	game.free(); quit()

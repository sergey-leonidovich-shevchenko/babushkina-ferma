extends Node2D

const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
var junctions := false
var season := "spring"

## Показывает ровно пять на пять модулей в том же масштабе 120%, без направляющих поверх рисунка.
func _draw() -> void:
	Meadow.draw(self,Vector2.ONE*Meadow.CELL*5,Terrain.ground_tint(season,"clear"))
	if not junctions: return
	var paths := [
		[Vector2(48,144),Vector2(384,144)],
		[Vector2(576,144),Vector2(864,144)], [Vector2(720,144),Vector2(720,288)],
		[Vector2(48,432),Vector2(240,432),Vector2(240,600)],
		[Vector2(528,480),Vector2(864,480)],
		[Vector2(48,816),Vector2(240,816),Vector2(240,672)],
		[Vector2(576,816),Vector2(864,816)], [Vector2(720,672),Vector2(720,912)]
	]
	for path in paths:
		for i in range(1,path.size()):
			Terrain.material(self,Terrain.capsule(path[i-1],path[i],36),Terrain.PATH)

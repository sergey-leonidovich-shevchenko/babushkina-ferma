extends Node2D

const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const MapData := preload("res://scripts/systems/village_map_data.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const LOCATIONS: Array[String] = [
	"overworld",
	"village_market",
	"village_garden",
	"village_river",
	"village_workyard",
	"village_orchard"
]
var season := "spring"


## Показывает шесть биомов одной деревни в одинаковом масштабе и сезонном тоне.
func _draw() -> void:
	var tile := Vector2(384, 324)
	for index in LOCATIONS.size():
		var offset := Vector2(index % 3, index / 3) * tile
		draw_set_transform(offset)
		Meadow.draw(
			self,
			tile,
			Terrain.ground_tint(season, "clear"),
			MapData.ground_biome(LOCATIONS[index]),
			true
		)
		draw_rect(Rect2(Vector2.ZERO, tile), Color(0.23, 0.29, 0.19, 0.72), false, 3.0)
	draw_set_transform(Vector2.ZERO)

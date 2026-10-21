extends Node2D

const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
var season := "spring"
var weather := "clear"
var cover := false
var holes := false
var soft_ground_edges := false
var paint_count := 0

## Перестраивает сохранённые команды только при изменении окружения, а не по фазе анимации.
func configure(next_season: String, next_weather: String, is_cover: bool, is_hole: bool = false, soft_edges: bool = false) -> void:
	if season==next_season and weather==next_weather and cover==is_cover and holes==is_hole and soft_ground_edges==soft_edges and paint_count>0: return
	season=next_season; weather=next_weather; cover=is_cover; holes=is_hole; soft_ground_edges=soft_edges; queue_redraw()

## Разделяет поверхность воды и неподвижное перекрытие без дополнительного render target.
func _draw() -> void:
	paint_count+=1
	if holes: Terrain.draw_cutouts(self)
	elif cover:
		Terrain.draw_cover(self,season,weather)
		# Выходные дорожки раньше рисовались после всех цветов и мостов: порядок сохраняется внутри кеша.
		preload("res://scripts/presentation/village_region_terrain.gd").paths(self,"overworld",soft_ground_edges)
	else: Terrain.draw_surface(self,season,true)

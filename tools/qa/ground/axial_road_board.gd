extends Node2D

const Builder := preload("res://tools/qa/ground/axial_road_builder.gd")
const LegacyBuilder := preload("res://tools/qa/ground/ground_edge_builder.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const PATHS := [
	[Vector2(48,144),Vector2(384,144)],
	[Vector2(576,144),Vector2(864,144)],[Vector2(720,144),Vector2(720,288)],
	[Vector2(48,432),Vector2(240,432),Vector2(240,600)],
	[Vector2(528,480),Vector2(864,480)],
	[Vector2(48,816),Vector2(240,816),Vector2(240,696)],
	[Vector2(576,816),Vector2(864,816)],[Vector2(720,672),Vector2(720,912)]
]
static var fixture: ArrayMesh
static var legacy_fixture: ArrayMesh
var kind := "after"
var season := "spring"

## Компилирует только отдельный проверочный чертёж; обычная игра загружает уже готовые маски.
func _ready() -> void:
	if fixture==null: fixture=Builder.build(PATHS,Vector2(960,960))
	if legacy_fixture==null: legacy_fixture=LegacyBuilder.build(PATHS,Vector2(960,960))
	queue_redraw()

## Показывает одинаковую геометрию со старой рамкой, мягкой кромкой, отдельно от цвета и с другим материалом.
func _draw() -> void:
	if kind=="legacy-mask": draw_mesh(legacy_fixture,null,Transform2D.IDENTITY,Color("315348")); return
	if kind in ["mask","recolor"]:
		draw_mesh(fixture,null if kind=="mask" else Terrain.DIRT,Transform2D.IDENTITY,Color("315348") if kind=="mask" else Color.WHITE)
		return
	Meadow.draw(self,Vector2(960,960),Terrain.ground_tint(season,"clear"))
	if kind=="after": draw_mesh(fixture,Terrain.PATH); return
	draw_mesh(legacy_fixture,Terrain.PATH)

extends Node2D

const Builder := preload("res://tools/road_network_builder.gd")
const Legacy := preload("res://tools/axial_road_builder.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const Terrain := preload("res://scripts/systems/village_terrain_renderer.gd")
const MAIN := [[Vector2(48,144),Vector2(384,144)],[Vector2(576,144),Vector2(864,144)],[Vector2(48,432),Vector2(240,432)],[Vector2(528,480),Vector2(864,480)],[Vector2(48,816),Vector2(240,816)],[Vector2(576,816),Vector2(864,816)]]
const UPPER := [[Vector2(384,144),Vector2(384,216)],[Vector2(720,144),Vector2(720,288)],[Vector2(240,432),Vector2(240,600)],[Vector2(240,816),Vector2(240,696)],[Vector2(720,672),Vector2(720,912)]]
static var fixture: Dictionary
static var reference: ArrayMesh
static var old_main: ArrayMesh
static var old_upper: ArrayMesh
var kind := "after"
var season := "spring"

## Строит независимые контрольные стыки; промышленная карта загружает готовые ресурсы.
func _ready() -> void:
	if fixture.is_empty():
		fixture=Builder.build(MAIN,UPPER,Vector2(960,960))
		reference=Legacy.build(MAIN+UPPER,Vector2(960,960))
		old_main=Legacy.build(MAIN,Vector2(960,960)); old_upper=Legacy.build(UPPER,Vector2(960,960))
	queue_redraw()

## Сравнивает два владельца с единой эталонной геометрией в том же материале, масштабе и мировой фазе.
func _draw() -> void:
	if kind=="reference-mask": draw_mesh(reference,null); return
	if kind in ["mask","recolor"]:
		var texture: Texture2D=Terrain.DIRT if kind=="recolor" else null
		draw_mesh(fixture.main,texture); draw_mesh(fixture.connectors,texture); return
	Meadow.draw(self,Vector2(960,960),Terrain.ground_tint(season,"clear"))
	if kind=="reference": draw_mesh(reference,Terrain.PATH)
	elif kind=="after": draw_mesh(fixture.main,Terrain.PATH); draw_mesh(fixture.connectors,Terrain.PATH)
	else: draw_mesh(old_main,Terrain.PATH); draw_mesh(old_upper,Terrain.PATH,Transform2D.IDENTITY,Color("ddc79e"))

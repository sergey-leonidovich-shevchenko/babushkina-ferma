extends RefCounted

const MAIN := preload("res://assets/game/locations/overworld/ground_masks/main.res")
const CONNECTORS := preload("res://assets/game/locations/overworld/ground_masks/connectors.res")
const AXIAL_MAIN := preload("res://assets/game/locations/overworld/axial_road_masks/main.res")
const AXIAL_CONNECTORS := preload("res://assets/game/locations/overworld/axial_road_masks/connectors.res")

const NETWORK_MAIN := preload("res://assets/game/locations/overworld/road_network_masks/main.res")
const NETWORK_CONNECTORS := preload("res://assets/game/locations/overworld/road_network_masks/connectors.res")

## Использует готовую альфа-геометрию с белыми вершинами; цвет приходит только из отдельного материала.
static func draw(canvas: Node2D, texture: Texture2D, connectors: bool=false, tint: Color=Color.WHITE, rectangular: bool=false, network: bool=false) -> void:
	var mesh: ArrayMesh=(AXIAL_CONNECTORS if connectors else AXIAL_MAIN) if rectangular else (CONNECTORS if connectors else MAIN)
	if rectangular and network: mesh=NETWORK_CONNECTORS if connectors else NETWORK_MAIN
	canvas.draw_mesh(mesh,texture,Transform2D.IDENTITY,Color.WHITE if rectangular and network else tint)

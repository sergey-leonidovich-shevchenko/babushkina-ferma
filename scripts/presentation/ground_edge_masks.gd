extends RefCounted

const MAIN := preload("res://assets/game/locations/overworld/ground_masks/main.res")
const CONNECTORS := preload("res://assets/game/locations/overworld/ground_masks/connectors.res")

## Использует готовую альфа-геометрию с белыми вершинами; цвет приходит только из отдельного материала.
static func draw(canvas: Node2D, texture: Texture2D, connectors: bool=false, tint: Color=Color.WHITE) -> void:
	canvas.draw_mesh(CONNECTORS if connectors else MAIN,texture,Transform2D.IDENTITY,tint)

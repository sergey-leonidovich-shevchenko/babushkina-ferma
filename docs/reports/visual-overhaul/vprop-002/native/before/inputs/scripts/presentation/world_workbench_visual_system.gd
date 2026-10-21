extends RefCounted

const Stations := preload("res://scripts/presentation/basement_visual_system.gd")
const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const FRONT_WIDTH := 96.0

## Выбирает настоящий ремесленный верстак из согласованного набора с тремя рабочими ракурсами.
static func texture(direction: int = 0) -> AtlasTexture:
	return Stations.texture("workbench",1,Facing.visible(direction))

## Совмещает изображение с нижней опорой и сохраняет общий масштаб переднего и боковых рисунков.
static func destination(ground: Vector2, direction: int = 0) -> Rect2:
	var size := texture(direction).get_size()*(FRONT_WIDTH/texture(0).get_width())
	return Rect2(ground-Vector2(size.x/2,size.y),size)

## Сохраняет прежнее основание верстака ремесленного двора независимо от деталей столешницы.
static func collision_rect(ground: Vector2) -> Rect2:
	return Rect2(ground-Vector2(36,48),Vector2(72,48))

## Рисует тиски, киянку, рубанок и полку без поворота готовой картинки и без растягивания.
static func draw(canvas: CanvasItem, ground: Vector2, direction: int = 0) -> void:
	canvas.draw_texture_rect(texture(direction),destination(ground,direction),false)

## Описывает тот же верстак для будущего прохода; обычный draw пока сохраняет прежний маршрут.
static func command(ground: Vector2, direction: int = 0) -> Dictionary:
	var image := texture(direction)
	return preload("res://scripts/presentation/object_draw_command.gd").create({
		"version":1,"id":"workbench:%s:%s"%[ground,direction],"world":"overworld","space":"world",
		"anchor":ground,"bounds":destination(ground,direction),"texture":image,
		"source":Rect2(Vector2.ZERO,image.get_size()),"material":null,"modulate":Color.WHITE,
		"local_uv":Rect2(0,0,1,1),"layer":"behind_actors"})

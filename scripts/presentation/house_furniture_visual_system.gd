extends RefCounted

const DIRECTIONS := ["south","west","north","east"]
const KINDS := ["rustic_table","wooden_chair","wooden_wardrobe","bed","shop","woven_rug","home_chest"]
const SPRITES := {
	"rustic_table":[preload("res://assets/game/interiors/furniture_a/rustic_table_south.png"),preload("res://assets/game/interiors/furniture_a/rustic_table_west.png"),preload("res://assets/game/interiors/furniture_a/rustic_table_north.png"),preload("res://assets/game/interiors/furniture_a/rustic_table_east.png")],
	"wooden_chair":[preload("res://assets/game/interiors/furniture_a/wooden_chair_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_west.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_north.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_east.png")],
	"wooden_wardrobe":[preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_west.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_north.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_east.png")],
	"bed":[preload("res://assets/game/interiors/furniture_a/bed_south.png"),preload("res://assets/game/interiors/furniture_a/bed_west.png"),preload("res://assets/game/interiors/furniture_a/bed_north.png"),preload("res://assets/game/interiors/furniture_a/bed_east.png")],
	"shop":[preload("res://assets/game/interiors/furniture_a/shop_south.png"),preload("res://assets/game/interiors/furniture_a/shop_west.png"),preload("res://assets/game/interiors/furniture_a/shop_north.png"),preload("res://assets/game/interiors/furniture_a/shop_east.png")],
	"woven_rug":[preload("res://assets/game/interiors/furniture_a/woven_rug_south.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_west.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_north.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_east.png")],
	"home_chest":[preload("res://assets/game/interiors/furniture_a/home_chest_south.png"),preload("res://assets/game/interiors/furniture_a/home_chest_west.png"),preload("res://assets/game/interiors/furniture_a/home_chest_north.png"),preload("res://assets/game/interiors/furniture_a/home_chest_east.png")],
	"pottery_1":[preload("res://assets/game/interiors/furniture_a/pottery_1_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_north.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_east.png")],
	"pottery_2":[preload("res://assets/game/interiors/furniture_a/pottery_2_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_north.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_east.png")],
	"pottery_3":[preload("res://assets/game/interiors/furniture_a/pottery_3_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_north.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_east.png")],
	"stairs":[preload("res://assets/game/interiors/furniture_a/stairs_south.png")],
}
static var _regions: Dictionary = {}

## Выбирает отдельный нарисованный ракурс; готовые изображения никогда не вращаются на холсте.
static func texture(kind: String, direction: int=0) -> Texture2D:
	return SPRITES[kind][posmod(direction,SPRITES[kind].size())]

## Один раз запоминает полный силуэт выбранного спрайта без прозрачных внешних полей.
static func source(kind: String, direction: int=0) -> Rect2:
	var key:=kind+"_"+str(posmod(direction,4))
	if not _regions.has(key): _regions[key]=Rect2(texture(kind,direction).get_image().get_used_rect())
	return _regions[key]

## Равномерно вписывает рисунок в габарит, сохраняя нижнюю центральную опору мебели.
static func destination(kind: String, position: Vector2, bounds: Vector2, direction: int=0) -> Rect2:
	var size:=source(kind,direction).size
	size*=minf(bounds.x/size.x,bounds.y/size.y)
	return Rect2(position-Vector2(size.x/2,size.y),size)

## Рисует утверждённую мебель А в одном из четырёх прямых ракурсов с неизменными пропорциями.
static func draw(canvas: CanvasItem, kind: String, position: Vector2, bounds: Vector2, direction: int=0, tint: Color=Color.WHITE) -> void:
	canvas.draw_texture_rect_region(texture(kind,direction),destination(kind,position,bounds,direction),source(kind,direction),tint)

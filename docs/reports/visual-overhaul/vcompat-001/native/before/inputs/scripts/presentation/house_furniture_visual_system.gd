extends RefCounted

const Facing := preload("res://scripts/systems/furniture_facing_system.gd")
const Resources := preload("res://scripts/systems/visual_resource_catalog.gd")
const DIRECTIONS := Facing.NAMES
const KINDS := ["rustic_table","wooden_chair","wooden_wardrobe","bed","shop","woven_rug","home_chest"]
# Индекс2 сохранён для старых записей и повторяет передний ресурс; задняя графика не загружается.
static var SPRITES := {
	"rustic_table":[Resources.texture("prop.rustic_table","south"),Resources.texture("prop.rustic_table","west"),Resources.texture("prop.rustic_table","south"),Resources.texture("prop.rustic_table","east")],
	"wooden_chair":[preload("res://assets/game/interiors/furniture_a/wooden_chair_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_west.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_chair_east.png")],
	"wooden_wardrobe":[preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_west.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_south.png"),preload("res://assets/game/interiors/furniture_a/wooden_wardrobe_east.png")],
	"bed":[preload("res://assets/game/interiors/furniture_a/bed_south.png"),preload("res://assets/game/interiors/furniture_a/bed_west.png"),preload("res://assets/game/interiors/furniture_a/bed_south.png"),preload("res://assets/game/interiors/furniture_a/bed_east.png")],
	"shop":[preload("res://assets/game/interiors/furniture_a/shop_south.png"),preload("res://assets/game/interiors/furniture_a/shop_west.png"),preload("res://assets/game/interiors/furniture_a/shop_south.png"),preload("res://assets/game/interiors/furniture_a/shop_east.png")],
	"woven_rug":[preload("res://assets/game/interiors/furniture_a/woven_rug_south.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_west.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_south.png"),preload("res://assets/game/interiors/furniture_a/woven_rug_east.png")],
	"home_chest":[preload("res://assets/game/interiors/furniture_a/home_chest_south.png"),preload("res://assets/game/interiors/furniture_a/home_chest_west.png"),preload("res://assets/game/interiors/furniture_a/home_chest_south.png"),preload("res://assets/game/interiors/furniture_a/home_chest_east.png")],
	"pottery_1":[preload("res://assets/game/interiors/furniture_a/pottery_1_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_1_east.png")],
	"pottery_2":[preload("res://assets/game/interiors/furniture_a/pottery_2_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_2_east.png")],
	"pottery_3":[preload("res://assets/game/interiors/furniture_a/pottery_3_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_west.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_south.png"),preload("res://assets/game/interiors/furniture_a/pottery_3_east.png")],
	"stairs":[preload("res://assets/game/interiors/furniture_a/stairs_south.png")],
}
static var _regions: Dictionary = {}

## Сохраняет прежнюю неизменяемость публичного каталога после разрешения текстур из паспорта.
static func _static_init() -> void:
	for sequence in SPRITES.values(): sequence.make_read_only()
	SPRITES.make_read_only()

## Выбирает лицевой или боковой рисунок; старый задний ракурс заменяется передним без растрового вращения.
static func texture(kind: String, direction: int=0) -> Texture2D:
	return SPRITES[kind][Facing.visible(direction) if SPRITES[kind].size()>1 else 0]

## Один раз запоминает полный силуэт выбранного спрайта без прозрачных внешних полей.
static func source(kind: String, direction: int=0) -> Rect2:
	if kind=="rustic_table": return Resources.describe("prop.rustic_table",Facing.NAMES[Facing.visible(direction)]).source
	var key:=kind+"_"+str(Facing.visible(direction))
	if not _regions.has(key): _regions[key]=Rect2(texture(kind,direction).get_image().get_used_rect())
	return _regions[key]

## Равномерно вписывает рисунок в габарит, сохраняя нижнюю центральную опору мебели.
static func destination(kind: String, position: Vector2, bounds: Vector2, direction: int=0) -> Rect2:
	if kind=="rustic_table": return Resources.destination(Resources.describe("prop.rustic_table",Facing.NAMES[Facing.visible(direction)]),position,bounds)
	var size:=source(kind,direction).size
	size*=minf(bounds.x/size.x,bounds.y/size.y)
	return Rect2(position-Vector2(size.x/2,size.y),size)

## Рисует утверждённую мебель А с видимой лицевой стороной и неизменными пропорциями.
static func draw(canvas: CanvasItem, kind: String, position: Vector2, bounds: Vector2, direction: int=0, tint: Color=Color.WHITE) -> void:
	var selected := Resources.sampled_texture("prop.rustic_table",Facing.NAMES[Facing.visible(direction)]) if kind=="rustic_table" else texture(kind,direction)
	canvas.draw_texture_rect_region(selected,destination(kind,position,bounds,direction),source(kind,direction),tint)

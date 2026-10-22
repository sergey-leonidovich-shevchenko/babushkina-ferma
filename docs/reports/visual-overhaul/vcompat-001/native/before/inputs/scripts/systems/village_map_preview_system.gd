extends RefCounted

const Layout:=preload("res://scripts/systems/village_layout_system.gd")
const BuildingSystem:=preload("res://scripts/systems/building_system.gd")
static var _texture:Texture2D

## Готовит миникарту в _ready фонового узла, до запуска управления; конец вступления не выполняет растеризацию внутри draw.
static func warmup()->void:
	texture()

## Создаёт мини-карту из действующего чертежа, поэтому мосты и дома совпадают с игровым миром после редизайна.
static func texture()->Texture2D:
	if _texture!=null: return _texture
	var dimensions:=Vector2i(Layout.MapData.WORLD_SIZE/12)
	var image:=Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8)
	for y in dimensions.y:
		for x in dimensions.x:
			var position:=Vector2(x,y)*12+Vector2(6,6)
			var color:=Color("788d49")
			if Layout.is_water(position,0): color=Color("4d8999")
			elif Layout.is_road_or_path(position): color=Color("c5ae79")
			elif Layout.is_farm_zone(position): color=Color("85623c")
			image.set_pixel(x,y,color)
	for id in BuildingSystem.buildings_at("overworld"):
		var rect:=BuildingSystem.destination_rect(id)
		image.fill_rect(Rect2i(rect.position/12,rect.size/12),Color("b98b4c"))
	for bridge in Layout.BRIDGES: image.fill_rect(Rect2i(bridge.position/12,bridge.size/12),Color("c6a665"))
	_texture=ImageTexture.create_from_image(image)
	return _texture

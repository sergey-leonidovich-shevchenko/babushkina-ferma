extends RefCounted

const SOURCE := preload("res://assets/game/locations/overworld/modular/plaza_limestone_v1.png")
const EARTH := preload("res://assets/game/locations/overworld/modular/path_material_v1.png")
const DIRT := preload("res://assets/game/locations/overworld/modular/dirt_material_v1.png")
const APRON := preload("res://assets/game/locations/overworld/plaza_masks/apron.res")
const CONTACT := preload("res://assets/game/locations/overworld/plaza_masks/contact.res")
const STONE := preload("res://assets/game/locations/overworld/plaza_masks/stone.res")
static var _textures: Dictionary={}

## Изолирует сглаживание и mipmaps нового материала; прежние текстуры других карт не меняются.
static func texture(source: Texture2D=SOURCE) -> CanvasTexture:
	if not _textures.has(source):
		var value := CanvasTexture.new(); value.diffuse_texture=source
		value.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; value.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
		_textures[source]=value
	return _textures[source]

## Ставит землю, лёгкий контакт и камень в прежнее место неподвижного прохода площади.
static func draw(canvas: Node2D, season: String, weather: String) -> void:
	var tint: Color={"summer":Color("f1ead7"),"autumn":Color("efdfc5"),"winter":Color("d2dddc")}.get(season,Color.WHITE)
	if weather in ["rain","storm"]: tint*=Color("ccd7dc")
	canvas.draw_mesh(APRON,texture(EARTH),Transform2D.IDENTITY,tint)
	canvas.draw_mesh(CONTACT,null,Transform2D.IDENTITY,Color("685b43"))
	canvas.draw_mesh(STONE,texture(),Transform2D.IDENTITY,Color("eee5d3")*tint)

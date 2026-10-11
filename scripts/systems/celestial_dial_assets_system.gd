extends RefCounted

const ROOT := "res://assets/game/ui/celestial_dial_v1/"
static var _textures: Dictionary = {}

## Прогревает три небольших слоя часов до первого игрового кадра.
static func warmup() -> void:
	for kind in ["sky", "landscape", "frame"]: texture(kind)

## Сохраняет линейную фильтрацию только для рисованного циферблата, не меняя пиксельные ресурсы мира.
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		var result := CanvasTexture.new()
		result.diffuse_texture=load(ROOT+kind+".png")
		result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_textures[kind]=result
	return _textures[kind]

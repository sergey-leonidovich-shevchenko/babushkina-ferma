extends RefCounted

const ROOT := "res://assets/game/ui/celestial_dial_v1/"
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
static var _textures: Dictionary = {}

## Прогревает три небольших слоя часов до первого игрового кадра.
static func warmup() -> void:
	for kind in ["sky", "landscape", "frame"]: texture(kind)

## Сохраняет линейную фильтрацию только для рисованного циферблата, не меняя пиксельные ресурсы мира.
static func texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind]=Sampling.create(load(ROOT+kind+".png"),"painted_ui")
	return _textures[kind]

extends RefCounted

const DATA := preload("res://assets/game/visual_sampling.json")
const FILTERS := {"nearest":CanvasItem.TEXTURE_FILTER_NEAREST,"linear":CanvasItem.TEXTURE_FILTER_LINEAR}


## Даёт независимую копию политики без изменяемого общего состояния.
static func policy() -> Dictionary:
	return DATA.data.duplicate(true)


## Закрепляет прежнюю фильтрацию полотна мира и интерфейса независимо от общего флага проекта.
static func preserve_legacy(canvas: CanvasItem) -> void:
	canvas.texture_filter=FILTERS[DATA.data.families.legacy_world.filter]


## Создаёт обёртку один раз у владельца ресурса; повторно использует исходную GPU-текстуру без копии пикселей.
static func create(texture: Texture2D, family: String, layout: String="standalone") -> CanvasTexture:
	var profile: Dictionary = DATA.data.families.get(family,{})
	if texture==null or texture is CanvasTexture or profile.is_empty() or layout not in profile.layouts or layout=="padded_atlas": return null
	if texture is AtlasTexture and profile.filter=="linear": return null
	return _wrap(texture,profile)


## Разрешает линейную страницу только по опубликованному паспорту, а не по произвольному флагу готовности.
static func padded_page(texture: Texture2D, level: int) -> CanvasTexture:
	var catalog: Dictionary = preload("res://assets/game/items/ui/padded/catalog.json").data
	if level<0 or level>=catalog.levels.size() or texture==null or texture is CanvasTexture or texture is AtlasTexture: return null
	var row: Dictionary = catalog.levels[level]
	if texture.resource_path!=row.file or texture.get_size()!=Vector2(row.pixels[0],row.pixels[1]): return null
	var profile: Dictionary = DATA.data.families.get(catalog.family,{})
	if profile.get("layouts",[])!=["padded_atlas"]: return null
	return _wrap(texture,profile)


## Устанавливает явные параметры над тем же источником после проверки вызывающего пути.
static func _wrap(texture: Texture2D, profile: Dictionary) -> CanvasTexture:
	var result := CanvasTexture.new()
	result.diffuse_texture=texture
	result.texture_filter=FILTERS[profile.filter]
	result.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	return result

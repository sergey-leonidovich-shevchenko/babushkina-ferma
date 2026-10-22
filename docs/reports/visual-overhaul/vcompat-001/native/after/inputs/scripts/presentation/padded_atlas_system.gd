extends RefCounted

const DATA := preload("res://assets/game/items/ui/padded/catalog.json")
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
static var _pages: Dictionary = {}


## Выбирает подготовленный уровень без аппаратного смешивания соседних кадров или изменения масштаба интерфейса.
static func level_for(pixels: float) -> int:
	if not is_finite(pixels) or pixels<=0: return -1
	return clampi(floori(log(float(DATA.data.base_size)/pixels)/log(2.0)),0,DATA.data.levels.size()-1)


## Создаёт регион только по известному ID и удерживает общую страницу у её владельца.
static func frame(kind: String, pixels: float) -> AtlasTexture:
	var level := level_for(pixels)
	if level<0 or not DATA.data.levels[level].entries.has(kind): return null
	if not _pages.has(level):
		var raw: Texture2D = load(DATA.data.levels[level].file)
		_pages[level]=Sampling.padded_page(raw,level)
	if _pages[level]==null: return null
	var values: Array = DATA.data.levels[level].entries[kind]
	var result := AtlasTexture.new(); result.atlas=_pages[level]
	result.region=Rect2(values[0],values[1],values[2],values[3]); result.filter_clip=true
	return result


## Освобождает удерживаемые обёртки при пересоздании каталога, не сканируя их каждый кадр.
static func clear() -> void:
	_pages.clear()


## Сохраняет старый доступ к основной странице по запросу, не предзагружая её ради меньшего уровня.
static func raw_base() -> Texture2D:
	return load(DATA.data.levels[0].file)


## Возвращает фактический предел страниц и удерживаемые уровни без загрузки отсутствующих текстур.
static func cache_info() -> Dictionary:
	return {"pages":_pages.size(),"limit":DATA.data.levels.size(),"levels":_pages.keys()}

extends RefCounted

const Padded := preload("res://scripts/presentation/padded_atlas_system.gd")
static var ATLAS: Texture2D:
	get: return Padded.raw_base()
const Catalog := preload("res://assets/game/items/ui/catalog.gd")
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
const SMALL_SIZE := int(Catalog.DATA.small)
const PREVIEW_SIZE := int(Catalog.DATA.large)
const PREVIEW_LIMIT := 16
static var _catalog:Dictionary=Catalog.DATA
static var _small:Dictionary={}
static var _large:Dictionary={}
static var _recent:Array[String]=[]
static var _loads := 0
static var _hits := 0
static var _evictions := 0

## Освобождает экранные пакеты после смены каталога, сохраняя один общий маленький атлас.
static func clear() -> void:
	_small.clear(); _large.clear(); _recent.clear()
	_loads=0; _hits=0; _evictions=0
	Padded.clear()

## Определяет экранную роль по проверенному размеру, не создавая текстуры и не угадывая назначение по имени.
static func role(pixels: float) -> String:
	if not is_finite(pixels) or pixels<=0: return ""
	return "preview" if pixels>SMALL_SIZE else "thumbnail"

## Читает компактный индекс один раз и сохраняет исходный контракт для выбранных нестандартных замен.
static func packet(kind: String, source: Dictionary, pixels: float) -> Dictionary:
	var entry:Dictionary=_catalog.entries.get(kind,{})
	if role(pixels).is_empty() or source.texture==null or entry.is_empty() or entry.provider!=source.provider or entry.path!=source.texture.resource_path or entry.tint!=source.tint.to_html(false): return source
	return prepared_packet(kind,source,pixels,entry)

## Сверяет прежние приоритеты и окраску по описанию, не требуя загрузить исходник для подтверждения его пути.
static func from_descriptor(kind: String, descriptor: Dictionary, pixels: float) -> Dictionary:
	var entry:Dictionary=_catalog.entries.get(kind,{})
	if role(pixels).is_empty() or entry.is_empty() or entry.provider!=descriptor.provider or entry.path!=descriptor.path or entry.tint!=descriptor.tint.to_html(false): return {}
	return prepared_packet(kind,{"texture":null,"provider":descriptor.provider,"tint":descriptor.tint,"square":true},pixels,entry)

## Возвращает тот же пакет миниатюры либо превью, сохраняя общий атлас и прежний предел шестнадцати больших текстур.
static func prepared_packet(kind: String, source: Dictionary, pixels: float, entry: Dictionary) -> Dictionary:
	if role(pixels).is_empty(): return source
	var preview:=role(pixels)=="preview"
	if preview:
		if not _large.has(kind):
			_large[kind]=Sampling.create(load("res://assets/game/items/ui/preview/"+kind+".png"),"painted_ui")
			_loads+=1
		else: _hits+=1
		_recent.erase(kind); _recent.append(kind)
		while _recent.size()>PREVIEW_LIMIT: _large.erase(_recent.pop_front()); _evictions+=1
	else:
		var key := kind+"/"+str(Padded.level_for(pixels))
		if not _small.has(key): _small[key]=Padded.frame(kind,pixels)
	var result:=source.duplicate(); result.texture=_large[kind] if preview else _small[kind+"/"+str(Padded.level_for(pixels))]; result.square=true
	result.prepared_role="preview" if preview else "thumbnail"
	result.prepared_size=PREVIEW_SIZE if preview else int(result.texture.get_width())
	result.texture_intent="color_srgb"
	return result

## Даёт проверкам точные размеры и число сохранённых превью без доступа к содержимому игры.
static func cache_info() -> Dictionary:
	var pixels: Array = Padded.DATA.data.levels[0].pixels
	return {"small":_small.size(),"large":_large.size(),"limit":PREVIEW_LIMIT,"atlas":Vector2(pixels[0],pixels[1]),
		"preview_load_requests":_loads,"preview_hits":_hits,"preview_evictions":_evictions,"preview_ids":_recent.duplicate()}

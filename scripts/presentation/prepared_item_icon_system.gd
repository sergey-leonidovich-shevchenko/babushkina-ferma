extends RefCounted

const Padded := preload("res://scripts/presentation/padded_atlas_system.gd")
static var ATLAS: Texture2D:
	get: return Padded.raw_base()
const Catalog := preload("res://assets/game/items/ui/catalog.gd")
const PREVIEW_LIMIT := 16
static var _catalog:Dictionary=Catalog.DATA
static var _small:Dictionary={}
static var _large:Dictionary={}
static var _recent:Array[String]=[]

## Освобождает экранные пакеты после смены каталога, сохраняя один общий маленький атлас.
static func clear() -> void:
	_small.clear(); _large.clear(); _recent.clear()
	Padded.clear()

## Читает компактный индекс один раз и сохраняет исходный контракт для выбранных нестандартных замен.
static func packet(kind: String, source: Dictionary, pixels: float) -> Dictionary:
	var entry:Dictionary=_catalog.entries.get(kind,{})
	if source.texture==null or entry.is_empty() or entry.provider!=source.provider or entry.path!=source.texture.resource_path or entry.tint!=source.tint.to_html(false): return source
	return prepared_packet(kind,source,pixels,entry)

## Сверяет прежние приоритеты и окраску по описанию, не требуя загрузить исходник для подтверждения его пути.
static func from_descriptor(kind: String, descriptor: Dictionary, pixels: float) -> Dictionary:
	var entry:Dictionary=_catalog.entries.get(kind,{})
	if entry.is_empty() or entry.provider!=descriptor.provider or entry.path!=descriptor.path or entry.tint!=descriptor.tint.to_html(false): return {}
	return prepared_packet(kind,{"texture":null,"provider":descriptor.provider,"tint":descriptor.tint,"square":true},pixels,entry)

## Возвращает тот же пакет миниатюры либо превью, сохраняя общий атлас и прежний предел шестнадцати больших текстур.
static func prepared_packet(kind: String, source: Dictionary, pixels: float, entry: Dictionary) -> Dictionary:
	var preview:=pixels>64
	if preview:
		if not _large.has(kind): _large[kind]=load("res://assets/game/items/ui/preview/"+kind+".png")
		_recent.erase(kind); _recent.append(kind)
		while _recent.size()>PREVIEW_LIMIT: _large.erase(_recent.pop_front())
	else:
		var key := kind+"/"+str(Padded.level_for(pixels))
		if not _small.has(key): _small[key]=Padded.frame(kind,pixels)
	var result:=source.duplicate(); result.texture=_large[kind] if preview else _small[kind+"/"+str(Padded.level_for(pixels))]; result.square=true
	return result

## Даёт проверкам точные размеры и число сохранённых превью без доступа к содержимому игры.
static func cache_info() -> Dictionary:
	var pixels: Array = Padded.DATA.data.levels[0].pixels
	return {"small":_small.size(),"large":_large.size(),"limit":PREVIEW_LIMIT,"atlas":Vector2(pixels[0],pixels[1])}

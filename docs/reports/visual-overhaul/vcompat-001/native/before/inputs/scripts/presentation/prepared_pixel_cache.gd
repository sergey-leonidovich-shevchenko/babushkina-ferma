extends RefCounted

const Catalog := preload("res://assets/game/prepared_pixels/catalog.gd")
const VERSION := 1
static var enabled:=true
static var _verified:Dictionary={}
static var _textures:Dictionary={}
static var _bounds_sources:Dictionary={}

## Проверяет точные исходные пиксели один раз на ресурс и возвращает заранее вычисленный результат прежнего алгоритма.
static func texture(source: Texture2D, algorithm: String) -> Texture2D:
	if not enabled or source==null or Catalog.VERSION!=VERSION: return null
	var key:=algorithm+"|"+source.resource_path
	var entry:Dictionary=Catalog.ENTRIES.get(key,{})
	if entry.is_empty(): return null
	var rid:=source.get_rid().get_id()
	if _verified.get(key,{}).get("rid",-1)!=rid:
		_verified[key]={"rid":rid,"valid":source_matches(source,entry)}
	if not _verified[key].valid: return null
	if not _textures.has(key):
		if entry.source_sha256==entry.output_sha256:
			_textures[key]=source; _bounds_sources[rid]=entry
			return source
		if not ResourceLoader.exists(entry.resource): return null
		var prepared:Texture2D=load(entry.resource)
		if prepared==null or prepared.get_size()!=source.get_size() or fingerprint(prepared)!=entry.output_sha256: return null
		_textures[key]=prepared
		_bounds_sources[prepared.get_rid().get_id()]=entry
	return _textures[key]

## Отказывает устаревшему или подменённому кешу по размеру и точному отпечатку исходника.
static func source_matches(source: Texture2D, entry: Dictionary) -> bool:
	return source!=null and source.get_size()==Vector2(entry.width,entry.height) and fingerprint(source)==entry.source_sha256

## Возвращает подготовленную область только для уже проверенной текстуры, сохраняя исходный алгоритм как запасной маршрут.
static func bounds(texture: Texture2D, area: Rect2i) -> Rect2i:
	var entry:Dictionary=_bounds_sources.get(texture.get_rid().get_id(),{})
	var value:Array=entry.get("bounds",{}).get(area_key(area),[])
	return Rect2i(value[0],value[1],value[2],value[3]) if value.size()==4 else Rect2i()

## Кодирует область целыми координатами без зависимости от представления Rect2i или локали.
static func area_key(area: Rect2i) -> String:
	return "%d,%d,%d,%d"%[area.position.x,area.position.y,area.size.x,area.size.y]

## Считает канонический отпечаток изображения без изменения источника и без зависимости от наличия исходного PNG внутри экспорта.
static func fingerprint(source: Texture2D) -> String:
	if source==null: return ""
	return image_fingerprint(source.get_image())

## Нормализует формат только временной копии, сохраняя все четыре канала, включая RGB прозрачных пикселей.
static func image_fingerprint(source: Image) -> String:
	if source==null: return ""
	var image:=source.duplicate() as Image
	if image.is_compressed() and image.decompress()!=OK: return ""
	image.convert(Image.FORMAT_RGBA8)
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(image.get_data())
	return hash.finish().hex_encode()

## Освобождает ограниченный каталог производных текстур; неизвестные источники никогда не добавляются в этот кеш.
static func clear() -> void:
	_verified.clear(); _textures.clear(); _bounds_sources.clear()

## Показывает размер каталога и проверенных записей для контроля постоянной верхней границы.
static func statistics() -> Dictionary:
	return {"catalog":Catalog.ENTRIES.size(),"verified":_verified.size(),"textures":_textures.size()}

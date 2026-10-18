extends RefCounted

const PATH := "res://assets/game/visual_resources.json"
const DATA := preload(PATH)
const Sampling := preload("res://scripts/presentation/visual_sampling_system.gd")
static var _catalog: Dictionary = DATA.data.duplicate(true)
static var _textures: Dictionary = {}
static var _path_views: Dictionary = {}
static var _descriptors: Dictionary = {}
static var _sampled_textures: Dictionary = {}


## Возвращает независимую копию проверенного при сборке паспорта без загрузки изображений.
static func catalog() -> Dictionary:
	return _catalog.duplicate(true)


## Разрешает устойчивый идентификатор, ракурс и качество без анализа имени файла.
static func describe(id: String, side: String="south", quality: String="") -> Dictionary:
	var key := id+"/"+side+"/"+quality
	if not _descriptors.has(key):
		var view := resolve(_catalog,id,side,quality)
		if view.is_empty(): return {}
		view.make_read_only(); _descriptors[key]=view
	return _descriptors[key]


## Преобразует проверенный паспорт в типизированную геометрию; неизвестное сочетание явно отсутствует.
static func resolve(data: Dictionary, id: String, side: String="south", quality: String="") -> Dictionary:
	var record: Dictionary = data.get("resources",{}).get(id,{})
	var view: Dictionary = record.get("views",{}).get(side,{})
	var selected := String(record.get("default_quality","")) if quality.is_empty() else quality
	var variant: Dictionary = view.get("variants",{}).get(selected,{})
	if record.is_empty() or view.is_empty() or variant.is_empty(): return {}
	var texture: Dictionary = data.get("textures",{}).get(variant.get("texture",""),{})
	if texture.is_empty(): return {}
	var source: Array = variant.source_rect
	return {"id":id,"kind":record.kind,"space":record.space,"side":side,"quality":selected,"path":texture.file,"filter":record.filter,
		"sampling_family":record.get("sampling_family","legacy_world"),"layout":texture.get("layout","standalone"),
		"source":Rect2(source[0],source[1],source[2],source[3]),"pivot":Vector2(view.pivot[0],view.pivot[1]),
		"logical_size":Vector2(view.logical_size[0],view.logical_size[1]),"footprint_size":Vector2(view.footprint_size[0],view.footprint_size[1])}


## Загружает лишь явно запрошенную текстуру и делит существующий кеш ResourceLoader.
static func texture(id: String, side: String="south", quality: String="") -> Texture2D:
	var view := describe(id,side,quality)
	if view.is_empty(): return null
	var path := String(view.path)
	if not _textures.has(path): _textures[path]=load(path)
	return _textures[path] as Texture2D


## Удерживает адресный фильтр рядом с ресурсом, не меняя полотно и не создавая обёртку на каждом кадре.
static func sampled_texture(id: String, side: String="south", quality: String="") -> Texture2D:
	var view := describe(id,side,quality)
	if view.is_empty(): return null
	var key: String = id+"/"+side+"/"+view.quality
	if not _sampled_textures.has(key): _sampled_textures[key]=Sampling.create(texture(id,side,quality),view.sampling_family,view.layout)
	return _sampled_textures[key]


## Подключает тот же фильтр в палитре, призраке и опубликованном уровне; незнакомые файлы сохраняют прежний путь.
static func sampled_for_path(path: String, fallback: Texture2D) -> Texture2D:
	var entry := editor_profile(path)
	return fallback if entry.is_empty() else sampled_texture(entry.visual_resource_id,entry.visual_resource_side)


## Сохраняет пропорции исходной области и нормализованную опору независимо от плотности PNG.
static func destination(view: Dictionary, position: Vector2, bounds: Vector2=Vector2.ZERO) -> Rect2:
	if view.is_empty(): return Rect2(position,Vector2.ZERO)
	if bounds==Vector2.ZERO: bounds=view.logical_size
	var size: Vector2 = view.source.size
	size*=minf(bounds.x/size.x,bounds.y/size.y)
	return Rect2(position-size*Vector2(view.pivot),size)


## Связывает палитру редактора с тем же паспортом; опубликованные уровни сохраняют прежний формат.
static func editor_profile(path: String) -> Dictionary:
	if _path_views.is_empty():
		for id in _catalog.resources:
			if _catalog.resources[id].kind!="prop" or _catalog.resources[id].space!="world": continue
			for side in _catalog.resources[id].views:
				var view := describe(id,side)
				if view.pivot!=Vector2(0.5,1.0): continue
				_path_views[String(view.path)]=view
	if not _path_views.has(path): return {}
	var view: Dictionary = _path_views[path]
	return {"visual_resource_id":view.id,"visual_resource_side":view.side,"source_rect":view.source,
		"display_size":destination(view,Vector2.ZERO).size,"collision_size":view.footprint_size,
		"collision_offset":Vector2.ZERO,"collision":Vector2(view.footprint_size)!=Vector2.ZERO,"anchor":"bottom"}


## Выравнивает левую кромку физического основания по выбранной сетке при ракурсах разной ширины.
static func editor_position(position: Vector2, world: Vector2, state: Dictionary, entry: Dictionary) -> Vector2:
	if not entry.has("visual_resource_id") or entry.get("anchor","")!="bottom" or not bool(state.snap): return position
	var footprint := Vector2(entry.get("collision_size",Vector2.ZERO))
	if footprint==Vector2.ZERO: return position
	var grid := float(state.grid)
	position.x=floorf(world.x/grid)*grid+fposmod(footprint.x*0.5,grid)
	return position

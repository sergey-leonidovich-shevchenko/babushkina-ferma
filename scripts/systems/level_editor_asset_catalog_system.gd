extends RefCounted

const IMAGE_EXTENSIONS := [".png", ".webp"]
const EXPECTED_BUILDINGS := ["chapel", "cottage", "forge", "guild_hall", "moon_castle", "prison", "shop_house", "wizard_tower"]
const SAFE_ATLAS_SLICES := {
	"buildable_fence_atlas_v1.png":64,
	"expansion_atlas.png":128,
	"farm_food_atlas.png":256,
	"farm_plants_objects_atlas_v1.png":96,
	"farm_plot_atlas.png":48,
	"forest_tree_growth_atlas_v1.png":256,
	"inventory_core_atlas.png":256,
	"inventory_rare_atlas.png":256,
	"village_polish_atlas.png":128,
}
const STRICT_SHEET_SLICES := {
	"annual_a.png":64,"annual_b.png":64,"annual_c.png":64,"annual_d.png":64,
	"farm_supplies.png":32,"fantasy_icons.png":48,
	"fruit_trees_4x4_v2.png":256,"herbs_seasons.png":64,"strawberry_seasons.png":64,
	"river tileset.png":16,"slime_attack.png":128,"slime_death.png":128,"slime_hurt.png":128,"slime_idle.png":128,
	"splash effect.png":16,"water tile.png":16,
}


## Рекурсивно собирает только пригодные для размещения игровые растры и добавляет правила привязки.
static func scan(root: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_scan_directory(root,result)
	result.sort_custom(func(left: Dictionary,right: Dictionary): return "%s:%s" % [left.category,left.name] < "%s:%s" % [right.category,right.name])
	return result


## Ищет описание выбранного ресурса без повторного обхода файловой системы.
static func find(entries: Array[Dictionary], path: String) -> Dictionary:
	for entry in entries:
		if String(entry.path) == path: return entry
	return metadata(path)


## Фильтрует каталог по категории, поиску и избранному без повторного обхода файловой системы.
static func filter(entries: Array[Dictionary], category: String, query: String, favorites_only: bool, favorites: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []; var normalized_query:=query.to_lower().strip_edges()
	for entry in entries:
		var path:=String(entry.path); var matches_search:=normalized_query.is_empty() or normalized_query in String(entry.name).to_lower() or normalized_query in path.to_lower()
		var matches_category:=not normalized_query.is_empty() or favorites_only or String(entry.category)==category
		if matches_search and matches_category and (not favorites_only or path in favorites): result.append(entry)
	return result


## Возвращает стабильные настройки слоя, якоря и коллизии по назначению ресурса.
static func metadata(path: String) -> Dictionary:
	var lower := path.to_lower()
	var category := category_for_path(path)
	var ground := category == "terrain" or "/editor/water/" in lower
	var bottom := category in ["buildings","vegetation","characters","enemies","decor"]
	var slice_size := _profile_slice_size(path)
	var display_size := _profile_display_size(path,slice_size)
	return {
		"path":path,
		"name":path.get_file().get_basename().replace("_"," ").replace("-"," "),
		"category":category,
		"anchor":"tile" if ground else ("bottom" if bottom else "center"),
		"layer":"ground" if ground else "objects",
		"collision":category in ["buildings","vegetation"] or "/environment/bridges/" in lower,
		"slice_size":slice_size,
		"display_size":display_size,
		"frame_count":_frame_count(path,slice_size),
		"unique_key":_unique_key(path),
		"surface_kind":_surface_kind(path),
		"sliced":slice_size>0,
	}


## Сводит полноту домов, безопасно нарезанные листы и уникальные сущности в диагностический отчёт каталога.
static func audit(entries: Array[Dictionary]) -> Dictionary:
	var buildings: Dictionary = {}
	var sliced := 0
	var unique := 0
	for entry in entries:
		if String(entry.category)=="buildings" and "/exteriors/" in String(entry.path): buildings[String(entry.path).get_file().get_basename()]=true
		if bool(entry.get("sliced",false)): sliced+=1
		if not String(entry.get("unique_key","")).is_empty(): unique+=1
	var missing: Array[String] = []
	for building in EXPECTED_BUILDINGS:
		if not buildings.has(building): missing.append(building)
	return {"placeable":entries.size(),"buildings":buildings.size(),"expected_buildings":EXPECTED_BUILDINGS.size(),"missing_buildings":missing,"sliced":sliced,"unique":unique,"excluded_composites":[]}


## Определяет пользовательскую группу спрайта по стабильной структуре каталогов проекта.
static func category_for_path(path: String) -> String:
	var lower := path.to_lower()
	if "/tiles/" in lower: return "terrain"
	if "/buildings/" in lower: return "buildings"
	if "/characters/" in lower: return "characters"
	if "/enemies/" in lower or "/wildlife/" in lower: return "enemies"
	if "/items/" in lower or "/resources/" in lower or "/world_loot/" in lower: return "items"
	if "/farming/" in lower: return "farming"
	if "/fishing/" in lower: return "fishing"
	if "/ui/" in lower: return "ui"
	if "/environment/" in lower and ("tree" in lower or "plant" in lower or "mushroom" in lower or "orchard" in lower): return "vegetation"
	if "/environment/" in lower or "/world_polish/" in lower or "/expansion_pack/" in lower: return "decor"
	return "other"


## Обходит одну папку и пропускает мастера, превью и служебные листы, которые нельзя ставить целиком.
static func _scan_directory(path: String, result: Array[Dictionary]) -> void:
	var directory := DirAccess.open(path)
	if directory == null: return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir() and not entry.begins_with("."):
			if entry.to_lower() not in ["source","transitions"]: _scan_directory(child,result)
		elif _is_placeable_image(entry):
			result.append(metadata(child))
		entry = directory.get_next()
	directory.list_dir_end()


## Проверяет расширение и исключает контрольные изображения из пользовательского каталога.
static func _is_placeable_image(filename: String) -> bool:
	var lower := filename.to_lower()
	if "preview" in lower or "master" in lower: return false
	if lower == "farm_plants.png": return false
	if "atlas" in lower and not SAFE_ATLAS_SLICES.has(lower): return false
	return IMAGE_EXTENSIONS.any(func(extension: String): return lower.ends_with(extension))


## Возвращает размер кадра только для листов с проверенной строгой геометрией.
static func _profile_slice_size(path: String) -> int:
	var lower:=path.to_lower(); var filename:=lower.get_file()
	if "/characters/directional/" in lower: return 222
	if "/enemies/animated/" in lower or "/wildlife/directional/" in lower: return 128
	if STRICT_SHEET_SLICES.has(filename): return int(STRICT_SHEET_SLICES[filename])
	return int(SAFE_ATLAS_SLICES.get(filename,0))


## Нормализует крупные кадры персонажей до игрового масштаба, не меняя размеры исходного изображения.
static func _profile_display_size(path: String, slice_size: int) -> Vector2:
	var lower:=path.to_lower()
	if "/characters/directional/" in lower:
		return Vector2(72,96) if "/hero_" in lower or "/hero" in lower else Vector2(96,96)
	if "/enemies/animated/" in lower or "/wildlife/directional/" in lower: return Vector2(96,96)
	if lower.get_file().begins_with("slime_"): return Vector2(96,96)
	return Vector2(slice_size,slice_size) if slice_size>0 else Vector2.ZERO


## Считает количество целых кадров и никогда не обещает пользователю частично обрезанный срез.
static func _frame_count(path: String, slice_size: int) -> int:
	if slice_size<=0 or not ResourceLoader.exists(path): return 1
	var texture:=ResourceLoader.load(path) as Texture2D
	if texture==null or int(texture.get_width())%slice_size!=0 or int(texture.get_height())%slice_size!=0: return 1
	return int(texture.get_width()/slice_size)*int(texture.get_height()/slice_size)


## Назначает стабильный ключ тем героям и NPC, которые существуют на уровне в единственном экземпляре.
static func _unique_key(path: String) -> String:
	var basename:=path.get_file().get_basename().to_lower()
	if basename.begins_with("hero_"): return "hero:player"
	if basename.begins_with("npc_official"): return "npc:guild_master"
	if basename.begins_with("npc_"): return "npc:"+basename.trim_prefix("npc_").trim_suffix("_walk_8dir")
	if basename.begins_with("companion_"): return "companion:"+basename.trim_prefix("companion_").trim_suffix("_walk_8dir")
	return ""


## Классифицирует покрытие для автоматической дорисовки границ между соседними материалами.
static func _surface_kind(path: String) -> String:
	var basename:=path.get_file().get_basename().to_lower()
	if basename.begins_with("grass_") or basename.ends_with("_grass") or basename=="grass": return "grass"
	if "water" in basename or basename.begins_with("shore_") or basename.begins_with("river_") or basename.begins_with("pond_"): return "water"
	if "sand" in basename: return "sand"
	if "gravel" in basename or "stone_road" in basename or "cobble" in basename: return "gravel"
	if "dirt" in basename or "soil" in basename or "mud" in basename: return "dirt"
	return ""

extends RefCounted

const RoadVisualSystem := preload("res://scripts/systems/road_visual_system.gd")
const WaterVisualSystem := preload("res://scripts/systems/water_visual_system.gd")

const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const DIRECTION_BITS := [1,2,4,8]
const DIAGONAL_DIRECTIONS := [Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
const DIAGONAL_CARDINALS := [[0,1],[1,2],[2,3],[3,0]]
const SURFACE_PRIORITY := {"grass":0,"dirt":1,"sand":2,"gravel":3}


## Пересчитывает четырёхстороннюю маску соседей для каждого тайла земли одного ресурса.
static func rebuild_autotile_masks(state: Dictionary) -> void:
	var lookup: Dictionary = {}
	for index in state.objects.size():
		var object: Dictionary = state.objects[index]
		if _is_ground_tile(object): lookup[_tile_key(state,object)] = index
	for index in state.objects.size():
		var object: Dictionary = state.objects[index]
		if not _is_ground_tile(object): object.autotile_mask=0; object.autotile_diagonal_mask=0; state.objects[index]=object; continue
		var cell := _cell(state,Vector2(object.position)); var mask := 0; var diagonal_mask:=0; var family:=_object_family(object); var neighbor_asset:=family if not family.is_empty() else String(object.asset_path)
		for direction_index in DIRECTIONS.size():
			var neighbor_index: int = int(lookup.get(_key(cell+DIRECTIONS[direction_index],neighbor_asset,String(object.layer)),-1))
			if neighbor_index>=0: mask|=DIRECTION_BITS[direction_index]
		for direction_index in DIAGONAL_DIRECTIONS.size():
			var neighbor_index: int = int(lookup.get(_key(cell+DIAGONAL_DIRECTIONS[direction_index],neighbor_asset,String(object.layer)),-1))
			if neighbor_index>=0: diagonal_mask|=DIRECTION_BITS[direction_index]
		object.autotile_mask=mask; object.autotile_diagonal_mask=diagonal_mask; state.objects[index]=object
	_apply_visual_variants(state)
	_rebuild_surface_transitions(state)


## Создаёт маски переходных накладок там, где соседствуют разные сухие покрытия.
static func _rebuild_surface_transitions(state: Dictionary) -> void:
	var cells:Dictionary={}
	for index in state.objects.size():
		var object:Dictionary=state.objects[index]; object.transition_masks={}; object.transition_corner_masks={}; state.objects[index]=object
		if _is_ground_tile(object): cells[_cell_layer_key(_cell(state,Vector2(object.position)),String(object.layer))]=index
	for index in state.objects.size():
		var object:Dictionary=state.objects[index]
		if not _is_ground_tile(object): continue
		var surface:=_surface_kind(object)
		if not SURFACE_PRIORITY.has(surface): continue
		var cell:=_cell(state,Vector2(object.position)); var masks:Dictionary={}; var corner_masks:Dictionary={}
		for direction_index in DIRECTIONS.size():
			var neighbor_index:=int(cells.get(_cell_layer_key(cell+DIRECTIONS[direction_index],String(object.layer)),-1))
			if neighbor_index<0: continue
			var neighbor_surface:=_surface_kind(state.objects[neighbor_index])
			if not SURFACE_PRIORITY.has(neighbor_surface) or int(SURFACE_PRIORITY[neighbor_surface])<=int(SURFACE_PRIORITY[surface]): continue
			masks[neighbor_surface]=int(masks.get(neighbor_surface,0))|DIRECTION_BITS[direction_index]
		for direction_index in DIAGONAL_DIRECTIONS.size():
			var neighbor_index:=int(cells.get(_cell_layer_key(cell+DIAGONAL_DIRECTIONS[direction_index],String(object.layer)),-1))
			if neighbor_index<0: continue
			var neighbor_surface:=_surface_kind(state.objects[neighbor_index])
			if not SURFACE_PRIORITY.has(neighbor_surface) or int(SURFACE_PRIORITY[neighbor_surface])<=int(SURFACE_PRIORITY[surface]): continue
			var adjacent:Array=DIAGONAL_CARDINALS[direction_index]
			if _neighbor_surface(cells,state,cell+DIRECTIONS[int(adjacent[0])],String(object.layer))==neighbor_surface or _neighbor_surface(cells,state,cell+DIRECTIONS[int(adjacent[1])],String(object.layer))==neighbor_surface: continue
			corner_masks[neighbor_surface]=int(corner_masks.get(neighbor_surface,0))|DIRECTION_BITS[direction_index]
		object.transition_masks=masks; object.transition_corner_masks=corner_masks; state.objects[index]=object


## Подставляет бесшовную вариацию травы, берег воды либо дорожный модуль по маске соседей.
static func _apply_visual_variants(state: Dictionary) -> void:
	for index in state.objects.size():
		var object:Dictionary=state.objects[index]; var family:=_object_family(object)
		if family.is_empty(): continue
		if family.begins_with("grass"):
			var cell:=_cell(state,Vector2(object.position)); var seed:=absi(cell.x*73+cell.y*151+19)
			var season:=family.trim_prefix("grass_") if family!="grass" else "summer"; var filename:String=String({"spring":"grass_spring","summer":"grass_flowers" if seed%17==0 else "grass_lush","autumn":"grass_autumn","winter":"ground_snow_grass"}.get(season,"grass_lush"))
			object.asset_path="res://assets/game/tiles/editor/terrain/%s.png"%filename; object.rotation=(seed%4)*PI*0.5; object.flip_x=seed%3==0; object.autotile_family="grass_"+season; object.autotile_managed=true; state.objects[index]=object; continue
		if family=="water_body":
			var water_variant:=_water_variant_for_mask(int(object.get("autotile_mask",0)),int(object.get("autotile_diagonal_mask",0)),_cell(state,Vector2(object.position))); object.asset_path=water_variant.path; object.rotation=water_variant.rotation; object.autotile_family=family; object.autotile_managed=true; state.objects[index]=object; continue
		var variant:=_variant_for_mask(int(object.get("autotile_mask",0))); object.asset_path="res://assets/game/tiles/editor/%s/%s_%s.png"%["water" if family=="river" else "terrain",family,variant.kind]; object.rotation=variant.rotation; object.autotile_family=family; object.autotile_managed=true; state.objects[index]=object


## Выбирает берег, угол, узкое русло или внутреннюю воду для свободно нарисованного водоёма.
static func _water_variant_for_mask(mask: int, diagonal_mask: int, cell: Vector2i) -> Dictionary:
	var variant:=WaterVisualSystem.variant_for_mask(mask,cell,0,diagonal_mask)
	return {"path":WaterVisualSystem.module_path(String(variant.kind)),"rotation":float(variant.rotation)}


## Выбирает канонический модуль и поворот по четырём битам N/E/S/W.
static func _variant_for_mask(mask: int) -> Dictionary:
	return RoadVisualSystem.variant_for_mask(mask)


## Проверяет структуру черновика, ресурсы, дубликаты клеток и опасные параметры перед экспортом.
static func validate(state: Dictionary) -> Dictionary:
	var errors: Array[String]=[]; var warnings: Array[String]=[]; var occupied: Dictionary={}; var ids: Dictionary={}; var unique_keys:Dictionary={}
	if String(state.level_name).strip_edges().is_empty(): errors.append("У уровня нет названия")
	if int(state.grid) not in [12,24,48,96]: errors.append("Неизвестный размер сетки: %s"%state.grid)
	if state.objects.is_empty(): warnings.append("Карта пока пуста")
	for index in state.objects.size():
		var object: Dictionary=state.objects[index]; var label:="#%s %s"%[object.get("id",index),object.get("name","Объект")]
		if ids.has(object.get("id",index)): errors.append("Повторяется id %s"%object.get("id",index))
		ids[object.get("id",index)]=true
		var unique_key:=String(object.get("unique_key",""))
		if not unique_key.is_empty() and unique_keys.has(unique_key): errors.append("%s: уникальный объект уже размещён как #%s"%[label,unique_keys[unique_key]])
		if not unique_key.is_empty(): unique_keys[unique_key]=object.get("id",index)
		if String(object.get("layer","")) not in ["background","ground","objects","foreground"]: errors.append("%s: неизвестный слой"%label)
		if Vector2(object.get("size",Vector2.ZERO)).x<=0 or Vector2(object.get("size",Vector2.ZERO)).y<=0: errors.append("%s: нулевой размер"%label)
		if not bool(object.get("reference",false)) and (String(object.get("asset_path","")).is_empty() or not ResourceLoader.exists(String(object.asset_path))): errors.append("%s: спрайт не найден"%label)
		if _is_ground_tile(object):
			var cell_key:=_key(_cell(state,Vector2(object.position)),"",String(object.layer))
			if occupied.has(cell_key): errors.append("%s: клетка земли уже занята объектом #%s"%[label,occupied[cell_key]])
			occupied[cell_key]=object.get("id",index)
			if bool(object.get("collision",false)): warnings.append("%s: земля помечена как непроходимая"%label)
		if absf(float(object.get("rotation",0.0))/ (PI*0.5)-roundf(float(object.get("rotation",0.0))/(PI*0.5)))>0.001: warnings.append("%s: поворот не кратен 90°"%label)
	return {"valid":errors.is_empty(),"errors":errors,"warnings":warnings,"checked":state.objects.size()}


## Выполняет строгую runtime-проверку старта, выходов, коллизий и реальной достижимости маршрута.
static func validate_runtime(state:Dictionary)->Dictionary:
	var report:=validate(state); var errors:Array[String]=report.errors.duplicate(); var warnings:Array[String]=report.warnings.duplicate(); var spawns:Array[Dictionary]=[]; var exits:Array[Dictionary]=[]
	for object in state.objects:
		var role:=String(object.get("runtime_role",""))
		if role=="spawn": spawns.append(object)
		elif role=="exit": exits.append(object)
		elif not role.is_empty() and role!="interaction": errors.append("#%s: неизвестная игровая роль %s"%[object.get("id","?"),role])
		if bool(object.get("collision",false)):
			var collision:=_collision_rect(object)
			if collision.size.x<=0 or collision.size.y<=0: errors.append("#%s: коллизия имеет нулевой размер"%object.get("id","?"))
	if spawns.size()!=1: errors.append("Нужна ровно одна точка SPAWN, сейчас: %d"%spawns.size())
	if exits.is_empty(): errors.append("Нужна хотя бы одна точка EXIT")
	if spawns.size()==1:
		var spawn_position:=Vector2(spawns[0].position)
		if _point_blocked(state.objects,spawn_position): errors.append("Точка SPAWN находится внутри коллизии")
		for exit_object in exits:
			var exit_position:=Vector2(exit_object.position)
			if _point_blocked(state.objects,exit_position): errors.append("EXIT #%s находится внутри коллизии"%exit_object.get("id","?"))
			elif not _reachable(state,spawn_position,exit_position): errors.append("EXIT #%s недостижим от SPAWN"%exit_object.get("id","?"))
	return {"valid":errors.is_empty(),"errors":errors,"warnings":warnings,"checked":state.objects.size(),"runtime":true}


## Возвращает пользовательский прямоугольник препятствия с учётом якоря, масштаба и смещения.
static func _collision_rect(object:Dictionary)->Rect2:
	var bounds:=_object_bounds(object); var size:=Vector2(object.get("collision_size",bounds.size)); var offset:=Vector2(object.get("collision_offset",Vector2.ZERO))
	if size==Vector2.ZERO: size=bounds.size
	return Rect2(bounds.get_center()+offset-size*0.5,size)


## Вычисляет визуальные границы объекта тем же способом, что редактор и runtime-отрисовка.
static func _object_bounds(object:Dictionary)->Rect2:
	var size:=Vector2(object.get("size",Vector2(24,24)))*clampf(float(object.get("scale",1.0)),0.25,4.0); var position:=Vector2(object.get("position",Vector2.ZERO))
	match String(object.get("anchor","center")):
		"tile": return Rect2(position,size)
		"bottom": return Rect2(position-Vector2(size.x*0.5,size.y),size)
		_: return Rect2(position-size*0.5,size)


## Проверяет попадание точки игрового маршрута в любое видимое непроходимое препятствие.
static func _point_blocked(objects:Array,point:Vector2,radius:float=5.0)->bool:
	for object in objects:
		if bool(object.get("hidden",false)) or not bool(object.get("collision",false)): continue
		var rect:=_collision_rect(object); var closest:=Vector2(clampf(point.x,rect.position.x,rect.end.x),clampf(point.y,rect.position.y,rect.end.y))
		if point.distance_squared_to(closest)<radius*radius: return true
	return false


## Ищет четырёхсторонний путь по малой сетке, чтобы опубликованный выход не оказался декоративным тупиком.
static func _reachable(state:Dictionary,start:Vector2,finish:Vector2)->bool:
	var grid:=maxi(6,int(state.get("grid",24))); var bounds:=Rect2(start,Vector2.ONE)
	for object in state.objects: bounds=bounds.merge(_object_bounds(object))
	bounds=bounds.merge(Rect2(finish,Vector2.ONE)).grow(grid*3.0)
	var minimum:=Vector2i(floori(bounds.position.x/grid),floori(bounds.position.y/grid)); var maximum:=Vector2i(ceili(bounds.end.x/grid),ceili(bounds.end.y/grid)); var start_cell:=Vector2i(floori(start.x/grid),floori(start.y/grid)); var finish_cell:=Vector2i(floori(finish.x/grid),floori(finish.y/grid))
	var queue:Array[Vector2i]=[start_cell]; var cursor:=0; var visited:Dictionary={start_cell:true}
	while cursor<queue.size() and cursor<25000:
		var cell:Vector2i=queue[cursor]; cursor+=1
		if cell==finish_cell: return true
		for direction in DIRECTIONS:
			var next:Vector2i=cell+direction
			if next.x<minimum.x or next.y<minimum.y or next.x>maximum.x or next.y>maximum.y or visited.has(next): continue
			var center:=(Vector2(next)+Vector2.ONE*0.5)*grid
			if _point_blocked(state.objects,center,grid*0.28): continue
			visited[next]=true; queue.append(next)
	return false


## Возвращает компактную строку результата для панели и журнала конструктора.
static func summary(report: Dictionary) -> String:
	if not report.valid: return "ПРОВЕРКА: %d ошибок · %d предупреждений"%[report.errors.size(),report.warnings.size()]
	return "ПРОВЕРКА: готово · %d объектов · %d предупреждений"%[report.checked,report.warnings.size()]


## Определяет тайл земли, который участвует в бесшовной четырёхсторонней связности.
static func _is_ground_tile(object: Dictionary) -> bool:
	return not bool(object.get("reference",false)) and String(object.get("anchor","center"))=="tile" and String(object.get("layer","objects")) in ["background","ground"]


## Строит ключ объекта по его сеточной клетке, ресурсу и слою.
static func _tile_key(state: Dictionary, object: Dictionary) -> String:
	var family:=_object_family(object)
	return _key(_cell(state,Vector2(object.position)),family if not family.is_empty() else String(object.asset_path),String(object.layer))


## Переводит мировую координату в малую клетку активной сетки конструктора.
static func _cell(state: Dictionary, position: Vector2) -> Vector2i:
	var grid:=maxi(1,int(state.grid)); return Vector2i(floori(position.x/grid),floori(position.y/grid))


## Формирует стабильный строковый ключ соседства для словаря автотайлов.
static func _key(cell: Vector2i, asset_path: String, layer: String) -> String:
	return "%d:%d:%s:%s"%[cell.x,cell.y,layer,asset_path]


## Формирует ключ клетки без семейства, чтобы сопоставить разные соседние покрытия.
static func _cell_layer_key(cell: Vector2i, layer: String) -> String:
	return "%d:%d:%s"%[cell.x,cell.y,layer]


## Возвращает сохранённое семейство объекта после автоматической замены исходного PNG.
static func _object_family(object: Dictionary) -> String:
	var stored:=String(object.get("autotile_family",""))
	return stored if not stored.is_empty() else _family(String(object.get("asset_path","")))


## Узнаёт семейство модульной поверхности независимо от выбранного пользователем варианта.
static func _family(path: String) -> String:
	var basename:=path.get_file().get_basename()
	for family in ["dirt_path","stone_road","river"]:
		if basename.begins_with(family+"_"): return family
	if basename=="grass_spring": return "grass_spring"
	if basename in ["grass_lush","grass_flowers"]: return "grass_summer"
	if basename=="grass_autumn": return "grass_autumn"
	if basename=="ground_snow_grass": return "grass_winter"
	if basename.begins_with("water_") or basename.begins_with("shore_") or basename=="pond_rocky": return "water_body"
	return ""


## Возвращает исходный тип покрытия даже после автоматической замены визуального модуля.
static func _surface_kind(object: Dictionary) -> String:
	var stored:=String(object.get("surface_kind",""))
	if not stored.is_empty(): return stored
	var basename:=String(object.get("asset_path","")).get_file().get_basename().to_lower()
	if basename.begins_with("grass_") or basename.ends_with("_grass") or basename=="grass": return "grass"
	if "water" in basename or basename.begins_with("shore_") or basename.begins_with("river_") or basename.begins_with("pond_"): return "water"
	if "sand" in basename: return "sand"
	if "gravel" in basename or "stone_road" in basename or "cobble" in basename: return "gravel"
	if "dirt" in basename or "soil" in basename or "mud" in basename: return "dirt"
	return ""


## Возвращает тип покрытия соседней клетки либо пустую строку за пределами нарисованной земли.
static func _neighbor_surface(cells: Dictionary, state: Dictionary, cell: Vector2i, layer: String) -> String:
	var index:=int(cells.get(_cell_layer_key(cell,layer),-1))
	return "" if index<0 else _surface_kind(state.objects[index])

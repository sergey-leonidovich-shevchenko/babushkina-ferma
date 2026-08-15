extends RefCounted

const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const DIRECTION_BITS := [1,2,4,8]


## Пересчитывает четырёхстороннюю маску соседей для каждого тайла земли одного ресурса.
static func rebuild_autotile_masks(state: Dictionary) -> void:
	var lookup: Dictionary = {}
	for index in state.objects.size():
		var object: Dictionary = state.objects[index]
		if _is_ground_tile(object): lookup[_tile_key(state,object)] = index
	for index in state.objects.size():
		var object: Dictionary = state.objects[index]
		if not _is_ground_tile(object): object.autotile_mask=0; state.objects[index]=object; continue
		var cell := _cell(state,Vector2(object.position)); var mask := 0; var family:=_family(String(object.asset_path)); var neighbor_asset:=family if not family.is_empty() else String(object.asset_path)
		for direction_index in DIRECTIONS.size():
			var neighbor_index: int = int(lookup.get(_key(cell+DIRECTIONS[direction_index],neighbor_asset,String(object.layer)),-1))
			if neighbor_index>=0: mask|=DIRECTION_BITS[direction_index]
		object.autotile_mask=mask; state.objects[index]=object
	_apply_visual_variants(state)


## Подставляет прямую, угол, развилку, крест или окончание для поддерживаемых дорожных семейств.
static func _apply_visual_variants(state: Dictionary) -> void:
	for index in state.objects.size():
		var object:Dictionary=state.objects[index]; var family:=_family(String(object.get("asset_path","")))
		if family.is_empty(): continue
		var variant:=_variant_for_mask(int(object.get("autotile_mask",0))); object.asset_path="res://assets/game/tiles/editor/%s/%s_%s.png"%["water" if family=="river" else "terrain",family,variant.kind]; object.rotation=variant.rotation; object.autotile_family=family; object.autotile_managed=true; state.objects[index]=object


## Выбирает канонический модуль и поворот по четырём битам N/E/S/W.
static func _variant_for_mask(mask: int) -> Dictionary:
	if mask==15: return {"kind":"cross","rotation":0.0}
	if mask in [7,11,13,14]: return {"kind":"t_junction","rotation":{11:0.0,7:PI*0.5,14:PI,13:-PI*0.5}[mask]}
	if mask in [3,6,9,12]: return {"kind":"corner","rotation":{3:0.0,6:PI*0.5,12:PI,9:-PI*0.5}[mask]}
	if mask==5: return {"kind":"vertical","rotation":0.0}
	if mask==10: return {"kind":"horizontal","rotation":0.0}
	return {"kind":"end","rotation":{0:0.0,1:0.0,2:PI*0.5,4:PI,8:-PI*0.5}.get(mask,0.0)}


## Проверяет структуру черновика, ресурсы, дубликаты клеток и опасные параметры перед экспортом.
static func validate(state: Dictionary) -> Dictionary:
	var errors: Array[String]=[]; var warnings: Array[String]=[]; var occupied: Dictionary={}; var ids: Dictionary={}
	if String(state.level_name).strip_edges().is_empty(): errors.append("У уровня нет названия")
	if int(state.grid) not in [12,24,48,96]: errors.append("Неизвестный размер сетки: %s"%state.grid)
	if state.objects.is_empty(): warnings.append("Карта пока пуста")
	for index in state.objects.size():
		var object: Dictionary=state.objects[index]; var label:="#%s %s"%[object.get("id",index),object.get("name","Объект")]
		if ids.has(object.get("id",index)): errors.append("Повторяется id %s"%object.get("id",index))
		ids[object.get("id",index)]=true
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


## Возвращает компактную строку результата для панели и журнала конструктора.
static func summary(report: Dictionary) -> String:
	if not report.valid: return "ПРОВЕРКА: %d ошибок · %d предупреждений"%[report.errors.size(),report.warnings.size()]
	return "ПРОВЕРКА: готово · %d объектов · %d предупреждений"%[report.checked,report.warnings.size()]


## Определяет тайл земли, который участвует в бесшовной четырёхсторонней связности.
static func _is_ground_tile(object: Dictionary) -> bool:
	return not bool(object.get("reference",false)) and String(object.get("anchor","center"))=="tile" and String(object.get("layer","objects")) in ["background","ground"]


## Строит ключ объекта по его сеточной клетке, ресурсу и слою.
static func _tile_key(state: Dictionary, object: Dictionary) -> String:
	return _key(_cell(state,Vector2(object.position)),_family(String(object.asset_path)) if not _family(String(object.asset_path)).is_empty() else String(object.asset_path),String(object.layer))


## Переводит мировую координату в малую клетку активной сетки конструктора.
static func _cell(state: Dictionary, position: Vector2) -> Vector2i:
	var grid:=maxi(1,int(state.grid)); return Vector2i(floori(position.x/grid),floori(position.y/grid))


## Формирует стабильный строковый ключ соседства для словаря автотайлов.
static func _key(cell: Vector2i, asset_path: String, layer: String) -> String:
	return "%d:%d:%s:%s"%[cell.x,cell.y,layer,asset_path]


## Узнаёт семейство модульной дороги независимо от текущего выбранного варианта.
static func _family(path: String) -> String:
	var basename:=path.get_file().get_basename()
	for family in ["dirt_path","stone_road","river"]:
		if basename.begins_with(family+"_"): return family
	return ""

extends RefCounted


## Возвращает все клетки прямоугольника между двумя углами включительно в порядке строк.
static func rectangle_cells(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var minimum:=Vector2i(mini(start.x,finish.x),mini(start.y,finish.y)); var maximum:=Vector2i(maxi(start.x,finish.x),maxi(start.y,finish.y))
	for y in range(minimum.y,maximum.y+1):
		for x in range(minimum.x,maximum.x+1): result.append(Vector2i(x,y))
	return result


## Копирует ресурс, слой, коллизию и область атласа объекта в активную кисть конструктора.
static func pick_object(state: Dictionary, object: Dictionary, categories: Array) -> bool:
	var path:=String(object.get("asset_path",""))
	if path.is_empty() or not ResourceLoader.exists(path): state.status="У референса нет доступного спрайта"; return false
	state.selected_asset=path; state.layer=String(object.get("layer","objects")); state.collision=bool(object.get("collision",false)); state.tool="paint"; state.drag_kind=""; state.scroll=0
	var source:=Rect2(object.get("source",Rect2()))
	state.slice_size=int(source.size.x) if source.size.x>0 and is_equal_approx(source.size.x,source.size.y) else 0; state.slice_index=0
	if int(state.slice_size)>0:
		var texture:=ResourceLoader.load(path) as Texture2D; var columns:=maxi(1,int(texture.get_width())/int(state.slice_size))
		state.slice_index=int(source.position.y/int(state.slice_size))*columns+int(source.position.x/int(state.slice_size))
	var category:=String(object.get("catalog_category",""))
	if category.is_empty(): category=_category_for_path(path)
	var category_index:=categories.find(category)
	if category_index>=0: state.category=category_index
	state.status="Пипетка: %s · кисть активна"%String(object.get("name",path.get_file().get_basename()))
	return true


## Определяет категорию выбранного объекта по тем же устойчивым папкам, не создавая зависимости от каталога.
static func _category_for_path(path: String) -> String:
	var lower:=path.to_lower()
	if "/tiles/" in lower:return "terrain"
	if "/buildings/" in lower:return "buildings"
	if "/characters/" in lower:return "characters"
	if "/enemies/" in lower or "/wildlife/" in lower:return "enemies"
	if "/items/" in lower or "/resources/" in lower or "/world_loot/" in lower:return "items"
	if "/farming/" in lower:return "farming"
	if "/fishing/" in lower:return "fishing"
	if "/environment/" in lower and ("tree" in lower or "plant" in lower or "mushroom" in lower or "orchard" in lower):return "vegetation"
	if "/environment/" in lower or "/world_polish/" in lower:return "decor"
	return "other"

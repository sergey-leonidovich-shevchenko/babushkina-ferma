extends RefCounted

const CELL_SIZE := 24
const NAVIGATION_HALF_WIDTH := 34.0
const FAMILY_DIRT := "dirt_path"
const FAMILY_STONE := "stone_road"
const ROOT := "res://assets/game/tiles/editor/terrain/"
const MODULE_KINDS := ["horizontal","vertical","corner","t_junction","cross","end"]
const MODULES := {
	FAMILY_DIRT:{
		"horizontal":preload("res://assets/game/tiles/editor/terrain/dirt_path_horizontal.png"), "vertical":preload("res://assets/game/tiles/editor/terrain/dirt_path_vertical.png"),
		"corner":preload("res://assets/game/tiles/editor/terrain/dirt_path_corner.png"), "t_junction":preload("res://assets/game/tiles/editor/terrain/dirt_path_t_junction.png"),
		"cross":preload("res://assets/game/tiles/editor/terrain/dirt_path_cross.png"), "end":preload("res://assets/game/tiles/editor/terrain/dirt_path_end.png"),
	},
	FAMILY_STONE:{
		"horizontal":preload("res://assets/game/tiles/editor/terrain/stone_road_horizontal.png"), "vertical":preload("res://assets/game/tiles/editor/terrain/stone_road_vertical.png"),
		"corner":preload("res://assets/game/tiles/editor/terrain/stone_road_corner.png"), "t_junction":preload("res://assets/game/tiles/editor/terrain/stone_road_t_junction.png"),
		"cross":preload("res://assets/game/tiles/editor/terrain/stone_road_cross.png"), "end":preload("res://assets/game/tiles/editor/terrain/stone_road_end.png"),
	},
}
const DIRECTIONS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const DIRECTION_BITS := [1,2,4,8]


## Возвращает единый data-профиль дороги для рендера, инспектора, редактора и проверки мировой сетки.
static func profile(family: String = FAMILY_DIRT) -> Dictionary:
	return {"family":family,"visual_size":Vector2(CELL_SIZE,CELL_SIZE),"anchor":"top_left","collision":Rect2(),"interaction_radius":0.0,"navigation_half_width":NAVIGATION_HALF_WIDTH}


## Растеризует все отрезки маршрутов в четырёхсвязные клетки 24 px без диагональных разрывов.
static func route_cells(paths: Array) -> Dictionary:
	var cells: Dictionary = {}
	for path in paths:
		for index in path.size()-1: _raster_segment(cells,world_cell(path[index]),world_cell(path[index+1]))
	return cells


## Добавляет один отрезок по алгоритму Брезенхэма и вставляет ортогональный мостик при диагональном шаге.
static func _raster_segment(cells: Dictionary, start: Vector2i, finish: Vector2i) -> void:
	var current:=start; var dx:=absi(finish.x-start.x); var sx:=1 if start.x<finish.x else -1; var dy:=-absi(finish.y-start.y); var sy:=1 if start.y<finish.y else -1; var error:=dx+dy
	while true:
		cells[current]=true
		if current==finish: break
		var twice:=2*error; var next:=current
		if twice>=dy: error+=dy; next.x+=sx
		if twice<=dx: error+=dx; next.y+=sy
		if next.x!=current.x and next.y!=current.y: cells[Vector2i(next.x,current.y)]=true
		current=next


## Переводит мировую позицию в верхнюю левую клетку общей пространственной сетки.
static func world_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x/CELL_SIZE),floori(position.y/CELL_SIZE))


## Вычисляет четырёхбитную маску N/E/S/W для выбора прямой, угла или развилки.
static func neighbor_mask(cell: Vector2i, cells: Dictionary) -> int:
	var mask:=0
	for index in DIRECTIONS.size():
		if cells.has(cell+DIRECTIONS[index]): mask|=DIRECTION_BITS[index]
	return mask


## Выбирает канонический модуль и поворот для любой из шестнадцати масок соседства.
static func variant_for_mask(mask: int) -> Dictionary:
	if mask==15: return {"kind":"cross","rotation":0.0}
	if mask in [7,11,13,14]: return {"kind":"t_junction","rotation":{11:0.0,7:PI*0.5,14:PI,13:-PI*0.5}[mask]}
	if mask in [3,6,9,12]: return {"kind":"corner","rotation":{3:0.0,6:PI*0.5,12:PI,9:-PI*0.5}[mask]}
	if mask==5: return {"kind":"vertical","rotation":0.0}
	if mask==10: return {"kind":"horizontal","rotation":0.0}
	return {"kind":"end","rotation":{0:0.0,1:0.0,2:PI*0.5,4:PI,8:-PI*0.5}.get(mask,0.0)}


## Возвращает отдельную crop-safe текстуру дорожного модуля без выборки соседней ячейки атласа.
static func texture(family: String, kind: String) -> Texture2D:
	return MODULES.get(family,MODULES[FAMILY_DIRT]).get(kind,MODULES[FAMILY_DIRT].horizontal)


## Подбирает спокойный сезонный tint, чтобы модульный слой не выглядел наклейкой поверх мастер-арта.
static func seasonal_tint(season: String) -> Color:
	return {"spring":Color(1.0,1.0,1.0,0.84),"summer":Color(0.96,1.0,0.90,0.84),"autumn":Color(1.0,0.88,0.68,0.84),"winter":Color(0.82,0.90,0.92,0.82)}.get(season,Color(1,1,1,0.84))


## Рисует одну дорожную клетку с каноническим поворотом вокруг её центра, не деформируя исходный PNG.
static func draw_module(canvas: Node2D, family: String, cell: Vector2i, mask: int, tint: Color = Color.WHITE) -> void:
	var variant:=variant_for_mask(mask); var destination:=Rect2(Vector2(cell)*CELL_SIZE,Vector2(CELL_SIZE,CELL_SIZE)); var source_texture:=texture(family,String(variant.kind))
	canvas.draw_set_transform(destination.get_center(),float(variant.rotation)); canvas.draw_texture_rect(source_texture,Rect2(-destination.size*0.5,destination.size),false,tint); canvas.draw_set_transform(Vector2.ZERO)


## Рисует живой дорожный слой первой локации и не перекрывает воду либо настил настоящего моста.
static func draw_first_location(canvas: Node2D, paths: Array, season: String) -> void:
	var cells:=route_cells(paths); var tint:=seasonal_tint(season)
	for cell in cells:
		var center:=(Vector2(cell)+Vector2(0.5,0.5))*CELL_SIZE
		if canvas.VillageLayoutSystem.is_on_bridge(center,4.0) or canvas.VillageLayoutSystem.is_water(center,2.0): continue
		draw_module(canvas,FAMILY_DIRT,cell,neighbor_mask(cell,cells),tint)

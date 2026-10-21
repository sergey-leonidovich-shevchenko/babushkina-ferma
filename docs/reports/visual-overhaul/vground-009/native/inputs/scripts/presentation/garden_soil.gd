extends RefCounted

const Map := preload("res://scripts/systems/village_map_data.gd")
const Meadow := preload("res://scripts/presentation/meadow_ground.gd")
const SOURCE := preload("res://assets/game/locations/overworld/modular/garden_loam_v1.png")
const FARM := Rect2(Vector2(Map.FARM_ORIGIN),Vector2(288,240))
const DRY := Color(1.10,1.04,0.94)
const WET := Color(0.57,0.64,0.65)
const IDLE := Color(1.20,1.16,1.06)
static var _texture: CanvasTexture
static var _base: ArrayMesh
static var _plots: Dictionary = {}

## Включает новый рисунок только на первой карте и возвращает прежний путь при откате флага.
static func enabled(game: Node) -> bool:
	var background := game.get_node_or_null("WorldBackground")
	return game.current_location=="overworld" and background!=null and background.soft_garden

## Сохраняет общий линейный семплер с mipmaps, не меняя ближайшую фильтрацию старых предметов.
static func texture() -> CanvasTexture:
	if _texture==null:
		_texture=CanvasTexture.new(); _texture.diffuse_texture=SOURCE
		_texture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_texture.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	return _texture

## Готовит ограниченный набор геометрии единожды; число клеток не зависит от времени игровой сессии.
static func warmup() -> void:
	if _base!=null: return
	_base=_mesh(FARM,4.0,false)
	for y in 5:
		for x in 6:
			var rect:=Rect2(FARM.position+Vector2(x,y)*48.0,Vector2(48,48))
			_plots[Vector2i(x,y)]=_mesh(rect,2.0,true)

## Рисует подготовленную землю с мягким краем внутри прежних границ участка и без ложных борозд.
static func draw_base(canvas: CanvasItem) -> void:
	warmup()
	canvas.draw_mesh(_base,texture(),Transform2D.IDENTITY,IDLE)

## Возвращает только домашнюю ячейку прежней сетки, не расширяя разрешённую область вспашки.
static func cell_for(rect: Rect2) -> Vector2i:
	var relative:=(rect.position-FARM.position)/48.0
	var cell:=Vector2i(relative.round())
	if rect.size!=Vector2(48,48) or not relative.is_equal_approx(Vector2(cell)) or cell.x<0 or cell.y<0 or cell.x>=6 or cell.y>=5: return Vector2i(-1,-1)
	return cell

## Рисует одну обработанную клетку; влажность меняет тон земли, но не геометрию и состояние культуры.
static func draw_plot(canvas: CanvasItem, rect: Rect2, plot: Dictionary, plots: Dictionary={}) -> void:
	var cell:=cell_for(rect)
	if cell==Vector2i(-1,-1):
		preload("res://scripts/systems/farm_visual_system.gd").draw_soil(canvas,rect,plot)
		return
	warmup()
	var contact:=contacts(cell,plot,plots)
	var meshes: Dictionary=canvas.get_meta(&"garden_soil_meshes",{})
	if not meshes.has(cell) or meshes[cell].contact!=contact:
		meshes[cell]={"contact":contact,"mesh":_plots[cell] if contact==0 else _mesh(rect,2.0,true,contact)}
		canvas.set_meta(&"garden_soil_meshes",meshes)
	canvas.draw_mesh(meshes[cell].mesh,texture(),Transform2D.IDENTITY,WET if bool(plot.get("watered",false)) else DRY)

## Убирает внутреннюю светлую сетку только между обработанными соседями одинаковой влажности.
static func contacts(cell: Vector2i, plot: Dictionary, plots: Dictionary) -> int:
	var result:=0; var directions:=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
	for index in 4:
		var neighbor: Dictionary=plots.get(cell+directions[index],{})
		if bool(neighbor.get("tilled",false)) and bool(neighbor.get("watered",false))==bool(plot.get("watered",false)): result|=1<<index
	return result

## Удерживает варианты у их владельца: другая сцена или предпросмотр не освобождают ещё видимый меш.
static func resource_ids(canvas: CanvasItem) -> Array:
	var result:=[_base.get_instance_id(),texture().get_instance_id()]
	for mesh: ArrayMesh in _plots.values(): result.append(mesh.get_instance_id())
	for entry: Dictionary in Dictionary(canvas.get_meta(&"garden_soil_meshes",{})).values(): result.append(entry.mesh.get_instance_id())
	return result

## Считает мягкое покрытие строго внутри осевого прямоугольника, не закрашивая соседнюю дорогу.
static func coverage(point: Vector2, rect: Rect2, worked: bool, contact: int=0) -> float:
	var local:=point-rect.position
	if local.x<0 or local.y<0 or local.x>rect.size.x or local.y>rect.size.y: return 0.0
	var sides:=[local.x,rect.size.x-local.x,local.y,rect.size.y-local.y]
	var edge:=100.0
	for index in 4:
		if not worked or (contact & (1<<index))==0: edge=minf(edge,float(sides[index]))
	var roughness:=0.35*sin(point.x*0.31)+0.25*sin(point.y*0.47)
	return smoothstep(0.0,2.2 if worked else 5.0,maxf(0.0,edge+minf(0.0,roughness)))

## Добавляет две неглубокие горизонтальные борозды без нового растра, узлов или анимационных часов.
static func furrow(point: Vector2, worked: bool) -> float:
	if not worked: return 1.0
	var y:=fposmod(point.y-FARM.position.y,48.0)
	var offset:=0.35*sin(point.x*0.14)
	var distance:=minf(absf(y-16.0-offset),absf(y-32.0-offset))
	return 1.0-0.25*exp(-distance*distance/3.5)

## Создаёт небольшой неизменяемый меш с мировой фазой материала и отдельной мягкой альфой.
static func _mesh(rect: Rect2, step: float, worked: bool, contact: int=0) -> ArrayMesh:
	var vertices:=PackedVector2Array(); var uvs:=PackedVector2Array(); var colors:=PackedColorArray(); var indices:=PackedInt32Array()
	var columns:=roundi(rect.size.x/step)+1; var rows:=roundi(rect.size.y/step)+1
	for y in rows:
		for x in columns:
			var point:=rect.position+Vector2(x,y)*step; var shade:=furrow(point,worked)
			vertices.append(point); uvs.append(Meadow.uv_at(point*0.5,Vector2i((point/384.0).floor())))
			colors.append(Color(shade,shade,shade,coverage(point,rect,worked,contact)))
	for y in rows-1:
		for x in columns-1:
			var i:=y*columns+x
			indices.append_array(PackedInt32Array([i,i+1,i+columns,i+1,i+columns+1,i+columns]))
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs; arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

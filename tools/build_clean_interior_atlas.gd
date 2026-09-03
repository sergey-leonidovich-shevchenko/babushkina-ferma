extends SceneTree

const SOURCE_PATH:="res://assets/game/world_polish/village_polish_atlas.png"
const OUTPUT_PATH:="res://assets/game/interiors/village_interior_atlas_v2.png"
const CELL_SIZE:=Vector2i(128,128)
const INTERIOR_CELLS:=[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(3,0),Vector2i(4,0)]
const SHADOW_COLOR:=Color(0.10,0.055,0.035,0.58)


## Загружает исходный атлас, очищает только внешнюю пурпурную кайму интерьерных ячеек и сохраняет воспроизводимый PNG.
func _initialize()->void:
	var image:=Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if image==null or image.get_size()!=Vector2i(640,512):
		push_error("Некорректный исходный интерьерный атлас")
		quit(1)
		return
	var changed:=0
	for cell in INTERIOR_CELLS: changed+=clean_cell(image,cell)
	var error:=image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error!=OK or changed<100:
		push_error("Не удалось собрать очищенный атлас: %s, пикселей %d"%[error,changed])
		quit(1)
		return
	print("INTERIOR ATLAS: заменено %d пурпурных пикселей"%changed)
	quit()


## Находит связанную с прозрачным фоном кайму одной ячейки и не затрагивает изолированные цвета внутри предмета.
static func clean_cell(image:Image,cell:Vector2i)->int:
	var origin:=cell*CELL_SIZE; var queue:Array[Vector2i]=[]; var marked:={}
	for y in CELL_SIZE.y:
		for x in CELL_SIZE.x:
			var local:=Vector2i(x,y); var pixel:=image.get_pixelv(origin+local)
			if is_magenta(pixel) and touches_transparency(image,origin,local):
				queue.append(local); marked[local]=true
	var cursor:=0
	while cursor<queue.size():
		var current:=queue[cursor]; cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			var neighbour:Vector2i=current+direction
			if neighbour.x<0 or neighbour.y<0 or neighbour.x>=CELL_SIZE.x or neighbour.y>=CELL_SIZE.y or marked.has(neighbour): continue
			if is_magenta(image.get_pixelv(origin+neighbour)):
				marked[neighbour]=true; queue.append(neighbour)
	for local in marked:
		var source:=image.get_pixelv(origin+local); var replacement:=SHADOW_COLOR; replacement.a=minf(source.a,SHADOW_COLOR.a)
		image.set_pixelv(origin+local,replacement)
	return marked.size()


## Отличает технический пурпурный fringe от красной ткани, синего металла и естественных тёплых теней предмета.
static func is_magenta(color:Color)->bool:
	return color.a>0.04 and color.r>0.20 and color.b>0.22 and color.g<minf(color.r,color.b)*0.62 and absf(color.r-color.b)<0.38


## Проверяет соседство пикселя с прозрачностью внутри строгой ячейки атласа.
static func touches_transparency(image:Image,origin:Vector2i,local:Vector2i)->bool:
	for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
		var neighbour:Vector2i=local+direction
		if neighbour.x<0 or neighbour.y<0 or neighbour.x>=CELL_SIZE.x or neighbour.y>=CELL_SIZE.y: return true
		if image.get_pixelv(origin+neighbour).a<0.04: return true
	return false

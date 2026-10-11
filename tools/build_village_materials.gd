extends SceneTree

## Нарезает существующий лист материалов без дорисовки и приводит новую траву к целому игровому масштабу.
func _initialize()->void:
	var root:="res://assets/game/locations/overworld/modular/"
	var meadow:=Image.load_from_file(root+"grass_meadow_v1.png")
	meadow.resize(384,384,Image.INTERPOLATE_NEAREST)
	meadow.save_png(root+"grass_meadow_tile_v1.png")
	var path:=Image.load_from_file(root+"path_source_v1.png")
	path.resize(384,384,Image.INTERPOLATE_NEAREST)
	path.save_png(root+"path_material_v1.png")
	var ground:=Image.load_from_file("res://assets/game/tiles/editor/source/editor_terrain_master_v1.png")
	var water:=Image.load_from_file("res://assets/game/tiles/editor/source/editor_water_master_v1.png")
	_save_tile(ground,Vector2i(3,0),root+"dirt_material_v1.png")
	_save_tile(ground,Vector2i(0,1),root+"stone_material_v1.png")
	_save_tile(water,Vector2i(0,0),root+"water_material_v1.png")
	_build_bridge(root)
	quit()

## Извлекает ровно одну ячейку 256×256 и сохраняет самостоятельный материал без соседних спрайтов.
func _save_tile(source:Image,cell:Vector2i,path:String)->void:
	# У листов есть белые технические границы; они не должны повторяться внутри воды и дороги.
	var tile:=source.get_region(Rect2i(cell*256+Vector2i(4,4),Vector2i(248,248)))
	tile.resize(192,192,Image.INTERPOLATE_NEAREST)
	tile.save_png(path)

## Изолирует фон вокруг моста и собирает короткий модуль из неизменных торцов и центральных досок.
func _build_bridge(root_path:String)->void:
	var image:=Image.load_from_file(root_path+"bridge_source_v1.png")
	image.convert(Image.FORMAT_RGBA8)
	var size:=image.get_size(); var bytes:=image.get_data(); var queue:=PackedInt32Array(); var visited:=PackedByteArray(); visited.resize(size.x*size.y)
	for x in size.x: queue.append(x); queue.append((size.y-1)*size.x+x)
	for y in size.y: queue.append(y*size.x); queue.append(y*size.x+size.x-1)
	var cursor:=0
	while cursor<queue.size():
		var index:=queue[cursor]; cursor+=1
		if visited[index]!=0: continue
		visited[index]=1
		var offset:=index*4; var low:=mini(bytes[offset],mini(bytes[offset+1],bytes[offset+2])); var high:=maxi(bytes[offset],maxi(bytes[offset+1],bytes[offset+2]))
		if bytes[offset+3]>10 and (low<175 or high-low>38): continue
		for channel in 4: bytes[offset+channel]=0
		var x:=index%size.x
		for adjacent in [index-size.x,index+size.x,index-1 if x>0 else -1,index+1 if x<size.x-1 else -1]:
			if adjacent>=0 and adjacent<size.x*size.y and visited[adjacent]==0: queue.append(adjacent)
	image=Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,bytes)
	var cropped:=image.get_region(image.get_used_rect())
	cropped.resize(128,roundi(cropped.get_height()*128.0/cropped.get_width()),Image.INTERPOLATE_NEAREST)
	var result:=Image.create(128,216,false,Image.FORMAT_RGBA8)
	result.blit_rect(cropped,Rect2i(0,0,128,24),Vector2i.ZERO)
	result.blit_rect(cropped,Rect2i(0,48,128,168),Vector2i(0,24))
	result.blit_rect(cropped,Rect2i(0,cropped.get_height()-24,128,24),Vector2i(0,192))
	var modular:=Image.create(144,216,false,Image.FORMAT_RGBA8)
	modular.blit_rect(result,Rect2i(0,0,128,216),Vector2i(8,0))
	modular.save_png(root_path+"bridge_modular_v1.png")

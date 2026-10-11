extends SceneTree

const ROOT:="res://assets/game/locations/overworld/modular/"
const KINDS:=["well","bench","lamp","board","cart","fence","gate","mill"]
const SIZES:=[Vector2i(120,120),Vector2i(96,72),Vector2i(48,120),Vector2i(120,96),Vector2i(120,96),Vector2i(96,48),Vector2i(72,72),Vector2i(288,240)]

## Нарезает новый авторский лист, сохраняет детали и готовит восемь самостоятельных PNG с прозрачностью.
func _initialize()->void:
	var atlas:=Image.load_from_file(ROOT+"village_props_source_v1.png")
	for index in KINDS.size():
		var x0:=roundi(float(index%4)*atlas.get_width()/4.0); var x1:=roundi(float(index%4+1)*atlas.get_width()/4.0)
		var y0:=roundi(float(index/4)*atlas.get_height()/2.0); var y1:=roundi(float(index/4+1)*atlas.get_height()/2.0)
		var image:=_extract_alpha(atlas.get_region(Rect2i(x0,y0,x1-x0,y1-y0)))
		var cropped:=image.get_region(image.get_used_rect()); var size:Vector2i=SIZES[index]
		var factor:=minf(float(size.x)/cropped.get_width(),float(size.y)/cropped.get_height())
		cropped.resize(maxi(1,roundi(cropped.get_width()*factor)),maxi(1,roundi(cropped.get_height()*factor)),Image.INTERPOLATE_NEAREST)
		var canvas:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
		canvas.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),Vector2i((size.x-cropped.get_width())/2,size.y-cropped.get_height()))
		canvas.save_png(ROOT+"prop_%s_v1.png"%KINDS[index])
	print("VILLAGE PROPS: 8 независимых спрайтов без полей соседних ячеек")
	quit()

## Превращает крупные нейтральные области технической подложки в альфа-канал; мелкие блики камня сохраняет.
func _extract_alpha(source:Image)->Image:
	source.convert(Image.FORMAT_RGBA8)
	var bytes:=source.get_data(); var size:=source.get_size(); var count:=size.x*size.y
	var candidates:=PackedByteArray(); candidates.resize(count); var visited:=PackedByteArray(); visited.resize(count)
	for index in count:
		var offset:=index*4; var low:=mini(bytes[offset],mini(bytes[offset+1],bytes[offset+2])); var high:=maxi(bytes[offset],maxi(bytes[offset+1],bytes[offset+2]))
		if low>=210 and high-low<=14: candidates[index]=1
	for first in count:
		if candidates[first]==0 or visited[first]!=0: continue
		var queue:=PackedInt32Array([first]); visited[first]=1; var cursor:=0
		while cursor<queue.size():
			var index:=queue[cursor]; cursor+=1; var x:=index%size.x
			for adjacent in [index-size.x,index+size.x,index-1 if x>0 else -1,index+1 if x<size.x-1 else -1]:
				if adjacent>=0 and adjacent<count and candidates[adjacent]!=0 and visited[adjacent]==0:
					visited[adjacent]=1; queue.append(adjacent)
		if queue.size()>64:
			for index in queue:
				for channel in 4: bytes[index*4+channel]=0
	return Image.create_from_data(size.x,size.y,false,Image.FORMAT_RGBA8,bytes)

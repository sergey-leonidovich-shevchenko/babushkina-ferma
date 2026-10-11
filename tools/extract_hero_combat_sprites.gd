extends SceneTree

const ROOT := "res://assets/game/characters/hero_v3/combat_v1/"

## Нарезает нерегулярные мастер-листы на независимые спрайты, исключая попавшие в crop кончики соседнего оружия.
func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"frames.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+"frames"))
	for kind in catalog:
		var master := Image.load_from_file(ProjectSettings.globalize_path(ROOT+kind+".png"))
		for index in catalog[kind].frames.size():
			var entry: Dictionary = catalog[kind].frames[index]
			var r: Array = entry.region
			var region := master.get_region(Rect2i(r[0],r[1],r[2],r[3]))
			var sprite := isolate(region,Vector2(entry.pivot[0],entry.pivot[1]))
			var draw_scale := 1.0 if kind=="bow-contact" else 0.32
			var factor := float(entry.scale)/draw_scale
			if not is_equal_approx(factor,1): sprite.resize(roundi(sprite.get_width()*factor),roundi(sprite.get_height()*factor),Image.INTERPOLATE_LANCZOS)
			entry.sprite="frames/%s-%02d.png" % [kind,index]
			entry.draw_pivot=[float(entry.pivot[0])*factor,float(entry.pivot[1])*factor]
			entry.draw_scale=draw_scale
			assert(sprite.save_png(ProjectSettings.globalize_path(ROOT+entry.sprite))==OK)
	FileAccess.open(ROOT+"frames.json",FileAccess.WRITE).store_string(JSON.stringify(catalog,"  ")+"\n")
	print("HERO EXTRACTION: 50 isolated RGBA sprites, original masters preserved")
	quit()

## Сохраняет исходные пиксели связной фигуры; отдельные фрагменты соседних ячеек не относятся к этому спрайту.
func isolate(source: Image, pivot: Vector2) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width(); var height := source.get_height()
	var bytes := source.get_data(); var visited := PackedByteArray(); visited.resize(width*height)
	var seed_index := -1
	# Середина туловища лежит над измеренной точкой стоп; соседний наконечник находится за пределами этой области.
	for y in range(roundi(pivot.y*0.5),roundi(pivot.y*0.85)):
		var x := clampi(roundi(pivot.x),0,width-1)
		if bytes[(y*width+x)*4+3] >= 16: seed_index=y*width+x; break
	assert(seed_index >= 0,"Sprite body must contain a connected foreground")
	var queue := PackedInt32Array([seed_index]); visited[seed_index]=1; var cursor:=0
	while cursor<queue.size():
		var index := queue[cursor]; cursor+=1
		var x := index%width
		for adjacent in [index-width,index+width,index-1 if x>0 else -1,index+1 if x<width-1 else -1]:
			if adjacent<0 or adjacent>=visited.size() or visited[adjacent]!=0 or bytes[adjacent*4+3]<16: continue
			visited[adjacent]=1; queue.append(adjacent)
	for index in visited.size():
		if visited[index]==0: bytes[index*4+3]=0
	return Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,bytes)

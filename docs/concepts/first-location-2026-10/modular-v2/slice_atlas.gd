extends SceneTree

const BASE := "res://docs/concepts/first-location-2026-10/modular-v2/"
const NAMES := ["bush","grass","flowers","stones","reeds","fern","leaves","berry_bush"]

## Нарезает прозрачный исходный атлас по ровным ячейкам и записывает области происхождения каждого PNG.
func _initialize() -> void:
	var source:=Image.load_from_file(ProjectSettings.globalize_path(BASE+"nature-atlas-v2.png"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BASE+"sprites"))
	var entries: Array=[]
	for i in NAMES.size():
		var x0:=roundi(float(i%4)*source.get_width()/4.0); var x1:=roundi(float(i%4+1)*source.get_width()/4.0)
		var y0:=roundi(float(i/4)*source.get_height()/2.0); var y1:=roundi(float(i/4+1)*source.get_height()/2.0)
		var cell:=Rect2i(x0,y0,x1-x0,y1-y0)
		var sprite:=source.get_region(cell); var used:=_visible_bounds(sprite)
		var margin:=8; var crop:=used.grow(margin).intersection(Rect2i(Vector2i.ZERO,sprite.get_size()))
		var result:=sprite.get_region(crop)
		var error:=result.save_png(ProjectSettings.globalize_path(BASE+"sprites/"+NAMES[i]+".png"))
		entries.append({"id":NAMES[i],"file":"sprites/"+NAMES[i]+".png","source_cell":[cell.position.x,cell.position.y,cell.size.x,cell.size.y],"crop":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"size":[result.get_width(),result.get_height()],"anchor":"bottom_center","alpha":true})
		print("SPRITE %s: %s, error %d"%[NAMES[i],result.get_size(),error])
	var output:=FileAccess.open(BASE+"sprites.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"schema":1,"atlas":"nature-atlas-v2.png","grid":[4,2],"sprites":entries},"\t")+"\n")
	quit()

## Находит видимую область объекта для нарезки, игнорируя почти прозрачный шум исходника вне силуэта.
func _visible_bounds(sprite: Image) -> Rect2i:
	var low:=sprite.get_size(); var high:=Vector2i(-1,-1)
	for y in sprite.get_height():
		for x in sprite.get_width():
			if sprite.get_pixel(x,y).a<0.1: continue
			low.x=mini(low.x,x); low.y=mini(low.y,y)
			high.x=maxi(high.x,x); high.y=maxi(high.y,y)
	return Rect2i(low,high-low+Vector2i.ONE)

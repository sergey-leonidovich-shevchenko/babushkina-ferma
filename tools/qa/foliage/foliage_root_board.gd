extends Node2D

const Roots:=preload("res://scripts/presentation/foliage_root_profile.gd")
const Ambient:=preload("res://scripts/systems/village_ambient_renderer.gd")
const Suite:=preload("res://tests/suites/foliage_root_suite.gd")
var entries:=[]
var textures:={}
var masks:={}
var page:=0
var observing:=false
var draw_frames:=[]

## Готовит только QA-текстуры и сохраняет точные одноканальные маски; в игре материалы не создаются.
func prepare(folder:String)->void:
	DirAccess.make_dir_recursive_absolute(folder)
	var atlas:=Image.load_from_file(ProjectSettings.globalize_path(Suite.ATLAS_PATH))
	for kind in Roots.PROFILES:
		var source:=Suite.source_image(kind,atlas);var data:=Roots.profile(kind);var mask:=Roots.build_mask(kind,source)
		textures[kind]=ImageTexture.create_from_image(source);masks[kind]=ImageTexture.create_from_image(mask)
		mask.save_png(folder.path_join(kind+".png"))
		var root_alpha:=roundi(source.get_pixelv(data.root).a*255)
		entries.append({"kind":kind,"mode":data.mode,"root":[data.root.x,data.root.y],"size":[data.size.x,data.size.y],"top":data.top,"lock_y":data.lock_y,"root_alpha":root_alpha,"mask_sha256":FileAccess.get_sha256(folder.path_join(kind+".png"))})

## Рисует четыре пары оригинал/маска с настоящими опорами; положение пикселей исходника не редактируется.
func _draw()->void:
	if observing:draw_frames.append(Engine.get_process_frames())
	draw_rect(Rect2(0,0,1152,648),Color("f3eddc"))
	var font:=ThemeDB.fallback_font
	draw_string(font,Vector2(28,38),"VFOLIAGE-001 | real roots and flexibility | "+str(page+1)+"/4",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("483e30"))
	draw_string(font,Vector2(28,65),"Cyan: root. Green: fixed base. Right: R8 weight. No wind or new art applied.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("6c6558"))
	for slot in 4:
		var i:=page*4+slot
		if i>=entries.size():continue
		var item:Dictionary=entries[i];var origin:=Vector2(28+(slot%2)*560,100+(slot/2)*260)
		var source_size:=Vector2(item.size[0],item.size[1]);var scale:=minf(225/source_size.x,210/source_size.y)
		var rect:=Rect2(origin+Vector2(0,23),source_size*scale);var right:=Rect2(rect.position+Vector2(265,0),rect.size)
		draw_string(font,origin,item.kind+" | "+item.mode+" | root "+str(item.root),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("433b31"))
		draw_rect(rect,Color("26352f"));draw_texture_rect(textures[item.kind],rect,false)
		draw_rect(right,Color.BLACK);draw_texture_rect(masks[item.kind],right,false)
		var point:=Roots.world_anchor(item.kind,rect)
		draw_line(point-Vector2(7,0),point+Vector2(7,0),Color.CYAN,2);draw_line(point-Vector2(0,7),point+Vector2(0,7),Color.CYAN,2)
		var lock:float=rect.position.y+float(item.lock_y)*scale
		draw_line(Vector2(rect.position.x,lock),Vector2(rect.end.x,lock),Color("8cbd72"),1)

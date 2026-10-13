extends SceneTree

const ROOT := "res://docs/concepts/house-furniture-2026-10-14/v1/"
const OUTPUT := "res://assets/game/interiors/furniture_a/"
const DIRECTIONS := ["south","west","north","east"]

## Нарезает выбранные мастера на самостоятельные текстуры, не меняя пропорции рисунков.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var base:=Image.load_from_file(ROOT+"furniture-a-clean.png")
	var extra:=Image.load_from_file(ROOT+"house-props-a.png")
	var rows:=[0,290,590,930,1285]
	var kinds:=["rustic_table","wooden_chair","wooden_wardrobe","bed"]
	for row in 4:
		var columns:=[0,320,630,900,1224] if row==3 else [0,365,620,930,1224]
		for column in 4: save_sprite(base,Rect2i(columns[column],rows[row],columns[column+1]-columns[column],rows[row+1]-rows[row]),kinds[row],column)
	rows=[0,380,720,1086]; kinds=["shop","woven_rug","home_chest"]
	var columns:=[0,520,720,1200,1448]
	for row in 3:
		for column in 4: save_sprite(extra,Rect2i(columns[column],rows[row],columns[column+1]-columns[column],rows[row+1]-rows[row]),kinds[row],column)
	var pottery:=Image.load_from_file(ROOT+"pottery-a.png")
	var pottery_columns:=[0,400,730,1100,1448]
	var pottery_rows:=[0,360,720,1086]
	for row in 3:
		for column in 4: save_sprite(pottery,Rect2i(pottery_columns[column],pottery_rows[row],pottery_columns[column+1]-pottery_columns[column],pottery_rows[row+1]-pottery_rows[row]),"pottery_"+str(row+1),column)
	var stairs:=Image.load_from_file(ROOT+"stairs-a.png")
	save_sprite(stairs,Rect2i(1086,0,543,724),"stairs",0)
	print("HOUSE FURNITURE: 28 furniture, 12 pottery, 1 house hatch"); quit()

## Удаляет почти прозрачную пыль, обрезает пустые поля и равномерно уменьшает целый силуэт.
func save_sprite(master: Image, region: Rect2i, kind: String, direction: int) -> void:
	var sprite:=master.get_region(region); sprite.convert(Image.FORMAT_RGBA8)
	for y in sprite.get_height():
		for x in sprite.get_width():
			if sprite.get_pixel(x,y).a<=0.08: sprite.set_pixel(x,y,Color.TRANSPARENT)
	sprite=sprite.get_region(sprite.get_used_rect())
	var scale:=240.0/maxf(sprite.get_width(),sprite.get_height())
	sprite.resize(maxi(1,roundi(sprite.get_width()*scale)),maxi(1,roundi(sprite.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
	var result:=Image.create(sprite.get_width()+16,sprite.get_height()+16,false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT); result.blit_rect(sprite,Rect2i(Vector2i.ZERO,sprite.get_size()),Vector2i(8,8))
	if result.save_png(OUTPUT+kind+"_"+DIRECTIONS[direction]+".png")!=OK: push_error("Не удалось сохранить мебель: "+kind)

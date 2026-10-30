extends Node2D

var data: Dictionary
var parts: Dictionary
var textures: Dictionary
var hero: Texture2D
var page := "stone"
var background := Color("f4efdf")
var camera := Vector2.ZERO
var candidate := true
var on_bridge := false
var show_grid := false
var wide_bridge := true

## Рисует каталог либо отдельный художественный участок при общей проекции viewport.
func _draw() -> void:
	draw_rect(Rect2(0,0,960,540),background)
	if page=="scene":
		draw_set_transform(-camera)
		_scene()
		draw_set_transform(Vector2.ZERO)
		return
	var ids: Array=[]
	for p: Dictionary in data.parts:
		if (page=="stone" and p.family=="stone") or (page=="reuse" and p.family in ["reference","bridge-wide"] and p.kind!="material"): ids.append(p.id)
	for i in ids.size():
		var pos:=Vector2(120+(i%4)*240,106+(i/4)*118)
		_sprite(ids[i],pos)
		_label(parts[ids[i]].label,pos+Vector2(-72,52),13)
	_label("16 береговых частей · 120% · без поворота освещённого PNG" if page=="stone" else "Земляной берег · прежний и расширенный настил · перила отдельно",Vector2(24,30),16)
	if page=="reuse": _hero(Vector2(840,450))

## Выбирает уже созданную текстуру и сохраняет исходный масштаб без растяжения по осям.
func _sprite(id: String, position_value: Vector2, flip := Vector2.ONE) -> void:
	var p: Dictionary=parts[id]
	var pivot:=Vector2(float(p.pivot[0]),float(p.pivot[1]))
	var size_value:=Vector2(float(p.rect[2]),float(p.rect[3]))
	var transform_before:=Transform2D(0,-camera) if page=="scene" else Transform2D.IDENTITY
	draw_set_transform_matrix(transform_before*Transform2D(0,flip,0,position_value))
	draw_texture_rect(textures[id],Rect2(-pivot*float(p.scale),size_value*float(p.scale)),false)
	draw_set_transform_matrix(transform_before)

## Повторяет принятую фактуру в пробных ячейках, не выдавая её за production-тайлинг.
func _material(rect: Rect2, id: String) -> void:
	var tex: Texture2D=textures[id]
	var tile:=Vector2(tex.get_size())*.375
	for yy in range(floori(rect.position.y/tile.y),ceili(rect.end.y/tile.y)):
		for xx in range(floori(rect.position.x/tile.x),ceili(rect.end.x/tile.x)):
			var origin:=Vector2(xx,yy)*tile
			var cut:=rect.intersection(Rect2(origin,tile))
			if not cut.has_area(): continue
			var vertices:=PackedVector2Array([cut.position,Vector2(cut.end.x,cut.position.y),cut.end,Vector2(cut.position.x,cut.end.y)])
			var uvs:=PackedVector2Array()
			for vertex: Vector2 in vertices:
				var uv: Vector2=(vertex-origin)/tile
				if posmod(xx,2)==1: uv.x=1-uv.x
				if posmod(yy,2)==1: uv.y=1-uv.y
				uvs.append(uv)
			draw_polygon(vertices,PackedColorArray([Color.WHITE]),uvs,tex)

## Сравнивает два берега на одной геометрии, не создавая новой игровой карты.
func _scene() -> void:
	_material(Rect2(-144,-144,1248,864),"meadow")
	_material(Rect2(456,-144,144,864),"water")
	for y in range(-108,649,72):
		if y>276 and y<396: continue
		if candidate:
			_sprite("stone-w",Vector2(456,y))
			_sprite("stone-e",Vector2(600,y))
		else:
			_sprite("bank-v",Vector2(442,y))
			_sprite("bank-v",Vector2(614,y),Vector2(-1,1))
	if candidate:
		_sprite("bridge-end-w",Vector2(444,306))
		_sprite("bridge-end-e",Vector2(612,306))
	var center:=Vector2(528,348 if wide_bridge else 336)
	_sprite("footing-a",Vector2(444,center.y))
	_sprite("footing-b",Vector2(612,center.y))
	if wide_bridge: _wide_deck(center)
	else: _sprite("bridge-deck",center)
	_sprite("bridge-rail",Vector2(528,318))
	if on_bridge: _hero(center+Vector2(0,18))
	else: _hero(Vector2(420,336))
	_sprite("bridge-rail",Vector2(528,383 if wide_bridge else 359))
	if show_grid:
		for x in range(-144,1105,24): draw_line(Vector2(x,-144),Vector2(x,720),Color(1,1,1,.12))
		for y in range(-144,721,24): draw_line(Vector2(-144,y),Vector2(1104,y),Color(1,1,1,.12))
		draw_rect(Rect2(432,312,192,72 if wide_bridge else 48),Color(1,.85,.4,.8),false,1)

## Стыкует две настоящие области настила с общим масштабом, без растяжения досок.
func _wide_deck(center: Vector2) -> void:
	var left_width: float=parts["bridge-deck-left"].rect[2]*parts["bridge-deck-left"].scale
	var right_width: float=parts["bridge-deck-right"].rect[2]*parts["bridge-deck-right"].scale
	_sprite("bridge-deck-left",center-Vector2(right_width/2,0))
	_sprite("bridge-deck-right",center+Vector2(left_width/2,0))

## Использует прежнюю позу как линейку роста, не принимая новую анимацию персонажа.
func _hero(feet: Vector2) -> void:
	var previous:=Transform2D(0,-camera) if page=="scene" else Transform2D.IDENTITY
	draw_set_transform_matrix(previous*Transform2D(0,feet))
	draw_texture_rect_region(hero,Rect2(-Vector2(96,160),Vector2(192,192)),Rect2(0,0,192,192))
	draw_set_transform_matrix(previous)

## Подписывает техническую витрину отдельно от игровых ресурсов.
func _label(text: String, position_value: Vector2, font_size: int) -> void:
	var color:=Color("ded7bb") if background.r<.3 else Color("483831")
	draw_string(ThemeDB.fallback_font,position_value,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
